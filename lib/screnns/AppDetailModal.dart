import 'package:flutter/material.dart';
import 'package:appytime/utils/time_utils.dart';

class AppDetailModal extends StatelessWidget {
  final Map app;

  const AppDetailModal({Key? key, required this.app}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int timeUsed = app['timeUsed'];
    int? timeLimit = app['timeLimit'];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(app['appName'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

          const SizedBox(height: 10),
          Text("Time Used: ${formatTime(timeUsed)}"),
          Text("Time Limit: ${timeLimit != null ? formatTime(timeLimit) : 'Not Set'}"),

          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text("Set or Change Limit"),
            onPressed: () {
              // You can use a dialog or page navigation here
            },
          ),

          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.timeline),
            label: const Text("View Usage Timeline"),
            onPressed: () {
              // Optional: Navigate to timeline or show chart
            },
          ),
        ],
      ),
    );
  }
}
