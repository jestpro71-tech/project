import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart'; // สำหรับ GPSPage
import 'package:endproject/screens/pump_page.dart';
import 'package:endproject/screens/sprinkler_page.dart';
import 'package:endproject/screens/gps_page.dart';
import 'package:endproject/screens/soil_detail_page.dart';
import 'package:endproject/screens/power_usage_page.dart';
import 'package:endproject/widgets/modern_card.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import Font Awesome
// import 'package:endproject/utils/color_extensions.dart'; // สำหรับ ColorBrightness extension - ลบบรรทัดนี้ออกเนื่องจากไม่ได้ใช้โดยตรงในไฟล์นี้

// กำหนด URL ของ ESP32 เป็นค่าคงที่
const String esp32Url = 'http://192.168.1.100';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double fontSize = 14; // นี่คือ fontSize หลักที่คุณสามารถปรับได้

  bool pumpOn = false;
  bool pumpAuto = true;

  bool sprinklerOn = false;
  bool sprinklerAuto = true;

  double waterLevel = 20;

  String date = '', time = '';
  Timer? timer;

  List<List<double>> traysCap = [List.filled(6, 0.0)];
  List<List<double>> traysRes = [List.filled(6, 0.0)];
  List<List<bool>> traysStatus = [List.filled(6, true)];
  List<bool> traysConnected = [true];

  List<Map<String, String>> waterHistory = [];
  List<Map<String, dynamic>> sprinklerHistory = [];

  final LatLng gpsPosition = const LatLng(18.7953, 98.9986);

  @override
  void initState() {
    super.initState();
    updateDateTime();
    timer = Timer.periodic(const Duration(seconds: 2), (_) {
      updateDateTime();
      fetchSoilData();
      fetchPumpStatus();
      fetchSprinklerStatus();
      controlAutoPump();
      controlAutoSprinkler();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void updateDateTime() {
    final now = DateTime.now();
    setState(() {
      date = DateFormat('dd/MM/yyyy').format(now);
      time = DateFormat('HH:mm:ss').format(now);
    });
  }

  // ส่วนฟังก์ชันควบคุม Auto ปั๊มน้ำ และ Auto สปริงเกอร์
  void controlAutoPump() {
    if (!pumpAuto) return;
    if (waterLevel < 9) {
      if (!pumpOn) togglePump(true);
    } else {
      if (pumpOn) togglePump(false);
    }
  }

  void controlAutoSprinkler() {
    if (!sprinklerAuto) return;
    for (int tray = 0; tray < traysCap.length; tray++) {
      double avg =
          ((traysCap[tray].reduce((a, b) => a + b) / 6) +
              (traysRes[tray].reduce((a, b) => a + b) / 6)) /
          2;
      if (avg < 70) {
        if (!sprinklerOn) {
          toggleSprinkler(true);
          sprinklerHistory.add({'tray': tray + 1, 'time': time});
          waterLevel = (waterLevel - 5).clamp(0, 30);
        }
      } else if (avg >= 80) {
        if (sprinklerOn) toggleSprinkler(false);
      }
    }
  }

  // ส่วนฟังก์ชันควบคุมปั๊มน้ำและสปริงเกอร์ (เปิด-ปิด)
  void togglePump(bool v) async {
    setState(() => pumpOn = v);
    final url = v ? '/pump/on' : '/pump/off';
    try {
      await http.get(Uri.parse('$esp32Url$url'));
    } catch (e) {
      print('Error: $e');
    }
    if (v) addWaterHistory();
  }

  void toggleSprinkler(bool v) async {
    setState(() => sprinklerOn = v);
    final url = v ? '/sprinkler/on' : '/sprinkler/off';
    try {
      await http.get(Uri.parse('$esp32Url$url'));
    } catch (e) {
      print('Error: $e');
    }
  }

  void addWaterHistory() {
    setState(() {
      waterHistory.add({'time': time, 'amount': '5 ลิตร'});
      waterLevel = (waterLevel + 5).clamp(0, 30);
    });
  }

  // ส่วนฟังก์ชันดึงข้อมูลจาก ESP32
  void fetchSoilData() async {
    try {
      final res = await http.get(Uri.parse('$esp32Url/soil'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          for (int tray = 0; tray < traysCap.length; tray++) {
            for (int i = 0; i < 6; i++) {
              String capKey = 'tray${tray + 1}_cap_sensor${i + 1}';
              String resKey = 'tray${tray + 1}_res_sensor${i + 1}';

              if (data.containsKey(capKey)) {
                double val = (data[capKey] as num).toDouble();
                traysCap[tray][i] = val;
                traysStatus[tray][i] = val >= 0;
              } else {
                traysStatus[tray][i] = false;
              }

              if (data.containsKey(resKey)) {
                traysRes[tray][i] = (data[resKey] as num).toDouble();
              }
            }
            traysConnected[tray] = true;
          }
        });
      }
    } catch (e) {
      print('Error soil fetch: $e');
    }
  }

  void fetchPumpStatus() async {
    // Placeholder API call to update pumpOn state
  }

  void fetchSprinklerStatus() async {
    // Placeholder API call to update sprinklerOn state
  }

  // ส่วนเพิ่มถาดปลูก (กรณีต้องการเพิ่มถาดใหม่)
  void addTray() {
    setState(() {
      traysCap.add(List.filled(6, 0.0));
      traysRes.add(List.filled(6, 0.0));
      traysStatus.add(List.filled(6, true));
      traysConnected.add(true);
    });
  }

  // ส่วน Build UI หลักของหน้า Dashboard
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        elevation: 6,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(
          '🌱 Smart Farm',
          style: TextStyle(
            fontSize: fontSize + 6,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 20,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Changed to FontAwesomeIcons.calendarDays
                        Icon(
                          FontAwesomeIcons.calendarDays,
                          color: Colors.green.shade700,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: fontSize + 4,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Changed to FontAwesomeIcons.clock
                        Icon(
                          FontAwesomeIcons.clock,
                          color: Colors.green.shade700,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: fontSize + 4,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      color: Colors.green.shade200,
                      thickness: 2,
                      indent: 30,
                      endIndent: 30,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ระบบฟาร์มอัจฉริยะ พร้อมควบคุมและติดตามสถานะได้แบบเรียลไทม์',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),
            // GridView แสดงเมนู Dashboard
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                // ปรับค่า childAspectRatio เพื่อให้การ์ดสูงขึ้นเล็กน้อยและดูสมดุล
                // ค่าที่น้อยกว่า 1.0 จะทำให้การ์ดสูงขึ้นเมื่อเทียบกับความกว้าง
                childAspectRatio: 0.9, // ปรับค่าจาก 0.8 เป็น 0.9
                children: [
                  // 🚰 ความชื้นในดิน
                  ModernCard(
                    title: 'ความชื้นในดิน',
                    subtitle: 'ตรวจสอบค่าความชื้น',
                    icon: FontAwesomeIcons.droplet, // ใช้ Font Awesome icon
                    gradientColors: const [
                      Color.fromARGB(255, 155, 235, 173),
                      Color.fromARGB(255, 54, 249, 103),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SoilDetailPageUpdated(
                            date: date,
                            time: time,
                            traysCap: traysCap,
                            traysRes: traysRes,
                            traysStatus: traysStatus,
                            traysConnected: traysConnected,
                            fontSize: fontSize,
                          ),
                        ),
                      );
                    },
                    titleFontSize: fontSize + 2,
                    subtitleFontSize: fontSize - 2,
                  ),

                  // 💧 ปั๊มน้ำ
                  ModernCard(
                    title: 'ปั๊มน้ำ',
                    subtitle: pumpOn ? 'สถานะ: ทำงาน' : 'สถานะ: ปิดอยู่',
                    icon: FontAwesomeIcons.water, // ใช้ Font Awesome icon
                    gradientColors: const [
                      Color.fromARGB(255, 159, 192, 255),
                      Color.fromARGB(255, 94, 207, 255),
                    ],
                    onTap: () async {
                      // ส่งข้อมูลและรอรับค่ากลับจาก PumpPage
                      final updatedHistory = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PumpPage(
                            initialPumpOn: pumpOn,
                            initialAuto: pumpAuto,
                            initialWaterLevel: waterLevel,
                            initialWaterHistory: waterHistory,
                            fontSize: fontSize,
                            onUpdateWaterHistory: (history) {
                              // Callback ที่จะถูกเรียกเมื่อมีการอัปเดตประวัติใน PumpPage
                              setState(() {
                                waterHistory = history;
                              });
                            },
                          ),
                        ),
                      );
                      // อัปเดต state ของ Dashboard หากมีการเปลี่ยนแปลง waterHistory
                      if (updatedHistory is List<Map<String, String>>) {
                        setState(() {
                          waterHistory = updatedHistory;
                        });
                      }
                    },
                    titleFontSize: fontSize + 2,
                    subtitleFontSize: fontSize - 2,
                  ),

                  // 🌾 สปริงเกอร์
                  ModernCard(
                    title: 'สปริงเกอร์',
                    subtitle: sprinklerOn ? 'กำลังรดน้ำ' : 'ปิดอยู่',
                    icon: FontAwesomeIcons.seedling, // ใช้ Font Awesome icon
                    gradientColors: const [
                      Color.fromARGB(255, 241, 203, 146),
                      Color.fromARGB(255, 249, 121, 82),
                    ],
                    onTap: () async {
                      // ส่งข้อมูลและรอรับค่ากลับจาก SprinklerPage
                      final updatedHistory = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SprinklerPage(
                            initialSprinklerOn: sprinklerOn,
                            initialAutoMode: sprinklerAuto,
                            initialHistory: sprinklerHistory,
                            fontSize: fontSize,
                            onUpdateHistory: (history) {
                              // Callback ที่จะถูกเรียกเมื่อมีการอัปเดตประวัติใน SprinklerPage
                              setState(() {
                                sprinklerHistory = history;
                              });
                            },
                          ),
                        ),
                      );
                      // อัปเดต state ของ Dashboard หากมีการเปลี่ยนแปลง sprinklerHistory
                      if (updatedHistory is List<Map<String, dynamic>>) {
                        setState(() {
                          sprinklerHistory = updatedHistory;
                        });
                      }
                    },
                    titleFontSize: fontSize + 2,
                    subtitleFontSize: fontSize - 2,
                  ),

                  // ⚡ อัตราการใช้ไฟฟ้า
                  ModernCard(
                    title: 'อัตราการใช้ไฟฟ้า',
                    subtitle: 'เช็คพลังงาน',
                    icon: FontAwesomeIcons.bolt, // ใช้ Font Awesome icon
                    gradientColors: const [
                      Color.fromARGB(255, 238, 218, 153),
                      Color.fromARGB(255, 246, 193, 70),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PowerUsagePage(
                            fontSize: fontSize,
                            sensors: const [
                              {'name': 'ปั๊มน้ำ', 'watt': 12.5},
                              {'name': 'สปริงเกอร์', 'watt': 8.3},
                              {'name': 'เซนเซอร์ 1', 'watt': 0.3},
                              {'name': 'เซนเซอร์ 2', 'watt': 0.3},
                              {'name': 'เซนเซอร์ 3', 'watt': 0.3},
                            ],
                          ),
                        ),
                      );
                    },
                    titleFontSize: fontSize + 1,
                    subtitleFontSize: fontSize - 2,
                  ),

                  // 📍 GPS Smart Farm
                  ModernCard(
                    title: 'GPS Smart Farm',
                    subtitle: 'ดูตำแหน่งแปลงเกษตร',
                    icon: FontAwesomeIcons.locationDot, // ใช้ Font Awesome icon
                    gradientColors: const [
                      Color.fromARGB(255, 252, 231, 179),
                      Color.fromARGB(255, 246, 174, 41),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GPSPage(position: gpsPosition),
                        ),
                      );
                    },
                    titleFontSize: fontSize + 1,
                    subtitleFontSize: fontSize - 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget buildDashboardCard ถูกย้ายไปที่ widgets/dashboard_card.dart
  // Widget buildModernCard ถูกย้ายไปที่ widgets/modern_card.dart
}
