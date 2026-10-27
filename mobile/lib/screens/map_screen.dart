import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/sos_request.dart';
import '../providers/sos_provider.dart';
import '../theme/theme.dart';
import '../utils/location_helper.dart';
import '../utils/routes.dart';
import '../widgets/glass_card.dart';

/// Interactive Rescue Map for ResQMesh AI.
/// Renders real SOS incident markers from the backend using OpenStreetMap,
/// color-coded by AI urgency level, with interactive detail previews.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  PriorityLevel? _selectedPriorityFilter;
  SosRequest? _selectedIncident;

  // Default fallback center (Pune, India region if no incidents available)
  static const LatLng _defaultCenter = LatLng(18.5204, 73.8567);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SosProvider>().fetchAllSos();
      }
    });
  }

  void _recenterToIncidents(List<SosRequest> incidents) {
    if (incidents.isEmpty) {
      _mapController.move(_defaultCenter, 13.0);
      return;
    }

    if (incidents.length == 1) {
      final first = incidents.first;
      _mapController.move(LatLng(first.latitude, first.longitude), 15.0);
      return;
    }

    double minLat = incidents.first.latitude;
    double maxLat = incidents.first.latitude;
    double minLng = incidents.first.longitude;
    double maxLng = incidents.first.longitude;

    for (final inc in incidents) {
      if (inc.latitude < minLat) minLat = inc.latitude;
      if (inc.latitude > maxLat) maxLat = inc.latitude;
      if (inc.longitude < minLng) minLng = inc.longitude;
      if (inc.longitude > maxLng) maxLng = inc.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(center, 13.0);
  }

  Future<void> _recenterToCurrentLocation() async {
    try {
      final position = await LocationHelper.getCurrentLocation();
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        15.0,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not fetch current GPS: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sosProvider = context.watch<SosProvider>();
    final allIncidents = sosProvider.allSos;

    final filteredIncidents = _selectedPriorityFilter == null
        ? allIncidents
        : allIncidents
            .where((i) => i.priorityLevel == _selectedPriorityFilter)
            .toList();

    final highCount = allIncidents
        .where((i) => i.priorityLevel == PriorityLevel.high && i.status != SosStatus.rescued)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rescue Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: AppColors.accentCyan),
            tooltip: 'My Location',
            onPressed: _recenterToCurrentLocation,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.accentCyan),
            tooltip: 'Refresh Incidents',
            onPressed: () => context.read<SosProvider>().fetchAllSos(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // OpenStreetMap Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: allIncidents.isNotEmpty
                  ? LatLng(allIncidents.first.latitude, allIncidents.first.longitude)
                  : _defaultCenter,
              initialZoom: 13.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (_, __) {
                if (_selectedIncident != null) {
                  setState(() => _selectedIncident = null);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.resqmesh.ai',
                tileBuilder: (context, tileWidget, tile) {
                  // Darken map tiles to blend with the ResQMesh dark aesthetic
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      0.21, 0.72, 0.07, 0, -35,
                      0.21, 0.72, 0.07, 0, -35,
                      0.21, 0.72, 0.07, 0, -35,
                      0,    0,    0,    1, 0,
                    ]),
                    child: tileWidget,
                  );
                },
              ),
              MarkerLayer(
                markers: filteredIncidents.map((incident) {
                  final isSelected = _selectedIncident?.uuid == incident.uuid;
                  final markerColor = switch (incident.priorityLevel) {
                    PriorityLevel.high => AppColors.danger,
                    PriorityLevel.medium => AppColors.warning,
                    PriorityLevel.low => AppColors.success,
                  };

                  return Marker(
                    point: LatLng(incident.latitude, incident.longitude),
                    width: isSelected ? 52 : 44,
                    height: isSelected ? 52 : 44,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIncident = incident;
                        });
                        _mapController.move(
                          LatLng(incident.latitude, incident.longitude),
                          14.5,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: markerColor,
                          border: Border.all(
                            color: isSelected ? Colors.white : AppColors.background,
                            width: isSelected ? 3.0 : 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: markerColor.withValues(alpha: isSelected ? 0.8 : 0.45),
                              blurRadius: isSelected ? 16 : 8,
                              spreadRadius: isSelected ? 4 : 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            incident.priorityLevel == PriorityLevel.high
                                ? Icons.emergency
                                : Icons.medical_services_rounded,
                            color: Colors.white,
                            size: isSelected ? 24 : 20,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Top Floating Bar: Stats & Priority Filter Chips
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Stats Card
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accentCyan,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${filteredIncidents.length} Incident${filteredIncidents.length == 1 ? '' : 's'} on Map',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      if (highCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.danger, width: 0.8),
                          ),
                          child: Text(
                            '$highCount CRITICAL',
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMapFilterChip(
                        label: 'All Urgencies',
                        isSelected: _selectedPriorityFilter == null,
                        color: AppColors.accentCyan,
                        onSelected: () => setState(() => _selectedPriorityFilter = null),
                      ),
                      const SizedBox(width: 6),
                      _buildMapFilterChip(
                        label: 'HIGH',
                        isSelected: _selectedPriorityFilter == PriorityLevel.high,
                        color: AppColors.danger,
                        onSelected: () => setState(() => _selectedPriorityFilter = PriorityLevel.high),
                      ),
                      const SizedBox(width: 6),
                      _buildMapFilterChip(
                        label: 'MEDIUM',
                        isSelected: _selectedPriorityFilter == PriorityLevel.medium,
                        color: AppColors.warning,
                        onSelected: () => setState(() => _selectedPriorityFilter = PriorityLevel.medium),
                      ),
                      const SizedBox(width: 6),
                      _buildMapFilterChip(
                        label: 'LOW',
                        isSelected: _selectedPriorityFilter == PriorityLevel.low,
                        color: AppColors.success,
                        onSelected: () => setState(() => _selectedPriorityFilter = PriorityLevel.low),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Fit all incidents floating button
          Positioned(
            right: 16,
            bottom: _selectedIncident != null ? 220 : 24,
            child: FloatingActionButton.small(
              heroTag: 'fit_markers',
              backgroundColor: AppColors.surfaceElevated,
              foregroundColor: AppColors.accentCyan,
              tooltip: 'Fit All Incidents',
              onPressed: () => _recenterToIncidents(filteredIncidents),
              child: const Icon(Icons.zoom_out_map),
            ),
          ),

          // Loading Overlay
          if (sosProvider.state == SosLoadState.loading && allIncidents.isEmpty)
            const Center(
              child: GlassCard(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.accentCyan),
                    SizedBox(height: 12),
                    Text(
                      'Loading incident coordinates...',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          // Empty State Banner
          if (filteredIncidents.isEmpty && sosProvider.state == SosLoadState.loaded)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.accentCyan),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No active distress incidents match the map filter.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _selectedPriorityFilter = null),
                      child: const Text('Reset', style: TextStyle(color: AppColors.accentCyan)),
                    ),
                  ],
                ),
              ),
            ),

          // Selected Marker Detail Popup Card
          if (_selectedIncident != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _buildIncidentDetailCard(_selectedIncident!),
            ),
        ],
      ),
    );
  }

  Widget _buildMapFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onSelected,
  }) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.35) : AppColors.surfaceElevated.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.glassBorder,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildIncidentDetailCard(SosRequest incident) {
    final priorityColor = switch (incident.priorityLevel) {
      PriorityLevel.high => AppColors.danger,
      PriorityLevel.medium => AppColors.warning,
      PriorityLevel.low => AppColors.success,
    };

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Victim Name, Priority Score, Close
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.victimName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: priorityColor.withValues(alpha: 0.6)),
                ),
                child: Text(
                  '${incident.priorityScore.toStringAsFixed(0)} • ${incident.priorityLevel.apiValue}',
                  style: TextStyle(
                    color: priorityColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                onPressed: () => setState(() => _selectedIncident = null),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.glassBorder),
          const SizedBox(height: 10),

          // Metadata Grid: Victims, Injury, Battery, Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCardMeta(Icons.people_outline, '${incident.victimCount} victim(s)'),
              _buildCardMeta(Icons.medical_services_outlined, incident.injuryType.apiValue),
              _buildCardMeta(Icons.battery_charging_full, '${incident.batteryPercentage}%'),
              _buildCardMeta(Icons.shield_outlined, incident.status.apiValue),
            ],
          ),
          const SizedBox(height: 14),

          // View Full Incident Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.incidentDetails,
                  arguments: incident,
                );
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open Incident Response', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.accentCyan),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
