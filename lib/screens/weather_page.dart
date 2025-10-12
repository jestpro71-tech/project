import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

// 🚨 API Key ที่คุณต้องการใช้งาน
const String kOpenWeatherApiKey = '7e0b123a7f044bb8111cac828f6aeb67';

// 💡 กำหนดค่าเริ่มต้นของพิกัดเพื่อให้แอปสามารถรันได้ทันที
const double kDefaultLatitude = 13.7563; // ละติจูดของกรุงเทพฯ
const double kDefaultLongitude = 100.5018; // ลองจิจูดของกรุงเทพฯ

// MARK: - Icon Mapping Helper
// 💡 ฟังก์ชันช่วยในการแปลงรหัสไอคอนจาก OpenWeatherMap เป็นไอคอน Font Awesome
IconData getWeatherIconData(String iconCode) {
  // รหัสไอคอนจาก OpenWeatherMap (เช่น '01d' = clear sky day, '01n' = clear sky night)
  switch (iconCode) {
    case '01d': // Clear sky (day)
      return FontAwesomeIcons.sun;
    case '01n': // Clear sky (night)
      return FontAwesomeIcons.moon;
    case '02d': // Few clouds (day)
      return FontAwesomeIcons.cloudSun;
    case '02n': // Few clouds (night)
      return FontAwesomeIcons.cloudMoon;
    case '03d': // Scattered clouds (day/night)
    case '03n':
      return FontAwesomeIcons.cloud;
    case '04d': // Broken clouds (day/night)
    case '04n':
      return FontAwesomeIcons.cloud;
    case '09d': // Shower rain (day/night)
    case '09n':
      return FontAwesomeIcons.cloudShowersHeavy;
    case '10d': // Rain (day)
      return FontAwesomeIcons.cloudSunRain;
    case '10n': // Rain (night)
      return FontAwesomeIcons.cloudMoonRain;
    case '11d': // Thunderstorm (day/night)
    case '11n':
      return FontAwesomeIcons.cloudBolt;
    case '13d': // Snow (day/night)
    case '13n':
      return FontAwesomeIcons.snowflake;
    case '50d': // Mist (day/night)
    case '50n':
      return FontAwesomeIcons.smog;
    default:
      return FontAwesomeIcons.temperatureHalf; // ไอคอนเริ่มต้นสำหรับกรณีที่ไม่พบ
  }
}

class WeatherPage extends StatefulWidget {
  final double latitude;
  final double longitude;
  final double fontSize;

  const WeatherPage({
    super.key,
    this.latitude = kDefaultLatitude,
    this.longitude = kDefaultLongitude,
    this.fontSize = 18.0,
  });

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  // สถานะสำหรับเก็บข้อมูลสภาพอากาศ
  String _weatherDescription = 'กำลังโหลด...';
  double _temperature = 0.0;
  String _cityName = 'ไม่ทราบเมือง';
  bool _isLoading = true;
  String? _error;
  String _iconCode = '01d'; 
  
