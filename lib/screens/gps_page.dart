import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';


// URL ของ Realtime Database (asia-southeast1)
const String rtdbUrl =
    'https://project-41b3d-default-rtdb.asia-southeast1.firebasedatabase.app';

class GPSPage extends StatefulWidget {
  final LatLng position; // พิกัดที่รับมาจาก Dashboard (state variable)
  final double fontSize;

  const GPSPage({
    super.key,
    required this.position,
    required this.fontSize,
  });

  @override
  State<GPSPage> createState() => _GPSPageState();
}

class _GPSPageState extends State<GPSPage> {
  late final FirebaseDatabase _database;
  StreamSubscription<DatabaseEvent>? _gpsDataSubscription;

  // ตัวแปรสำหรับเก็บข้อมูล GPS เพิ่มเติมจาก Firebase
  String date = '00/00/0000';
  String time = '00:00:00';
  double altitude = 0.0;
  double speed = 0.0;
  int satellites = 0;
  bool isConnected = false;
  LatLng currentPosition = const LatLng(18.7953, 98.9986); // พิกัดตั้งต้น (เชียงใหม่)

  @override
  void initState() {
    super.initState();
    // ใช้พิกัดที่ส่งมาจาก Dashboard เป็นพิกัดตั้งต้น
    currentPosition = widget.position; 
    
    _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: rtdbUrl,
    );

    _listenToGPSData();
  }

  @override
  void dispose() {
    _gpsDataSubscription?.cancel();
    super.dispose();
  }

  // MARK: - Firebase Listener
  void _listenToGPSData() {
    // อ้างอิงถึง /devices/gps ตามโครงสร้างข้อมูลใน Realtime Database
    final gpsRef = _database.ref('devices/gps'); 

    _gpsDataSubscription = gpsRef.onValue.listen(
      (event) {
        final data = event.snapshot.value;
        if (data != null && data is Map) {
          // ดึงค่าทั้งหมดออกมาจาก Firebase และจัดการค่าว่างด้วย ?? 0.0 หรือ ?? 0
          final lat = data['latitude'] as num? ?? 0.0;
          final lng = data['longitude'] as num? ?? 0.0;
          final alt = data['altitude'] as num? ?? 0.0;
          final spd = data['speed'] as num? ?? 0.0;
          final sats = data['satellites'] as num? ?? 0;
          final conn = data['isConnected'] as bool? ?? false;
          
          String? dateStr = data['date'] as String?;
          String? timeStr = data['time'] as String?;

          setState(() {
            currentPosition = LatLng(lat.toDouble(), lng.toDouble());
            altitude = alt.toDouble();
            speed = spd.toDouble();
            satellites = sats.toInt();
            isConnected = conn;

            // ตรวจสอบและแสดงวันที่/เวลา
            date = dateStr?.isNotEmpty == true ? dateStr! : 'N/A';
            time = timeStr?.isNotEmpty == true ? timeStr! : 'N/A';

          });
          debugPrint('GPS Detail Updated: $currentPosition');
        }
      },
      onError: (error) {
        debugPrint("Error listening to GPS data: $error");
      },
    );
  }

  // สร้าง Widget สำหรับแสดงรายละเอียด GPS
  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: widget.fontSize + 2,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade800, // ใช้สีม่วงสำหรับค่า
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // กำหนด Zoom เริ่มต้น
    double zoomLevel = (currentPosition.latitude == 0.0 && currentPosition.longitude == 0.0)
        ? 3.0 // Zoom ออกถ้าพิกัดเป็น 0,0
        : 15.0; // Zoom เข้าถ้ามีพิกัดจริง

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.purple.shade700, // เปลี่ยนเป็นสีม่วง
        elevation: 4,
        title: Text(
          'GPS Smart Farm', // เปลี่ยน Title ตามที่คุณระบุ
          style: TextStyle(
            fontSize: widget.fontSize + 4,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ส่วนแสดงแผนที่
            Container(
              height: 350,
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FlutterMap(
                  options: MapOptions(
                    // แก้ไข: ใช้ 'center' แทน 'initialCenter' 
                    center: currentPosition, 
                    // แก้ไข: ใช้ 'zoom' แทน 'initialZoom'
                    zoom: zoomLevel,
                    // กำหนดขอบเขตการซูม
                    minZoom: 2.0,
                    maxZoom: 18.0, 
                  ),
                  children: [
                    // Tile Layer (พื้นผิวแผนที่)
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.smartfarm',
                    ),
                    // Marker (หมุดแสดงตำแหน่ง)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: currentPosition,
                          width: 80,
                          height: 80,
                          // *** แก้ไขตรงนี้: เปลี่ยน 'child' เป็น 'builder' ***
                          builder: (context) => const Icon(
                            FontAwesomeIcons.mapPin,
                            color: Colors.red,
                            size: 30.0,
                          ),
                          // *** ลบคอมม่าหลังสุดหากเวอร์ชันเก่ากว่าไม่รองรับการมีคอมม่าท้ายรายการ (Trailing Comma) ***
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // ส่วนแสดงรายละเอียดข้อมูล GPS
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.shade100, width: 2), // ขอบสีม่วง
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.shade50.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'สถานะ GPS (Realtime)',
                      style: TextStyle(
                        fontSize: widget.fontSize + 4,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700, // เปลี่ยนเป็นสีม่วง
                      ),
                    ),
                  ),
                  const Divider(height: 24, thickness: 1),
                  _buildDetailRow(
                    FontAwesomeIcons.signal,
                    'เชื่อมต่อ',
                    isConnected ? 'เชื่อมต่อ' : 'หลุด',
                    isConnected ? Colors.purple.shade500 : Colors.red.shade500,
                  ),
                  _buildDetailRow(
                    FontAwesomeIcons.compass,
                    'ละติจูด',
                    currentPosition.latitude.toStringAsFixed(6),
                    Colors.blue.shade600,
                  ),
                  _buildDetailRow(
                    FontAwesomeIcons.globe,
                    'ลองจิจูด',
                    currentPosition.longitude.toStringAsFixed(6),
                    Colors.blue.shade600,
                  ),
                  _buildDetailRow(
                    FontAwesomeIcons.mountain,
                    'ระดับความสูง',
                    '${altitude.toStringAsFixed(2)} ม.',
                    Colors.brown.shade500,
                  ),
                  _buildDetailRow(
                    FontAwesomeIcons.gaugeHigh,
                    'ความเร็ว',
                    '${speed.toStringAsFixed(2)} กม./ชม.',
                    Colors.orange.shade500,
                  ),
                  _buildDetailRow(
                    FontAwesomeIcons.satellite,
                    'ดาวเทียม',
                    '$satellites ดวง',
                    Colors.teal.shade500,
                  ),
                  _buildDetailRow(
                    FontAwesomeIcons.calendar,
                    'วันที่บันทึก',
                    date,
                    Colors.purple.shade500,
                  ),
                  _buildDetailRow(
                    FontAwesomeIcons.clock,
                    'เวลาบันทึก',
                    time,
                    Colors.purple.shade500,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
