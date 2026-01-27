import 'package:shared_preferences/shared_preferences.dart';

/// Developer mode service for testing and debugging features
class DeveloperModeService {
  static const String _devModeKey = 'dev_mode_enabled';
  static const String _devSimulateGpsKey = 'dev_simulate_gps';

  /// Enable or disable developer mode for the current user
  static Future<void> setDeveloperMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_devModeKey, enabled);
  }

  /// Check if developer mode is enabled
  static Future<bool> isDeveloperMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_devModeKey) ?? false;
  }

  /// Enable or disable GPS simulation (for testing check-ins without moving)
  static Future<void> setSimulateGps(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_devSimulateGpsKey, enabled);
  }

  /// Check if GPS simulation is enabled
  static Future<bool> isGpsSimulationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_devSimulateGpsKey) ?? false;
  }

  /// Toggle developer mode
  static Future<bool> toggleDeveloperMode() async {
    final current = await isDeveloperMode();
    await setDeveloperMode(!current);
    return !current;
  }

  /// Toggle GPS simulation
  static Future<bool> toggleGpsSimulation() async {
    final current = await isGpsSimulationEnabled();
    await setSimulateGps(!current);
    return !current;
  }
}
