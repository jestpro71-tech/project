import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;

const String kOpenWeatherApiKey = '7e0b123a7f044bb8111cac828f6aeb67';

class WeatherPage extends StatefulWidget {
  final double latitude;
  final double longitude;
  final double fontSize;

  const WeatherPage({
    super.key,
    required this.latitude,
    required this.longitude,
    this.fontSize = 18.0,
  });

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  bool _isLoading = true;
  String? _error;
  String _city = '';
  String _description = '';
  double _temp = 0;
  int _humidity = 0;
  double _wind = 0;
  String _icon = '01d';
  List<dynamic> _forecast = [];

  @override
  void initState() {
    super.initState();
    _fetchWeatherData();
  }

  Future<void> _fetchWeatherData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentUrl =
          'https://api.openweathermap.org/data/2.5/weather?lat=${widget.latitude}&lon=${widget.longitude}&appid=$kOpenWeatherApiKey&units=metric&lang=th';
      final forecastUrl =
          'https://api.openweathermap.org/data/2.5/forecast?lat=${widget.latitude}&lon=${widget.longitude}&appid=$kOpenWeatherApiKey&units=metric&lang=th';

      final responses = await Future.wait([
        http.get(Uri.parse(currentUrl)),
        http.get(Uri.parse(forecastUrl)),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final currentData = json.decode(responses[0].body);
        final forecastData = json.decode(responses[1].body);

        setState(() {
          _city = currentData['name'];
          _temp = currentData['main']['temp'].toDouble();
          _humidity = currentData['main']['humidity'];
          _wind = currentData['wind']['speed'].toDouble();
          _description = currentData['weather'][0]['description'];
          _icon = currentData['weather'][0]['icon'];
          _forecast = forecastData['list'];
          _isLoading = false;
        });
      } else {
        throw Exception('โหลดข้อมูลไม่สำเร็จ');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  IconData _mapIcon(String code) {
    switch (code) {
      case '01d':
        return FontAwesomeIcons.sun;
      case '01n':
        return FontAwesomeIcons.moon;
      case '02d':
        return FontAwesomeIcons.cloudSun;
      case '02n':
        return FontAwesomeIcons.cloudMoon;
      case '09d':
      case '09n':
        return FontAwesomeIcons.cloudShowersHeavy;
      case '10d':
        return FontAwesomeIcons.cloudSunRain;
      case '10n':
        return FontAwesomeIcons.cloudMoonRain;
      case '11d':
      case '11n':
        return FontAwesomeIcons.cloudBolt;
      case '13d':
      case '13n':
        return FontAwesomeIcons.snowflake;
      default:
        return FontAwesomeIcons.cloud;
    }
  }

  List<Color> _gradientColors(String code) {
    if (code.contains('d')) {
      return [const Color(0xFF90CAF9), const Color(0xFF2196F3), const Color(0xFF1565C0)];
    } else {
      return [const Color(0xFF001F3F), const Color(0xFF0D47A1)];
    }
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _gradientColors(_icon);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _city.isNotEmpty ? 'สภาพอากาศ\n$_city' : 'สภาพอากาศ',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(child: Text('เกิดข้อผิดพลาด: $_error'))
              : Stack(
                  children: [
                    // 🌈 Gradient Sky
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: gradient,
                        ),
                      ),
                    ),

                    // 🌥 Main Content
                    SingleChildScrollView(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 100),
                      child: Column(
                        children: [
                          // 🌤 Glass Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                FaIcon(_mapIcon(_icon),
                                    color: Colors.white, size: 90),
                                const SizedBox(height: 10),
                                Text(
                                  '${_temp.toStringAsFixed(1)}°C',
                                  style: TextStyle(
                                    fontSize: widget.fontSize + 28,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _description,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 18),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildInfoChip(FontAwesomeIcons.droplet,
                                        'ความชื้น: $_humidity%'),
                                    const SizedBox(width: 10),
                                    _buildInfoChip(FontAwesomeIcons.wind,
                                        'ลม: ${_wind.toStringAsFixed(1)} ม./วินาที'),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // 🔮 Forecast section
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '🌈 พยากรณ์อากาศล่วงหน้า',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: widget.fontSize + 2,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildForecastList(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildForecastList() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _forecast.length >= 6 ? 6 : _forecast.length,
        itemBuilder: (context, index) {
          final item = _forecast[index];
          final date =
              DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
          final temp = item['main']['temp'].toDouble();
          final icon = item['weather'][0]['icon'];
          final desc = item['weather'][0]['description'];

          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.25), Colors.white10],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(_mapIcon(icon),
                          color: Colors.white, size: 26),
                      const SizedBox(height: 8),
                      Text('${temp.toStringAsFixed(0)}°C',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                      const SizedBox(height: 6),
                      Text(
                        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:00',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(desc,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
