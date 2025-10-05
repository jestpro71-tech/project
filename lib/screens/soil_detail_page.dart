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
  StreamSubscription<DatabaseEvent>? _soilMoistureSub;

  @override
  void initState() {
    super.initState();

    // clone ค่าจาก parent แล้ว normalize เป็น 12 เซ็นเซอร์/ถาด
    traysCap = widget.traysCap.map((l) => _ensureLenDouble(l)).toList();
    traysRes = widget.traysRes.map((l) => _ensureLenDouble(l)).toList();
    traysStatus = widget.traysStatus.map((l) => _ensureLenBool(l)).toList();
    traysConnected = List<bool>.from(widget.traysConnected);
    if (traysCap.isEmpty) {
      traysCap = [List.filled(kSensorsPerTray, 0.0)];
      traysRes = [List.filled(kSensorsPerTray, 0.0)];
      traysStatus = [List.filled(kSensorsPerTray, true)];
      traysConnected = [true];
    }

    _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: rtdbUrl,
    );

    // โหลดจาก local แล้วฟังค่า RTDB
    loadData().then((_) => _listenToSoilMoisture());
  }

  @override
  void dispose() {
    _soilMoistureSub?.cancel();
    super.dispose();
  }

  // --------- RTDB: ผูกเฉพาะเซ็นเซอร์ 1 (index 0) ----------
  void _listenToSoilMoisture() {
    final ref = _database.ref('devices/pump/soil/latest/');
    _soilMoistureSub = ref.onValue.listen((event) {
      final raw = event.snapshot.value;
      double? v;
      if (raw is num) v = raw.toDouble();
      if (raw is String) v = double.tryParse(raw);

      if (v != null) {
        final val = v.clamp(0, 100).toDouble();
        setState(() {
          for (int t = 0; t < traysRes.length; t++) {
            traysRes[t][0] = val; // <-- อัปเดตเฉพาะเซ็นเซอร์ 1
            // ที่เหลือ index 1..11 คงไว้ (mockup), เริ่มต้นคือ 0.0
          }
        });
      }
    }, onError: (e) {
      debugPrint('SoilMoisture listener error: $e');
    });
  }

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
              .map<List<bool>>((t) => _ensureLenBool(List<bool>.from(t)))
              .toList()
          : traysStatus;
      traysConnected = savedConnected != null
          ? List<bool>.from(jsonDecode(savedConnected))
          : traysConnected;
      if (traysCap.isEmpty) {
        traysCap = [List.filled(kSensorsPerTray, 0.0)];
        traysRes = [List.filled(kSensorsPerTray, 0.0)];
        traysStatus = [List.filled(kSensorsPerTray, true)];
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
      traysStatus.add(List.filled(kSensorsPerTray, true));
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
    return List<bool>.from(src)
      ..addAll(List.filled(kSensorsPerTray - src.length, true));
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

  // ---- Widget สำหรับแสดงค่าเฉลี่ย ----
  Widget _buildAverageSection(int trayIndex) {
    final List<double> sensorValues = traysRes[trayIndex];
    final List<bool> sensorStatuses = traysStatus[trayIndex];

    final List<double> activeSensorValues = [];
    for (int i = 0; i < sensorValues.length; i++) {
      if (sensorStatuses[i]) {
        activeSensorValues.add(sensorValues[i]);
      }
    }

    double average = 0.0;
    if (activeSensorValues.isNotEmpty) {
      average =
          activeSensorValues.reduce((a, b) => a + b) / activeSensorValues.length;
    }

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
                    'จาก ${activeSensorValues.length} เซ็นเซอร์',
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
              final String statusText = status ? '✅ ปกติ' : '❌ ขัดข้อง';
              final Color statusColor = status ? Colors.green : Colors.red;

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
                              status ? Icons.check_circle : Icons.error,
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