import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/mesh_provider.dart';
import '../providers/sos_provider.dart';
import '../services/mesh_service.dart';
import '../theme/theme.dart';
import '../widgets/glass_card.dart';

/// ResQMesh Network Screen with Manual, Highly-Reliable BLE Peer Discovery and Relay.
/// Allows the user to scan for nearby peers, inspect canonical deduplicated nodes,
/// explicitly initiate packet transfer to a chosen peer, and view diagnostic logs.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  int _activeSimulationStep = -1;
  bool _isSimulating = false;
  Timer? _simulationTimer;

  static const List<Map<String, dynamic>> _meshHops = [
    {
      'title': 'Victim Device',
      'subtitle': 'Distress Originator',
      'role': 'Originator',
      'icon': Icons.person_pin_circle,
      'color': AppColors.danger,
      'log': '[HOP 0] Victim device generates SOS packet with GPS coordinates, injury severity & battery percentage.',
    },
    {
      'title': 'Relay Node Alpha',
      'subtitle': 'Hop 1 • Mobile Peer',
      'role': 'Store-and-Forward Peer',
      'icon': Icons.cell_tower,
      'color': AppColors.warning,
      'log': '[HOP 1] Relay Node Alpha detects BLE transfer, validates payload integrity and caches packet.',
    },
    {
      'title': 'Relay Node Beta',
      'subtitle': 'Hop 2 • Perimeter Repeater',
      'role': 'Mesh Repeater',
      'icon': Icons.router,
      'color': AppColors.accentCyan,
      'log': '[HOP 2] Relay Node Beta receives packet, verifies hop count, and forwards to command gateway.',
    },
    {
      'title': 'Rescue Gateway',
      'subtitle': 'Uplink Node • Base Station',
      'role': 'Command Gateway',
      'icon': Icons.satellite_alt,
      'color': AppColors.primaryBlue,
      'log': '[HOP 3] Rescue Gateway ingests packet and transmits via LTE/satellite uplink to FastAPI backend.',
    },
    {
      'title': 'Command Centre',
      'subtitle': 'Rescue Dashboard',
      'role': 'Incident Triage',
      'icon': Icons.dashboard_customize,
      'color': AppColors.success,
      'log': '[DELIVERED] SOS recorded in SQLite, AI Priority scored, Responder Dashboard notified!',
    },
  ];

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _startSimulation() {
    if (_isSimulating) return;

    setState(() {
      _isSimulating = true;
      _activeSimulationStep = 0;
    });

    _advanceSimulationStep(1);
  }

  void _advanceSimulationStep(int step) {
    if (step >= _meshHops.length) {
      setState(() {
        _isSimulating = false;
      });
      return;
    }

    _simulationTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _activeSimulationStep = step;
      });
      _advanceSimulationStep(step + 1);
    });
  }

  void _resetSimulation() {
    _simulationTimer?.cancel();
    setState(() {
      _isSimulating = false;
      _activeSimulationStep = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final meshProvider = context.watch<MeshProvider>();
    final sosProvider = context.watch<SosProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('GHOSTLINK Network & BLE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.accentCyan),
            tooltip: 'Reset Diagnostics / Refresh',
            onPressed: () {
              _resetSimulation();
              meshProvider.resetDiagnostics();
              sosProvider.refreshOutbox();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, Color(0xFF10182B)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // BLE Transport Overview Card with Scan Peers Trigger
                _buildRealBleCard(context, meshProvider),
                const SizedBox(height: 14),

                // Canonical Discovered Peers List with Manual Relay Actions
                _buildPeerRegistrySection(context, meshProvider, sosProvider),
                const SizedBox(height: 14),

                // Diagnostic Packet Pipeline Tracker
                _buildDiagnosticPipelineCard(meshProvider),
                const SizedBox(height: 14),

                // Live BLE Activity Console
                _buildLiveLogsSection(meshProvider),
                const SizedBox(height: 20),

                // Multi-Hop Simulation Architecture Divider
                const Divider(height: 1, color: AppColors.glassBorder),
                const SizedBox(height: 16),

                // Conceptual Simulation Banner
                _buildPrototypeBanner(),
                const SizedBox(height: 14),

                // Multi-Hop Relay Animation
                const Text(
                  'Multi-Hop Store-and-Forward Topology',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _buildMeshDiagramCard(),
                const SizedBox(height: 16),

                // Simulation Trigger Action Bar
                _buildSimulationControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // REAL BLE TRANSPORT LAYER WIDGETS
  // ===========================================================================

  Widget _buildRealBleCard(BuildContext context, MeshProvider mesh) {
    final isBtOn = mesh.isBluetoothAvailable;
    final isAdv = mesh.isAdvertising;
    final isScanning = mesh.isScanning;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isBtOn ? AppColors.success : AppColors.danger,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isBtOn ? 'BLE TRANSPORT: ACTIVE' : 'BLE: BLUETOOTH OFF',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isAdv ? AppColors.accentCyan : AppColors.surfaceElevated)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isAdv ? AppColors.accentCyan : AppColors.glassBorder,
                  ),
                ),
                child: Text(
                  isAdv ? 'RELAY LISTENING' : 'STANDBY',
                  style: TextStyle(
                    color: isAdv ? AppColors.accentCyan : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.glassBorder),
          const SizedBox(height: 14),

          // Real Telemetry Statistics Grid
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  label: 'Discovered Peers',
                  value: '${mesh.peers.length}',
                  icon: Icons.cell_tower,
                ),
              ),
              Expanded(
                child: _buildMetric(
                  label: 'Relayed Packets',
                  value: '${mesh.relayedCount}',
                  icon: Icons.swap_calls_rounded,
                ),
              ),
              Expanded(
                child: _buildMetric(
                  label: 'Gateway Uplinks',
                  value: '${mesh.deliveredCount}',
                  icon: Icons.cloud_done_rounded,
                ),
              ),
              Expanded(
                child: _buildMetric(
                  label: 'Deduplicated',
                  value: '${mesh.duplicatesIgnoredCount}',
                  icon: Icons.filter_alt_off_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Scan Peers Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isScanning ? AppColors.surfaceElevated : AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isScanning ? null : () => mesh.scanForPeers(),
              icon: isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
                    )
                  : const Icon(Icons.bluetooth_searching, size: 20),
              label: Text(
                isScanning ? 'Scanning for Nearby GHOSTLINK Peers...' : 'Scan Peers',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CANONICAL PEER REGISTRY SECTION (ONE PHYSICAL DEVICE = ONE ROW)
  // ===========================================================================

  Widget _buildPeerRegistrySection(
    BuildContext context,
    MeshProvider mesh,
    SosProvider sos,
  ) {
    final peers = mesh.peers;
    final hasQueuedSos = sos.queuedCount > 0;
    final isTransferring = mesh.isTransferring;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.devices, size: 16, color: AppColors.accentCyan),
              const SizedBox(width: 8),
              const Text(
                'Discovered GHOSTLINK Peers',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${peers.length} found',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (peers.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: const Text(
                'No peers discovered yet.\nTap "Scan Peers" above to discover nearby GHOSTLINK devices.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
              ),
            )
          else
            Column(
              children: peers.map((peer) {
                final secondsAgo = DateTime.now().difference(peer.lastSeen).inSeconds;
                final lastSeenText = secondsAgo <= 1 ? 'Just now' : '${secondsAgo}s ago';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentCyan.withValues(alpha: 0.15),
                        ),
                        child: const Icon(Icons.phone_android, color: AppColors.accentCyan, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              peer.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${peer.deviceId} • Seen $lastSeenText • ${peer.rssi} dBm',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (hasQueuedSos)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: isTransferring
                              ? null
                              : () async {
                                  final success = await mesh.relayToPeer(peer);
                                  await sos.refreshOutbox();

                                  if (!context.mounted) return;
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('✓ Packet delivered to ${peer.name} (ACK confirmed)!'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Relay to ${peer.name} failed. Packet kept in outbox.'),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  }
                                },
                          icon: isTransferring && peer.isConnecting
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded, size: 14),
                          label: Text(
                            isTransferring && peer.isConnecting ? 'Relaying...' : 'Relay SOS',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'AVAILABLE',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DIAGNOSTIC PIPELINE CARD
  // ===========================================================================

  Widget _buildDiagnosticPipelineCard(MeshProvider mesh) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist_rtl_rounded, size: 16, color: AppColors.accentCyan),
              SizedBox(width: 6),
              Text(
                'Packet Pipeline Diagnostic',
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              Text(
                'Manual Test Mode',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.glassBorder),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildPipelineChip('SOS Created', mesh.getDiagnostic(DiagnosticStage.sosCreated)),
              _buildPipelineChip('Outbox Queued', mesh.getDiagnostic(DiagnosticStage.outboxQueued)),
              _buildPipelineChip('Mesh Packet', mesh.getDiagnostic(DiagnosticStage.meshPacketCreated)),
              _buildPipelineChip('GATT Connected', mesh.getDiagnostic(DiagnosticStage.gattConnected)),
              _buildPipelineChip('Char Ready', mesh.getDiagnostic(DiagnosticStage.characteristicFound)),
              _buildPipelineChip('Packet Sent', mesh.getDiagnostic(DiagnosticStage.packetWritten)),
              _buildPipelineChip('Packet Received', mesh.getDiagnostic(DiagnosticStage.packetReceived)),
              _buildPipelineChip('Gateway Uplink', mesh.getDiagnostic(DiagnosticStage.backendDelivered)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineChip(String label, bool isSuccess) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSuccess
            ? AppColors.success.withValues(alpha: 0.18)
            : AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSuccess ? AppColors.success : AppColors.glassBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 12,
            color: isSuccess ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            '$label: ${isSuccess ? "YES" : "NO"}',
            style: TextStyle(
              color: isSuccess ? Colors.white : AppColors.textSecondary,
              fontSize: 10,
              fontWeight: isSuccess ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveLogsSection(MeshProvider mesh) {
    final logs = mesh.activityLogs;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, size: 16, color: AppColors.accentCyan),
              const SizedBox(width: 6),
              const Text(
                'Real BLE Mesh Activity Console',
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => mesh.clearLogs(),
                child: const Text('Clear', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.glassBorder),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 140),
            child: logs.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Awaiting BLE network events...',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '❯ ${logs[index]}',
                          style: TextStyle(
                            color: index == 0 ? AppColors.textPrimary : AppColors.textSecondary,
                            fontSize: 11,
                            height: 1.3,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TOPOLOGY SIMULATION WALKTHROUGH WIDGETS
  // ===========================================================================

  Widget _buildPrototypeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.hub_outlined, color: AppColors.accentCyan, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Prototype Multi-Hop Topology: Demonstrates store-and-forward routing as packets traverse across multiple mesh hops.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.accentCyan),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  Widget _buildMeshDiagramCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (int i = 0; i < _meshHops.length; i++) ...[
            _buildHopRow(
              index: i,
              hop: _meshHops[i],
              isActive: _activeSimulationStep == i,
              isCompleted: _activeSimulationStep > i,
            ),
            if (i < _meshHops.length - 1)
              _buildHopConnector(
                isActive: _activeSimulationStep == i || _activeSimulationStep == i + 1,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildHopRow({
    required int index,
    required Map<String, dynamic> hop,
    required bool isActive,
    required bool isCompleted,
  }) {
    final color = hop['color'] as Color;
    final icon = hop['icon'] as IconData;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.22)
            : isCompleted
                ? AppColors.surfaceElevated.withValues(alpha: 0.6)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? color
              : isCompleted
                  ? color.withValues(alpha: 0.4)
                  : Colors.transparent,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? AppColors.success
                  : isActive
                      ? color
                      : color.withValues(alpha: 0.15),
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              color: (isCompleted || isActive) ? Colors.white : color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hop['title'] as String,
                  style: TextStyle(
                    color: isActive ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hop['subtitle'] as String,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'RELAYING',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
            )
          else
            Text(
              hop['role'] as String,
              style: TextStyle(
                color: isCompleted ? AppColors.success : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHopConnector({required bool isActive}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 28),
          Container(
            width: 2,
            height: 16,
            color: isActive ? AppColors.accentCyan : AppColors.glassBorder,
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.arrow_downward,
            size: 14,
            color: isActive ? AppColors.accentCyan : AppColors.textSecondary.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationControls() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _isSimulating ? AppColors.warning : AppColors.primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _isSimulating ? null : _startSimulation,
        icon: _isSimulating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.play_arrow_rounded, size: 22),
        label: Text(
          _isSimulating ? 'Simulating Multi-Hop Hop Progression...' : 'Simulate Multi-Hop SOS Relay',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
