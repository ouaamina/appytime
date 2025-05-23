import 'package:shared_preferences/shared_preferences.dart';

/// Save the daily limit in minutes for a specific app.
Future<void> saveDailyLimit(String packageName, int limitInMinutes) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('dailyLimit_$packageName', limitInMinutes);
}

/// Load the daily limit for an app. Returns 60 if no value is saved.
Future<int> loadDailyLimit(String packageName) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('dailyLimit_$packageName') ?? 60;
}
