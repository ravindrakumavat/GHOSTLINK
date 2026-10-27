import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'constants/constants.dart';
import 'providers/connection_provider.dart';
import 'providers/mesh_provider.dart';
import 'providers/sos_provider.dart';
import 'services/mesh_service.dart';
import 'theme/theme.dart';
import 'utils/routes.dart';

void main() {
  runApp(const ResQMeshApp());
}

class ResQMeshApp extends StatefulWidget {
  const ResQMeshApp({super.key});

  @override
  State<ResQMeshApp> createState() => _ResQMeshAppState();
}

class _ResQMeshAppState extends State<ResQMeshApp> {
  late final MeshService _meshService;
  late final MeshProvider _meshProvider;
  late final SosProvider _sosProvider;

  @override
  void initState() {
    super.initState();
    _meshService = MeshService();
    _meshProvider = MeshProvider(meshService: _meshService);
    _sosProvider = SosProvider(meshService: _meshService);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _sosProvider),
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProvider.value(value: _meshProvider),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.routes,
      ),
    );
  }
}
