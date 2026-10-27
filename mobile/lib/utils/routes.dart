import 'package:flutter/material.dart';

import '../screens/dashboard_screen.dart';
import '../screens/devices_screen.dart';
import '../screens/home_screen.dart';
import '../screens/incident_details_screen.dart';
import '../screens/map_screen.dart';
import '../screens/splash_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String home = '/home';
  static const String dashboard = '/dashboard';
  static const String incidentDetails = '/incident-details';
  static const String map = '/map';
  static const String devices = '/devices';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        home: (context) => const HomeScreen(),
        dashboard: (context) => const DashboardScreen(),
        incidentDetails: (context) => const IncidentDetailsScreen(),
        map: (context) => const MapScreen(),
        devices: (context) => const DevicesScreen(),
      };
}
