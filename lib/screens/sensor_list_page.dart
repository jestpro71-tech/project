import 'package:flutter/material.dart';
import 'package:endproject/screens/sensor_detail_page.dart'; // Import SensorDetailPage

class SensorListPage extends StatelessWidget {
  final List<Map<String, dynamic>> sensors;

  const SensorListPage({super.key, required this.sensors});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดเซ็นเซอร์ความชื้น'),
        backgroundColor: Colors.teal.shade700,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sensors.length,
        itemBuilder: (context, index) {
          final s = sensors[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              title: Text(
                s['name'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('พลังงาน: ${s['power']} W'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SensorDetailPage(sensor: s),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
