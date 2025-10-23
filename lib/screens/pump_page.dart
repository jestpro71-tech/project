import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class PumpPage extends StatefulWidget {
  final double fontSize;
  const PumpPage({super.key, this.fontSize = 16.0});

  @override
  State<PumpPage> createState() => _PumpPageState();
}

class _PumpPageState extends State<PumpPage> {
  // สถานะที่อ่านจาก Firestore/RTDB
  bool pumpOn = false; // สถานะปั๊ม: อ่านจาก Firestore 'status'
  bool auto = false; // โหมดอัตโนมัติ: อ่านจาก Firestore 'autoMode'
  double waterLevel = 0.0; // ระดับน้ำ: อ่านจาก RTDB
  double tankCapacity = 100.0; // ความจุถัง: อ่านจาก RTDB
  bool floatSwitchOn = false; // สถานะลูกลอย: อ่านจาก RTDB

  // ประวัติการเติมน้ำ: อ่านจาก Firestore Subcollection
  List<Map<String, dynamic>> waterHistory = [];

  // Firestore & Realtime Database Instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final FirebaseDatabase _database;

  static const String rtdbUrl =
      'https://project-41b3d-default-rtdb.asia-southeast1.firebasedatabase.app';

  // Stream Subscriptions
  StreamSubscription<DatabaseEvent>? _waterLevelSubscription;
  StreamSubscription<DatabaseEvent>? _tankCapacitySubscription;
  StreamSubscription<DatabaseEvent>? _floatSwitchSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _pumpStatusSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _waterHistorySubscription;

  @override
  void initState() {
    super.initState();

    _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: rtdbUrl,
    );

