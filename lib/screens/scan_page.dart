import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

const String QR_SECRET = "KUMBHATHON_2027_SECRET";

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final String volunteerZone = "RAMKUND_G1"; // THIS DEVICE ZONE
  bool scanned = false;

  String status = "";
  String message = "";
  Color statusColor = Colors.grey;

  // ───── SIGN ─────
  String _sign(String qrId) {
    final hmac = Hmac(sha256, utf8.encode(QR_SECRET));
    return hmac.convert(utf8.encode(qrId)).toString().substring(0, 10);
  }

  bool _isDateValid(String dateStr) {
    final visitDate = DateTime.parse(dateStr);
    final now = DateTime.now();
    return now.isAfter(visitDate.subtract(const Duration(days: 1))) &&
        now.isBefore(visitDate.add(const Duration(days: 1)));
  }

  // ───── MAIN SCAN HANDLER ─────
  Future<void> _handleScan(String raw) async {
    if (scanned) return;
    scanned = true;

    try {
      final decoded =
      jsonDecode(utf8.decode(base64Decode(raw))) as Map<String, dynamic>;

      final qrId = decoded["qr_id"];
      final date = decoded["date"];
      final zone = decoded["zone"];
      final sig = decoded["sig"];

      if (_sign(qrId) != sig) {
        _fail("INVALID QR");
        return;
      }

      if (!_isDateValid(date)) {
        _fail("QR EXPIRED");
        return;
      }

      final online =
          (await Connectivity().checkConnectivity()) != ConnectivityResult.none;

      if (!online) {
        _success("OFFLINE VERIFIED", "Allow entry");
        return;
      }

      await _onlineProcess(qrId, zone);
    } catch (e) {
      _fail("INVALID QR FORMAT");
    }
  }

  // ───── ONLINE ENTRY / EXIT ─────
  Future<void> _onlineProcess(String qrId, String zone) async {
    final qrRef =
    FirebaseFirestore.instance.collection("qr_passes").doc(qrId);

    final qrSnap = await qrRef.get();
    if (!qrSnap.exists) {
      _fail("QR NOT FOUND");
      return;
    }

    final data = qrSnap.data()!;
    final int count = data["group_size"] ?? 1;
    final travelMode = data["zones"]?["parking"] != null ? "CAR" : "WALK";

    // ───── ENTRY ─────
    if (data["entered_at"] == null) {
      if (zone != volunteerZone) {
        _redirect(zone);
        return;
      }

      await qrRef.update({
        "entered_at": FieldValue.serverTimestamp(),
        "entered_zone": volunteerZone,
        "expected_exit_at": travelMode == "WALK"
            ? Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 90)))
            : null,
        "exit_mode": travelMode == "WALK" ? "AUTO_TIMER" : "MANUAL",
      });

      await _updateZoneCounter(
        zoneId: volunteerZone,
        field: "entered",
        value: count,
      );

      await _logEvent(
        qrId: qrId,
        zoneId: volunteerZone,
        type: "ENTRY",
        count: count,
        mode: travelMode,
        source: "VOLUNTEER_SCAN",
      );

      _success("ENTRY OK", "Allow pilgrim inside");
      return;
    }

    // ───── EXIT (CAR ONLY) ─────
    if (data["exited_at"] == null && travelMode == "CAR") {
      await qrRef.update({
        "exited_at": FieldValue.serverTimestamp(),
        "exit_zone": volunteerZone,
      });

      await _updateZoneCounter(
        zoneId: volunteerZone,
        field: "exited",
        value: count,
      );

      await _logEvent(
        qrId: qrId,
        zoneId: volunteerZone,
        type: "EXIT",
        count: count,
        mode: "CAR",
        source: "VOLUNTEER_SCAN",
      );

      _success("EXIT OK", "Pilgrim exited");
      return;
    }

    _fail("ALREADY USED");
  }

  // ───── ZONE COUNTER UPDATE ─────
  Future<void> _updateZoneCounter({
    required String zoneId,
    required String field,
    required int value,
  }) async {
    final ref =
    FirebaseFirestore.instance.collection("zones").doc(zoneId);

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final current = snap["counters"][field] ?? 0;
      txn.update(ref, {
        "counters.$field": current + value,
      });
    });
  }

  // ───── EVENT LOG ─────
  Future<void> _logEvent({
    required String qrId,
    required String zoneId,
    required String type,
    required int count,
    required String mode,
    required String source,
  }) async {
    await FirebaseFirestore.instance.collection("zone_events").add({
      "qr_id": qrId,
      "zone_id": zoneId,
      "event": type,
      "count": count,
      "mode": mode,
      "source": source,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  // ───── UI HELPERS ─────
  void _success(String t, String m) {
    setState(() {
      status = t;
      message = m;
      statusColor = Colors.green;
    });
  }

  void _fail(String m) {
    setState(() {
      status = "REJECTED";
      message = m;
      statusColor = Colors.red;
    });
  }

  void _redirect(String zone) {
    setState(() {
      status = "WRONG ZONE";
      message = "Go to $zone";
      statusColor = Colors.orange;
    });
  }

  void _reset() {
    setState(() {
      scanned = false;
      status = "";
      message = "";
    });
  }

  // ───── UI ─────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Volunteer Scan")),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              onDetect: (c) {
                final raw = c.barcodes.first.rawValue;
                if (raw != null) _handleScan(raw);
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: _result(),
          )
        ],
      ),
    );
  }

  Widget _result() {
    if (status.isEmpty) {
      return const Center(child: Text("Scan QR"));
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(status,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: statusColor)),
        const SizedBox(height: 10),
        Text(message),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _reset, child: const Text("Scan Next"))
      ],
    );
  }
}
