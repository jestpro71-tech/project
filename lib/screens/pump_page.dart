import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import Font Awesome
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firebase Firestore

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
  List<Map<String, dynamic>> waterHistory = []; // เปลี่ยนเป็น List ธรรมดา เพราะจะดึงจาก Firestore

  // สร้าง instance ของ Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<double>? _waterLevelSubscription; // <--- เพิ่มการประกาศตัวแปรนี้

  @override
  void initState() {
    super.initState();
    pumpOn = widget.initialPumpOn;
    auto = widget.initialAuto;
    waterLevel = widget.initialWaterLevel;
    // ไม่ต้องใช้ initialWaterHistory ตรงๆ แล้ว เพราะจะดึงจาก Firestore

    // เริ่มฟังการเปลี่ยนแปลงสถานะปั๊มน้ำจาก Firestore
    _listenToPumpStatus();
    // เริ่มฟังการเปลี่ยนแปลงประวัติการเติมน้ำจาก Firestore
    _listenToWaterHistory();

    // subscribe stream water level ถ้ามี
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

  // ฟังก์ชันสำหรับฟังการเปลี่ยนแปลงสถานะปั๊มน้ำจาก Firestore
  void _listenToPumpStatus() {
    _firestore.collection('devices').doc('pump').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          setState(() {
            // อัปเดตสถานะ pumpOn ตามค่าจาก Firestore
            pumpOn = data['status'] == 'on';
            auto = data['autoMode'] ?? false; // ดึงค่า autoMode ด้วย
          });
        }
      }
    }, onError: (error) {
      print("Error listening to pump status: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อกับ Firebase: $error')),
      );
    });
  }

  // ฟังก์ชันสำหรับฟังการเปลี่ยนแปลงประวัติการเติมน้ำจาก Firestore
  void _listenToWaterHistory() {
    _firestore
        .collection('devices')
        .doc('pump')
        .collection('history') // เข้าถึง subcollection 'history'
        .orderBy('timestamp', descending: true) // เรียงลำดับตามเวลาล่าสุด
        .limit(10) // จำกัดจำนวนประวัติที่แสดง
        .snapshots()
        .listen((snapshot) {
      setState(() {
        waterHistory = snapshot.docs.map((doc) => doc.data()).toList();
      });
    }, onError: (error) {
      print("Error listening to water history: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดประวัติการเติมน้ำ: $error')),
      );
    });
  }

  // ฟังก์ชันสำหรับสลับสถานะปั๊มน้ำและอัปเดต Firestore
  Future<void> togglePump(bool value) async {
    setState(() {
      pumpOn = value;
      if (pumpOn && auto) { // แก้ไขจาก autoMode เป็น auto
        auto = false; // ถ้าเปิดเองด้วยมือ ให้ปิดโหมดอัตโนมัติ
      }
    });

    try {
      // อัปเดตสถานะใน Firestore
      await _firestore.collection('devices').doc('pump').set({
        'status': value ? 'on' : 'off',
        'autoMode': auto, // อัปเดต autoMode ด้วย
        'lastUpdated': FieldValue.serverTimestamp(), // บันทึกเวลาที่อัปเดต
      }, SetOptions(merge: true)); // ใช้ merge เพื่อไม่ให้เขียนทับ field อื่นๆ

      if (value) {
        _addWaterHistory('Manual'); // เพิ่มประวัติเมื่อเปิดด้วยมือ
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ปั๊มน้ำถูก ${value ? "เปิด" : "ปิด"} แล้ว')),
      );
    } catch (e) {
      print("Error updating pump status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถอัปเดตสถานะปั๊มน้ำได้: $e')),
      );
      // ย้อนสถานะกลับหากเกิดข้อผิดพลาดในการอัปเดต Firebase
      setState(() {
        pumpOn = !value;
      });
    }
  }

  // ฟังก์ชันสำหรับสลับโหมดอัตโนมัติและอัปเดต Firestore
  Future<void> toggleAuto() async {
    setState(() {
      auto = !auto;
      if (auto && pumpOn) {
        pumpOn = false; // ถ้าเข้าโหมดอัตโนมัติ ให้ปิดการทำงานด้วยมือ
      }
    });

    try {
      // อัปเดตโหมดอัตโนมัติใน Firestore
      await _firestore.collection('devices').doc('pump').set({
        'autoMode': auto,
        'status': pumpOn ? 'on' : 'off', // อัปเดต status ด้วย
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (auto) {
        _addWaterHistory('Auto'); // เพิ่มประวัติเมื่อเข้าโหมดอัตโนมัติ
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหมดอัตโนมัติถูก ${auto ? "เปิด" : "ปิด"} แล้ว')),
      );
    } catch (e) {
      print("Error updating auto mode: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถอัปเดตโหมดอัตโนมัติได้: $e')),
      );
      // ย้อนสถานะกลับหากเกิดข้อผิดพลาดในการอัปเดต Firebase
      setState(() {
        auto = !auto;
      });
    }
  }

  // ฟังก์ชันสำหรับเพิ่มประวัติการเติมน้ำลง Firestore
  Future<void> _addWaterHistory(String mode) async {
    final now = DateTime.now();
    final item = {
      'time': '${now.hour}:${now.minute.toString().padLeft(2, '0')} น.',
      'amount': '${(5 + (waterLevel % 10)).toStringAsFixed(1)} ลิตร ($mode)',
      'timestamp': FieldValue.serverTimestamp(), // เพิ่ม timestamp สำหรับการเรียงลำดับ
    };

    try {
      await _firestore.collection('devices').doc('pump').collection('history').add(item);
      // ไม่ต้อง setState waterHistory ตรงๆ แล้ว เพราะ _listenToWaterHistory จะอัปเดตให้เอง
      // ไม่ต้องเรียก widget.onUpdateWaterHistory(waterHistory) แล้ว เพราะข้อมูลจะถูกดึงจาก Firestore โดยตรง
    } catch (e) {
      print("Error adding water history to Firestore: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถบันทึกประวัติการเติมน้ำได้: $e')),
      );
    }
  }

  // ฟังก์ชันสำหรับล้างประวัติการเติมน้ำใน Firestore
  void _clearWaterHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ล้างประวัติ', style: TextStyle(fontFamily: 'Prompt')),
        content: const Text('ต้องการล้างประวัติการเติมน้ำทั้งหมดหรือไม่?', style: TextStyle(fontFamily: 'Prompt')),
        actions: [
          TextButton(
            child: const Text('ยกเลิก', style: TextStyle(fontFamily: 'Prompt')),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('ล้าง', style: TextStyle(color: Colors.red, fontFamily: 'Prompt')),
            onPressed: () async {
              try {
                // ลบเอกสารทั้งหมดใน subcollection 'history'
                final historySnapshot = await _firestore.collection('devices').doc('pump').collection('history').get();
                for (DocumentSnapshot doc in historySnapshot.docs) {
                  await doc.reference.delete();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ล้างประวัติเรียบร้อยแล้ว')),
                );
              } catch (e) {
                print("Error clearing water history from Firestore: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('ไม่สามารถล้างประวัติได้: $e')),
                );
              } finally {
                Navigator.pop(context);
              }
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
            fontFamily: 'Prompt', // เพิ่ม fontFamily
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
                      fontFamily: 'Prompt', // เพิ่ม fontFamily
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
                        fontFamily: 'Prompt', // เพิ่ม fontFamily
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
                            fontFamily: 'Prompt', // เพิ่ม fontFamily
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
                              FontAwesomeIcons.water, // Changed to FontAwesomeIcons.water
                              color: Colors.blue.shade400,
                            ),
                            title: Text(
                              'เวลา: ${item['time']}',
                              style: TextStyle(
                                fontSize: widget.fontSize,
                                fontFamily: 'Prompt', // เพิ่ม fontFamily
                              ),
                            ),
                            subtitle: Text(
                              'ปริมาณ: ${item['amount']}',
                              style: TextStyle(
                                fontSize: widget.fontSize - 2,
                                fontFamily: 'Prompt', // เพิ่ม fontFamily
                              ),
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
        onTap: () => togglePump(!pumpOn), // เรียกใช้ togglePump
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                FontAwesomeIcons.water, // Changed to FontAwesomeIcons.water
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
                        fontFamily: 'Prompt', // เพิ่ม fontFamily
                      ),
                    ),
                    Text(
                      pumpOn ? 'กำลังทำงาน' : 'ปิดอยู่',
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        color: Colors.grey.shade700,
                        fontFamily: 'Prompt', // เพิ่ม fontFamily
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: pumpOn,
                activeColor: Colors.green,
                onChanged: togglePump, // เรียกใช้ togglePump
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
        onTap: toggleAuto, // เรียกใช้ toggleAuto
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                FontAwesomeIcons.robot, // Changed to FontAwesomeIcons.robot for auto mode
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
                    fontFamily: 'Prompt', // เพิ่ม fontFamily
                  ),
                ),
              ),
              Switch(
                value: auto,
                activeColor: Colors.green,
                onChanged: (_) => toggleAuto(), // เรียกใช้ toggleAuto
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
                fontFamily: 'Prompt', // เพิ่ม fontFamily
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${waterLevel.toStringAsFixed(1)} ลิตร',
              style: TextStyle(
                fontSize: widget.fontSize + 1,
                color: Colors.blueGrey,
                fontFamily: 'Prompt', // เพิ่ม fontFamily
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
