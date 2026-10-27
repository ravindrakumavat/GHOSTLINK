import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/sos_request.dart';
import '../services/api_service.dart';
import '../services/mesh_service.dart';
import '../services/outbox_storage.dart';
import '../utils/api_exception.dart';

enum SosLoadState { idle, loading, loaded, error }

enum SosCreationResult { onlineSuccess, offlineQueued, failed }

enum NetworkStatus { online, offline, syncing }

/// State management for ResQMesh AI SOS incidents and Offline Outbox.
/// Automatically handles offline store-and-forward queuing and background sync.
class SosProvider extends ChangeNotifier {
  SosProvider({
    ApiService? apiService,
    OutboxStorage? outboxStorage,
    MeshService? meshService,
  })  : _apiService = apiService ?? ApiService(),
        _outboxStorage = outboxStorage ?? OutboxStorage(),
        _meshService = meshService {
    _initOutbox();
  }

  final ApiService _apiService;
  final OutboxStorage _outboxStorage;
  MeshService? _meshService;

  void setMeshService(MeshService service) {
    _meshService = service;
  }

  SosLoadState _state = SosLoadState.idle;
  SosRequest? _latestSos;
  List<SosRequest> _allSos = [];
  List<QueuedSos> _outbox = [];
  String? _errorMessage;

  bool _isSyncing = false;
  bool _isOnline = true;
  Timer? _autoSyncTimer;

  SosLoadState get state => _state;
  SosRequest? get latestSos => _latestSos;
  List<SosRequest> get allSos => _allSos;
  List<QueuedSos> get outbox => _outbox;
  int get queuedCount => _outbox.length;
  String? get errorMessage => _errorMessage;

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;

  NetworkStatus get networkStatus {
    if (_isSyncing) return NetworkStatus.syncing;
    if (!_isOnline || _outbox.isNotEmpty) return NetworkStatus.offline;
    return NetworkStatus.online;
  }

  Future<void> _initOutbox() async {
    _outbox = await _outboxStorage.loadQueue();
    notifyListeners();

    // Start periodic background auto-sync every 8 seconds
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_outbox.isNotEmpty && !_isSyncing) {
        syncOutbox();
      }
    });

    // Try initial sync if outbox already contains items from a previous session
    if (_outbox.isNotEmpty) {
      syncOutbox();
    }
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  /// Fetches all SOS requests from backend and synchronizes with the outbox.
  Future<void> fetchAllSos() async {
    _state = SosLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await _apiService.listSos(sort: 'newest');
      _allSos = results;
      _latestSos = results.isNotEmpty ? results.first : null;
      _isOnline = true;
      _state = SosLoadState.loaded;

      // When backend is reachable, trigger outbox synchronization
      if (_outbox.isNotEmpty && !_isSyncing) {
        syncOutbox();
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
      _isOnline = false;
      _state = SosLoadState.error;
    } catch (_) {
      _isOnline = false;
      _state = SosLoadState.error;
    }

    notifyListeners();
  }

  Future<void> fetchLatestSos() async {
    return fetchAllSos();
  }

  /// Submits an SOS request.
  /// If online: directly posts to FastAPI backend.
  /// If offline / timeout: saves to local Outbox and schedules automatic sync.
  Future<SosCreationResult> createSos(SosRequestCreate payload) async {
    _state = SosLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Attempt direct live backend transmission
      await _apiService.createSos(payload);
      _isOnline = true;
      await fetchAllSos();
      return SosCreationResult.onlineSuccess;
    } catch (error) {
      // 2. Offline Fallback: Queue locally in Outbox
      _isOnline = false;
      final localId = 'outbox_${DateTime.now().millisecondsSinceEpoch}_${payload.deviceId}';
      final queuedItem = QueuedSos(
        localId: localId,
        payload: payload,
        queuedAt: DateTime.now().toUtc(),
      );

      _outbox.add(queuedItem);
      await _outboxStorage.saveQueue(_outbox);

      _meshService?.logEvent('SOS', 'Created messageId=$localId');
      _meshService?.logEvent('OUTBOX', 'Queued messageId=$localId');
      _meshService?.updateDiagnostic(DiagnosticStage.sosCreated, true);
      _meshService?.updateDiagnostic(DiagnosticStage.outboxQueued, true);

      _state = SosLoadState.loaded;
      notifyListeners();
      return SosCreationResult.offlineQueued;
    }
  }

  /// Reloads the outbox from persistent storage.
  Future<void> refreshOutbox() async {
    _outbox = await _outboxStorage.loadQueue();
    notifyListeners();
  }

  /// Synchronizes all queued offline SOS requests to the FastAPI backend.
  Future<int> syncOutbox() async {
    if (_isSyncing || _outbox.isEmpty) return 0;

    _isSyncing = true;
    notifyListeners();

    int syncedCount = 0;
    final List<QueuedSos> pending = List.from(_outbox);

    for (final item in pending) {
      try {
        await _apiService.createSos(item.payload);
        // On verified receipt: remove from local outbox immediately
        await _outboxStorage.remove(item.localId);
        _outbox.removeWhere((q) => q.localId == item.localId);
        syncedCount++;
        _isOnline = true;
      } catch (_) {
        // Backend still unreachable: stop this sync pass and keep remaining in outbox
        _isOnline = false;
        break;
      }
    }

    if (syncedCount > 0) {
      try {
        final results = await _apiService.listSos(sort: 'newest');
        _allSos = results;
        _latestSos = results.isNotEmpty ? results.first : null;
      } catch (_) {}
    }

    _isSyncing = false;
    notifyListeners();
    return syncedCount;
  }

  /// Updates status of an incident on the backend.
  Future<SosRequest?> updateSosStatus(String uuid, SosStatus newStatus) async {
    try {
      final updated = await _apiService.updateSosStatus(uuid, newStatus);
      final index = _allSos.indexWhere((item) => item.uuid == uuid);
      if (index != -1) {
        _allSos[index] = updated;
      }
      if (_latestSos?.uuid == uuid) {
        _latestSos = updated;
      }
      _isOnline = true;
      notifyListeners();
      return updated;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return null;
    }
  }
}
