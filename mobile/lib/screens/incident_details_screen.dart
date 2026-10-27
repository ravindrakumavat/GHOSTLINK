import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/sos_request.dart';
import '../providers/sos_provider.dart';
import '../theme/theme.dart';
import '../widgets/glass_card.dart';

/// Incident Details Screen with interactive status workflow.
/// Allows responders to view full telemetry, GPS, priority scores,
/// and transition incidents through the PENDING -> RECEIVED -> ASSIGNED -> RESCUED lifecycle.
class IncidentDetailsScreen extends StatefulWidget {
  const IncidentDetailsScreen({super.key, this.incident});

  final SosRequest? incident;

  @override
  State<IncidentDetailsScreen> createState() => _IncidentDetailsScreenState();
}

class _IncidentDetailsScreenState extends State<IncidentDetailsScreen> {
  SosRequest? _incident;
  bool _isUpdatingStatus = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_incident == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is SosRequest) {
        _incident = args;
      } else if (widget.incident != null) {
        _incident = widget.incident;
      }
    }
  }

  Future<void> _updateStatus(SosStatus newStatus) async {
    final incident = _incident;
    if (incident == null || _isUpdatingStatus) return;

    setState(() => _isUpdatingStatus = true);

    try {
      final updated = await context.read<SosProvider>().updateSosStatus(
            incident.uuid,
            newStatus,
          );

      if (!mounted) return;

      if (updated != null) {
        setState(() {
          _incident = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.apiValue}'),
            backgroundColor: AppColors.surfaceElevated,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update incident status.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final incident = _incident;

    if (incident == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Incident Details')),
        body: const Center(
          child: Text(
            'No incident data provided.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final priorityColor = switch (incident.priorityLevel) {
      PriorityLevel.high => AppColors.danger,
      PriorityLevel.medium => AppColors.warning,
      PriorityLevel.low => AppColors.success,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Details'),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Card: Victim Name & AI Priority Score
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  incident.victimName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'UUID: ${incident.uuid}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: priorityColor.withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${incident.priorityScore.toStringAsFixed(0)} / 100',
                                  style: TextStyle(
                                    color: priorityColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  '${incident.priorityLevel.apiValue} PRIORITY',
                                  style: TextStyle(
                                    color: priorityColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.glassBorder),
                      const SizedBox(height: 16),

                      // Status & Reported Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Current Status: ',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                              _buildStatusBadge(incident.status),
                            ],
                          ),
                          Text(
                            _formatDate(incident.createdAt),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Responder Status Action Workflow Card
                const Text(
                  'Incident Response Workflow',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _buildStatusActionCard(incident),
                const SizedBox(height: 16),

                // Distress Telemetry & Victim Info Grid
                const Text(
                  'Distress Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.people,
                        label: 'Victim Count',
                        value: '${incident.victimCount} person(s)',
                        iconColor: AppColors.primaryBlue,
                      ),
                      const Divider(height: 16, color: AppColors.glassBorder),
                      _buildInfoRow(
                        icon: Icons.medical_services,
                        label: 'Injury Type',
                        value: incident.injuryType.apiValue,
                        iconColor: AppColors.danger,
                      ),
                      const Divider(height: 16, color: AppColors.glassBorder),
                      _buildInfoRow(
                        icon: Icons.warning_rounded,
                        label: 'Emergency Level',
                        value: incident.emergencyLevel.apiValue,
                        iconColor: AppColors.warning,
                      ),
                      const Divider(height: 16, color: AppColors.glassBorder),
                      _buildInfoRow(
                        icon: Icons.battery_charging_full,
                        label: 'Device Battery',
                        value: '${incident.batteryPercentage}%',
                        iconColor: incident.batteryPercentage <= 20
                            ? AppColors.danger
                            : AppColors.success,
                      ),
                      const Divider(height: 16, color: AppColors.glassBorder),
                      _buildInfoRow(
                        icon: Icons.phone_android,
                        label: 'Device ID',
                        value: incident.deviceId,
                        iconColor: AppColors.accentCyan,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // GPS Location Telemetry
                const Text(
                  'GPS Coordinates',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.my_location,
                        label: 'Latitude',
                        value: incident.latitude.toStringAsFixed(6),
                        iconColor: AppColors.accentCyan,
                      ),
                      const Divider(height: 16, color: AppColors.glassBorder),
                      _buildInfoRow(
                        icon: Icons.location_searching,
                        label: 'Longitude',
                        value: incident.longitude.toStringAsFixed(6),
                        iconColor: AppColors.accentCyan,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusActionCard(SosRequest incident) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Progression Line
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildProgressStep('PENDING', incident.status == SosStatus.pending, incident.status.index >= 0),
              _buildProgressDivider(incident.status.index >= 1),
              _buildProgressStep('RECEIVED', incident.status == SosStatus.received, incident.status.index >= 1),
              _buildProgressDivider(incident.status.index >= 2),
              _buildProgressStep('ASSIGNED', incident.status == SosStatus.assigned, incident.status.index >= 2),
              _buildProgressDivider(incident.status.index >= 3),
              _buildProgressStep('RESCUED', incident.status == SosStatus.rescued, incident.status.index >= 3),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.glassBorder),
          const SizedBox(height: 16),

          // Primary Workflow Button
          if (incident.status != SosStatus.rescued) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getNextStatusColor(incident.status),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isUpdatingStatus
                    ? null
                    : () {
                        final next = _getNextStatus(incident.status);
                        if (next != null) _updateStatus(next);
                      },
                icon: _isUpdatingStatus
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_getNextStatusIcon(incident.status), size: 20),
                label: Text(
                  _getNextStatusLabel(incident.status),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Incident Successfully Resolved & Rescued',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Manual Status Quick-Select Chips
          const Text(
            'Override Status:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: SosStatus.values.map((status) {
                final isCurrent = incident.status == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(status.apiValue, style: const TextStyle(fontSize: 11)),
                    selected: isCurrent,
                    onSelected: _isUpdatingStatus || isCurrent
                        ? null
                        : (_) => _updateStatus(status),
                    selectedColor: AppColors.accentCyan.withValues(alpha: 0.3),
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isCurrent ? AppColors.accentCyan : AppColors.glassBorder,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(String label, bool isCurrent, bool isDone) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? AppColors.accentCyan
                : isCurrent
                    ? AppColors.primaryBlue
                    : AppColors.surfaceElevated,
            border: Border.all(
              color: isCurrent ? AppColors.accentCyan : AppColors.glassBorder,
              width: 1.5,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 14, color: Colors.black)
                : Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isCurrent ? AppColors.accentCyan : AppColors.textSecondary,
            fontSize: 9,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressDivider(bool isDone) {
    return Expanded(
      child: Container(
        height: 2,
        color: isDone ? AppColors.accentCyan : AppColors.glassBorder,
        margin: const EdgeInsets.only(bottom: 14),
      ),
    );
  }

  SosStatus? _getNextStatus(SosStatus current) {
    switch (current) {
      case SosStatus.pending:
        return SosStatus.received;
      case SosStatus.received:
        return SosStatus.assigned;
      case SosStatus.assigned:
        return SosStatus.rescued;
      case SosStatus.rescued:
        return null;
    }
  }

  String _getNextStatusLabel(SosStatus current) {
    switch (current) {
      case SosStatus.pending:
        return 'Acknowledge (Mark RECEIVED)';
      case SosStatus.received:
        return 'Assign Rescue Team (Mark ASSIGNED)';
      case SosStatus.assigned:
        return 'Confirm Rescue (Mark RESCUED)';
      case SosStatus.rescued:
        return 'Completed';
    }
  }

  Color _getNextStatusColor(SosStatus current) {
    switch (current) {
      case SosStatus.pending:
        return AppColors.primaryBlue;
      case SosStatus.received:
        return AppColors.accentCyan;
      case SosStatus.assigned:
        return AppColors.success;
      case SosStatus.rescued:
        return AppColors.surfaceElevated;
    }
  }

  IconData _getNextStatusIcon(SosStatus current) {
    switch (current) {
      case SosStatus.pending:
        return Icons.mark_email_read_outlined;
      case SosStatus.received:
        return Icons.assignment_ind_outlined;
      case SosStatus.assigned:
        return Icons.check_circle_outlined;
      case SosStatus.rescued:
        return Icons.done_all;
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(SosStatus status) {
    final (statusColor, statusIcon) = switch (status) {
      SosStatus.pending => (AppColors.warning, Icons.pending_outlined),
      SosStatus.received => (AppColors.primaryBlue, Icons.mark_email_read_outlined),
      SosStatus.assigned => (AppColors.accentCyan, Icons.assignment_ind_outlined),
      SosStatus.rescued => (AppColors.success, Icons.check_circle_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 12, color: statusColor),
          const SizedBox(width: 4),
          Text(
            status.apiValue,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
