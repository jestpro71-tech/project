import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <<< เพิ่ม: สำหรับสั่งควบคุมปั๊มน้ำ

// --- คลาส StatefulWidget (ส่วนที่ 1) ---
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

// --- คลาส State (ส่วนที่ 2 ที่แก้ไข) ---
class _SoilDetailPageUpdatedV2State extends State<SoilDetailPageUpdated> {
  static const int kSensorsPerTray = 12;

  List<List<double>> traysCap = [];
  List<List<double>> traysRes = [];
  List<List<bool>> traysStatus = [];
  List<bool> traysConnected = [];

  // Firebase Instances
  late final FirebaseDatabase _database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // <<< เพิ่ม: Firestore Instance
  static const String rtdbUrl =
      'https://project-41b3d-default-rtdb.asia-southeast1.firebasedatabase.app';

  final List<StreamSubscription<DatabaseEvent>?> _soilMoistureSubs =
      List.filled(kSensorsPerTray, null);

  bool _isInitialDataLoaded = false;
  
  // ตัวแปรสำหรับควบคุมการสั่งงานปั๊มเพื่อป้องกันการสั่งซ้ำๆ ติดกัน
  String _lastPumpStatus = 'unknown';

  @override
  void initState() {
    super.initState();

    // 1. กำหนดค่าเริ่มต้นจาก Widget/ค่าว่าง
    traysCap = widget.traysCap.map((l) => _ensureLenDouble(l)).toList();
    traysRes = widget.traysRes.map((l) => _ensureLenDouble(l)).toList();
    traysStatus = widget.traysStatus.map((l) => _ensureLenBool(l)).toList();
    traysConnected = List<bool>.from(widget.traysConnected);

    // หากไม่มีถาดเลย ให้สร้างถาดเริ่มต้น 1 ถาด
    if (traysCap.isEmpty) {
      traysCap = [List.filled(kSensorsPerTray, 0.0)];
      traysRes = [List.filled(kSensorsPerTray, 0.0)];
      traysStatus = [List.filled(kSensorsPerTray, false)];
      traysConnected = [true];
    }

    _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: rtdbUrl,
    );

    // 2. เริ่ม Listener ทันทีเพื่อให้ดึงค่าจาก Firebase มาแสดงผล
    _listenToAllSoilMoisture();

