import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:endproject/screens/pump_page.dart';
import 'package:endproject/screens/sprinkler_page.dart';
import 'package:endproject/screens/gps_page.dart';
import 'package:endproject/screens/soil_detail_page.dart';
import 'package:endproject/screens/power_usage_page.dart';
import 'package:endproject/widgets/modern_card.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:endproject/screens/pump_detail_page.dart';
import 'package:endproject/screens/sprinkler_detail_page.dart';
import 'package:endproject/screens/sensor_detail_page.dart';

import 'package:firebase_core/firebase_core.dart';        // <-- เพิ่ม
import 'package:firebase_database/firebase_database.dart'; // <-- ใช้คู่กัน

// กำหนด URL ของ ESP32 เป็นค่าคงที่
const String esp32Url = 'http://192.168.1.100';

// URL ของ Realtime Database (asia-southeast1)
const String rtdbUrl =
    'https://project-41b3d-default-rtdb.asia-southeast1.firebasedatabase.app';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double fontSize = 14;

  // ใช้ late final แล้วกำหนดค่าจริงใน initState() หลัง Firebase.init เสร็จ
  late final FirebaseDatabase _database;

  // Stream Subscriptions
  StreamSubscription<DatabaseEvent>? _waterLevelSubscription;

  bool pumpOn = false;
  bool pumpAuto = true;
  bool sprinklerOn = false;
  bool sprinklerAuto = true;

  // จะถูกอัปเดตจาก Firebase
  double waterLevel = 0.0;

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

    // ชี้ไปยัง RTDB instance ที่ถูกต้อง
    _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: rtdbUrl,
    );

    updateDateTime();
    _listenToWaterLevel(); // ฟังการเปลี่ยนแปลง waterLevel จาก Firebase

    timer = Timer.periodic(const Duration(seconds: 2), (_) {
      updateDateTime();
      fetchSoilData();
      fetchPumpStatus();
      fetchSprinklerStatus();
      // controlAutoPump(); // ถ้าจะใช้ค่อยเปิด
      controlAutoSprinkler();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _waterLevelSubscription?.cancel();
    super.dispose();
  }

  // MARK: - Firebase Listener
  void _listenToWaterLevel() {
    final waterLevelRef = _database.ref('devices/pump/waterLevel');

    _waterLevelSubscription = waterLevelRef.onValue.listen(
      (event) {
        final data = event.snapshot.value;

        if (data != null) {
          double? parsedWaterLevel;

          if (data is num) {
            parsedWaterLevel = data.toDouble();
          } else if (data is String) {
            parsedWaterLevel = double.tryParse(data);
          }

          if (parsedWaterLevel != null) {
            setState(() {
              waterLevel = parsedWaterLevel!;
            });
          } else {
            debugPrint("Warning: Could not parse water level data: $data");
            setState(() => waterLevel = 0.0);
          }
        } else {
          setState(() => waterLevel = 0.0);
        }
      },
      onError: (error) {
        debugPrint("Error listening to water level: $error");
      },
    );
  }

  void updateDateTime() {
    final now = DateTime.now();
    setState(() {
      date = DateFormat('dd/MM/yyyy').format(now);
      time = DateFormat('HH:mm:ss').format(now);
    });
  }

  // --- Auto controls ---
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
        }
      } else if (avg >= 80) {
        if (sprinklerOn) toggleSprinkler(false);
      }
    }
  }

  // --- Controls ---
  void togglePump(bool v) async {
    setState(() => pumpOn = v);
    final url = v ? '/pump/on' : '/pump/off';
    try {
      await http.get(Uri.parse('$esp32Url$url'));
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void toggleSprinkler(bool v) async {
    setState(() => sprinklerOn = v);
    final url = v ? '/sprinkler/on' : '/sprinkler/off';
    try {
      await http.get(Uri.parse('$esp32Url$url'));
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  // --- Fetch from ESP32 ---
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
      debugPrint('Error soil fetch: $e');
    }
  }

  void fetchPumpStatus() async {
    // Placeholder
  }

  void fetchSprinklerStatus() async {
    // Placeholder
  }

  void addTray() {
    setState(() {
      traysCap.add(List.filled(6, 0.0));
      traysRes.add(List.filled(6, 0.0));
      traysStatus.add(List.filled(6, true));
      traysConnected.add(true);
    });
  }

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
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 0.9,
                children: [
                  ModernCard(
                    title: 'ความชื้นในดิน',
                    subtitle: 'ตรวจสอบค่าความชื้น',
                    icon: FontAwesomeIcons.droplet,
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
                  ModernCard(
                    title: 'ปั๊มน้ำ',
                    // แสดงระดับน้ำที่ดึงมาจาก Firebase
                    subtitle: 'ระดับน้ำ: ${waterLevel.toStringAsFixed(1)} ลิตร',
                    icon: FontAwesomeIcons.water,
                    gradientColors: const [
                      Color.fromARGB(255, 159, 192, 255),
                      Color.fromARGB(255, 94, 207, 255),
                    ],
                    onTap: () async {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PumpPage(
                            fontSize: 16.0,
                          ),
                        ),
                      );
                    },
                    titleFontSize: fontSize + 2,
                    subtitleFontSize: fontSize - 2,
                  ),
                  ModernCard(
                    title: 'สปริงเกอร์',
                    subtitle: sprinklerOn ? 'กำลังรดน้ำ' : 'ปิดอยู่',
                    icon: FontAwesomeIcons.seedling,
                    gradientColors: const [
                      Color.fromARGB(255, 241, 203, 146),
                      Color.fromARGB(255, 249, 121, 82),
                    ],
                    onTap: () async {
                      final updatedHistory = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SprinklerPage(
                            initialSprinklerOn: sprinklerOn,
                            initialAutoMode: sprinklerAuto,
                            initialHistory: sprinklerHistory,
                            fontSize: fontSize,
                            onUpdateHistory: (history) {
                              setState(() {
                                sprinklerHistory = history;
                              });
                            },
                          ),
                        ),
                      );
                      if (updatedHistory is List<Map<String, dynamic>>) {
                        setState(() {
                          sprinklerHistory = updatedHistory;
                        });
                      }
                    },
                    titleFontSize: fontSize + 2,
                    subtitleFontSize: fontSize - 2,
                  ),
                  ModernCard(
                    title: 'อัตราการใช้ไฟฟ้า',
                    subtitle: 'เช็คพลังงาน',
                    icon: FontAwesomeIcons.bolt,
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
                            sensors: [
                              {
                                'name': 'ปั๊มน้ำ',
                                'watt': 12.5,
                                'color': Colors.blue,
                                'lastUsed': '09:45 น.',
                                'usageCountToday': 3,
                                'icon': FontAwesomeIcons.water,
                                'detailPage': () => const PumpDetailPage(),
                              },
                              {
                                'name': 'สปริงเกอร์',
                                'watt': 8.3,
                                'color': Colors.orange,
                                'lastUsed': '07:30 น.',
                                'usageCountToday': 2,
                                'icon': FontAwesomeIcons.seedling,
                                'detailPage': () => const SprinklerDetailPage(),
                              },
                              {
                                'name': 'เซนเซอร์ 1',
                                'watt': 0.3,
                                'color': Colors.teal,
                                'lastUsed': '-',
                                'usageCountToday': 0,
                                'icon': FontAwesomeIcons.droplet,
                                'detailPage': () => const SensorDetailPage(
                                  sensor: {
                                    'name': 'เซนเซอร์ 1',
                                    'watt': 0.3,
                                    'value': 50.0,
                                  },
                                ),
                              },
                              {
                                'name': 'เซนเซอร์ 2',
                                'watt': 0.3,
                                'color': Colors.teal,
                                'lastUsed': '-',
                                'usageCountToday': 0,
                                'icon': FontAwesomeIcons.droplet,
                                'detailPage': () => const SensorDetailPage(
                                  sensor: {
                                    'name': 'เซนเซอร์ 2',
                                    'watt': 0.3,
                                    'value': 60.0,
                                  },
                                ),
                              },
                              {
                                'name': 'เซนเซอร์ 3',
                                'watt': 0.3,
                                'color': Colors.teal,
                                'lastUsed': '-',
                                'usageCountToday': 0,
                                'icon': FontAwesomeIcons.droplet,
                                'detailPage': () => const SensorDetailPage(
                                  sensor: {
                                    'name': 'เซนเซอร์ 3',
                                    'watt': 0.3,
                                    'value': 70.0,
                                  },
                                ),
                              },
                            ],
                          ),
                        ),
                      );
                    },
                    titleFontSize: fontSize + 1,
                    subtitleFontSize: fontSize - 2,
                  ),
                  ModernCard(
                    title: 'GPS Smart Farm',
                    subtitle: 'ดูตำแหน่งแปลงเกษตร',
                    icon: FontAwesomeIcons.locationDot,
                    gradientColors: const [
                      Color.fromARGB(255, 252, 231, 179),
                      Color.fromARGB(255, 246, 174, 41),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GPSPage(
                            position: gpsPosition,
                            fontSize: fontSize,
                          ),
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
}
