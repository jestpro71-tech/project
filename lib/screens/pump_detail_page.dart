import 'package:flutter/material.dart';

class PumpDetailPage extends StatelessWidget {
  const PumpDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดปั๊มน้ำ'),
        backgroundColor: Colors.blue.shade700,
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
              children: const [
                Icon(Icons.water, size: 60, color: Colors.blue),
                SizedBox(height: 16),
                Text(
                  'พลังงานที่ใช้: 50.0 W',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'จำนวนครั้งที่ใช้งานวันนี้: 3',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'เวลาใช้งานล่าสุด: 09:45 น.',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
