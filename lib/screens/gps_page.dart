import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GPSPage extends StatelessWidget {
  final LatLng position;
  const GPSPage({super.key, required this.position});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GPS ตำแหน่งฟาร์ม')),
      body: FlutterMap(
        options: MapOptions(
          center: position,
          zoom: 15,
          maxZoom: 18,
          minZoom: 5,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: position,
                width: 80,
                height: 80,
                builder: (context) =>
                    const Icon(Icons.location_pin, color: Colors.red, size: 48),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
