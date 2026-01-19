import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:math' as math;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // REPLACE with your actual Firebase Web Config
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "YOUR_API_KEY",
      authDomain: "your-project.firebaseapp.com",
      projectId: "your-project",
      storageBucket: "your-project.appspot.com",
      messagingSenderId: "123456789",
      appId: "1:12345:web:abcde",
    ),
  );
  
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: TreasureHuntMap(),
  ));
}

class TreasureHuntMap extends StatefulWidget {
  const TreasureHuntMap({super.key});
  @override
  State<TreasureHuntMap> createState() => _TreasureHuntMapState();
}

class _TreasureHuntMapState extends State<TreasureHuntMap> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final TextEditingController _distController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  LatLng _fromLocation = const LatLng(12.9716, 77.5946);
  LatLng? _targetLocation;
  double _currentBearing = 0.0;
  int _gold = 0;
  bool _showWinAnimation = false;
  
  late AnimationController _pulseController;
  late AnimationController _winController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _winController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    
    _latController.text = _fromLocation.latitude.toString();
    _lngController.text = _fromLocation.longitude.toString();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _winController.dispose();
    super.dispose();
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double dLon = (end.longitude - start.longitude) * (math.pi / 180);
    double lat1 = start.latitude * (math.pi / 180);
    double lat2 = end.latitude * (math.pi / 180);
    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return math.atan2(y, x);
  }

  LatLng _projectLocation(LatLng start, double distanceMeters) {
    const double earthRadius = 6378137; 
    double bearing = math.pi / 4; 
    double lat1 = start.latitude * (math.pi / 180);
    double lon1 = start.longitude * (math.pi / 180);
    double lat2 = math.asin(math.sin(lat1) * math.cos(distanceMeters / earthRadius) +
        math.cos(lat1) * math.sin(distanceMeters / earthRadius) * math.cos(bearing));
    double lon2 = lon1 + math.atan2(math.sin(bearing) * math.sin(distanceMeters / earthRadius) * math.cos(lat1),
        math.cos(distanceMeters / earthRadius) - math.sin(lat1) * math.sin(lat2));
    return LatLng(lat2 * (180 / math.pi), lon2 * (180 / math.pi));
  }

  void _triggerWin() {
    setState(() {
      _showWinAnimation = true;
      _gold += 500;
    });
    _winController.forward(from: 0).then((_) {
      Future.delayed(const Duration(seconds: 2), () {
        setState(() => _showWinAnimation = false);
      });
    });
  }

  void _calculatePath() {
    double? lat = double.tryParse(_latController.text);
    double? lng = double.tryParse(_lngController.text);
    double? dist = double.tryParse(_distController.text);

    if (lat != null && lng != null && dist != null) {
      setState(() {
        _fromLocation = LatLng(lat, lng);
        _targetLocation = _projectLocation(_fromLocation, dist);
        _currentBearing = _calculateBearing(_fromLocation, _targetLocation!);
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_fromLocation, 16));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. MAP LAYER
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(target: _fromLocation, zoom: 15),
            markers: {
              Marker(markerId: const MarkerId("h"), position: _fromLocation, icon: BitmapDescriptor.defaultMarkerWithHue(210.0)),
              if (_targetLocation != null) Marker(markerId: const MarkerId("t"), position: _targetLocation!, icon: BitmapDescriptor.defaultMarkerWithHue(30.0)),
            },
            polylines: _targetLocation == null ? {} : {
              Polyline(
                polylineId: const PolylineId("path"),
                points: [_fromLocation, _targetLocation!],
                color: Colors.amber,
                width: 4,
                patterns: [PatternItem.dash(20), PatternItem.gap(10)],
              )
            },
            circles: _targetLocation == null ? {} : {
              Circle(
                circleId: const CircleId("p"),
                center: _targetLocation!,
                radius: 10 + (40 * _pulseController.value),
                fillColor: Colors.amber.withOpacity(0.3),
                strokeWidth: 0,
              )
            },
          ),

          // 2. HUD: COMPASS (Top Right)
          Positioned(
            top: 50,
            right: 20,
            child: AnimatedRotation(
              turns: _currentBearing / (2 * math.pi),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.elasticOut,
              child: const Icon(Icons.navigation, color: Colors.deepOrange, size: 80),
            ),
          ),

          // 3. HUD: GOLD COUNTER (Top Left)
          Positioned(
            top: 50,
            left: 20,
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 1, end: _showWinAnimation ? 1.4 : 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber)),
                  child: Text("💰 $_gold GOLD", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),

          // 4. WIN OVERLAY (Pop-up Animation)
          if (_showWinAnimation)
            Center(
              child: ScaleTransition(
                scale: CurvedAnimation(parent: _winController, curve: Curves.bounceOut),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.card_giftcard, size: 150, color: Colors.amber),
                    Text("TREASURE FOUND!", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 10, color: Colors.black)])),
                  ],
                ),
              ),
            ),

          // 5. CONTROL PANEL
          Positioned(
            bottom: 20,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.brown.shade900.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: _distController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Meters to Treasure", labelStyle: TextStyle(color: Colors.amber))),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () { _calculatePath(); _triggerWin(); },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, minimumSize: const Size(double.infinity, 50)),
                    child: const Text("FIND TREASURE!", style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}