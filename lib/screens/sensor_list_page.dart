import 'package:flutter/material.dart';
import 'package:endproject/screens/sensor_detail_page.dart'; // Import SensorDetailPage
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import Font Awesome

class SensorListPage extends StatelessWidget {
  final List<Map<String, dynamic>> sensors;
  final double fontSize; // <--- เพิ่มการประกาศ fontSize ที่นี่

  const SensorListPage({
    super.key,
    required this.sensors,
    required this.fontSize, // <--- เพิ่ม fontSize ใน constructor
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'รายละเอียดเซ็นเซอร์แต่ละตัว',
          style: TextStyle(
            fontSize: fontSize + 4,
            fontWeight: FontWeight.bold,
            fontFamily: 'Prompt', // Apply Prompt font
          ),
        ),
        backgroundColor: Colors.teal.shade700,
        centerTitle: true,
      ),
      body: sensors.isEmpty
          ? Center(
              child: Text(
                'ไม่พบข้อมูลเซ็นเซอร์',
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.grey.shade600,
                  fontFamily: 'Prompt', // Apply Prompt font
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sensors.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final sensor = sensors[index];
                // Ensure 'watt' is handled safely for display
                final double power = (sensor['watt'] as num?)?.toDouble() ?? 0.0;

                return Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  shadowColor: Colors.teal.withOpacity(0.5),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.teal.withOpacity(0.2),
                      child: const Icon(FontAwesomeIcons.droplet, color: Colors.teal, size: 30), // Icon for individual sensor
                    ),
                    title: Text(
                      sensor['name'],
                      style: TextStyle(
                        fontSize: fontSize + 2,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        fontFamily: 'Prompt', // Apply Prompt font
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'พลังงาน: ${power.toStringAsFixed(1)} W',
                          style: TextStyle(
                            fontSize: fontSize - 1,
                            color: Colors.grey[700],
                            fontFamily: 'Prompt', // Apply Prompt font
                          ),
                        ),
                        // You can add more sensor-specific details here if available
                      ],
                    ),
                    trailing: Icon(
                      FontAwesomeIcons.chevronRight, // Arrow icon
                      color: Colors.grey.shade600,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SensorDetailPage(sensor: sensor),
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