    // เริ่ม Listeners ทั้งหมด
    _listenToPumpStatus();
    _listenToWaterHistory();
    _listenToWaterLevel();
    _listenToTankCapacity();
    _listenToFloatSwitch();
  }

  @override
  void dispose() {
    _pumpStatusSubscription?.cancel();
    _waterHistorySubscription?.cancel();
    _waterLevelSubscription?.cancel();
    _tankCapacitySubscription?.cancel();
    _floatSwitchSubscription?.cancel();
    super.dispose();
  }

  // ---------- Helpers & Listeners (โค้ดเดิม) ----------

  bool _parseBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
      final n = num.tryParse(s);
      return (n ?? 0) != 0;
    }
    return false;
  }

  void _safeSetState(VoidCallback cb) {
    if (!mounted) return;
    setState(cb);
  }

  void _listenToPumpStatus() {
    _pumpStatusSubscription = _firestore
        .collection('devices')
        .doc('pump')
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data();
              if (data != null) {
                _safeSetState(() {
                  // อัปเดตสถานะปั๊มและโหมดอัตโนมัติตาม Firestore
                  pumpOn = data['status'] == 'on'; //
                  auto = data['autoMode'] ?? false; //
                });
              }
            }
          },
          onError: (error) {
            debugPrint("Error listening to pump status: $error");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อสถานะปั๊ม: $error'),
              ),
            );
          },
        );
  }

  void _listenToWaterHistory() {
    _waterHistorySubscription = _firestore
        .collection('devices')
        .doc('pump')
        .collection('history')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            _safeSetState(() {
              waterHistory = snapshot.docs.map((doc) => doc.data()).toList();
            });
          },
          onError: (error) {
            debugPrint("Error listening to water history: $error");
          },
        );
  }

  void _listenToWaterLevel() {
    final waterLevelRef = _database.ref('devices/pump/waterLevel');
    _waterLevelSubscription = waterLevelRef.onValue.listen(
      (event) {
        final data = event.snapshot.value;
        if (data != null) {
          double? parsed;
          if (data is num) parsed = data.toDouble();
          if (data is String) parsed = double.tryParse(data);
          if (parsed != null) {
            _safeSetState(() => waterLevel = parsed!);
          } else {
            _safeSetState(() => waterLevel = 0.0);
          }
        } else {
          _safeSetState(() => waterLevel = 0.0);
        }
      },
      onError: (error) {
        debugPrint("Error listening to water level: $error");
      },
    );
  }

  void _listenToTankCapacity() {
    final capRef = _database.ref('devices/pump/tankCapacity');
    _tankCapacitySubscription = capRef.onValue.listen(
      (event) {
        final v = event.snapshot.value;
        double? cap;
        if (v is num) cap = v.toDouble();
        if (v is String) cap = double.tryParse(v);
        if (cap != null && cap > 0) {
          _safeSetState(() => tankCapacity = cap!);
        }
      },
      onError: (error) {
        debugPrint("Error listening to tankCapacity: $error");
      },
    );
  }

  void _listenToFloatSwitch() {
    final ref = _database.ref('devices/pump/floatSwitchState');
    _floatSwitchSubscription = ref.onValue.listen(
      (event) {
        final raw = event.snapshot.value;
        final next = _parseBool(raw);
        _safeSetState(() => floatSwitchOn = next);
      },
      onError: (e) {
        debugPrint('FloatSwitch listener error: $e');
      },
    );
  }

  // ---------- Actions (เพิ่ม Logic บล็อกเมื่อ Auto Mode ทำงาน) ----------

  Future<void> togglePump(bool value) async {
    // *** Logic การบล็อกเมื่อ Auto Mode ทำงาน ***
    if (auto) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ ปิดปั๊มด้วยมือไม่ได้! ปั๊มถูกควบคุมโดยโหมดอัตโนมัติ (ความชื้น)',
            style: TextStyle(fontSize: widget.fontSize, fontFamily: 'Prompt'),
          ),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      // ต้อง set state กลับเพื่อให้ switch ไม่ขยับตามการแตะ
      _safeSetState(() => pumpOn = !value);
      return;
    }

    // โค้ดเดิม: สั่งงานเมื่อ Auto Mode ถูกปิด
    _safeSetState(() {
      pumpOn = value;
      // เนื่องจาก Auto ถูกปิดอยู่แล้ว จึงไม่ต้อง set auto = false ซ้ำ
    });

    try {
      await _firestore.collection('devices').doc('pump').set({
        'status': value ? 'on' : 'off',
        'autoMode': auto,
        'lastManualUpdated': FieldValue.serverTimestamp(), // เปลี่ยนชื่อ Field ให้ชัดเจน
      }, SetOptions(merge: true));

      if (value) await _addWaterHistory('Manual');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
          'ปั๊มน้ำถูก ${value ? "เปิด" : "ปิด"} แล้ว',
          style: TextStyle(fontFamily: 'Prompt'),
        )),
      );
    } catch (e) {
      debugPrint("Error updating pump status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
          'ไม่สามารถอัปเดตสถานะปั๊มน้ำได้: $e',
          style: TextStyle(fontFamily: 'Prompt'),
        )),
      );
      _safeSetState(() => pumpOn = !value);
    }
  }

  Future<void> toggleAuto() async {
    final bool nextAuto = !auto;

    // หากเปิดโหมดอัตโนมัติ ต้องสั่งปิดปั๊มทันทีเพื่อส่งมอบการควบคุมให้ระบบอัตโนมัติ
    if (nextAuto && pumpOn) {
      await _firestore.collection('devices').doc('pump').set({
        'status': 'off', // สั่งปิดทันที
        'autoMode': nextAuto,
        'lastManualUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    
    // อัปเดต Auto Mode เท่านั้น
    try {
      await _firestore.collection('devices').doc('pump').set({
        'autoMode': nextAuto,
        'lastAutoModeToggle': FieldValue.serverTimestamp(), // เปลี่ยนชื่อ Field ให้ชัดเจน
      }, SetOptions(merge: true));

      _safeSetState(() {
        auto = nextAuto;
        // pumpOn จะถูกอัปเดตอัตโนมัติโดย Listener
      });

      if (nextAuto) await _addWaterHistory('Auto On');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
          'โหมดอัตโนมัติถูก ${nextAuto ? "เปิด" : "ปิด"} แล้ว',
          style: TextStyle(fontFamily: 'Prompt'),
        )),
      );
    } catch (e) {
      debugPrint("Error updating auto mode: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
          'ไม่สามารถอัปเดตโหมดอัตโนมัติได้: $e',
          style: TextStyle(fontFamily: 'Prompt'),
        )),
      );
    }
  }

  // (ส่วน _addWaterHistory และ _clearWaterHistory ใช้โค้ดเดิม)
  Future<void> _addWaterHistory(String mode) async {
    // ... (ใช้โค้ดเดิม) ...
    double currentWaterLevel = 0.0;
    try {
      final snapshot = await _database.ref('devices/pump/waterLevel').once();
      final data = snapshot.snapshot.value;
      if (data is num) currentWaterLevel = data.toDouble();
      if (data is String) currentWaterLevel = double.tryParse(data) ?? 0.0;
    } catch (e) {
      debugPrint("Error fetching current water level for history: $e");
    }

    final now = DateTime.now();
    final item = {
      'time': '${now.hour}:${now.minute.toString().padLeft(2, '0')} น.',
      'amount': '${currentWaterLevel.toStringAsFixed(1)} ลิตร ($mode)',
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore
          .collection('devices')
          .doc('pump')
          .collection('history')
          .add(item);
    } catch (e) {
      debugPrint("Error adding water history to Firestore: $e");
    }
  }
  
  void _clearWaterHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ล้างประวัติ',
          style: TextStyle(fontFamily: 'Prompt'),
        ),
        content: const Text(
          'ต้องการล้างประวัติการเติมน้ำทั้งหมดหรือไม่?',
          style: TextStyle(fontFamily: 'Prompt'),
        ),
        actions: [
          TextButton(
            child: const Text('ยกเลิก', style: TextStyle(fontFamily: 'Prompt')),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text(
              'ล้าง',
              style: TextStyle(color: Colors.red, fontFamily: 'Prompt'),
            ),
            onPressed: () async {
              try {
                final historySnapshot = await _firestore
                    .collection('devices')
                    .doc('pump')
                    .collection('history')
                    .get();
                for (DocumentSnapshot doc in historySnapshot.docs) {
                  await doc.reference.delete();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ล้างประวัติเรียบร้อยแล้ว')),
                );
              } catch (e) {
                debugPrint("Error clearing water history: $e");
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


  // ---------- UI (มีการแก้ไข Switch ใน Card) ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ปั๊มน้ำ',
          style: TextStyle(
            fontSize: widget.fontSize + 4,
            fontWeight: FontWeight.bold,
            fontFamily: 'Prompt',
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
              const SizedBox(height: 16),
              _buildFloatSwitchCard(),
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
                      fontFamily: 'Prompt',
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
                        fontFamily: 'Prompt',
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
                            fontFamily: 'Prompt',
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
                              FontAwesomeIcons.water,
                              color: Colors.blue.shade400,
                            ),
                            title: Text(
                              'เวลา: ${item['time']}',
                              style: TextStyle(
                                fontSize: widget.fontSize,
                                fontFamily: 'Prompt',
                              ),
                            ),
                            subtitle: Text(
                              'ปริมาณ: ${item['amount']}',
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
        onTap: () => togglePump(!pumpOn),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                FontAwesomeIcons.water,
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
                        fontFamily: 'Prompt',
                      ),
                    ),
                    Text(
                      pumpOn
                          ? (auto ? 'ถูกควบคุมโดยอัตโนมัติ' : 'กำลังทำงาน')
                          : 'ปิดอยู่',
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        color: pumpOn ? Colors.teal.shade700 : Colors.grey.shade700,
                        fontFamily: 'Prompt',
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: pumpOn,
                // **แก้ไข:** เปลี่ยน activeThumbColor เป็น activeColor
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
      color: auto ? Colors.lightGreen.shade50 : Colors.grey.shade100,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: toggleAuto,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    FontAwesomeIcons.robot,
                    color: auto ? Colors.green : Colors.grey,
                    size: 50,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'โหมดอัตโนมัติ',
                          style: TextStyle(
                            fontSize: widget.fontSize + 2,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Prompt',
                          ),
                        ),
                        Text(
                          auto ? 'ควบคุมปั๊มตามค่าความชื้น' : 'ควบคุมด้วยมือเท่านั้น',
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
                    value: auto,
                    // **แก้ไข:** เปลี่ยน activeThumbColor เป็น activeColor
                    activeColor: Colors.green,
                    onChanged: (_) => toggleAuto(),
                  ),
                ],
              ),
              if (auto) ...[
                const SizedBox(height: 10),
                Divider(color: Colors.green.shade200),
                const SizedBox(height: 5),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatSwitchCard() {
    return Card(
      color: floatSwitchOn ? Colors.lightBlue.shade50 : Colors.grey.shade100,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              FontAwesomeIcons.lifeRing,
              color: floatSwitchOn ? Colors.blue : Colors.grey,
              size: 50,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สถานะลูกลอย (Float Switch)',
                    style: TextStyle(
                      fontSize: widget.fontSize + 2,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Prompt',
                    ),
                  ),
                  Text(
                    floatSwitchOn ? 'ON (น้ำเต็ม/กำลังสูง)' : 'OFF (น้ำลด/กำลังต่ำ)',
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      color: Colors.grey.shade700,
                      fontFamily: 'Prompt',
                    ),
                  ),
                ],
              ),
            ),
            IgnorePointer(
              child: Switch(
                value: floatSwitchOn,
                // **แก้ไข:** เปลี่ยน activeThumbColor เป็น activeColor
                activeColor: Colors.blue, // ใช้สีฟ้าให้เข้ากับน้ำ
                onChanged: (_) {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterLevel() {
    final progress = (waterLevel / tankCapacity).clamp(0.0, 1.0);
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
                fontFamily: 'Prompt',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${waterLevel.toStringAsFixed(1)} ลิตร / ${tankCapacity.toStringAsFixed(0)} ลิตร',
              style: TextStyle(
                fontSize: widget.fontSize + 1,
                color: Colors.blueGrey,
                fontFamily: 'Prompt',
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
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