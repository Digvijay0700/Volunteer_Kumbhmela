import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../volunteer_gatt_service.dart';
import 'scan_page.dart';

class VolunteerHomePage extends StatefulWidget {
  const VolunteerHomePage({super.key});

  @override
  State<VolunteerHomePage> createState() => _VolunteerHomePageState();
}

class _VolunteerHomePageState extends State<VolunteerHomePage> {
  double? emergencyLat;
  double? emergencyLng;
  bool isScanning = false;

  final String volunteerZone = "RAMKUND_G1";
  int registeredCount = 0;
  int enteredCount = 0;
  int sosCount = 0;

  @override
  void initState() {
    super.initState();
    _loadZoneStats();
    _loadSOSCount();
  }

  Future<void> _loadZoneStats() async {
    final zoneDoc = await FirebaseFirestore.instance.collection("zones").doc(volunteerZone).get();
    if (zoneDoc.exists) {
      setState(() {
        registeredCount = zoneDoc.data()?['registered'] ?? 0;
        enteredCount = zoneDoc.data()?['entered'] ?? 0;
      });
    }
  }

  Future<void> _loadSOSCount() async {
    final sosSnap = await FirebaseFirestore.instance.collection("sos_alerts").where("status", isEqualTo: "active").get();
    setState(() => sosCount = sosSnap.docs.length);
  }

  // 🔥 NEW: Function triggered by the button
  Future<void> _handleStartScan() async {
    setState(() => isScanning = true);
    try {
      await VolunteerGattService.startListening((lat, lng) {
        setState(() {
          emergencyLat = lat;
          emergencyLng = lng;
          isScanning = false; 
        });
      });
    } catch (e) {
      setState(() => isScanning = false);
      debugPrint("GATT Error: $e");
      // The system popup will appear automatically if it's a permission issue
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Volunteer Dashboard", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFD9822B),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _sosCard(),
            const SizedBox(height: 20),
            _scanButton(),
          ],
        ),
      ),
    );
  }

  Widget _sosCard() {
    bool hasEmergency = emergencyLat != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hasEmergency ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hasEmergency ? Colors.red : Colors.grey.shade300, width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(hasEmergency ? Icons.warning_amber_rounded : Icons.radar, 
                   color: hasEmergency ? Colors.red : Colors.blue),
              const SizedBox(width: 10),
              Text(
                hasEmergency ? "SOS SIGNAL DETECTED" : "Nearby SOS Scanner",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: hasEmergency ? Colors.red : Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (hasEmergency) ...[
            Text("Pilgrim Location: $emergencyLat, $emergencyLng", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => setState(() { emergencyLat = null; emergencyLng = null; }),
              child: const Text("Clear Alert"),
            )
          ] else ...[
            const Text("Click below to start searching for offline SOS signals."),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: isScanning ? null : _handleStartScan,
              icon: isScanning 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search),
              label: Text(isScanning ? "Scanning Nearby..." : "Start Scanning"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade100,
                foregroundColor: Colors.orange.shade900,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scanButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanPage())),
        child: const Text("Scan Pilgrim QR Pass", style: TextStyle(fontSize: 18, color: Colors.white)),
      ),
    );
  }
}