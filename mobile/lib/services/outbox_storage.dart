import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sos_request.dart';

/// Lightweight persistent local storage service for the ResQMesh SOS Outbox.
/// Uses SharedPreferences to ensure queued distress messages survive app restarts.
class OutboxStorage {
  static const String _outboxKey = 'resqmesh_sos_outbox_queue';

  /// Loads all locally queued SOS requests from disk.
  Future<List<QueuedSos>> loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_outboxKey) ?? [];

      return rawList.map((rawJson) {
        final Map<String, dynamic> decoded = jsonDecode(rawJson) as Map<String, dynamic>;
        return QueuedSos.fromJson(decoded);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves the full queue of SOS requests to disk.
  Future<void> saveQueue(List<QueuedSos> queue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = queue.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_outboxKey, stringList);
    } catch (_) {
      // Ignored
    }
  }

  /// Enqueues a new SOS request to local persistence.
  Future<void> enqueue(QueuedSos item) async {
    final current = await loadQueue();
    current.add(item);
    await saveQueue(current);
  }

  /// Removes an SOS request by its unique local identifier after successful backend receipt.
  Future<void> remove(String localId) async {
    final current = await loadQueue();
    current.removeWhere((item) => item.localId == localId);
    await saveQueue(current);
  }

  /// Clears the entire outbox queue.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_outboxKey);
  }
}
