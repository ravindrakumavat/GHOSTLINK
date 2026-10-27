import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/sos_request.dart';
import '../providers/sos_provider.dart';
import '../theme/theme.dart';
import '../utils/routes.dart';
import '../widgets/glass_card.dart';

enum IncidentSortMode {
  priorityHighFirst,
  newestFirst,
  oldestFirst,
}

/// Responder / Command Centre Incident Queue Dashboard.
/// Displays all SOS distress requests, prioritized by AI score,
/// with filter chips for status/priority and direct access to incident details.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  PriorityLevel? _selectedPriority;
  SosStatus? _selectedStatus;
  IncidentSortMode _sortMode = IncidentSortMode.priorityHighFirst;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SosProvider>().fetchAllSos();
      }
    });
  }

  List<SosRequest> _filterAndSortIncidents(List<SosRequest> incidents) {
    var filtered = incidents.where((item) {
      if (_selectedPriority != null && item.priorityLevel != _selectedPriority) {
        return false;
      }
      if (_selectedStatus != null && item.status != _selectedStatus) {
        return false;
      }
      return true;
    }).toList();

    switch (_sortMode) {
      case IncidentSortMode.priorityHighFirst:
        // Sort highest priority score first, then newest
        filtered.sort((a, b) {
          final scoreComparison = b.priorityScore.compareTo(a.priorityScore);
          if (scoreComparison != 0) return scoreComparison;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case IncidentSortMode.newestFirst:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case IncidentSortMode.oldestFirst:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final sosProvider = context.watch<SosProvider>();
    final allIncidents = sosProvider.allSos;
    final displayIncidents = _filterAndSortIncidents(allIncidents);

    final highPriorityCount = allIncidents
        .where((i) => i.priorityLevel == PriorityLevel.high && i.status != SosStatus.rescued)
        .length;
    final pendingCount = allIncidents
        .where((i) => i.status == SosStatus.pending)
        .length;
    final rescuedCount = allIncidents
        .where((i) => i.status == SosStatus.rescued)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.accentCyan),
            tooltip: 'Refresh queue',
            onPressed: () => context.read<SosProvider>().fetchAllSos(),
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
          child: Column(
            children: [
              // Outbox Sync Banner (if queued offline SOS exist)
              if (sosProvider.queuedCount > 0)
                _buildOutboxBanner(context, sosProvider),

              // Summary Stats Bar
              _buildStatsRow(
                total: allIncidents.length,
                highPriority: highPriorityCount,
                pending: pendingCount,
                rescued: rescuedCount,
              ),

              // Filter & Sort Section
              _buildFilterSection(),

              // Incident List or Empty / Loading State
              Expanded(
                child: _buildListContent(sosProvider, displayIncidents),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutboxBanner(BuildContext context, SosProvider sosProvider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.outbox_rounded, color: AppColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${sosProvider.queuedCount} offline SOS pending sync',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: sosProvider.isSyncing
                  ? null
                  : () async {
                      final count = await sosProvider.syncOutbox();
                      if (!context.mounted) return;
                      if (count > 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✓ Synced $count queued request(s)!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
              child: Text(
                sosProvider.isSyncing ? 'Syncing...' : 'Sync Now',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow({
    required int total,
    required int highPriority,
    required int pending,
    required int rescued,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              label: 'Total',
              count: total.toString(),
              color: AppColors.textPrimary,
              icon: Icons.list_alt,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatItem(
              label: 'Critical',
              count: highPriority.toString(),
              color: AppColors.danger,
              icon: Icons.warning_amber_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatItem(
              label: 'Pending',
              count: pending.toString(),
              color: AppColors.warning,
              icon: Icons.hourglass_top_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatItem(
              label: 'Rescued',
              count: rescued.toString(),
              color: AppColors.success,
              icon: Icons.check_circle_outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                count,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Sort Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<IncidentSortMode>(
                value: _sortMode,
                isDense: true,
                dropdownColor: AppColors.surfaceElevated,
                icon: const Icon(Icons.sort, size: 16, color: AppColors.accentCyan),
                items: const [
                  DropdownMenuItem(
                    value: IncidentSortMode.priorityHighFirst,
                    child: Text('Urgency (AI Rank)', style: TextStyle(fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: IncidentSortMode.newestFirst,
                    child: Text('Newest First', style: TextStyle(fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: IncidentSortMode.oldestFirst,
                    child: Text('Oldest First', style: TextStyle(fontSize: 12)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _sortMode = val);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Priority Filter Chips
          _buildFilterChip(
            label: 'All Urgencies',
            isSelected: _selectedPriority == null,
            onSelected: (_) => setState(() => _selectedPriority = null),
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            label: 'HIGH',
            isSelected: _selectedPriority == PriorityLevel.high,
            selectedColor: AppColors.danger,
            onSelected: (_) => setState(() => _selectedPriority = PriorityLevel.high),
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            label: 'MEDIUM',
            isSelected: _selectedPriority == PriorityLevel.medium,
            selectedColor: AppColors.warning,
            onSelected: (_) => setState(() => _selectedPriority = PriorityLevel.medium),
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            label: 'LOW',
            isSelected: _selectedPriority == PriorityLevel.low,
            selectedColor: AppColors.success,
            onSelected: (_) => setState(() => _selectedPriority = PriorityLevel.low),
          ),
          const SizedBox(width: 10),

          // Status Filter Chips
          _buildFilterChip(
            label: 'All Statuses',
            isSelected: _selectedStatus == null,
            onSelected: (_) => setState(() => _selectedStatus = null),
          ),
          const SizedBox(width: 6),
          ...SosStatus.values.map((s) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildFilterChip(
                label: s.apiValue,
                isSelected: _selectedStatus == s,
                selectedColor: AppColors.primaryBlue,
                onSelected: (_) => setState(() => _selectedStatus = s),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
    Color? selectedColor,
  }) {
    final activeColor = selectedColor ?? AppColors.accentCyan;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textSecondary)),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: activeColor.withValues(alpha: 0.3),
      checkmarkColor: activeColor,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? activeColor : AppColors.glassBorder,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  Widget _buildListContent(SosProvider sosProvider, List<SosRequest> incidents) {
    if (sosProvider.state == SosLoadState.loading && sosProvider.allSos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.accentCyan),
        ),
      );
    }

    if (sosProvider.state == SosLoadState.error && sosProvider.allSos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppColors.danger),
              const SizedBox(height: 12),
              Text(
                sosProvider.errorMessage ?? 'Failed to load incident queue.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.read<SosProvider>().fetchAllSos(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (incidents.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            const Text(
              'No incidents match current filters',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedPriority = null;
                  _selectedStatus = null;
                });
              },
              child: const Text('Clear Filters', style: TextStyle(color: AppColors.accentCyan)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accentCyan,
      backgroundColor: AppColors.surfaceElevated,
      onRefresh: () => context.read<SosProvider>().fetchAllSos(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: incidents.length,
        itemBuilder: (context, index) {
          final incident = incidents[index];
          return _buildIncidentCard(incident);
        },
      ),
    );
  }

  Widget _buildIncidentCard(SosRequest incident) {
    final priorityColor = switch (incident.priorityLevel) {
      PriorityLevel.high => AppColors.danger,
      PriorityLevel.medium => AppColors.warning,
      PriorityLevel.low => AppColors.success,
    };

    final timeString = _formatTimestamp(incident.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          // Navigate to Incident Details (or pass arguments)
          Navigator.pushNamed(
            context,
            AppRoutes.incidentDetails,
            arguments: incident,
          );
        },
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Victim Name & Priority Badge
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
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Reported $timeString',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildPriorityScorePill(
                    score: incident.priorityScore,
                    level: incident.priorityLevel,
                    color: priorityColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.glassBorder),
              const SizedBox(height: 12),

              // Details Grid: Victims, Injury, Emergency, Battery
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildMetaTag(
                    icon: Icons.people_outline,
                    label: '${incident.victimCount} victim${incident.victimCount > 1 ? 's' : ''}',
                    color: AppColors.textPrimary,
                  ),
                  _buildMetaTag(
                    icon: Icons.medical_services_outlined,
                    label: incident.injuryType.apiValue,
                    color: AppColors.accentCyan,
                  ),
                  _buildMetaTag(
                    icon: Icons.battery_charging_full,
                    label: '${incident.batteryPercentage}% battery',
                    color: incident.batteryPercentage <= 20
                        ? AppColors.danger
                        : AppColors.textSecondary,
                  ),
                  _buildMetaTag(
                    icon: Icons.location_on_outlined,
                    label: '${incident.latitude.toStringAsFixed(3)}, ${incident.longitude.toStringAsFixed(3)}',
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Bottom Row: Status Badge and View Chevron
              Row(
                children: [
                  _buildStatusPill(incident.status),
                  const Spacer(),
                  const Text(
                    'Details',
                    style: TextStyle(
                      color: AppColors.accentCyan,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.accentCyan,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityScorePill({
    required double score,
    required PriorityLevel level,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 14, color: color),
          const SizedBox(width: 3),
          Text(
            '${score.toStringAsFixed(0)} • ${level.apiValue}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(SosStatus status) {
    final (statusColor, statusIcon) = switch (status) {
      SosStatus.pending => (AppColors.warning, Icons.pending_outlined),
      SosStatus.received => (AppColors.primaryBlue, Icons.mark_email_read_outlined),
      SosStatus.assigned => (AppColors.accentCyan, Icons.assignment_ind_outlined),
      SosStatus.rescued => (AppColors.success, Icons.check_circle_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 13, color: statusColor),
          const SizedBox(width: 5),
          Text(
            status.apiValue,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now().toUtc();
    final difference = now.difference(dt);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}
