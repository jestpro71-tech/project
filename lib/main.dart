import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

//ส่วน main() และ MyApp (Widget หลักของแอป)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Farm',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const Dashboard(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  double fontSize = 16;

  bool pumpOn = false;
  bool pumpAuto = true;

  bool sprinklerOn = false;
  bool sprinklerAuto = true;

  double waterLevel = 20;

  String date = '', time = '';
  Timer? timer;

  final String esp32Url = 'http://192.168.1.100';

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

  //ส่วนฟังก์ชันควบคุม Auto ปั๊มน้ำ และ Auto สปริงเกอร์
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

  //ส่วนฟังก์ชันควบคุมปั๊มน้ำและสปริงเกอร์ (เปิด-ปิด)
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

  //ส่วนฟังก์ชันดึงข้อมูลจาก ESP32
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
  //ส่วนเพิ่มถาดปลูก (กรณีต้องการเพิ่มถาดใหม่)
  void addTray() {
    setState(() {
      traysCap.add(List.filled(6, 0.0));
      traysRes.add(List.filled(6, 0.0));
      traysStatus.add(List.filled(6, true));
      traysConnected.add(true);
    });
  }

  //ส่วน Build UI หลักของหน้า Dashboard
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        elevation: 6,
        shape: RoundedRectangleBorder(
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
                    offset: Offset(0, 6),
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
                          Icons.calendar_today,
                          color: Colors.green.shade700,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: fontSize + 4,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade800,
                          ),
                        ),
                        SizedBox(width: 16),
                        Icon(
                          Icons.access_time,
                          color: Colors.green.shade700,
                          size: 22,
                        ),
                        SizedBox(width: 8),
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
                    SizedBox(height: 12),
                    Divider(
                      color: Colors.green.shade200,
                      thickness: 2,
                      indent: 30,
                      endIndent: 30,
                    ),
                    SizedBox(height: 12),
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
            //GridView แสดงเมนู Dashboard
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 1.0,
                children: [
                  // 🚰 ความชื้นในดิน
                  buildModernCard(
                    title: 'ความชื้นในดิน',
                    subtitle: 'ตรวจสอบค่าความชื้น',
                    icon: Icons.water_drop,
                    gradientColors: [
                      const Color.fromARGB(255, 155, 235, 173),
                      const Color.fromARGB(255, 54, 249, 103),
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
                  ),

                  // 💧 ปั๊มน้ำ
                  buildModernCard(
                    title: 'ปั๊มน้ำ',
                    subtitle: pumpOn ? 'สถานะ: ทำงาน' : 'สถานะ: ปิดอยู่',
                    icon: Icons.water,
                    gradientColors: [
                      Color.fromARGB(255, 159, 192, 255),
                      Color.fromARGB(255, 94, 207, 255),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PumpPage(
                            initialPumpOn: pumpOn,
                            initialAuto: pumpAuto,
                            initialWaterLevel: waterLevel,
                            initialWaterHistory: waterHistory,
                            fontSize: fontSize,
                            onUpdateWaterHistory: (updatedHistory) {
                              setState(() {
                                waterHistory =
                                    updatedHistory; // << สำคัญ: อัปเดตประวัติกลับมาหน้าแรก
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),

                  // 🌾 สปริงเกอร์
                  buildModernCard(
                    title: 'สปริงเกอร์',
                    subtitle: sprinklerOn ? 'กำลังรดน้ำ' : 'ปิดอยู่',
                    icon: Icons.grass,
                    gradientColors: [
                      Color.fromARGB(255, 241, 203, 146),
                      Color.fromARGB(255, 249, 121, 82),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SprinklerPage(
                            initialSprinklerOn: sprinklerOn,
                            initialAutoMode: sprinklerAuto,
                            initialHistory: sprinklerHistory,
                            fontSize: fontSize,
                            onUpdateHistory: (updatedHistory) {
                              setState(() {
                                sprinklerHistory = updatedHistory;
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),

                  // ⚡ อัตราการใช้ไฟฟ้า
                  buildModernCard(
                    title: 'อัตราการใช้ไฟฟ้า',
                    subtitle: 'เช็คพลังงาน',
                    icon: Icons.bolt,
                    gradientColors: [
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
                  ),

                  // 📍 GPS Smart Farm
                  buildModernCard(
                    title: 'GPS Smart Farm',
                    subtitle: 'ดูตำแหน่งแปลงเกษตร',
                    icon: Icons.location_on,
                    gradientColors: [
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //Widget ที่ใช้แสดงเมนูในหน้าหลัก (Dashboard)
  Widget buildModernCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ✅ วงกลม Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: Colors.black87, // ใช้สีไอคอนตามธีมได้
                ),
              ),

              const SizedBox(height: 16),

              // ✅ หัวข้อใหญ่ (Title)
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Prompt', // ✅ ใส่ฟอนต์สวย
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color.fromARGB(255, 31, 0, 0),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // ✅ หัวข้อย่อย (Subtitle)
              if (subtitle != null) ...[
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily:
                        'Prompt', // ✅ ใช้ฟอนต์ Prompt ให้ตรงกับหัวข้อหลัก
                    fontSize: 13, // ✅ เพิ่มขนาดให้ใหญ่ขึ้นอีกนิด
                    fontWeight: FontWeight.w600, // ✅ หนาเล็กน้อยแต่ยังอ่านง่าย
                    color: Color.fromARGB(
                      255,
                      88,
                      87,
                      87,
                    ), // ✅ สีเทาเข้มอ่านง่ายขึ้น (แทน ARGB เดิม)
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget buildDashboardCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    Color? bgColor,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 6,
        color: bgColor ?? Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 56),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: fontSize + 2,
                  fontWeight: FontWeight.w700,
                  color: iconColor.darken(0.3),
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: fontSize - 2,
                    color: iconColor.darken(0.5),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class GPSPage extends StatelessWidget {
  final LatLng position;
  const GPSPage({super.key, required this.position});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GPS ตำแหน่งฟาร์ม')),
      body: FlutterMap(
        options: MapOptions(
          center: position,
          zoom: 15,
          maxZoom: 18,
          minZoom: 5,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: position,
                width: 80,
                height: 80,
                builder: (context) =>
                    const Icon(Icons.location_pin, color: Colors.red, size: 48),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// หน้า PumpPage (ปั๊มน้ำ)
class PumpPage extends StatefulWidget {
  final bool initialPumpOn;
  final bool initialAuto;
  final double initialWaterLevel;
  final List<Map<String, String>> initialWaterHistory;
  final double fontSize;
  final ValueChanged<List<Map<String, String>>> onUpdateWaterHistory;

  // เพิ่มรับ Stream<double> สำหรับรับค่าระดับน้ำจากภายนอก
  final Stream<double>? waterLevelStream;

  const PumpPage({
    super.key,
    required this.initialPumpOn,
    required this.initialAuto,
    required this.initialWaterLevel,
    required this.initialWaterHistory,
    required this.fontSize,
    required this.onUpdateWaterHistory,
    this.waterLevelStream,
  });

  @override
  State<PumpPage> createState() => _PumpPageState();
}

class _PumpPageState extends State<PumpPage> {
  late bool pumpOn;
  late bool auto;
  late double waterLevel;
  late List<Map<String, String>> waterHistory;

  StreamSubscription<double>? _waterLevelSubscription;

  @override
  void initState() {
    super.initState();
    pumpOn = widget.initialPumpOn;
    auto = widget.initialAuto;
    waterLevel = widget.initialWaterLevel;
    waterHistory = List<Map<String, String>>.from(widget.initialWaterHistory);

    // subscribe stream ถ้ามี
    if (widget.waterLevelStream != null) {
      _waterLevelSubscription = widget.waterLevelStream!.listen((level) {
        setState(() {
          waterLevel = level;
        });
      });
    }
  }

  @override
  void dispose() {
    _waterLevelSubscription?.cancel();
    super.dispose();
  }

  void togglePump(bool value) {
    setState(() {
      pumpOn = value;
      if (pumpOn && auto) {
        auto = false;
      }
      if (pumpOn) {
        _addWaterHistory('Manual');
      }
    });
  }

  void toggleAuto() {
    setState(() {
      auto = !auto;
      if (auto && pumpOn) {
        pumpOn = false;
      }
      if (auto) {
        _addWaterHistory('Auto');
      }
    });
  }

  void _addWaterHistory(String mode) {
    final now = DateTime.now();
    final item = {
      'time': '${now.hour}:${now.minute.toString().padLeft(2, '0')} น.',
      'amount': '${(5 + (waterLevel % 10)).toStringAsFixed(1)} ลิตร ($mode)',
    };

    setState(() {
      waterHistory.insert(0, item);
      if (waterHistory.length > 10) {
        waterHistory.removeLast();
      }
    });

    widget.onUpdateWaterHistory(waterHistory);
  }

  void _clearWaterHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ล้างประวัติ'),
        content: const Text('ต้องการล้างประวัติการเติมน้ำทั้งหมดหรือไม่?'),
        actions: [
          TextButton(
            child: const Text('ยกเลิก'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('ล้าง', style: TextStyle(color: Colors.red)),
            onPressed: () {
              setState(() {
                waterHistory.clear();
                widget.onUpdateWaterHistory(waterHistory);
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ปั๊มน้ำ',
          style: TextStyle(
            fontSize: widget.fontSize + 4,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 16),
              _buildAutoCard(),
              const SizedBox(height: 24),
              _buildWaterLevel(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'ประวัติการเติมน้ำ',
                    style: TextStyle(
                      fontSize: widget.fontSize + 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _clearWaterHistory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                    ),
                    child: Text(
                      'ล้างประวัติ',
                      style: TextStyle(
                        fontSize: widget.fontSize - 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 400,
                child: waterHistory.isEmpty
                    ? Center(
                        child: Text(
                          'ยังไม่มีประวัติ',
                          style: TextStyle(
                            fontSize: widget.fontSize,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: waterHistory.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = waterHistory[index];
                          return ListTile(
                            leading: Icon(
                              Icons.water,
                              color: Colors.blue.shade400,
                            ),
                            title: Text(
                              'เวลา: ${item['time']}',
                              style: TextStyle(fontSize: widget.fontSize),
                            ),
                            subtitle: Text(
                              'ปริมาณ: ${item['amount']}',
                              style: TextStyle(fontSize: widget.fontSize - 2),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: pumpOn ? Colors.green.shade100 : Colors.grey.shade100,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          togglePump(!pumpOn);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.water,
                color: pumpOn ? Colors.teal : Colors.grey,
                size: 50,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'สถานะปั๊มน้ำ',
                      style: TextStyle(
                        fontSize: widget.fontSize + 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      pumpOn ? 'กำลังทำงาน' : 'ปิดอยู่',
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: pumpOn,
                activeColor: Colors.green,
                onChanged: togglePump,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoCard() {
    return Card(
      color: auto ? Colors.green.shade50 : Colors.grey.shade100,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: toggleAuto,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.grass,
                color: auto ? Colors.green : Colors.grey,
                size: 50,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'โหมดอัตโนมัติ',
                  style: TextStyle(
                    fontSize: widget.fontSize + 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: auto,
                activeColor: Colors.green,
                onChanged: (_) => toggleAuto(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaterLevel() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ระดับน้ำในถัง',
              style: TextStyle(
                fontSize: widget.fontSize + 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${waterLevel.toStringAsFixed(1)} ลิตร',
              style: TextStyle(
                fontSize: widget.fontSize + 1,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (waterLevel / 30).clamp(0.0, 1.0),
                minHeight: 16,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation(Colors.blue.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// หน้า SprinklerPage (สปริงเกอร์)
class SprinklerPage extends StatefulWidget {
  final bool initialSprinklerOn;
  final bool initialAutoMode;
  final List<Map<String, dynamic>> initialHistory;
  final double fontSize;
  final ValueChanged<List<Map<String, dynamic>>> onUpdateHistory;

  const SprinklerPage({
    super.key,
    required this.initialSprinklerOn,
    required this.initialAutoMode,
    required this.initialHistory,
    required this.fontSize,
    required this.onUpdateHistory,
  });

  @override
  State<SprinklerPage> createState() => _SprinklerPageState();
}

class _SprinklerPageState extends State<SprinklerPage> {
  late bool sprinklerOn;
  late bool autoMode;
  late List<Map<String, dynamic>> history;

  @override
  void initState() {
    super.initState();
    sprinklerOn = widget.initialSprinklerOn;
    autoMode = widget.initialAutoMode;
    history = List<Map<String, dynamic>>.from(widget.initialHistory);
  }

  void toggleSprinkler(bool value) {
    setState(() {
      sprinklerOn = value;
      if (sprinklerOn && autoMode) {
        autoMode = false;
      }
      if (sprinklerOn) {
        _addHistory('Manual');
      }
    });
  }

  void toggleAutoMode() {
    setState(() {
      autoMode = !autoMode;
      if (autoMode && sprinklerOn) {
        sprinklerOn = false;
      }
      if (autoMode) {
        _addHistory('Auto');
      }
    });
  }

  void _addHistory(String mode) {
    final now = DateTime.now();
    history.insert(0, {
      'tray': mode == 'Auto' ? 'ถาด 1,2,3' : 'Manual',
      'time': '${now.hour}:${now.minute.toString().padLeft(2, '0')} น. ($mode)',
    });
    if (history.length > 10) history.removeLast();
    widget.onUpdateHistory(history);
  }

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ล้างประวัติ'),
        content: const Text(
          'ต้องการล้างประวัติการทำงานสปริงเกอร์ทั้งหมดหรือไม่?',
        ),
        actions: [
          TextButton(
            child: const Text('ยกเลิก'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('ล้าง', style: TextStyle(color: Colors.red)),
            onPressed: () {
              setState(() {
                history.clear();
                widget.onUpdateHistory(history);
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'สปริงเกอร์',
          style: TextStyle(
            fontSize: widget.fontSize + 4,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.orange.shade700,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildAutoCard(),
            const SizedBox(height: 24),
            Expanded(child: _buildHistoryCard()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: sprinklerOn ? Colors.orange.shade100 : Colors.grey.shade100,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => toggleSprinkler(!sprinklerOn),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.grass,
                color: sprinklerOn ? Colors.orange.shade700 : Colors.grey,
                size: 50,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'สถานะสปริงเกอร์',
                      style: TextStyle(
                        fontSize: widget.fontSize + 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      sprinklerOn ? 'กำลังทำงาน' : 'ปิดอยู่',
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: sprinklerOn,
                activeColor: Colors.orange.shade700,
                onChanged: toggleSprinkler,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoCard() {
    return Card(
      color: autoMode ? Colors.orange.shade50 : Colors.grey.shade100,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: toggleAutoMode,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.eco,
                color: autoMode ? Colors.orange.shade700 : Colors.grey,
                size: 50,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'โหมดอัตโนมัติ',
                  style: TextStyle(
                    fontSize: widget.fontSize + 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: autoMode,
                activeColor: Colors.orange.shade700,
                onChanged: (_) => toggleAutoMode(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'ประวัติการทำงานสปริงเกอร์',
                  style: TextStyle(
                    fontSize: widget.fontSize + 2,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange.shade900,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _clearHistory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                  ),
                  child: Text(
                    'ล้างประวัติ',
                    style: TextStyle(
                      fontSize: widget.fontSize - 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: history.isEmpty
                  ? Center(
                      child: Text(
                        'ยังไม่มีประวัติ',
                        style: TextStyle(
                          fontSize: widget.fontSize,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const Divider(height: 10),
                      itemBuilder: (context, index) {
                        final item = history[index];
                        return ListTile(
                          leading: Icon(
                            Icons.invert_colors,
                            color: Colors.orange.shade700,
                          ),
                          title: Text(
                            'ถาด: ${item['tray']}',
                            style: TextStyle(fontSize: widget.fontSize),
                          ),
                          subtitle: Text(
                            'เวลา: ${item['time']}',
                            style: TextStyle(fontSize: widget.fontSize - 2),
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

/// หน้า SoilDetailPageUpdated (รายละเอียดความชื้นในดิน พร้อมเพิ่ม-ลบถาดได้)
class SoilDetailPageUpdated extends StatefulWidget {
  final String date;
  final String time;
  final List<List<double>> traysCap;
  final List<List<double>> traysRes;
  final List<List<bool>> traysStatus;
  final List<bool> traysConnected;
  final double fontSize;

  const SoilDetailPageUpdated({
    super.key,
    required this.date,
    required this.time,
    required this.traysCap,
    required this.traysRes,
    required this.traysStatus,
    required this.traysConnected,
    required this.fontSize,
  });

  @override
  State<SoilDetailPageUpdated> createState() => _SoilDetailPageUpdatedV2State();
}

class _SoilDetailPageUpdatedV2State extends State<SoilDetailPageUpdated> {
  List<List<double>> traysCap = [];
  List<List<double>> traysRes = [];
  List<List<bool>> traysStatus = [];
  List<bool> traysConnected = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCap = prefs.getString('traysCap');
    final savedRes = prefs.getString('traysRes');
    final savedStatus = prefs.getString('traysStatus');
    final savedConnected = prefs.getString('traysConnected');

    setState(() {
      traysCap = savedCap != null
          ? (jsonDecode(savedCap) as List)
                .map<List<double>>((t) => List<double>.from(t))
                .toList()
          : [List.filled(6, 0.0)];
      traysRes = savedRes != null
          ? (jsonDecode(savedRes) as List)
                .map<List<double>>((t) => List<double>.from(t))
                .toList()
          : [List.filled(6, 0.0)];
      traysStatus = savedStatus != null
          ? (jsonDecode(savedStatus) as List)
                .map<List<bool>>((t) => List<bool>.from(t))
                .toList()
          : [List.filled(6, true)];
      traysConnected = savedConnected != null
          ? List<bool>.from(jsonDecode(savedConnected))
          : [true];
    });
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('traysCap', jsonEncode(traysCap));
    await prefs.setString('traysRes', jsonEncode(traysRes));
    await prefs.setString('traysStatus', jsonEncode(traysStatus));
    await prefs.setString('traysConnected', jsonEncode(traysConnected));
  }

  void addTray() {
    setState(() {
      traysCap.add(List.filled(6, 0.0));
      traysRes.add(List.filled(6, 0.0));
      traysStatus.add(List.filled(6, true));
      traysConnected.add(true);
    });
    saveData();
  }

  void removeTray(int index) {
    setState(() {
      traysCap.removeAt(index);
      traysRes.removeAt(index);
      traysStatus.removeAt(index);
      traysConnected.removeAt(index);
    });
    saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ความชื้นในดิน',
          style: TextStyle(
            fontSize: widget.fontSize + 3,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'เพิ่มถาดความชื้น',
            onPressed: addTray,
          ),
        ],
      ),
      body: traysCap.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: traysCap.length,
              itemBuilder: (context, trayIndex) {
                return buildTrayCard(trayIndex);
              },
            ),
    );
  }

  Widget buildTrayCard(int trayIndex) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ถาด ${trayIndex + 1}',
                    style: TextStyle(
                      fontSize: widget.fontSize + 3,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => removeTray(trayIndex),
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  tooltip: 'ลบถาดนี้',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'วันที่: ${widget.date}  เวลา: ${widget.time}',
              style: TextStyle(
                fontSize: widget.fontSize,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(6, (sensorIndex) {
              bool status = traysStatus[trayIndex][sensorIndex];
              double capVal = traysCap[trayIndex][sensorIndex];
              double resVal = traysRes[trayIndex][sensorIndex];

              String statusText = status ? '✅ ปกติ' : '❌ ขัดข้อง';
              Color statusColor = status ? Colors.green : Colors.red;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Icon(
                            status ? Icons.check_circle : Icons.error,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'เซ็นเซอร์ ${sensorIndex + 1}',
                            style: TextStyle(
                              fontSize: widget.fontSize + 1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ค่าความจุ: ${capVal.toStringAsFixed(1)}%',
                                style: TextStyle(fontSize: widget.fontSize),
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: capVal / 100,
                                minHeight: 10,
                                color: Colors.blue.shade400,
                                backgroundColor: Colors.blue.shade100,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ค่าความชื้น: ${resVal.toStringAsFixed(1)}%',
                                style: TextStyle(fontSize: widget.fontSize),
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: resVal / 100,
                                minHeight: 10,
                                color: Colors.teal.shade400,
                                backgroundColor: Colors.teal.shade100,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

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
        'icon': Icons.water,
        'color': Colors.blue,
        'lastUsed': '09:45 น.',
        'usageCountToday': 3,
        'detailPage': () => PumpDetailPage(),
      },
      {
        'name': 'สปริงเกอร์',
        'power': 30.0,
        'icon': Icons.grass,
        'color': Colors.orange,
        'lastUsed': '07:30 น.',
        'usageCountToday': 2,
        'detailPage': () => SprinklerDetailPage(),
      },
    ];

    final List<Map<String, dynamic>> allDevices = [
      ...devices,
      ...sensors.map(
        (sensor) => {
          'name': sensor['name'],
          'power': sensor['power'],
          'icon': Icons.water_drop,
          'color': Colors.teal,
          'lastUsed': '-',
          'usageCountToday': 0,
          'detailPage': () => SensorDetailPage(sensor: sensor),
        },
      ),
    ];

    double totalPower = allDevices.fold(
      0,
      (sum, d) => sum + (d['power'] as double),
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
                  Icon(Icons.bolt, color: Colors.orange.shade800, size: 28),
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
                  final double power = device['power'];
                  final Color color = device['color'];
                  final double percent = power / totalPower;

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

class SensorListPage extends StatelessWidget {
  final List<Map<String, dynamic>> sensors; // เอา const ออก

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

class SensorDetailPage extends StatelessWidget {
  final Map<String, dynamic> sensor;
  const SensorDetailPage({super.key, required this.sensor});

  @override
  Widget build(BuildContext context) {
    final moisture = sensor['value'];

    String statusText;
    Color statusColor;
    if (moisture < 60) {
      statusText = '⚠️ ความชื้นต่ำเกินไป';
      statusColor = Colors.red;
    } else if (moisture > 80) {
      statusText = '⚠️ ความชื้นสูงเกินไป';
      statusColor = Colors.red;
    } else {
      statusText = '✅ ความชื้นปกติ';
      statusColor = Colors.green;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(sensor['name']),
        backgroundColor: Colors.teal.shade700,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ชื่อเซ็นเซอร์: ${sensor['name']}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'พลังงาน: ${sensor['power']} W',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                Text(
                  'ค่าความชื้น: ${sensor['value']}%',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: moisture / 100,
                    minHeight: 18,
                    color: Colors.teal.shade700,
                    backgroundColor: Colors.teal.shade200,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension ColorBrightness on Color {
  Color darken([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
