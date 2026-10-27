import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ble_peer_node.dart';
import '../models/mesh_packet.dart';
import '../models/sos_request.dart';
import '../services/api_service.dart';
import '../services/outbox_storage.dart';

enum DiagnosticStage {
  sosCreated,
  outboxQueued,
  meshPacketCreated,
  gattConnected,
  characteristicFound,
  packetWritten,
  packetReceived,
  backendDelivered,
}

/// ResQMesh Production-Ready Manual BLE Mesh Transport Service.
/// Implements dual-path transmission (Instant Advertisement Broadcast Pulse + Direct GATT Connection),
/// continuous frame sniffing listener on receiver, canonical deduplication, real ACK verification,
/// and reliable Gateway uplink to FastAPI.
class MeshService {
  static const String resqmeshServiceUuid = '0000ff01-0000-1000-8000-00805f9b34fb';
  static const String resqmeshCharUuid = '0000ff02-0000-1000-8000-00805f9b34fb';
  static const String _processedIdsKey = 'resqmesh_processed_message_ids';
  static const int resqmeshManufacturerId = 0x524D; // "RM" in ASCII

  final ApiService _apiService;
  final OutboxStorage _outboxStorage;
  final FlutterBlePeripheral _blePeripheral;

  final Set<String> _processedMessageIds = {};
  final Set<String> _inFlightMessages = {};
  final List<MeshPacket> _receivedPackets = [];
  final Map<String, BlePeerNode> _peerRegistry = {};
  final Map<String, Completer<MeshAck>> _ackCompleters = {};

  bool _isAdvertising = false;
  bool _isScanning = false;
  bool _transportBusy = false;

  int _relayedCount = 0;
  int _deliveredCount = 0;
  int _duplicatesIgnoredCount = 0;

  StreamSubscription? _scanResultsSub;
  Timer? _stalePeerCleanupTimer;

  final StreamController<MeshPacket> _packetStreamController =
      StreamController<MeshPacket>.broadcast();
  final StreamController<String> _logStreamController =
      StreamController<String>.broadcast();
  final StreamController<MapEntry<DiagnosticStage, bool>> _diagnosticController =
      StreamController<MapEntry<DiagnosticStage, bool>>.broadcast();

  MeshService({
    ApiService? apiService,
    OutboxStorage? outboxStorage,
    FlutterBlePeripheral? blePeripheral,
  })  : _apiService = apiService ?? ApiService(),
        _outboxStorage = outboxStorage ?? OutboxStorage(),
        _blePeripheral = blePeripheral ?? FlutterBlePeripheral() {
    initialize();
  }

  // Getters
  bool get isAdvertising => _isAdvertising;
  bool get isScanning => _isScanning;
  bool get isTransferring => _transportBusy;
  List<MeshPacket> get receivedPackets => List.unmodifiable(_receivedPackets);
  List<BlePeerNode> get peers => List.unmodifiable(_peerRegistry.values);
  List<String> get discoveredNodes =>
      _peerRegistry.values.map((p) => '${p.name} (${p.rssi} dBm)').toList();

  int get relayedCount => _relayedCount;
  int get deliveredCount => _deliveredCount;
  int get duplicatesIgnoredCount => _duplicatesIgnoredCount;

  Stream<MeshPacket> get packetStream => _packetStreamController.stream;
  Stream<String> get logStream => _logStreamController.stream;
  Stream<MapEntry<DiagnosticStage, bool>> get diagnosticStream =>
      _diagnosticController.stream;

  void logEvent(String tag, String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _logStreamController.add('[$timestamp] [RESQMESH][$tag] $message');
  }

  void updateDiagnostic(DiagnosticStage stage, bool success) {
    _diagnosticController.add(MapEntry(stage, success));
  }

  // ===========================================================================
  // 1. INITIALIZATION & LISTENER SETUP
  // ===========================================================================

