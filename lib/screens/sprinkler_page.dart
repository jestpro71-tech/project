import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // <--- ตรวจสอบให้แน่ใจว่าบรรทัดนี้มีอยู่
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firebase Firestore

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

  // สร้าง instance ของ Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    sprinklerOn = widget.initialSprinklerOn;
    autoMode = widget.initialAutoMode;
    history = List<Map<String, dynamic>>.from(widget.initialHistory);

    // เริ่มฟังการเปลี่ยนแปลงสถานะสปริงเกอร์จาก Firestore
    _listenToSprinklerStatus();
  }

  // ฟังก์ชันสำหรับฟังการเปลี่ยนแปลงสถานะสถานะสปริงเกอร์จาก Firestore
  void _listenToSprinklerStatus() {
    _firestore.collection('devices').doc('sprinkler').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          setState(() {
            // อัปเดตสถานะ sprinklerOn ตามค่าจาก Firestore
            sprinklerOn = data['status'] == 'on';
            autoMode = data['autoMode'] ?? false; // ดึงค่า autoMode ด้วย
          });
        }
      }
    }, onError: (error) {
      print("Error listening to sprinkler status: $error");
      // แสดงข้อความแจ้งเตือนผู้ใช้หากเกิดข้อผิดพลาดในการเชื่อมต่อ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อกับ Firebase: $error')),
      );
    });
  }

  // ฟังก์ชันสำหรับสลับสถานะสปริงเกอร์และอัปเดต Firestore
  Future<void> toggleSprinkler(bool value) async {
    setState(() {
      sprinklerOn = value;
      if (sprinklerOn && autoMode) {
        autoMode = false; // ถ้าเปิดเองด้วยมือ ให้ปิดโหมดอัตโนมัติ
      }
    });

    try {
      // อัปเดตสถานะใน Firestore
      await _firestore.collection('devices').doc('sprinkler').set({
        'status': value ? 'on' : 'off',
        'autoMode': autoMode, // อัปเดต autoMode ด้วย
        'lastUpdated': FieldValue.serverTimestamp(), // บันทึกเวลาที่อัปเดต
      }, SetOptions(merge: true)); // ใช้ merge เพื่อไม่ให้เขียนทับ field อื่นๆ

      if (value) {
        _addHistory('Manual'); // เพิ่มประวัติเมื่อเปิดด้วยมือ
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สปริงเกอร์ถูก ${value ? "เปิด" : "ปิด"} แล้ว')),
      );
    } catch (e) {
      print("Error updating sprinkler status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถอัปเดตสถานะสปริงเกอร์ได้: $e')),
      );
      // ย้อนสถานะกลับหากเกิดข้อผิดพลาดในการอัปเดต Firebase
      setState(() {
        sprinklerOn = !value;
      });
    }
  }

  // ฟังก์ชันสำหรับสลับโหมดอัตโนมัติและอัปเดต Firestore
  Future<void> toggleAutoMode() async {
    setState(() {
      autoMode = !autoMode;
      if (autoMode && sprinklerOn) {
        sprinklerOn = false; // ถ้าเข้าโหมดอัตโนมัติ ให้ปิดการทำงานด้วยมือ
      }
    });

    try {
      // อัปเดตโหมดอัตโนมัติใน Firestore
      await _firestore.collection('devices').doc('sprinkler').set({
        'autoMode': autoMode,
        'status': sprinklerOn ? 'on' : 'off', // อัปเดต status ด้วย
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (autoMode) {
        _addHistory('Auto'); // เพิ่มประวัติเมื่อเข้าโหมดอัตโนมัติ
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหมดอัตโนมัติถูก ${autoMode ? "เปิด" : "ปิด"} แล้ว')),
      );
    } catch (e) {
      print("Error updating auto mode: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถอัปเดตโหมดอัตโนมัติได้: $e')),
      );
      // ย้อนสถานะกลับหากเกิดข้อผิดพลาดในการอัปเดต Firebase
      setState(() {
        autoMode = !autoMode;
      });
    }
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
            fontFamily: 'Prompt',
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
                FontAwesomeIcons.seedling,
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
                        fontFamily: 'Prompt',
                      ),
                    ),
                    Text(
                      sprinklerOn ? 'กำลังทำงาน' : 'ปิดอยู่',
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        color: Colors.grey.shade700,
                        fontFamily: 'Prompt',
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
                FontAwesomeIcons.robot,
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
                    fontFamily: 'Prompt',
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
                    fontFamily: 'Prompt',
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
                      fontFamily: 'Prompt',
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
                          fontFamily: 'Prompt',
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
                            FontAwesomeIcons.droplet, // เปลี่ยนจาก solidDroplet เป็น droplet
                            color: Colors.orange.shade700,
                          ),
                          title: Text(
                            'ถาด: ${item['tray']}',
                            style: TextStyle(
                              fontSize: widget.fontSize,
                              fontFamily: 'Prompt',
                            ),
                          ),
                          subtitle: Text(
                            'เวลา: ${item['time']}',
                            style: TextStyle(
                              fontSize: widget.fontSize - 2,
                              fontFamily: 'Prompt',
                            ),
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
