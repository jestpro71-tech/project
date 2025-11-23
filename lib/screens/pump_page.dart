import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

// 🔑 OpenWeather API Key
const String kOpenWeatherApiKey = '7e0b123a7f044bb8111cac828f6aeb67';

class PumpPage extends StatefulWidget {
  final double fontSize;

  // ถ้ามี GPS จริงจากหน้าอื่น ส่งเข้ามาได้
  final double? latitude;
  final double? longitude;

  const PumpPage({
    super.key,
    this.fontSize = 16.0,
    this.latitude,
    this.longitude,
  });

  @override
  State<PumpPage> createState() => _PumpPageState();
}

class _PumpPageState extends State<PumpPage> {
  // ================= BASIC STATE =================

  bool pumpOn = false;          // สถานะปั๊ม
  bool auto = false;            // โหมดอัตโนมัติ
  double waterLevel = 0.0;      // ระดับน้ำในถัง
  double tankCapacity = 100.0;  // ความจุถัง
  bool floatSwitchOn = false;   // ลูกลอย

  List<Map<String, dynamic>> waterHistory = [];

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final FirebaseDatabase _database;

  static const String rtdbUrl =
      'https://project-41b3d-default-rtdb.asia-southeast1.firebasedatabase.app';

  // Streams
  StreamSubscription<DatabaseEvent>? _waterLevelSubscription;
  StreamSubscription<DatabaseEvent>? _tankCapacitySubscription;
  StreamSubscription<DatabaseEvent>? _floatSwitchSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _pumpStatusSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _waterHistorySubscription;

  // =============== WEATHER FORECAST ===============

  List<dynamic> _forecast = [];
  bool _isEvaluatingAuto = false;

  // ถ้าไม่ได้ส่ง GPS จะใช้ค่าดีฟอลต์ = เชียงใหม่
  double get _lat => widget.latitude ?? 18.7904;
  double get _lon => widget.longitude ?? 98.9853;

  @override
  void initState() {
    super.initState();

    _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: rtdbUrl,
    );

    // เริ่มฟังค่าจาก Firebase
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

  // =================== HELPERS ====================

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

  // ================== LISTENERS ===================

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

        // ทุกครั้งที่ระดับน้ำเปลี่ยน ให้ลองประเมิน Auto
        _evaluateAutoPump();
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

