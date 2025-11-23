import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:endproject/firebase_options.dart'; // ตรวจสอบ path ให้ถูกต้อง
import 'package:endproject/screens/dashboard_screen.dart'; // Import DashboardScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Farm',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        // 💡 เพิ่มบรรทัดนี้เพื่อตั้งค่าฟอนต์ Prompt เป็นค่าเริ่มต้น
        fontFamily: 'Prompt',
      ),
      home: const DashboardScreen(), // เรียกใช้ DashboardScreen ที่แยกออกมา
      debugShowCheckedModeBanner: false,
    );
  }
}
