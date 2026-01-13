import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';

const String QR_SECRET = "KUMBHATHON_2027_SECRET";

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final String volunteerZone = "RAMKUND_G1";
  bool scanned = false;

  String status = "";
  Color statusColor = Colors.grey;
  String message = "";

  // ───────── SIGNATURE ─────────
  String _sign(String qrId) {
    final hmac = Hmac(sha256, utf8.encode(QR_SECRET));
    return hmac.convert(utf8.encode(qrId)).toString().substring(0, 10);
  }

  // ───────── MAIN HANDLER ─────────
  Future<void> _handleScan(String raw) async {
    if (scanned) return;
    scanned = true;

    try {
      final decoded =
      jsonDecode(utf8.decode(base64Decode(raw))) as Map<String, dynamic>;

      final qrId = decoded["qr_id"];
      final date = decoded["date"];
      final slot = decoded["slot"];
      final zone = decoded["zone"];
      final sig = decoded["sig"];

      // 🔐 1. SIGNATURE CHECK
      if (_sign(qrId) != sig) {
        _fail("INVALID QR (Signature mismatch)");
        return;
      }

      // 📅 2. DATE CHECK
      final today = DateFormat("yyyy-MM-dd").format(DateTime.now());
      if (date != today) {
        _fail("QR EXPIRED / INVALID DATE");
        return;
      }

      // 🌐 CHECK CONNECTIVITY
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity != ConnectivityResult.none;

      if (!isOnline) {
        _offlineValidate(zone, slot);
        return;
      }

      // 🔵 ONLINE VALIDATION
      await _onlineValidate(qrId, zone);
    } catch (e) {
      _fail("INVALID QR FORMAT");
    }
  }

  // ───────── OFFLINE MODE ─────────
  void _offlineValidate(String zone, String slot) {
    if (zone != volunteerZone) {
      _redirect(zone);
      return;
    }

    _success("VERIFIED (OFFLINE)", "Allow entry");
  }

  // ───────── ONLINE MODE ─────────
  Future<void> _onlineValidate(String qrId, String zone) async {
    final doc = await FirebaseFirestore.instance
        .collection("qr_passes")
        .doc(qrId)
        .get();

    if (!doc.exists) {
      _fail("QR NOT FOUND");
      return;
    }

    final data = doc.data()!;
    if (data["entered_at"] != null) {
      _fail("ALREADY ENTERED");
      return;
    }

    if (zone != volunteerZone) {
      _redirect(zone);
      return;
    }

    // ✅ MARK ENTRY
    await doc.reference.update({
      "entered_at": FieldValue.serverTimestamp(),
      "entered_zone": volunteerZone,
    });

    // 🔢 INCREMENT COUNTER
    final groupSize = data["group_size"] ?? 1;
    final zoneRef = FirebaseFirestore.instance
        .collection("zones")
        .doc(volunteerZone);

    FirebaseFirestore.instance.runTransaction((txn) async {
      final snap = await txn.get(zoneRef);
      final current = snap["counters"]["entered"] ?? 0;
      txn.update(zoneRef, {
        "counters.entered": current + groupSize,
      });
    });

    _success("VERIFIED", "Entry allowed");
  }

  // ───────── UI HELPERS ─────────
  void _success(String title, String msg) {
    setState(() {
      status = title;
      statusColor = Colors.green;
      message = msg;
    });
  }

  void _redirect(String correctZone) {
    setState(() {
      status = "WRONG ZONE";
      statusColor = Colors.orange;
      message = "Redirect pilgrim to $correctZone";
    });
  }

  void _fail(String msg) {
    setState(() {
      status = "REJECTED";
      statusColor = Colors.red;
      message = msg;
    });
  }

  void _reset() {
    setState(() {
      scanned = false;
      status = "";
      message = "";
    });
  }

  // ───────── UI ─────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      appBar: AppBar(
        title: const Text("Scan Pilgrim QR"),
        backgroundColor: const Color(0xFFD9822B),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              onDetect: (barcode) {
                final raw = barcode.barcodes.first.rawValue;
                if (raw != null) _handleScan(raw);
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: _resultCard(),
          ),
        ],
      ),
    );
  }

  Widget _resultCard() {
    if (status.isEmpty) {
      return const Center(
        child: Text(
          "Scan a pilgrim QR",
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            status,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _reset,
            style: ElevatedButton.styleFrom(
              backgroundColor: statusColor,
            ),
            child: const Text("Scan Next"),
          )
        ],
      ),
    );
  }
}
