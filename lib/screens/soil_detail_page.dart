import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // ใช้ข้อมูลที่ส่งมาจาก Dashboard แทนการโหลดจาก SharedPreferences ใน initState
    // หรือคุณสามารถเลือกที่จะโหลดจาก SharedPreferences ถ้าต้องการให้ค่าคงอยู่แม้ปิดแอป
    traysCap = List<List<double>>.from(widget.traysCap.map((list) => List<double>.from(list)));
    traysRes = List<List<double>>.from(widget.traysRes.map((list) => List<double>.from(list)));
    traysStatus = List<List<bool>>.from(widget.traysStatus.map((list) => List<bool>.from(list)));
    traysConnected = List<bool>.from(widget.traysConnected);

    loadData(); // ยังคงเรียก loadData เพื่อโหลดข้อมูลที่บันทึกไว้ (ถ้ามี)
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
