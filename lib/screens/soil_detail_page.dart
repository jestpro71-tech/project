import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

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


// --- คลาส State (ส่วนที่ 2 ที่เราแก้ไขกัน) ---
class _SoilDetailPageUpdatedV2State extends State<SoilDetailPageUpdated> {
  // ---- ตั้งให้ 1 ถาดมี 12 เซ็นเซอร์ ----
  static const int kSensorsPerTray = 12;

  List<List<double>> traysCap = [];
  List<List<double>> traysRes = [];
  List<List<bool>> traysStatus = [];
  List<bool> traysConnected = [];

  // RTDB
  late final FirebaseDatabase _database;
  static const String rtdbUrl =
      'https://project-41b3d-default-rtdb.asia-southeast1.firebasedatabase.app';
  
  // ใช้ List เพื่อจัดการ StreamSubscription ทั้ง 12 ตัว
  final List<StreamSubscription<DatabaseEvent>?> _soilMoistureSubs = 
      List.filled(kSensorsPerTray, null); 

  @override
  void initState() {
    super.initState();

    // clone ค่าจาก parent แล้ว normalize เป็น 12 เซ็นเซอร์/ถาด
    traysCap = widget.traysCap.map((l) => _ensureLenDouble(l)).toList();
    traysRes = widget.traysRes.map((l) => _ensureLenDouble(l)).toList();
    // ใช้ _ensureLenBool เพื่อให้สถานะเริ่มต้นของเซ็นเซอร์เป็น false
    traysStatus = widget.traysStatus.map((l) => _ensureLenBool(l)).toList();
    traysConnected = List<bool>.from(widget.traysConnected);
    if (traysCap.isEmpty) {
      traysCap = [List.filled(kSensorsPerTray, 0.0)];
      traysRes = [List.filled(kSensorsPerTray, 0.0)];
      // ให้สถานะเริ่มต้นของเซ็นเซอร์เป็น false
      traysStatus = [List.filled(kSensorsPerTray, false)]; 
      traysConnected = [true];
    }

    // ต้องแน่ใจว่าได้เรียก Firebase.initializeApp() ไว้ก่อนหน้านี้ใน App แล้ว
    _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: rtdbUrl,
    );

