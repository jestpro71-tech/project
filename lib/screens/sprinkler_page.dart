import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  List<Map<String, dynamic>> history = []; // เปลี่ยนเป็น List ธรรมดา เพราะจะดึงจาก Firestore

  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // สร้าง instance ของ Firestore

  @override
  void initState() {
    super.initState();
    sprinklerOn = widget.initialSprinklerOn;
    autoMode = widget.initialAutoMode;
    // ไม่ต้องใช้ initialHistory ตรงๆ แล้ว เพราะจะดึงจาก Firestore

    // เริ่มฟังการเปลี่ยนแปลงสถานะสปริงเกอร์จาก Firestore
    _listenToSprinklerStatus();
    // เริ่มฟังการเปลี่ยนแปลงประวัติการทำงานสปริงเกอร์จาก Firestore
    _listenToSprinklerHistory();
  }

  // ฟังก์ชันสำหรับฟังการเปลี่ยนแปลงสถานะสถานะสปริงเกอร์จาก Firestore
  void _listenToSprinklerStatus() {
    _firestore.collection('devices').doc('sprinkler').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          setState(() {
            sprinklerOn = data['status'] == 'on';
            autoMode = data['autoMode'] ?? false;
          });
        }
      }
    }, onError: (error) {
      print("Error listening to sprinkler status: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อกับ Firebase: $error')),
      );
    });
  }

  // ฟังก์ชันสำหรับฟังการเปลี่ยนแปลงประวัติการทำงานสปริงเกอร์จาก Firestore
  void _listenToSprinklerHistory() {
    _firestore
        .collection('devices')
        .doc('sprinkler')
        .collection('history') // เข้าถึง subcollection 'history'
        .orderBy('timestamp', descending: true) // เรียงลำดับตามเวลาล่าสุด
        .limit(10) // จำกัดจำนวนประวัติที่แสดง
        .snapshots()
        .listen((snapshot) {
      setState(() {
        history = snapshot.docs.map((doc) => doc.data()).toList();
      });
    }, onError: (error) {
      print("Error listening to sprinkler history: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดประวัติสปริงเกอร์: $error')),
      );
    });
  }

  // ฟังก์ชันสำหรับสลับสถานะสปริงเกอร์และอัปเดต Firestore
  Future<void> toggleSprinkler(bool value) async {
    setState(() {
      sprinklerOn = value;
      if (sprinklerOn && autoMode) { // แก้ไขจาก pumpOn เป็น sprinklerOn
        autoMode = false;
      }
    });

    try {
      await _firestore.collection('devices').doc('sprinkler').set({
        'status': value ? 'on' : 'off',
        'autoMode': autoMode,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (value) {
        _addHistory('Manual');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สปริงเกอร์ถูก ${value ? "เปิด" : "ปิด"} แล้ว')),
      );
    } catch (e) {
      print("Error updating sprinkler status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถอัปเดตสถานะสปริงเกอร์ได้: $e')),
      );
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
        sprinklerOn = false;
      }
    });

    try {
      await _firestore.collection('devices').doc('sprinkler').set({
        'autoMode': autoMode,
        'status': sprinklerOn ? 'on' : 'off',
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (autoMode) {
        _addHistory('Auto');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหมดอัตโนมัติถูก ${autoMode ? "เปิด" : "ปิด"} แล้ว')),
      );
    } catch (e) {
      print("Error updating auto mode: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถอัปเดตโหมดอัตโนมัติได้: $e')),
      );
      setState(() {
        autoMode = !autoMode;
      });
    }
  }

  // ฟังก์ชันสำหรับเพิ่มประวัติการทำงานลง Firestore
  Future<void> _addHistory(String mode) async {
    final now = DateTime.now();
    final item = {
      'tray': mode == 'Auto' ? 'ถาด 1,2,3' : 'Manual',
      'time': '${now.hour}:${now.minute.toString().padLeft(2, '0')} น. ($mode)',
      'timestamp': FieldValue.serverTimestamp(), // เพิ่ม timestamp สำหรับการเรียงลำดับ
    };

    try {
      await _firestore.collection('devices').doc('sprinkler').collection('history').add(item);
      // ไม่ต้อง setState history ตรงๆ แล้ว เพราะ _listenToSprinklerHistory จะอัปเดตให้เอง
      // ไม่ต้องเรียก widget.onUpdateHistory(history) แล้ว เพราะข้อมูลจะถูกดึงจาก Firestore โดยตรง
    } catch (e) {
      print("Error adding history to Firestore: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถบันทึกประวัติได้: $e')),
      );
    }
  }

  // ฟังก์ชันสำหรับล้างประวัติการทำงานใน Firestore
  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ล้างประวัติ', style: TextStyle(fontFamily: 'Prompt')),
        content: const Text(
          'ต้องการล้างประวัติการทำงานสปริงเกอร์ทั้งหมดหรือไม่?',
          style: TextStyle(fontFamily: 'Prompt'),
        ),
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
                final historySnapshot = await _firestore.collection('devices').doc('sprinkler').collection('history').get();
                for (DocumentSnapshot doc in historySnapshot.docs) {
                  await doc.reference.delete();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ล้างประวัติเรียบร้อยแล้ว')),
                );
              } catch (e) {
                print("Error clearing history from Firestore: $e");
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
                            FontAwesomeIcons.droplet,
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
