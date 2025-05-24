import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appytime/services/usage_permission_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:appytime/screnns/AppUsageDetailScreen.dart';
import 'package:appytime/utils/time_utils.dart';
import '../utils/limit_utils.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const platform = MethodChannel('com.example.app/usage');
  List<Map<String, dynamic>> _appUsage = [];
  bool _isLoading = true;
  bool _showAllApps = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoad();
  }

  Future<void> _checkPermissionAndLoad() async {
    final hasPermission = await UsagePermissionService.isUsagePermissionGranted();
    if (!hasPermission) {
      await UsagePermissionService.openUsageSettings();
      setState(() => _isLoading = false);
      return;
    }
    _getAppUsage();
  }

  Future<void> _getAppUsage() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getAppUsage');
      List<Map<String, dynamic>> usageList = List<Map<String, dynamic>>.from(
        result.map((e) => Map<String, dynamic>.from(e)),
      );

      // Load time limits for each app
      await Future.wait(usageList.map((app) async {
        app['timeLimit'] = await loadDailyLimit(app['appPackageName']);
      }));

      setState(() {
        _appUsage = usageList..sort((a, b) => (b['timeUsed'] as int).compareTo(a['timeUsed'] as int));
        _isLoading = false;
      });
    } on PlatformException catch (e) {
      print("Failed to get app usage: '${e.message}'.");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredAppUsage = _showAllApps
        ? _appUsage
        : _appUsage.where((app) => app['timeUsed'] > 0 || app['appCategory'] != 'Other').toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Appy Time', style: TextStyle(fontSize: 20)),
            Text(
              DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text("App Icon", style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 10),
                Expanded(flex: 2, child: Text("App Name", style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 10),
                Expanded(flex: 2, child: Text("Category", style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 10),
                SizedBox(width: 80, child: Text("Time Used", style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 20),
                SizedBox(width: 100, child: Text("Limit Set?", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          // Toggle button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() => _showAllApps = !_showAllApps);
                },
                icon: Icon(_showAllApps ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                label: Text(_showAllApps ? "Hide Other" : "Display Other"),
              ),
            ],
          ),

          // App list
          Expanded(
            child: ListView.builder(
              itemCount: filteredAppUsage.length,
              itemBuilder: (context, index) {
                final app = filteredAppUsage[index];
                Uint8List? appIconBytes;

                try {
                  appIconBytes = base64Decode(app['appIcon']);
                } catch (_) {
                  appIconBytes = null;
                }

                int timeUsed = app['timeUsed'] as int;
                int? timeLimit = app['timeLimit'];
                double progress = timeLimit != null ? (timeUsed / timeLimit).clamp(0.0, 1.0) : 0.0;

                String limitStatus;
                if (timeLimit == null) {
                  limitStatus = "❌ Not Set";
                } else if (timeUsed > timeLimit) {
                  limitStatus = "⛔ ${formatTime(timeLimit)} (Over)";
                } else {
                  limitStatus = "✅ ${formatTime(timeLimit)}";
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppUsageDetailScreen(
                            app: app,
                            appIconBytes: appIconBytes,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: appIconBytes != null
                              ? Image.memory(appIconBytes, width: 40, height: 40, fit: BoxFit.cover)
                              : const Icon(Icons.apps, size: 40),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Text(app['appName'], style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Text(
                            app['appCategory'] ?? "Other",
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(width: 80, child: Text(formatTime(timeUsed))),
                        const SizedBox(width: 20),
                        SizedBox(width: 100, child: Text(limitStatus)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
