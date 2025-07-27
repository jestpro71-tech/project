import 'package:flutter/material.dart';// Keep for individual sensor page
import 'package:endproject/screens/sensor_list_page.dart'; // New: Import SensorListPage
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import Font Awesome

// หน้าแสดงอัตราการใช้ไฟฟ้าหลัก
class PowerUsagePage extends StatelessWidget {
  final double fontSize;
  final List<Map<String, dynamic>> sensors; // This list contains ALL devices passed from DashboardScreen

  const PowerUsagePage({
    super.key,
    required this.fontSize,
    required this.sensors,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out 'ปั๊มน้ำ' and 'สปริงเกอร์' to get only actual sensors
    final List<Map<String, dynamic>> actualSensors = sensors.where((device) {
      final name = device['name'] as String;
      return name.contains('เซนเซอร์'); // Only include items with 'เซนเซอร์' in their name
    }).toList();

    // Define core devices (pump, sprinkler) to be displayed separately
    final List<Map<String, dynamic>> coreDevices = sensors.where((device) {
      final name = device['name'] as String;
      return name == 'ปั๊มน้ำ' || name == 'สปริงเกอร์';
    }).toList();

    // Calculate total power for all actual sensors
    double totalSensorPower = actualSensors.fold(0.0, (sum, sensor) => sum + ((sensor['watt'] as num?)?.toDouble() ?? 0.0));

    // Create the aggregated "เซ็นเซอร์รวม" card data
    final Map<String, dynamic> combinedSensorCard = {
      'name': 'เซ็นเซอร์รวม',
      'power': totalSensorPower, // Sum of all actual sensor powers
      'icon': FontAwesomeIcons.microchip, // A suitable icon for combined sensors
      'color': Colors.teal, // A distinct color for sensors
      'lastUsed': '-', // Placeholder, as it's a combined card
      'usageCountToday': actualSensors.length, // Number of actual sensors
      'detailPage': () => SensorListPage(sensors: actualSensors, fontSize: fontSize), // Pass ONLY actual sensors
    };

    // Combine core devices and the new combined sensor card for display
    final List<Map<String, dynamic>> allDisplayDevices = [
      ...coreDevices, // Pump and Sprinkler are here
      combinedSensorCard, // The combined sensor card is here
    ];

    // Calculate overall total power for the top summary card
    double overallTotalPower = allDisplayDevices.fold(
      0.0,
      (sum, d) => sum + ((d['power'] as num?)?.toDouble() ?? 0.0),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'อัตราการใช้ไฟฟ้า',
          style: TextStyle(
            fontSize: fontSize + 4,
            fontWeight: FontWeight.bold,
            fontFamily: 'Prompt', // Apply Prompt font
          ),
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
                  Icon(FontAwesomeIcons.bolt, color: Colors.orange.shade800, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'รวมการใช้พลังงาน: ${overallTotalPower.toStringAsFixed(1)} วัตต์',
                      style: TextStyle(
                        fontSize: fontSize + 3,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                        fontFamily: 'Prompt', // Apply Prompt font
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: allDisplayDevices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final device = allDisplayDevices[index];
                  final double power = (device['power'] as num?)?.toDouble() ?? 0.0;
                  // แก้ไขตรงนี้: เพิ่มการตรวจสอบ null และกำหนดสีเริ่มต้น (Colors.grey) หาก device['color'] เป็น null
                  final Color color = (device['color'] as Color?) ?? Colors.grey;
                  final double percent = overallTotalPower > 0 ? power / overallTotalPower : 0.0;

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
                          fontFamily: 'Prompt', // Apply Prompt font
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
                              fontFamily: 'Prompt', // Apply Prompt font
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
                          fontFamily: 'Prompt', // Apply Prompt font
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
