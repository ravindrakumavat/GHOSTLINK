import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/mesh_provider.dart';
import '../providers/sos_provider.dart';
import '../theme/theme.dart';
import 'glass_card.dart';

/// Meaningful connection status card displaying live network connectivity,
/// store-and-forward outbox queue metrics, automatic BLE mesh peers, and sync actions.
class ConnectionStatusCard extends StatelessWidget {
  const ConnectionStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final sosProvider = context.watch<SosProvider>();
    final meshProvider = context.watch<MeshProvider>();

    final isSyncing = sosProvider.isSyncing;
    final isOnline = sosProvider.isOnline && sosProvider.queuedCount == 0;
    final queuedCount = sosProvider.queuedCount;
    final peerCount = meshProvider.peers.length;

    final Color indicatorColor = isSyncing
        ? AppColors.accentCyan
        : isOnline
            ? AppColors.success
            : AppColors.warning;

    final IconData statusIcon = isSyncing
        ? Icons.sync
        : isOnline
            ? Icons.cloud_done
            : Icons.cloud_off;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: indicatorColor.withValues(alpha: 0.15),
                ),
                child: isSyncing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.accentCyan,
                        ),
                      )
                    : Icon(statusIcon, color: indicatorColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isSyncing
                              ? 'SYNCING'
                              : isOnline
                                  ? 'ONLINE'
                                  : 'OFFLINE MODE',
                          style: TextStyle(
                            color: indicatorColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: indicatorColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: indicatorColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            queuedCount > 0 ? 'Queued SOS: $queuedCount' : '$peerCount BLE Peer(s)',
                            style: TextStyle(
                              color: indicatorColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSyncing
                          ? 'Synchronizing emergency requests to server...'
                          : isOnline
                              ? 'Connected to GHOSTLINK network. Automatic BLE peer relay active ($peerCount nearby).'
                              : 'Offline mode. Automatic BLE mesh relay enabled ($peerCount peer(s) in range).',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Action row if there are queued items or when offline
          if (queuedCount > 0 || !isOnline) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.glassBorder),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bluetooth_audio, size: 14, color: AppColors.accentCyan),
                    const SizedBox(width: 6),
                    Text(
                      queuedCount > 0
                          ? '$queuedCount pending auto-relay'
                          : 'Auto-relay listening ($peerCount peers)',
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: isSyncing
                      ? null
                      : () async {
                          final synced = await sosProvider.syncOutbox();
                          if (!context.mounted) return;

                          if (synced > 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ Successfully synced $synced emergency request(s)!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } else if (!sosProvider.isOnline) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("You're offline. Automatic BLE mesh is relaying to nearby peers."),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                          }
                        },
                  icon: isSyncing
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accentCyan),
                        )
                      : const Icon(Icons.sync, size: 16, color: AppColors.accentCyan),
                  label: Text(
                    isSyncing ? 'Syncing...' : 'Sync Now',
                    style: const TextStyle(
                      color: AppColors.accentCyan,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