    // 3. โหลดข้อมูล Local Storage มาอัปเดตค่าอื่นๆ 
    loadData();
  }

  @override
  void dispose() {
    for (final sub in _soilMoistureSubs) {
      sub?.cancel();
    }
    super.dispose();
  }

  // --------- RTDB SINGLE LISTENER & Pump Control ----------
  void _listenToAllSoilMoisture() {
    final ref = _database.ref('devices/soil/latest');

    _soilMoistureSubs[0] = ref.onValue.listen(
      (event) {
        final dataMap = event.snapshot.value as Map<dynamic, dynamic>?;

        if (dataMap == null) {
          debugPrint('Latest soil data is NULL or not a Map.');
          return;
        }

        // ใช้ setState ครั้งเดียวเมื่อข้อมูลมาถึง
        setState(() {
          for (int i = 0; i < kSensorsPerTray; i++) {
            final sensorName = 'soilMoisture${i + 1}';
            final rawValue = dataMap[sensorName];
            double v = 0.0;

            if (rawValue is num) {
              v = rawValue.toDouble();
            } else if (rawValue is String) {
              v = double.tryParse(rawValue) ?? 0.0;
            }

            final val = v.clamp(0.0, 100.0).toDouble();

            // อัปเดตทุกถาด: traysRes คือค่าความชื้น
            for (int t = 0; t < traysRes.length; t++) {
              traysRes[t][i] = val;
              traysStatus[t][i] = (val > 0.0);
            }
          }

          _isInitialDataLoaded = true;
          
          // *********************************************************
          // *** Logic การควบคุมปั๊มน้ำอัตโนมัติ ***
          // *********************************************************
          if (traysRes.isNotEmpty) {
            // ใช้ค่าเฉลี่ยของถาดแรก (index 0) ในการตัดสินใจ
            final average = _calculateAverageMoisture(0);
            _checkAndControlPump(average);
          }
          // *********************************************************

        });
        saveData();
      },
      onError: (e) {
        debugPrint('All soil moisture listener error: $e');
      },
    );
  }
  // ------------------------------------------

  // *** Helper สำหรับคำนวณค่าเฉลี่ย ***
  double _calculateAverageMoisture(int trayIndex) {
    if (traysRes.isEmpty || traysRes.length <= trayIndex) return 0.0;
    
    final List<double> sensorValues = traysRes[trayIndex];
    final List<double> activeSensorValues = sensorValues
        .where((val) => val > 0.0)
        .toList();

    if (activeSensorValues.isEmpty) return 0.0;

    double sum = activeSensorValues.reduce((a, b) => a + b);
    return sum / activeSensorValues.length;
  }
  
  // *** Logic การควบคุมปั๊มน้ำอัตโนมัติ ***
  void _checkAndControlPump(double averageMoisture) {
    String? status;
    
    // เงื่อนไข: น้อยกว่า 60% -> เปิดปั๊ม (สถานะ 'on')
    if (averageMoisture < 60.0) {
      status = 'on';
    } 
    // เงื่อนไข: มากกว่า 70% -> ปิดปั๊ม (สถานะ 'off')
    else if (averageMoisture > 70.0) {
      status = 'off';
    }
    
    // สั่งควบคุมเมื่อสถานะมีการเปลี่ยนแปลงเท่านั้น
    if (status != null && status != _lastPumpStatus) {
      _controlPumpStatus(status, averageMoisture);
    }
  }

  // ฟังก์ชันสั่งเขียนสถานะปั๊มน้ำลง Firestore
  Future<void> _controlPumpStatus(String status, double avg) async {
    try {
      // เขียนสถานะปั๊มไปยัง devices/pump
      await _firestore.collection('devices').doc('pump').set({
        'status': status,
        // ตั้ง autoMode เป็น true เพื่อให้รู้ว่าถูกควบคุมจากระบบความชื้น
        'autoMode': true, 
        'lastAutoUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      _lastPumpStatus = status; // อัปเดตสถานะสุดท้ายที่สั่ง
      debugPrint('Pump set to $status by soil auto control (Avg: ${avg.toStringAsFixed(1)}%)');
    } catch (e) {
      debugPrint("Error controlling pump: $e");
    }
  }
  // --------------------------------------------------------------------------

  // ---------- Local storage (load/save/add/remove) ----------
  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCap = prefs.getString('traysCap');
    final savedRes = prefs.getString('traysRes');
    final savedStatus = prefs.getString('traysStatus');
    final savedConnected = prefs.getString('traysConnected');

    setState(() {
      // โหลดค่า Capacitance (traysCap)
      traysCap = savedCap != null
          ? (jsonDecode(savedCap) as List)
                .map<List<double>>(
                  (t) => _ensureLenDouble(List<double>.from(t)),
                )
                .toList()
          : traysCap;

      // โหลดค่า Resistance (traysRes) จาก Local Storage แต่จะถูกแทนที่ทันทีด้วย Firebase
      traysRes = savedRes != null
          ? (jsonDecode(savedRes) as List)
                .map<List<double>>(
                  (t) => _ensureLenDouble(List<double>.from(t)),
                )
                .toList()
          : traysRes;

      // โหลดสถานะ
      traysStatus = savedStatus != null
          ? (jsonDecode(savedStatus) as List).map<List<bool>>((t) {
                final trayIndex = (jsonDecode(savedStatus) as List).indexOf(t);
                final currentRes = traysRes.length > trayIndex
                    ? traysRes[trayIndex]
                    : List<double>.filled(kSensorsPerTray, 0.0);
                return _ensureLenBool(
                  List.generate(kSensorsPerTray, (i) => currentRes[i] > 0.0),
                );
              }).toList()
          : traysStatus;

      traysConnected = savedConnected != null
          ? List<bool>.from(jsonDecode(savedConnected))
          : traysConnected;

      // ตรวจสอบความว่างอีกครั้ง
      if (traysCap.isEmpty) {
        traysCap = [List.filled(kSensorsPerTray, 0.0)];
        traysRes = [List.filled(kSensorsPerTray, 0.0)];
        traysStatus = [List.filled(kSensorsPerTray, false)];
        traysConnected = [true];
      }
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
      traysCap.add(List.filled(kSensorsPerTray, 0.0));
      traysRes.add(List.filled(kSensorsPerTray, 0.0));
      traysStatus.add(List.filled(kSensorsPerTray, false));
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

  List<double> _ensureLenDouble(List<double> src) {
    if (src.length == kSensorsPerTray) return List<double>.from(src);
    if (src.length > kSensorsPerTray) return src.sublist(0, kSensorsPerTray);
    return List<double>.from(src)
      ..addAll(List.filled(kSensorsPerTray - src.length, 0.0));
  }

  List<bool> _ensureLenBool(List<bool> src) {
    if (src.length == kSensorsPerTray) return List<bool>.from(src);
    if (src.length > kSensorsPerTray) return src.sublist(0, kSensorsPerTray);
    return List<bool>.from(src)
      ..addAll(List.filled(kSensorsPerTray - src.length, false));
  }
  // --------------------------------------------------------------------------

  // --- Widget สำหรับแสดงค่าเฉลี่ย ---
  Widget _buildAverageSection(int trayIndex) {
    final double average = _calculateAverageMoisture(trayIndex);
    
    final List<double> sensorValues = traysRes[trayIndex];
    final int sensorsCounted = sensorValues
        .where((val) => val > 0.0)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ค่าความชื้นเฉลี่ย',
                style: TextStyle(
                  fontSize: widget.fontSize + 2,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${average.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: widget.fontSize + 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    'จาก $sensorsCounted เซ็นเซอร์ที่เชื่อมต่อ',
                    style: TextStyle(
                      fontSize: widget.fontSize - 1,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (average / 100).clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: Colors.blueGrey.shade100,
                  valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        const SizedBox(height: 12),
      ],
    );
  }

  // ---------- UI ----------
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
      body: traysCap.isEmpty || !_isInitialDataLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: traysCap.length,
              itemBuilder: (context, trayIndex) => buildTrayCard(trayIndex),
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
              'วันที่: ${widget.date}    เวลา: ${widget.time}',
              style: TextStyle(
                fontSize: widget.fontSize,
                color: Colors.grey.shade600,
              ),
            ),

            // --- เรียกใช้ Widget ค่าเฉลี่ย ---
            _buildAverageSection(trayIndex),

            // --- แสดงรายการเซ็นเซอร์ ---
            ...List.generate(kSensorsPerTray, (sensorIndex) {
              final double resVal = traysRes[trayIndex][sensorIndex];

              String statusText;
              Color statusColor;
              IconData statusIcon;

              if (resVal > 0.0) {
                // มีค่า: ปกติ
                statusText = '✅ ปกติ';
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
              } else {
                // ไม่มีค่า (0.0%): ยังไม่เชื่อมต่อ
                statusText = '⏳ ยังไม่เชื่อมต่อ';
                statusColor = Colors.amber;
                statusIcon = Icons.access_time;
              }

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
                            statusIcon, 
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
                    Text(
                      'ค่าความชื้น: ${resVal.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: widget.fontSize),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (resVal / 100).clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: Colors.teal.shade100,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.teal.shade400,
                        ),
                      ),
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