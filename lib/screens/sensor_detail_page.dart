import 'package:flutter/material.dart';

class SensorDetailPage extends StatelessWidget {
  final Map<String, dynamic> sensor;
  const SensorDetailPage({super.key, required this.sensor});

  @override
  Widget build(BuildContext context) {
    // ตรวจสอบว่า 'value' มีอยู่หรือไม่ และเป็น double หรือไม่
    final double moisture = (sensor['value'] as num?)?.toDouble() ?? 0.0;

    String statusText;
    Color statusColor;
    if (moisture < 60) {
      statusText = '⚠️ ความชื้นต่ำเกินไป';
      statusColor = Colors.red;
    } else if (moisture > 80) {
      statusText = '⚠️ ความชื้นสูงเกินไป';
      statusColor = Colors.red;
    } else {
      statusText = '✅ ความชื้นปกติ';
      statusColor = Colors.green;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(sensor['name']),
        backgroundColor: Colors.teal.shade700,
      ),
      body: Center(
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          margin: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ชื่อเซ็นเซอร์: ${sensor['name']}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'พลังงาน: ${sensor['power']} W',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                Text(
                  'ค่าความชื้น: ${moisture.toStringAsFixed(1)}%', // แสดงค่าความชื้น
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: moisture / 100,
                    minHeight: 18,
                    color: Colors.teal.shade700,
                    backgroundColor: Colors.teal.shade200,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
