import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../providers/sos_provider.dart';
import '../theme/theme.dart';
import 'glass_card.dart';

/// Displays the most recent SOS request's status on the Home screen,
/// backed entirely by [SosProvider]. No SOS creation happens here -
/// Phase 1 only reads whatever the backend already has via
/// GET /api/sos.
class LatestSosStatusCard extends StatelessWidget {
  const LatestSosStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final sosProvider = context.watch<SosProvider>();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Latest SOS Status',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                color: AppColors.accentCyan,
                onPressed: () => context.read<SosProvider>().fetchLatestSos(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildContent(context, sosProvider),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, SosProvider sosProvider) {
    switch (sosProvider.state) {
      case SosLoadState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        );
      case SosLoadState.error:
        return Text(
          sosProvider.errorMessage ?? 'Unable to load SOS status.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.danger),
        );
      case SosLoadState.loaded:
        final latest = sosProvider.latestSos;
        if (latest == null) {
          return Text(
            'No active SOS requests.',
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      latest.victimName,
      style: Theme.of(context).textTheme.bodyLarge,
    ),
    const SizedBox(height: 6),

    Text(
      "Injury: ${latest.injuryType.apiValue}",
    ),

    Text(
      "Victims: ${latest.victimCount}",
    ),

    const SizedBox(height: 10),

    Row(
      children: [
        _StatusBadge(status: latest.status),
        const SizedBox(width: 8),
        _PriorityBadge(priorityLevel: latest.priorityLevel),
      ],
    ),
  ],
),
          ],
        );
      case SosLoadState.idle:
        return Text(
          'Tap refresh to check the latest SOS status.',
          style: Theme.of(context).textTheme.bodyMedium,
        );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SosStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.apiValue,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priorityLevel});

  final PriorityLevel priorityLevel;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (priorityLevel) {
      PriorityLevel.high => AppColors.danger,
      PriorityLevel.medium => AppColors.warning,
      PriorityLevel.low => AppColors.success,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        priorityLevel.apiValue,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
