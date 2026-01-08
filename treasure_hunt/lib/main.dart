import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase correctly for Web
  // REPLACE THESE PLACEHOLDERS with values from your Firebase Console
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "YOUR_FIREBASE_WEB_API_KEY",
      authDomain: "your-project-id.firebaseapp.com",
      projectId: "your-project-id",
      storageBucket: "your-project-id.appspot.com",
      messagingSenderId: "your-sender-id",
      appId: "your-app-id",
    ),
  );
  
  runApp(const MaterialApp(home: TreasureHuntMap()));
}

class TreasureHuntMap extends StatefulWidget {
  const TreasureHuntMap({super.key});
  @override
  State<TreasureHuntMap> createState() => _TreasureHuntMapState();
}

class _TreasureHuntMapState extends State<TreasureHuntMap> {
  List<DocumentSnapshot> _stopDocs = [];

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  void _startTracking() {
    Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high)
    ).listen((Position position) {
      _checkArrival(position.latitude, position.longitude);
    });
  }

  void _checkArrival(double userLat, double userLng) {
    for (var doc in _stopDocs) {
      try {
        if (doc.get('isFound') == true) continue; 

        double dist = Geolocator.distanceBetween(
          userLat, userLng, doc['latitude'], doc['longitude']
        );

        if (dist < 50) { 
          _unlockStop(doc.id, doc['title']);
        }
      } catch (e) {
        // This catches cases where 'isFound' might be missing in a document
        continue;
      }
    }
  }

  void _unlockStop(String id, String name) {
    FirebaseFirestore.instance.collection('stops').doc(id).update({'isFound': true});
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✨ Goal Reached: $name!"), 
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Treasure Run MVP")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('stops').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          _stopDocs = snapshot.data!.docs;

          final markers = _stopDocs.map((doc) {
            return Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(doc['latitude'], doc['longitude']),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                doc['isFound'] == true ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed
              ),
              infoWindow: InfoWindow(title: doc['title']),
            );
          }).toSet();

          return GoogleMap(
            initialCameraPosition: const CameraPosition(target: LatLng(12.9716, 77.5946), zoom: 14),
            markers: markers,
            myLocationEnabled: true,
          );
        },
      ),
    );
  }
}