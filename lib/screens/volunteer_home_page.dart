import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/scan_page.dart';
class VolunteerHomePage extends StatefulWidget {
  const VolunteerHomePage({super.key});

  @override
  State<VolunteerHomePage> createState() => _VolunteerHomePageState();
}

class _VolunteerHomePageState extends State<VolunteerHomePage> {
  final String volunteerZone = "RAMKUND_G1";

  int registeredCount = 0;
  int enteredCount = 0;
  int sosCount = 0;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadZoneStats();
    _loadSOSCount();
  }

  // ───────── LOAD ZONE STATS ─────────
  Future<void> _loadZoneStats() async {
    try {
      final zoneDoc = await FirebaseFirestore.instance
          .collection("zones")
          .doc(volunteerZone)
          .get();

      if (zoneDoc.exists) {
        final counters = zoneDoc.data()?['counters'] ?? {};

        setState(() {
          registeredCount = counters['registered'] ?? 0;
          enteredCount = counters['entered'] ?? 0;
          loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading zone stats: $e");
      setState(() => loading = false);
    }
  }

  // ───────── LOAD SOS COUNT ─────────
  Future<void> _loadSOSCount() async {
    final snap = await FirebaseFirestore.instance
        .collection("sos_requests")
        .where("zone", isEqualTo: volunteerZone)
        .where("status", isEqualTo: "ACTIVE")
        .get();

    setState(() {
      sosCount = snap.docs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      appBar: AppBar(
        title: const Text("Volunteer Dashboard"),
        backgroundColor: const Color(0xFFD9822B),
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _zoneCard(),
            const SizedBox(height: 20),
            _statsRow(),
            const SizedBox(height: 30),
            _scanButton(),
            const SizedBox(height: 20),
            _sosCard(),
          ],
        ),
      ),
    );
  }

  // ───────── ZONE CARD ─────────
  Widget _zoneCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text(
            "Assigned Zone",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            volunteerZone,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // ───────── STATS ─────────
  Widget _statsRow() {
    return Row(
      children: [
        _statBox(
          title: "Registered",
          value: registeredCount.toString(),
          color: Colors.blue,
        ),
        const SizedBox(width: 12),
        _statBox(
          title: "Entered",
          value: enteredCount.toString(),
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _statBox({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────── SCAN BUTTON ─────────
  Widget _scanButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.qr_code_scanner, size: 28),
        label: const Text(
          "Scan Pilgrim QR",
          style: TextStyle(fontSize: 18),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: () {
          Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScanPage()),
          );

        },
      ),
    );
  }

  // ───────── SOS CARD ─────────
  Widget _sosCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: sosCount > 0 ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: sosCount > 0
            ? Border.all(color: Colors.red, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sosCount > 0
                  ? "SOS Requests: $sosCount Active"
                  : "No Active SOS Requests",
              style: const TextStyle(fontSize: 16),
            ),
          ),
          if (sosCount > 0)
            TextButton(
              onPressed: () {
                // TODO: Open SOS List Page
              },
              child: const Text("View"),
            )
        ],
      ),
    );
  }
}