    // โหลดจาก local แล้วฟังค่า RTDB
    loadData().then((_) {
      // วนลูปเพื่อเชื่อมต่อ Listener ทั้ง 12 ตัว (index 0 ถึง 11)
      for (int i = 0; i < kSensorsPerTray; i++) {
        _listenToSoilMoisture(i);
      }
    });
  }

  @override
  void dispose() {
    // ยกเลิก Subscription ทั้งหมดใน List
    for (final sub in _soilMoistureSubs) {
      sub?.cancel();
    }
    super.dispose();
  }

  // --------- NEW GENERIC RTDB LISTENER for Sensor (index 0 to 11) ----------
  void _listenToSoilMoisture(int sensorIndex) {
    // สร้าง Path ชื่อ 'soilMoisture1', 'soilMoisture2', ..., 'soilMoisture12'
    final sensorName = 'soilMoisture${sensorIndex + 1}';
    final ref = _database.ref('devices/soil/latest/$sensorName');
    
    _soilMoistureSubs[sensorIndex] = ref.onValue.listen((event) {
      final raw = event.snapshot.value; 
      double? v;

      // ตรวจสอบและแปลงค่าที่ถูกต้อง
      if (raw is num) {
        v = raw.toDouble();
      } else if (raw is String) {
        v = double.tryParse(raw);
      } else {
        debugPrint('$sensorName: Invalid data type received: ${raw.runtimeType}');
      }

      if (v != null) {
        final val = v.clamp(0.0, 100.0).toDouble();
        setState(() {
          // อัปเดตทุกถาดที่ index ปัจจุบัน (sensorIndex)
          for (int t = 0; t < traysRes.length; t++) {
            traysRes[t][sensorIndex] = val; 
            // อัปเดตสถานะเป็น true เมื่อได้รับค่า > 0.0
            traysStatus[t][sensorIndex] = (val > 0.0);
          }
        });
        saveData(); // บันทึกสถานะใหม่
      }
    }, onError: (e) {
      debugPrint('$sensorName listener error: $e');
    });
  }
  // ----------------------------------------------------

  // ---------- Local storage ----------
  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCap = prefs.getString('traysCap');
    final savedRes = prefs.getString('traysRes');
    final savedStatus = prefs.getString('traysStatus');
    final savedConnected = prefs.getString('traysConnected');

    setState(() {
      traysCap = savedCap != null
          ? (jsonDecode(savedCap) as List)
              .map<List<double>>((t) => _ensureLenDouble(List<double>.from(t)))
              .toList()
          : traysCap;
      traysRes = savedRes != null
          ? (jsonDecode(savedRes) as List)
              .map<List<double>>((t) => _ensureLenDouble(List<double>.from(t)))
              .toList()
          : traysRes;
      traysStatus = savedStatus != null
          ? (jsonDecode(savedStatus) as List)
              // โหลดสถานะและปรับให้เป็น false ถ้าค่าความชื้นเป็น 0.0
              .map<List<bool>>((t) {
                final loadedStatus = List<bool>.from(t);
                final trayIndex = (jsonDecode(savedStatus) as List).indexOf(t);
                final currentRes = traysRes.length > trayIndex ? traysRes[trayIndex] : List<double>.filled(kSensorsPerTray, 0.0);

                return _ensureLenBool(
                  List.generate(kSensorsPerTray, (i) => currentRes[i] > 0.0)
                );
              })
              .toList()
          : traysStatus;

      traysConnected = savedConnected != null
          ? List<bool>.from(jsonDecode(savedConnected))
          : traysConnected;
      if (traysCap.isEmpty) {
        traysCap = [List.filled(kSensorsPerTray, 0.0)];
        traysRes = [List.filled(kSensorsPerTray, 0.0)];
        traysStatus = [List.filled(kSensorsPerTray, false)]; // ใช้ false
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
      traysStatus.add(List.filled(kSensorsPerTray, false)); // ใช้ false
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

  // ---------- Helpers ----------
  List<double> _ensureLenDouble(List<double> src) {
    if (src.length == kSensorsPerTray) return List<double>.from(src);
    if (src.length > kSensorsPerTray) return src.sublist(0, kSensorsPerTray);
    return List<double>.from(src)
      ..addAll(List.filled(kSensorsPerTray - src.length, 0.0));
  }

  List<bool> _ensureLenBool(List<bool> src) {
    if (src.length == kSensorsPerTray) return List<bool>.from(src);
    if (src.length > kSensorsPerTray) return src.sublist(0, kSensorsPerTray);
    // ค่าเริ่มต้นของสถานะเป็น false (ยังไม่ต่อ)
    return List<bool>.from(src)
      ..addAll(List.filled(kSensorsPerTray - src.length, false));
  }

  // --- Widget สำหรับแสดงค่าเฉลี่ย ---
  Widget _buildAverageSection(int trayIndex) {
    final List<double> sensorValues = traysRes[trayIndex];
    final List<bool> sensorStatuses = traysStatus[trayIndex];

    // ดึงค่าเซ็นเซอร์ที่มีค่าความชื้น > 0.0% มาคำนวณเท่านั้น
    final List<double> activeSensorValues = [];

    // วนลูปตรวจสอบสถานะเซ็นเซอร์ทั้งหมด (ตั้งแต่ 1 ถึง 12)
    for (int i = 0; i < kSensorsPerTray; i++) {
      // ใช้เงื่อนไขที่เข้มงวด: ต้องมีค่า > 0.0 (ถึงแม้ว่า status จะเป็น true ก็ตาม)
      if (sensorValues[i] > 0.0) { 
        activeSensorValues.add(sensorValues[i]);
      }
    }

    double average = 0.0;
    if (activeSensorValues.isNotEmpty) {
      // คำนวณค่าเฉลี่ยตามจำนวนเซ็นเซอร์ที่ใช้งานจริง (มากกว่า 0.0%)
      average =
          activeSensorValues.reduce((a, b) => a + b) / activeSensorValues.length;
    }

    // จำนวนเซ็นเซอร์ที่นับรวมในการเฉลี่ย
    final int sensorsCounted = activeSensorValues.length;

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
                    // แสดงจำนวนเซ็นเซอร์ที่ใช้เฉลี่ย (ตามจำนวนที่ต่อจริง)
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
        title: Text('ความชื้นในดิน',
            style: TextStyle(
                fontSize: widget.fontSize + 3, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        actions: [
          IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'เพิ่มถาดความชื้น',
              onPressed: addTray),
        ],
      ),
      body: traysCap.isEmpty
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
                  child: Text('ถาด ${trayIndex + 1}',
                      style: TextStyle(
                          fontSize: widget.fontSize + 3,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800)),
                ),
                IconButton(
                  onPressed: () => removeTray(trayIndex),
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  tooltip: 'ลบถาดนี้',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('วันที่: ${widget.date}   เวลา: ${widget.time}',
                style: TextStyle(
                    fontSize: widget.fontSize, color: Colors.grey.shade600)),
            
            // --- เรียกใช้ Widget ค่าเฉลี่ย ---
            _buildAverageSection(trayIndex),

            // --- แสดงรายการเซ็นเซอร์ ---
            ...List.generate(kSensorsPerTray, (sensorIndex) {
              final bool status = traysStatus[trayIndex][sensorIndex];
              final double resVal = traysRes[trayIndex][sensorIndex];
              
              // กำหนดสถานะตามค่าจริง
              String statusText;
              Color statusColor;

              if (resVal > 0.0) { // เซ็นเซอร์ถือว่า 'ปกติ' และ 'ต่อแล้ว' ก็ต่อเมื่อมีค่า > 0.0
                 statusText = '✅ ปกติ';
                 statusColor = Colors.green;
              } else if (status == false && resVal == 0.0) {
                 statusText = '⏳ รอค่า';
                 statusColor = Colors.amber;
              } else {
                 statusText = '❌ ขัดข้อง';
                 statusColor = Colors.red;
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
                        offset: const Offset(0, 3))
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
                              (statusText == '✅ ปกติ') ? Icons.check_circle : (statusText == '⏳ รอค่า' ? Icons.access_time : Icons.error),
                              color: statusColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('เซ็นเซอร์ ${sensorIndex + 1}',
                              style: TextStyle(
                                  fontSize: widget.fontSize + 1,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Text(statusText,
                            style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('ค่าความชื้น: ${resVal.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: widget.fontSize)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (resVal / 100).clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: Colors.teal.shade100,
                        valueColor:
                            AlwaysStoppedAnimation(Colors.teal.shade400),
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
