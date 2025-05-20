import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appytime/utils/time_utils.dart';
import 'package:fl_chart/fl_chart.dart';

class AppUsageDetailScreen extends StatefulWidget {
  final Map app;
  final int dailyLimit = 200;

  const AppUsageDetailScreen({Key? key, required this.app}) : super(key: key);

  @override
  State<AppUsageDetailScreen> createState() => _AppUsageDetailScreenState();
}

class _AppUsageDetailScreenState extends State<AppUsageDetailScreen> {
  List<Duration> usageList = List.generate(31, (_) => Duration.zero);
  int maxMinutes = 0;

  @override
  void initState() {
    super.initState();
    _loadUsageDataForMonth(5); // May
  }

  Future<void> _loadUsageDataForMonth(int month) async {
    try {
      const platform = MethodChannel('com.example.app/usage');

      final result = await platform.invokeMethod('getAppState', {
        'packageName': widget.app['appPackageName'],
        'month': month,
      });

      print("App Detail getAppState: '$result'.");

      final Map<String, dynamic> rawMap = Map<String, dynamic>.from(result);
      final List<dynamic> dailyUsage = rawMap['dailyUsage'];

      usageList = List.generate(31, (i) => Duration.zero);

      for (var entry in dailyUsage) {
        final day = entry['day'];
        final timeUsed = entry['timeUsed'];
        if (day is int && timeUsed is int && day >= 1 && day <= 31) {
          usageList[day - 1] = Duration(minutes: timeUsed);
        }
      }

      maxMinutes = usageList.map((d) => d.inMinutes).reduce((a, b) => a > b ? a : b);

      setState(() {});
    } catch (e) {
      print("Error loading usage data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOverLimit = widget.app['timeUsed'] > widget.dailyLimit;

    return Scaffold(
      appBar: AppBar(title: Text(widget.app['appName'])),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                widget.app['appName'],
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              child: ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('Aujourd’hui'),
                trailing: Text(
                  formatTime(widget.app['timeUsed']),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildCard(
              child: ListTile(
                leading: Icon(
                  isOverLimit ? Icons.block : Icons.check_circle,
                  color: isOverLimit ? Colors.red : Colors.green,
                ),
                title: const Text('Temps limite'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatTime(widget.dailyLimit),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isOverLimit ? Colors.red : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Consommation ce mois-ci',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 30,
                                reservedSize: 50,
                                getTitlesWidget: (value, meta) {
                                  final minutes = value.toInt();
                                  if (minutes == 0) return const Text('0');
                                  if (minutes < 60) return Text('$minutes min');
                                  final hours = minutes ~/ 60;
                                  final mins = minutes % 60;
                                  return Text(mins == 0 ? '$hours h' : '$hours h ${mins}m');
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 5,
                                getTitlesWidget: (value, meta) {
                                  return Text('${value.toInt()}');
                                },
                              ),
                            ),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(color: const Color(0xff37434d), width: 1),
                          ),
                          minX: 1,
                          maxX: 31,
                          minY: 0,
                          maxY: (maxMinutes < 60)
                              ? 60
                              : (maxMinutes + 30 - maxMinutes % 30).toDouble(),
                          lineBarsData: [
                            LineChartBarData(
                              spots: [
                                for (int i = 0; i < usageList.length; i++)
                                  FlSpot(i + 1.0, usageList[i].inMinutes.toDouble()),
                              ],
                              isCurved: true,
                              color: Colors.red,
                              belowBarData: BarAreaData(show: false),
                              dotData: FlDotData(show: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
