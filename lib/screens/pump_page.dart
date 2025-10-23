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
  bool pumpOn = false;
  bool auto = false;
  double waterLevel = 0.0;

  double tankCapacity = 100.0;
  bool floatSwitchOn = false;

  List<Map<String, dynamic>> waterHistory = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final FirebaseDatabase _database;

  static const String rtdbUrl =
      'https://project-41b3d-default-rtdb.asia-southeast1.firebasedatabase.app';

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

    _listenToPumpStatus();
    _listenToWaterHistory();
    _listenToWaterLevel();
    _listenToTankCapacity();
    _listenToFloatSwitch(); // ฟังลูกลอย
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

  // ---------- Helpers ----------
  bool _parseBool(dynamic v) {
    // รองรับ bool / 1/0 / "true"/"false" / "1"/"0" (รวมถึงเว้นวรรค)
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

  // ---------- Firebase Listeners ----------

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
                  pumpOn = data['status'] == 'on';
                  auto = data['autoMode'] ?? false;
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดประวัติ: $error')),
            );
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
            debugPrint("Warning: Could not parse water level: $data");
            _safeSetState(() => waterLevel = 0.0);
          }
        } else {
          _safeSetState(() => waterLevel = 0.0);
        }
      },
      onError: (error) {
        debugPrint("Error listening to water level: $error");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อระดับน้ำ: $error'),
          ),
        );
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

  // <<< จุดสำคัญ: ฟัง floatSwitchState และพาร์สให้ชัดเจน >>>
  void _listenToFloatSwitch() {
    final ref = _database.ref('devices/pump/floatSwitchState');
    _floatSwitchSubscription = ref.onValue.listen(
      (event) {
        final raw = event.snapshot.value;
        debugPrint('floatSwitchState raw: $raw (${raw.runtimeType})');
        final next = _parseBool(raw);
        _safeSetState(() => floatSwitchOn = next);
      },
      onError: (e) {
        debugPrint('FloatSwitch listener error: $e');
      },
    );
  }

  // ---------- Actions ----------

  Future<void> togglePump(bool value) async {
    _safeSetState(() {
      pumpOn = value;
      if (pumpOn && auto) auto = false;
    });

    try {
      await _firestore.collection('devices').doc('pump').set({
        'status': value ? 'on' : 'off',
        'autoMode': auto,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (value) await _addWaterHistory('Manual');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ปั๊มน้ำถูก ${value ? "เปิด" : "ปิด"} แล้ว')),
      );
    } catch (e) {
      debugPrint("Error updating pump status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถอัปเดตสถานะปั๊มน้ำได้: $e')),
      );
      _safeSetState(() => pumpOn = !value);
    }
  }

  Future<void> toggleAuto() async {
    _safeSetState(() {
      auto = !auto;
      if (auto && pumpOn) pumpOn = false;
    });

    try {
      await _firestore.collection('devices').doc('pump').set({
        'autoMode': auto,
        'status': pumpOn ? 'on' : 'off',
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (auto) await _addWaterHistory('Auto');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('โหมดอัตโนมัติถูก ${auto ? "เปิด" : "ปิด"} แล้ว'),
        ),
      );
    } catch (e) {
      debugPrint("Error updating auto mode: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถอัปเดตโหมดอัตโนมัติได้: $e')),
      );
      _safeSetState(() => auto = !auto);
    }
  }

  Future<void> _addWaterHistory(String mode) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถบันทึกประวัติการเติมน้ำได้: $e')),
      );
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

  // ---------- UI ----------

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
                      pumpOn ? 'กำลังทำงาน' : 'ปิดอยู่',
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
                value: pumpOn,
                // แก้ไข: เปลี่ยน activeThumbColor เป็น activeColor
                activeThumbColor: Colors.green,
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
                FontAwesomeIcons.robot,
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
                    fontFamily: 'Prompt',
                  ),
                ),
              ),
              Switch(
                value: auto,
                // แก้ไข: เปลี่ยน activeThumbColor เป็น activeColor
                activeThumbColor: Colors.green,
                onChanged: (_) => toggleAuto(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatSwitchCard() {
    return Card(
      color: floatSwitchOn ? Colors.green.shade50 : Colors.grey.shade100,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              FontAwesomeIcons.lifeRing,
              color: floatSwitchOn ? Colors.teal : Colors.grey,
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
                    floatSwitchOn ? 'ON' : 'OFF',
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
                // แก้ไข: เปลี่ยน activeThumbColor เป็น activeColor
                activeThumbColor: Colors.green,
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
