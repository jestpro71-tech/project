import 'package:flutter/material.dart';

class ModernCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final double titleFontSize;    // เพิ่ม property สำหรับขนาด font ของ title
  final double subtitleFontSize; // เพิ่ม property สำหรับขนาด font ของ subtitle

  const ModernCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
    this.titleFontSize = 18,    // กำหนดค่า default ถ้าไม่ถูกส่งมา
    this.subtitleFontSize = 13, // กำหนดค่า default ถ้าไม่ถูกส่งมา
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // วงกลม Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: Colors.black87, // ใช้สีไอคอนตามธีมได้
                ),
              ),

              const SizedBox(height: 16),

              // หัวข้อใหญ่ (Title) - ใช้ Expanded เพื่อให้ Text ยืดหยุ่น
              // เพิ่ม Expanded, maxLines, และ overflow เพื่อป้องกันข้อความล้น
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Prompt',
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w700,
                    color: const Color.fromARGB(255, 31, 0, 0),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2, // กำหนดจำนวนบรรทัดสูงสุด
                  overflow: TextOverflow.ellipsis, // แสดง ... ถ้าข้อความยาวเกิน
                ),
              ),

              const SizedBox(height: 8),

              // หัวข้อย่อย (Subtitle) - ใช้ Expanded เพื่อให้ Text ยืดหยุ่น
              if (subtitle != null) ...[
                // เพิ่ม Expanded, maxLines, และ overflow เพื่อป้องกันข้อความล้น
                Expanded(
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: 'Prompt',
                      fontSize: subtitleFontSize,
                      fontWeight: FontWeight.w600,
                      color: const Color.fromARGB(
                        255,
                        88,
                        87,
                        87,
                      ),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2, // กำหนดจำนวนบรรทัดสูงสุด
                    overflow: TextOverflow.ellipsis, // แสดง ... ถ้าข้อความยาวเกิน
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
