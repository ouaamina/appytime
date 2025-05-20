import 'dart:io';
import 'package:flutter/services.dart';

class UsagePermissionService {
  static const MethodChannel _channel = MethodChannel('com.example.app/usage');

  static Future<bool> isUsagePermissionGranted() async {
    try {
      final bool result = await _channel.invokeMethod('isUsagePermissionGranted');
      return result;
    } catch (e) {
      print("Erreur vérification autorisation : $e");
      return false;
    }
  }

  static Future<void> openUsageSettings() async {
    try {
      await _channel.invokeMethod('openUsageSettings');
    } catch (e) {
      print("Erreur ouverture paramètres : $e");
    }
  }
}