        // ถ้าลูกลอยเปลี่ยนสถานะ ให้ประเมิน Auto ใหม่
        _evaluateAutoPump();
      },
      onError: (e) {
        debugPrint('FloatSwitch listener error: $e');
      },
    );
  }

  // ========== WEATHER FORECAST & AUTO LOGIC ==========

  Future<List<dynamic>> _fetchForecast() async {
    final url =
        'https://api.openweathermap.org/data/2.5/forecast?lat=$_lat&lon=$_lon&appid=$kOpenWeatherApiKey&units=metric&lang=th';

    try {
      final response = await http.get(Uri.parse(url));
      debugPrint('🌦 Forecast status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['list'] as List<dynamic>;
        _forecast = list;
        return list;
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching forecast: $e');
      return [];
    }
  }

  /// ตรวจว่ามีฝนไหมใน 12 ชั่วโมงข้างหน้า (ดึง 4 ช่วง x 3 ชั่วโมง)
  bool _willRainSoon(List<dynamic> forecast) {
    final int count = forecast.length < 4 ? forecast.length : 4;
    for (int i = 0; i < count; i++) {
      final f = forecast[i];
      final String main =
          f['weather'][0]['main'].toString().toLowerCase(); // Rain / Clouds
      if (main.contains('rain')) return true;
    }
    return false;
  }

  /// ใช้ใน Auto Mode: ตัดสินใจเปิด/ปิดปั๊มจาก
  /// - สถานะลูกลอย
  /// - พยากรณ์ฝน
  Future<void> _evaluateAutoPump() async {
    if (!auto) return; // ไม่อยู่ในโหมด Auto ก็ไม่ต้องทำอะไร
    if (_isEvaluatingAuto) return; // กันการเรียกซ้อน

    _isEvaluatingAuto = true;

    try {
      // 1) โหลดพยากรณ์อากาศ
      final forecast = await _fetchForecast();
      if (forecast.isEmpty) {
        debugPrint('Forecast empty, skip auto pump decision.');
        _isEvaluatingAuto = false;
        return;
      }

      final rainComing = _willRainSoon(forecast);
      debugPrint('🌧 Rain coming soon? $rainComing');
      debugPrint('💧 WaterLevel: $waterLevel / $tankCapacity');
      debugPrint('🔵 FloatSwitch: $floatSwitchOn');

      // 2) Logic ตัดสินใจ
      if (floatSwitchOn) {
        // น้ำเต็ม → ปิดปั๊ม
        await _setPumpStatus(false, 'Auto: Float full');
      } else if (rainComing) {
        // ฝนกำลังจะตก → ปิดปั๊ม เก็บน้ำฝน
        await _setPumpStatus(false, 'Auto: Rain forecast');
      } else {
        // ไม่มีฝน และน้ำยังไม่เต็ม → เปิดปั๊ม
        await _setPumpStatus(true, 'Auto: Weather OK');
      }
    } catch (e) {
      debugPrint('Error in _evaluateAutoPump: $e');
    } finally {
      _isEvaluatingAuto = false;
    }
  }

  /// helper สำหรับสั่งสถานะปั๊มจาก Auto Logic
  Future<void> _setPumpStatus(bool on, String mode) async {
    // ลดการเขียนซ้ำ ถ้าสถานะเดิมเหมือนเดิมแล้ว
    if (pumpOn == on && auto) return;

    try {
      await _firestore.collection('devices').doc('pump').set({
        'status': on ? 'on' : 'off',
        'autoMode': true,
        'autoReason': mode,
        'lastAutoUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _safeSetState(() {
        pumpOn = on;
      });

      if (on) {
        await _addWaterHistory(mode);
      }
    } catch (e) {
      debugPrint('Error setting pump status (auto): $e');
    }
  }

  // =================== ACTIONS ====================

  Future<void> togglePump(bool value) async {
    // ถ้าอยู่ในโหมด Auto → ไม่ให้ควบคุมด้วยมือ
    if (auto) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ ปิด/เปิดปั๊มด้วยมือไม่ได้!\nปั๊มถูกควบคุมโดยโหมดอัตโนมัติ',
            style: TextStyle(fontSize: widget.fontSize, fontFamily: 'Prompt'),
          ),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      _safeSetState(() => pumpOn = !value);
      return;
    }

    _safeSetState(() {
      pumpOn = value;
    });

    try {
      await _firestore.collection('devices').doc('pump').set({
        'status': value ? 'on' : 'off',
        'autoMode': auto,
        'lastManualUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (value) await _addWaterHistory('Manual');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ปั๊มน้ำถูก ${value ? "เปิด" : "ปิด"} แล้ว',
            style: const TextStyle(fontFamily: 'Prompt'),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error updating pump status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ไม่สามารถอัปเดตสถานะปั๊มน้ำได้: $e',
            style: const TextStyle(fontFamily: 'Prompt'),
          ),
        ),
      );
      _safeSetState(() => pumpOn = !value);
    }
  }

  Future<void> toggleAuto() async {
    final bool nextAuto = !auto;

    try {
      // ถ้าเปิด Auto และปั๊มยังเปิดอยู่ → ปิดก่อน
      if (nextAuto && pumpOn) {
        await _firestore.collection('devices').doc('pump').set({
          'status': 'off',
          'autoMode': nextAuto,
          'lastManualUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await _firestore.collection('devices').doc('pump').set({
        'autoMode': nextAuto,
        'lastAutoModeToggle': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _safeSetState(() {
        auto = nextAuto;
      });

      if (nextAuto) {
        await _addWaterHistory('Auto On');
        // เมื่อเปิด Auto ให้ประเมินจากอากาศทันที
        _evaluateAutoPump();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'โหมดอัตโนมัติถูก ${nextAuto ? "เปิด" : "ปิด"} แล้ว',
            style: const TextStyle(fontFamily: 'Prompt'),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error updating auto mode: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ไม่สามารถอัปเดตโหมดอัตโนมัติได้: $e',
            style: const TextStyle(fontFamily: 'Prompt'),
          ),
        ),
      );
    }
  }

  // ============== HISTORY / UTILS ==============

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

  // ====================== UI ======================

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
                        color: pumpOn
                            ? Colors.teal.shade700
                            : Colors.grey.shade700,
                        fontFamily: 'Prompt',
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
                          auto
                              ? 'ควบคุมปั๊มตามสภาพอากาศ + เซนเซอร์'
                              : 'ควบคุมด้วยมือเท่านั้น',
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
                    activeColor: Colors.green,
                    onChanged: (_) => toggleAuto(),
                  ),
                ],
              ),
              if (auto) ...[
                const SizedBox(height: 10),
                Divider(color: Colors.green.shade200),
                const SizedBox(height: 5),
                Text(
                  '',
                  style: TextStyle(
                    fontSize: widget.fontSize - 2,
                    color: Colors.green.shade700,
                    fontFamily: 'Prompt',
                  ),
                ),
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
                    floatSwitchOn
                        ? 'ON (น้ำเต็ม/กำลังสูง)'
                        : 'OFF (น้ำลด/กำลังต่ำ)',
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
                activeColor: Colors.blue,
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
