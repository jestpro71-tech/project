import 'package:flutter/material.dart';
import 'package:endproject/utils/color_extensions.dart'; // Import extension

class DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color? bgColor;
  final String? subtitle;
  final VoidCallback onTap;
  final double fontSize; // เพิ่ม fontSize เข้ามาเป็น property

  const DashboardCard({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    this.bgColor,
    this.subtitle,
    required this.onTap,
    this.fontSize = 16, // กำหนดค่าเริ่มต้น
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 6,
        color: bgColor ?? Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 56),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: fontSize + 2,
                  fontWeight: FontWeight.w700,
                  color: iconColor.darken(0.3),
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: fontSize - 2,
                    color: iconColor.darken(0.5),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}