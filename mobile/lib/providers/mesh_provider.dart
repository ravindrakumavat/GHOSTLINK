import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/ble_peer_node.dart';
import '../models/mesh_packet.dart';
import '../services/mesh_service.dart';

/// State management for the ResQMesh BLE Mesh Transport Layer.
/// Manages manual BLE advertising, peer discovery, canonical peer registry,
/// and user-controlled relay to selected peers.
class MeshProvider extends ChangeNotifier {
  final MeshService _meshService;
  StreamSubscription<MeshPacket>? _packetSub;
  StreamSubscription<String>? _logSub;
  StreamSubscription<MapEntry<DiagnosticStage, bool>>? _diagSub;

  final List<String> _activityLogs = [];
  final Map<DiagnosticStage, bool> _pipelineState = {
    DiagnosticStage.sosCreated: false,
    DiagnosticStage.outboxQueued: false,
    DiagnosticStage.meshPacketCreated: false,
    DiagnosticStage.gattConnected: false,
    DiagnosticStage.characteristicFound: false,
    DiagnosticStage.packetWritten: false,
    DiagnosticStage.packetReceived: false,
    DiagnosticStage.backendDelivered: false,
  };

  bool _isBluetoothAvailable = true;

  MeshProvider({MeshService? meshService})
      : _meshService = meshService ?? MeshService() {
    _init();
  }

  void _init() {
    // Listen for incoming BLE mesh packets
    _packetSub = _meshService.packetStream.listen((packet) {
      notifyListeners();
    });

    // Listen for live mesh activity logs
    _logSub = _meshService.logStream.listen((log) {
      _activityLogs.insert(0, log);
      if (_activityLogs.length > 60) {
        _activityLogs.removeLast();
      }
      notifyListeners();
    });

    // Listen for diagnostic stage updates
    _diagSub = _meshService.diagnosticStream.listen((entry) {
      _pipelineState[entry.key] = entry.value;
      notifyListeners();
    });

    // Check adapter state
    FlutterBluePlus.adapterState.listen((state) {
      _isBluetoothAvailable = (state == BluetoothAdapterState.on);
      notifyListeners();
    });
  }

  // Getters
  bool get isBluetoothAvailable => _isBluetoothAvailable;
  bool get isAdvertising => _meshService.isAdvertising;
  bool get isScanning => _meshService.isScanning;
  bool get isTransferring => _meshService.isTransferring;
  List<MeshPacket> get receivedPackets => _meshService.receivedPackets;
  List<BlePeerNode> get peers => _meshService.peers;
  List<String> get discoveredNodes => _meshService.discoveredNodes;
  List<String> get activityLogs => List.unmodifiable(_activityLogs);
  int get relayedCount => _meshService.relayedCount;
  int get deliveredCount => _meshService.deliveredCount;
  int get duplicatesIgnoredCount => _meshService.duplicatesIgnoredCount;

  bool getDiagnostic(DiagnosticStage stage) => _pipelineState[stage] ?? false;

  /// Starts advertising ResQMesh BLE service.
  Future<bool> startRelayListener() async {
    final success = await _meshService.startAdvertising();
    notifyListeners();
    return success;
  }

  /// Stops advertising ResQMesh BLE service.
  Future<void> stopRelayListener() async {
    await _meshService.stopAdvertising();
    notifyListeners();
  }

  /// Manually starts a controlled BLE peer scan.
  Future<void> scanForPeers({Duration timeout = const Duration(seconds: 8)}) async {
    await _meshService.scanForNearbyNodes(timeout: timeout);
    notifyListeners();
  }

  /// Manually relays the pending outbox SOS packet to the selected peer.
  Future<bool> relayToPeer(BlePeerNode peer) async {
    final success = await _meshService.relayPendingPacketToPeer(peer);
    notifyListeners();
    return success;
  }

  /// Ingests a packet manually or for testing.
  Future<void> ingestPacket(MeshPacket packet) async {
    await _meshService.ingestPacket(packet);
    notifyListeners();
  }

  void resetDiagnostics() {
    for (final key in _pipelineState.keys.toList()) {
      _pipelineState[key] = false;
    }
    notifyListeners();
  }

  void clearLogs() {
    _activityLogs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _packetSub?.cancel();
    _logSub?.cancel();
    _diagSub?.cancel();
    _meshService.dispose();
    super.dispose();
  }
}
