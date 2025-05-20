import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appytime/utils/time_utils.dart';

class AppDetailPage extends StatefulWidget {
  final Map app;

  const AppDetailPage({Key? key, required this.app}) : super(key: key);

  @override
  State<AppDetailPage> createState() => _AppDetailPageState();
}

class _AppDetailPageState extends State<AppDetailPage> {
  late Future<Map<String, dynamic>> _appStateFuture;

  @override
  void initState() {
    super.initState();
    _appStateFuture = _getAppState(widget.app['appPackageName'], 4);
  }

  Future<Map<String, dynamic>> _getAppState(String packageName, int month) async {
    const platform = MethodChannel('com.example.app/usage');
    final result = await platform.invokeMethod('getAppState', {
      'packageName': packageName,
      'month': month,
    });
    print("App Detail Page : '${result}'.");

    return Map<String, dynamic>.from(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.app['appName'])),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _appStateFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Error loading app details'));
          }

          final appDetails = snapshot.data!;
          // final iconBytes = base64Decode(appDetails['appIcon']);
          final List dailyUsage = appDetails['dailyUsage'];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Center(child: Image.memory(iconBytes, width: 64, height: 64)),
                const SizedBox(height: 16),
                Text("Usage Timeline", style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: dailyUsage.length,
                    itemBuilder: (context, index) {
                      final usage = dailyUsage[index];
                      final day = usage['day'];
                      final timeUsed = usage['timeUsed'];
                      return ListTile(
                        title: Text("${day}"),
                        trailing: Text(formatTime(timeUsed)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Handle edit limit
                  },
                  child: const Text("Edit Limit"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
