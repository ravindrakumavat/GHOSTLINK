import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/constants.dart';
import '../providers/sos_provider.dart';
import '../theme/theme.dart';
import '../utils/routes.dart';
import '../widgets/create_sos_dialog.dart';
import '../widgets/connection_status_card.dart';
import '../widgets/latest_sos_status_card.dart';
import '../widgets/sos_button.dart';

/// Phase 1 Home screen: the large SOS button, a connection status
/// card, the latest SOS status card, and placeholder buttons for
/// screens that don't exist yet. No SOS form, dashboard, map, or
/// Bluetooth logic is wired up here - those are later phases.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SosProvider>().fetchLatestSos();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, Color(0xFF10182B)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWide ? 560 : double.infinity,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        SosButton(
                          onPressed: () {
                           showDialog(
                             context: context,
                              builder: (_) => const CreateSosDialog(),
                             );
                           },
                        ),
                        const SizedBox(height: 32),
                        const ConnectionStatusCard(),
                        const SizedBox(height: 16),
                        const LatestSosStatusCard(),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.dashboard);
                              },
                              icon: const Icon(Icons.dashboard_outlined, size: 20),
                              label: const Text('Dashboard'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.map);
                              },
                              icon: const Icon(Icons.map_outlined, size: 20),
                              label: const Text('Map'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.devices);
                              },
                              icon: const Icon(Icons.devices_other_outlined, size: 20),
                              label: const Text('Devices'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