  // 🛑 เพิ่มตัวแปรสำหรับเก็บข้อมูลเพิ่มเติม
  int _humidity = 0; // ความชื้นเป็นเปอร์เซ็นต์
  double _windSpeed = 0.0; // ความเร็วลมเป็นเมตรต่อวินาที

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  // MARK: - API Call Function
  Future<void> _fetchWeather() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=${widget.latitude}&lon=${widget.longitude}&appid=$kOpenWeatherApiKey&units=metric&lang=th';
      
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 🛑 ตรวจสอบโครงสร้างข้อมูลที่จำเป็นทั้งหมด
        if (data.containsKey('main') && data.containsKey('weather') && data.containsKey('wind')) {
          setState(() {
            _temperature = data['main']['temp'].toDouble(); 
            _weatherDescription = data['weather'][0]['description']; 
            _cityName = data['name'];
            _iconCode = data['weather'][0]['icon']; 
            
            // ✅ ดึงข้อมูลเพิ่มเติม
            _humidity = data['main']['humidity'];
            _windSpeed = data['wind']['speed'].toDouble(); 

            _isLoading = false;
          });
        } else {
          throw Exception("API response structure unexpected. Please check the API documentation.");
        }
      } else if (response.statusCode == 401) {
         throw Exception("API Key ไม่ถูกต้องหรือยังไม่เปิดใช้งาน (Status: 401). โปรดตรวจสอบ Key");
      }
      else {
        throw Exception('Failed to load weather data (Status: ${response.statusCode})');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Weather fetch error: $e');
      }
      setState(() {
        _error = 'ไม่สามารถดึงข้อมูลสภาพอากาศได้: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // MARK: - Modern UI Helper
  // 💡 สร้าง Card สำหรับแสดงรายละเอียดเพิ่มเติม (ความชื้น/ความเร็วลม)
  Widget _buildDetailCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      width: 150, // กำหนดความกว้างคงที่เพื่อความสมมาตร
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2), // พื้นหลังโปร่งใสเล็กน้อย
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          FaIcon(icon, color: Colors.white70, size: 28),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: widget.fontSize - 2,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: widget.fontSize + 2,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - UI Build
  @override
  Widget build(BuildContext context) {
    // ใช้งานฟังก์ชันภายนอกเพื่อแปลงรหัสไอคอน
    final icon = getWeatherIconData(_iconCode);
    
    // 🛑 กำหนดสี Gradient ตามเวลากลางวัน/กลางคืน
    Color topColor;
    Color bottomColor;
    if (_iconCode.endsWith('d')) { // กลางวัน (Day)
      topColor = Colors.lightBlue.shade300;
      bottomColor = Colors.lightBlue.shade700;
    } else { // กลางคืน (Night)
      topColor = Colors.indigo.shade700;
      bottomColor = Colors.blueGrey.shade900;
    }

    // ตรวจสอบว่าสามารถย้อนกลับได้หรือไม่ (มีหน้าก่อนหน้านี้ใน Stack หรือไม่)
    final canPop = Navigator.canPop(context);

    return MaterialApp(
      title: 'Flutter Weather',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: Scaffold(
        // ทำให้ Body สามารถขยายไปถึงด้านหลัง AppBar ได้
        extendBodyBehindAppBar: true, 
        appBar: AppBar(
          // ทำให้ AppBar โปร่งใสและไม่มีเงา
          backgroundColor: Colors.transparent,
          elevation: 0,
          // 🛑 เพิ่มปุ่มนำทาง (Leading) หากมีหน้าก่อนหน้าใน Stack
          leading: canPop
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () {
                    // ใช้ Navigator.pop() เพื่อย้อนกลับ
                    Navigator.pop(context);
                  },
                )
              : null, // ถ้าไม่มีหน้าก่อนหน้า ก็ไม่ต้องแสดงปุ่ม
          title: Text(
            'สภาพอากาศปัจจุบัน',
            style: TextStyle(
              fontSize: widget.fontSize + 4, 
              fontWeight: FontWeight.bold, 
              color: Colors.white,
              shadows: const [Shadow(blurRadius: 10, color: Colors.black38)],
            ),
          ),
          foregroundColor: Colors.white,
        ),
        // 🛑 ใช้ Container พร้อม Gradient เป็นพื้นหลัง
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [topColor, bottomColor],
            ),
          ),
          child: Center(
            child: _isLoading
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text('กำลังดึงข้อมูลสภาพอากาศ...', style: TextStyle(color: Colors.white70)),
                    ],
                  )
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                            const SizedBox(height: 16),
                            Text(
                              _error!, 
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.redAccent, fontSize: widget.fontSize),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _fetchWeather,
                              child: const Text('ลองใหม่'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Padding(
                          // เพิ่ม Padding ด้านบนเพื่อชดเชย AppBar โปร่งใส
                          padding: const EdgeInsets.only(top: 100, bottom: 40), 
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              // 1. Location (City Name)
                              Text(
                                '📍 ${_cityName}',
                                style: TextStyle(
                                  fontSize: widget.fontSize + 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  shadows: const [Shadow(blurRadius: 10, color: Colors.black38)],
                                ),
                              ),
                              // 2. Coordinates
                              Text(
                                '(${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)})',
                                style: TextStyle(
                                  fontSize: widget.fontSize,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 60),

                              // 3. Main Weather Icon & Temp
                              FaIcon(icon, color: Colors.white, size: 100), 
                              const SizedBox(height: 16),
                              Text(
                                '${_temperature.toStringAsFixed(1)} °C',
                                style: TextStyle(
                                  fontSize: widget.fontSize + 40,
                                  fontWeight: FontWeight.w200,
                                  color: Colors.white,
                                  shadows: const [Shadow(blurRadius: 15, color: Colors.black38)],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // 4. Description
                              Text(
                                _weatherDescription.toUpperCase(),
                                style: TextStyle(
                                  fontSize: widget.fontSize + 4,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 60),

                              // 5. Auxiliary Data Cards (Humidity & Wind)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildDetailCard(
                                      FontAwesomeIcons.droplet, 
                                      'ความชื้น', 
                                      '${_humidity}%'
                                    ),
                                    _buildDetailCard(
                                      FontAwesomeIcons.wind, 
                                      'ความเร็วลม', 
                                      '${_windSpeed.toStringAsFixed(1)} ม./วินาที'
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 60),
                              
                              // 6. Refresh Button (Modernized look)
                              ElevatedButton.icon(
                                onPressed: _fetchWeather,
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                label: const Text('อัปเดตข้อมูล', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.2), // พื้นหลังโปร่งใส
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side: const BorderSide(color: Colors.white54)
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}
