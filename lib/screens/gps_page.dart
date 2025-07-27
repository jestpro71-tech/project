import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart'; // Import LatLng

class GPSPage extends StatelessWidget {
  final double fontSize;
  final LatLng position; // รับค่าตำแหน่งเข้ามา

  const GPSPage({
    super.key,
    required this.fontSize,
    required this.position, // เพิ่ม fontSize และ position ใน constructor
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'GPS Smart Farm',
          style: TextStyle(
            fontSize: fontSize + 4,
            fontWeight: FontWeight.bold,
            fontFamily: 'Prompt', // Apply Prompt font
          ),
        ),
        backgroundColor: Colors.purple.shade700,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ตำแหน่งแปลงเกษตร',
                style: TextStyle(
                  fontSize: fontSize + 6,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade800,
                  fontFamily: 'Prompt',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'ละติจูด: ${position.latitude.toStringAsFixed(6)}',
                style: TextStyle(
                  fontSize: fontSize + 2,
                  color: Colors.grey.shade700,
                  fontFamily: 'Prompt',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'ลองจิจูด: ${position.longitude.toStringAsFixed(6)}',
                style: TextStyle(
                  fontSize: fontSize + 2,
                  color: Colors.grey.shade700,
                  fontFamily: 'Prompt',
                ),
              ),
              const SizedBox(height: 30),
              // คุณสามารถเพิ่มแผนที่จริงที่นี่ได้ เช่นใช้ flutter_map หรือ google_maps_flutter
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.purple.shade300, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  'แผนที่แสดงตำแหน่ง (จำลอง)',
                  style: TextStyle(
                    fontSize: fontSize,
                    color: Colors.grey.shade500,
                    fontFamily: 'Prompt',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ข้อมูลตำแหน่งนี้เป็นค่าจำลอง คุณสามารถเชื่อมต่อกับ GPS จริงได้',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize - 2,
                  color: Colors.grey.shade500,
                  fontFamily: 'Prompt',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
