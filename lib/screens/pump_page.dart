import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import Font Awesome

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
  late List<Map<String, String>> waterHistory;

  StreamSubscription<double>? _waterLevelSubscription;

  @override
  void initState() {
    super.initState();
    pumpOn = widget.initialPumpOn;
    auto = widget.initialAuto;
    waterLevel = widget.initialWaterLevel;
    waterHistory = List<Map<String, String>>.from(widget.initialWaterHistory);

    // subscribe stream ถ้ามี
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

  void togglePump(bool value) {
    setState(() {
      pumpOn = value;
      if (pumpOn && auto) {
        auto = false;
      }
      if (pumpOn) {
        _addWaterHistory('Manual');
      }
    });
    // ควรเรียก API ตรงนี้ หรือเรียกผ่าน service ที่แยกไป
  }

  void toggleAuto() {
    setState(() {
      auto = !auto;
      if (auto && pumpOn) {
        pumpOn = false;
      }
      if (auto) {
        _addWaterHistory('Auto');
      }
    });
    // ควรเรียก API ตรงนี้ หรือเรียกผ่าน service ที่แยกไป
  }

  void _addWaterHistory(String mode) {
    final now = DateTime.now();
    final item = {
      'time': '${now.hour}:${now.minute.toString().padLeft(2, '0')} น.',
      'amount': '${(5 + (waterLevel % 10)).toStringAsFixed(1)} ลิตร ($mode)',
    };

    setState(() {
      waterHistory.insert(0, item);
      if (waterHistory.length > 10) {
        waterHistory.removeLast();
      }
    });

    widget.onUpdateWaterHistory(waterHistory); // ส่งประวัติที่อัปเดตกลับไป Dashboard
  }

  void _clearWaterHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ล้างประวัติ'),
        content: const Text('ต้องการล้างประวัติการเติมน้ำทั้งหมดหรือไม่?'),
        actions: [
          TextButton(
            child: const Text('ยกเลิก'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('ล้าง', style: TextStyle(color: Colors.red)),
            onPressed: () {
              setState(() {
                waterHistory.clear();
                widget.onUpdateWaterHistory(waterHistory);
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
        onTap: () {
          togglePump(!pumpOn);
        },
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
                onChanged: (_) => toggleAuto(),
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