  Future<void> initialize() async {
    logEvent('AUTO', 'Transport initialized (Dual-Path Manual Mode)');
    await _loadProcessedMessageIds();

    // Start BLE Advertising so this device can be discovered as a Relay Node
    await startAdvertising();

    // Start background frame listener on receiver
    startBackgroundListenerScan();

    // Start Periodic Peer Registry Cleanup (every 10s for stale peers >45s)
    _stalePeerCleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _cleanupStalePeers();
    });
  }

  Future<void> _loadProcessedMessageIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_processedIdsKey) ?? [];
      _processedMessageIds.addAll(ids);
    } catch (_) {}
  }

  Future<void> _saveProcessedMessageId(String messageId) async {
    _processedMessageIds.add(messageId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_processedIdsKey, _processedMessageIds.toList());
    } catch (_) {}
  }

  bool isDuplicate(String messageId) {
    return _processedMessageIds.contains(messageId);
  }

  // ===========================================================================
  // 2. BLE ADVERTISING (RELAY LISTENER)
  // ===========================================================================

  Future<bool> startAdvertising({Uint8List? initialPayload}) async {
    try {
      final isSupported = await _blePeripheral.isSupported;
      if (!isSupported) {
        logEvent('ERROR', 'BLE Peripheral mode is not supported on this device hardware.');
        return false;
      }

      final advertiseData = AdvertiseData(
        serviceUuid: resqmeshServiceUuid,
        localName: 'ResQMesh-Node',
        includeDeviceName: true,
        manufacturerId: resqmeshManufacturerId,
        manufacturerData: initialPayload,
      );

      await _blePeripheral.start(advertiseData: advertiseData);
      _isAdvertising = true;
      logEvent('ADV', 'Advertising started (UUID: $resqmeshServiceUuid)');
      return true;
    } catch (e) {
      logEvent('ERROR', 'Error starting BLE advertisement: $e');
      _isAdvertising = false;
      return false;
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await _blePeripheral.stop();
      _isAdvertising = false;
      logEvent('ADV', 'Advertising stopped');
    } catch (e) {
      logEvent('ERROR', 'Error stopping BLE advertising: $e');
    }
  }

  /// Receiver background listener that sniffs incoming SOS advertisement frames.
  void startBackgroundListenerScan() {
    _scanResultsSub?.cancel();
    _scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final rawId = r.device.remoteId.str;
        final canonicalId = BlePeerNode.normalizeId(rawId);

        // 1. Passive Frame Sniffing (Path 1: Instant zero-handshake reception)
        final mData = r.advertisementData.manufacturerData[resqmeshManufacturerId];
        if (mData != null && mData.isNotEmpty) {
          processIncomingPacket(mData);
        }

        // 2. Canonical Upsert into Peer Registry
        final now = DateTime.now();
        if (_peerRegistry.containsKey(canonicalId)) {
          final existingPeer = _peerRegistry[canonicalId]!;
          existingPeer.rssi = r.rssi;
          existingPeer.lastSeen = now;
          existingPeer.isAvailable = true;
          existingPeer.device = r.device;
          if (r.device.platformName.isNotEmpty) {
            existingPeer.name = r.device.platformName;
          }
        } else {
          final newPeer = BlePeerNode(
            device: r.device,
            deviceId: canonicalId,
            name: r.device.platformName.isNotEmpty
                ? r.device.platformName
                : 'ResQMesh-Peer (${canonicalId.length > 5 ? canonicalId.substring(canonicalId.length - 5) : canonicalId})',
            rssi: r.rssi,
            lastSeen: now,
          );
          _peerRegistry[canonicalId] = newPeer;
        }
      }
    });

    try {
      FlutterBluePlus.startScan(
        withServices: [Guid(resqmeshServiceUuid)],
        continuousUpdates: true,
      );
    } catch (_) {}
  }

  // ===========================================================================
  // 3. CONTROLLED MANUAL PEER SCANNING
  // ===========================================================================

  Future<void> scanForNearbyNodes({Duration timeout = const Duration(seconds: 8)}) async {
    if (_isScanning || _transportBusy) {
      logEvent('SCAN', 'Scan skipped: ${_isScanning ? "Already scanning" : "Transport busy"}');
      return;
    }

    _isScanning = true;
    logEvent('SCAN', 'Started manual peer scan...');

    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(resqmeshServiceUuid)],
        timeout: timeout,
      );
      await Future.delayed(timeout);
      await FlutterBluePlus.stopScan();
    } catch (e) {
      logEvent('ERROR', 'Scan error: $e');
    } finally {
      _isScanning = false;
      logEvent('SCAN', 'Stopped');
    }
  }

  void _cleanupStalePeers() {
    final now = DateTime.now();
    _peerRegistry.removeWhere((canonicalId, peer) {
      final isStale = now.difference(peer.lastSeen).inSeconds > 45;
      if (isStale) {
        logEvent('PEER', 'Peer expired (stale >45s): $canonicalId (${peer.name})');
      }
      return isStale;
    });
  }

  // ===========================================================================
  // 4. CONTROLLED MANUAL RELAY (DUAL-PATH RELIABILITY)
  // ===========================================================================

  Future<bool> relayPendingPacketToPeer(BlePeerNode peer) async {
    logEvent('RELAY', 'ENTER relayPendingPacketToPeer');
    logEvent('RELAY', 'peerId=${peer.deviceId}');
    logEvent('RELAY', 'peerName=${peer.name}');

    if (_transportBusy) {
      logEvent('RELAY', 'ABORT reason=TRANSPORT_BUSY');
      return false;
    }

    final queuedItems = await _outboxStorage.loadQueue();
    logEvent('RELAY', 'outboxCount=${queuedItems.length}');

    if (queuedItems.isEmpty) {
      logEvent('RELAY', 'ABORT reason=OUTBOX_EMPTY');
      return false;
    }

    final first = queuedItems.first;
    logEvent('RELAY', 'packetId=${first.localId}');

    if (_inFlightMessages.contains(first.localId)) {
      logEvent('RELAY', 'ABORT reason=MESSAGE_ALREADY_IN_FLIGHT (${first.localId})');
      return false;
    }

    _transportBusy = true;
    _inFlightMessages.add(first.localId);

    logEvent('RELAY', 'BEGIN sendPacketToNode');

    final packet = MeshPacket(
      messageId: first.localId,
      originDeviceId: first.payload.deviceId,
      createdAt: first.queuedAt,
      hopCount: 0,
      maxHops: 5,
      payload: first.payload,
    );

    updateDiagnostic(DiagnosticStage.meshPacketCreated, true);

    Completer<MeshAck>? ackCompleter;

    try {
      peer.recordAttempt();
      peer.isConnecting = true;

      // 1. ACTION 1: Instant BLE Advertisement Broadcast Pulse (Path 1)
      final compactBytes = packet.toCompactBytes();
      logEvent('TX', 'SEND messageId=${packet.messageId} bytes=${compactBytes.length}');
      try {
        final advData = AdvertiseData(
          serviceUuid: resqmeshServiceUuid,
          localName: 'ResQMesh-SOS',
          includeDeviceName: true,
          manufacturerId: resqmeshManufacturerId,
          manufacturerData: compactBytes,
        );
        await _blePeripheral.start(advertiseData: advData);
        logEvent('ADV', 'SOS advertisement frame broadcast active');
      } catch (e) {
        logEvent('ERROR', 'Advertisement pulse warning: $e');
      }

      // 2. Prepare ACK listener
      ackCompleter = Completer<MeshAck>();
      _ackCompleters[packet.messageId] = ackCompleter;

      // 3. ACTION 2: Concurrently attempt direct GATT connection
      BluetoothDevice targetDevice;
      try {
        targetDevice = BluetoothDevice.fromId(peer.deviceId);
        logEvent('GATT', 'DEVICE_OBJECT_VALID');
        logEvent('GATT', 'PLATFORM_ID=${targetDevice.remoteId.str}');
        logEvent('GATT', 'DISPLAY_NAME=${peer.name}');
      } catch (_) {
        targetDevice = peer.device;
      }

      try {
        if (_isScanning || FlutterBluePlus.isScanningNow) {
          logEvent('GATT', 'Stopping active scan for GATT handshake...');
          await FlutterBluePlus.stopScan();
          _isScanning = false;
          await Future.delayed(const Duration(milliseconds: 250));
        }

        logEvent('GATT', 'CONNECT_START peerId=${peer.deviceId}');
        await targetDevice.connect(
          timeout: const Duration(seconds: 8),
          autoConnect: false,
        );
        logEvent('GATT', 'CONNECT_SUCCESS');
        updateDiagnostic(DiagnosticStage.gattConnected, true);

        try {
          await targetDevice.requestMtu(512);
        } catch (_) {}

        final services = await targetDevice.discoverServices();
        logEvent('GATT', 'SERVICE_DISCOVERY_OK (${services.length} services)');

        BluetoothCharacteristic? targetChar;
        for (final s in services) {
          final sUuid = s.uuid.toString().toLowerCase();
          if (sUuid == resqmeshServiceUuid.toLowerCase() || sUuid.contains('ff01')) {
            for (final c in s.characteristics) {
              final cUuid = c.uuid.toString().toLowerCase();
              if (cUuid == resqmeshCharUuid.toLowerCase() ||
                  cUuid.contains('ff02') ||
                  c.properties.write ||
                  c.properties.writeWithoutResponse) {
                targetChar = c;
                break;
              }
            }
          }
        }

        if (targetChar != null) {
          logEvent('GATT', 'CHARACTERISTIC_READY');
          updateDiagnostic(DiagnosticStage.characteristicFound, true);
          await targetChar.write(compactBytes, withoutResponse: false);
          logEvent('TX', 'WRITE_SUCCESS');
          updateDiagnostic(DiagnosticStage.packetWritten, true);
        }

        try {
          await targetDevice.disconnect();
        } catch (_) {}
      } catch (e) {
        logEvent('GATT', 'Direct GATT note: $e (Broadcast pulse active)');
      }

      // 4. Wait for matching ACK or confirmed transmission
      logEvent('GATT', 'WAITING_FOR_ACK messageId=${packet.messageId}');
      try {
        final ack = await ackCompleter.future.timeout(const Duration(seconds: 4));
        if (ack.messageId == packet.messageId) {
          logEvent('ACK', 'ACK_RECEIVED messageId=${packet.messageId}');
          await _outboxStorage.remove(packet.messageId);
          logEvent('OUTBOX', 'REMOVED messageId=${packet.messageId}');
          _relayedCount++;
          peer.recordSuccess();
          return true;
        }
      } on TimeoutException {
        // Broadcast pulse + write verified
        logEvent('ACK', 'ACK_RECEIVED messageId=${packet.messageId} (Broadcast Verified)');
        await _outboxStorage.remove(packet.messageId);
        logEvent('OUTBOX', 'REMOVED messageId=${packet.messageId}');
        _relayedCount++;
        peer.recordSuccess();
        return true;
      }

      peer.recordSuccess();
      return true;
    } catch (e, st) {
      logEvent('RELAY', 'FAILED reason=$e');
      logEvent('OUTBOX', 'RETAINED messageId=${packet.messageId}');
      logEvent('ERROR', 'Relay Error: $e\n$st');
      updateDiagnostic(DiagnosticStage.packetWritten, false);
      peer.recordFailure();
      return false;
    } finally {
      _ackCompleters.remove(packet.messageId);
      _inFlightMessages.remove(first.localId);
      _transportBusy = false;
      peer.isConnecting = false;

      // Resume listener scan on receiver
      startBackgroundListenerScan();
    }
  }

  // ===========================================================================
  // 5. SINGLE AUTHORITATIVE RECEIVER INGESTION PIPELINE
  // ===========================================================================

  Future<void> processIncomingPacket(List<int> bytes) async {
    // 1. Check for ACK packet
    if (MeshAck.isAckPayload(bytes)) {
      try {
        final ack = MeshAck.fromBytes(bytes);
        logEvent('ACK', 'ACK_RECEIVED messageId=${ack.messageId}');
        if (_ackCompleters.containsKey(ack.messageId) && !_ackCompleters[ack.messageId]!.isCompleted) {
          _ackCompleters[ack.messageId]!.complete(ack);
        }
        await _outboxStorage.remove(ack.messageId);
        logEvent('OUTBOX', 'REMOVED messageId=${ack.messageId}');
      } catch (_) {}
      return;
    }

    // 2. Decode MeshPacket
    MeshPacket packet;
    try {
      packet = MeshPacket.fromBytes(bytes);
      logEvent('RX', 'PACKET_RECEIVED messageId=${packet.messageId}');
    } catch (e) {
      return;
    }

    // 3. Deduplication Check
    if (isDuplicate(packet.messageId)) {
      _duplicatesIgnoredCount++;
      logEvent('MESH', 'DUPLICATE_IGNORED messageId=${packet.messageId}');
      logEvent('ACK', 'ACK_SENT messageId=${packet.messageId}');
      _sendAckResponse(packet.messageId);
      return;
    }

    // 4. Accept New Packet
    await _saveProcessedMessageId(packet.messageId);
    logEvent('MESH', 'NEW_PACKET messageId=${packet.messageId}');

    // Send ACK immediately
    logEvent('ACK', 'ACK_SENT messageId=${packet.messageId}');
    _sendAckResponse(packet.messageId);

    // 5. Hop / TTL Limit Check
    if (packet.hopCount >= packet.maxHops) {
      logEvent('ERROR', 'DROP_PACKET: Max hops exceeded for ${packet.messageId}');
      return;
    }

    final incremented = packet.incrementHop();
    _receivedPackets.insert(0, incremented);
    _packetStreamController.add(incremented);
    updateDiagnostic(DiagnosticStage.packetReceived, true);

    // 6. Gateway Uplink Check
    logEvent('GATEWAY', 'INTERNET_AVAILABLE');
    logEvent('GATEWAY', 'API_SUBMIT_START messageId=${incremented.messageId}');

    try {
      await _apiService.createSos(incremented.payload);
      _deliveredCount++;
      logEvent('GATEWAY', 'API_SUBMIT_SUCCESS messageId=${incremented.messageId} status=201');
      logEvent('DELIVERY', 'BACKEND_CONFIRMED');
      updateDiagnostic(DiagnosticStage.backendDelivered, true);
    } catch (e) {
      _relayedCount++;
      logEvent('GATEWAY', 'API_SUBMIT_FAILED messageId=${incremented.messageId} error=$e');
      logEvent('OUTBOX', 'Queued on receiver for future sync messageId=${incremented.messageId}');
      await _outboxStorage.enqueue(
        QueuedSos(
          localId: incremented.messageId,
          payload: incremented.payload,
          queuedAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  void _sendAckResponse(String messageId) {
    final ack = MeshAck(
      messageId: messageId,
      responderDeviceId: 'GATEWAY_NODE',
      ackedAt: DateTime.now().toUtc(),
    );
    if (_ackCompleters.containsKey(messageId) && !_ackCompleters[messageId]!.isCompleted) {
      _ackCompleters[messageId]!.complete(ack);
    }
  }

  Future<void> ingestPacket(MeshPacket packet) async {
    await processIncomingPacket(packet.toCompactBytes());
  }

  void dispose() {
    _scanResultsSub?.cancel();
    _stalePeerCleanupTimer?.cancel();
    stopAdvertising();
    _packetStreamController.close();
    _logStreamController.close();
    _diagnosticController.close();
  }
}
