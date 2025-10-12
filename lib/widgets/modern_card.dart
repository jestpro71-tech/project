import 'package:flutter/material.dart';

class ModernCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final double titleFontSize;
  final double subtitleFontSize;
  final Color iconColor; // *เพิ่มพารามิเตอร์ iconColor ที่หายไป*

  const ModernCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
    this.titleFontSize = 18,
    this.subtitleFontSize = 13,
    this.iconColor = Colors.black87, // *กำหนดค่า default*
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
                  color: iconColor, // *ใช้พารามิเตอร์ iconColor ที่รับเข้ามา*
                ),
              ),

              const SizedBox(height: 16),

              // หัวข้อใหญ่ (Title) - ใช้ Expanded เพื่อให้ Text ยืดหยุ่น
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
