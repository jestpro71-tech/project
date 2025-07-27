import 'package:flutter/material.dart';
import 'package:endproject/screens/pump_detail_page.dart';
import 'package:endproject/screens/sprinkler_detail_page.dart';
import 'package:endproject/screens/sensor_detail_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import Font Awesome

// หน้าแสดงอัตราการใช้ไฟฟ้าหลัก
class PowerUsagePage extends StatelessWidget {
  final double fontSize;
  final List<Map<String, dynamic>> sensors;

  const PowerUsagePage({
    super.key,
    required this.fontSize,
    required this.sensors,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> devices = [
      {
        'name': 'ปั๊มน้ำ',
        'power': 50.0,
        'icon': FontAwesomeIcons.water, // Changed to FontAwesomeIcons.water
        'color': Colors.blue,
        'lastUsed': '09:45 น.',
        'usageCountToday': 3,
        'detailPage': () => const PumpDetailPage(), // ใช้ const
      },
      {
        'name': 'สปริงเกอร์',
        'power': 30.0,
        'icon': FontAwesomeIcons.seedling, // Changed to FontAwesomeIcons.seedling
        'color': Colors.orange,
        'lastUsed': '07:30 น.',
        'usageCountToday': 2,
        'detailPage': () => const SprinklerDetailPage(), // ใช้ const
      },
    ];

    // สร้างรายการอุปกรณ์ทั้งหมดรวมเซ็นเซอร์
    final List<Map<String, dynamic>> allDevices = [
      ...devices,
      ...sensors.map(
        (sensor) => {
          'name': sensor['name'],
          // แก้ไขตรงนี้: ตรวจสอบว่า 'watt' ไม่เป็น null ก่อนแปลงเป็น double
          // ถ้าเป็น null ให้ใช้ 0.0 เป็นค่าเริ่มต้น
          'power': (sensor['watt'] as num?)?.toDouble() ?? 0.0,
          'icon': FontAwesomeIcons.droplet, // Changed to FontAwesomeIcons.droplet
          'color': Colors.teal,
          'lastUsed': '-',
          'usageCountToday': 0,
          'detailPage': () => SensorDetailPage(sensor: sensor),
        },
      ),
    ];

    // คำนวณพลังงานรวม
    // แก้ไขตรงนี้: ตรวจสอบว่า 'power' ใน device ไม่เป็น null ก่อนบวก
    double totalPower = allDevices.fold(
      0.0, // เริ่มต้นด้วย 0.0 เพื่อให้แน่ใจว่าเป็น double
      (sum, d) => sum + ((d['power'] as num?)?.toDouble() ?? 0.0),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'อัตราการใช้ไฟฟ้า',
          style: TextStyle(fontSize: fontSize + 4, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal.shade700,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(FontAwesomeIcons.bolt, color: Colors.orange.shade800, size: 28), // Changed to FontAwesomeIcons.bolt
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'รวมการใช้พลังงาน: ${totalPower.toStringAsFixed(1)} วัตต์',
                      style: TextStyle(
                        fontSize: fontSize + 3,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: allDevices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final device = allDevices[index];
                  // แก้ไขตรงนี้: ตรวจสอบว่า 'power' ไม่เป็น null ก่อนใช้งาน
                  final double power = (device['power'] as num?)?.toDouble() ?? 0.0;
                  final Color color = device['color'];
                  final double percent = totalPower > 0 ? power / totalPower : 0.0; // ป้องกันหารด้วยศูนย์

                  return Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    shadowColor: color.withOpacity(0.5),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: color.withOpacity(0.2),
                        child: Icon(device['icon'], color: color, size: 30),
                      ),
                      title: Text(
                        device['name'],
                        style: TextStyle(
                          fontSize: fontSize + 2,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: percent,
                              color: color,
                              backgroundColor: color.withOpacity(0.2),
                              minHeight: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'ใช้งานล่าสุด: ${device['lastUsed']} | ${device['usageCountToday']} ครั้งวันนี้',
                            style: TextStyle(
                              fontSize: fontSize - 1,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        '${power.toStringAsFixed(1)} W',
                        style: TextStyle(
                          fontSize: fontSize + 1,
                          fontWeight: FontWeight.bold,
                          color: color.withOpacity(0.8),
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => device['detailPage'](),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
