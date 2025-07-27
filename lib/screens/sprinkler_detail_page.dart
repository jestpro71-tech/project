import 'package:flutter/material.dart';

class SprinklerDetailPage extends StatelessWidget {
  final List<Map<String, dynamic>> sprinklers = const [
    {
      'name': 'สปริงเกอร์ 1',
      'power': 10.0,
      'status': 'เปิด',
      'lastTime': '08:30',
      'waterUsed': 12.5,
    },
    {
      'name': 'สปริงเกอร์ 2',
      'power': 12.0,
      'status': 'ปิด',
      'lastTime': '07:00',
      'waterUsed': 15.0,
    },
    {
      'name': 'สปริงเกอร์ 3',
      'power': 8.0,
      'status': 'เปิด',
      'lastTime': '06:15',
      'waterUsed': 10.2,
    },
  ];

  const SprinklerDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดสปริงเกอร์'),
        backgroundColor: Colors.orange.shade700,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sprinklers.length,
        itemBuilder: (context, index) {
          final s = sprinklers[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s['name']} (สถานะ: ${s['status']})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('พลังงาน: ${s['power']} W'),
                  Text('น้ำใช้: ${s['waterUsed']} ลิตร'),
                  Text('เวลา: ${s['lastTime']}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
