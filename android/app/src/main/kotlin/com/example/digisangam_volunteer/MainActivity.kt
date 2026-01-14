package com.example.digisangam_volunteer

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "volunteer_gatt_channel"

    // Define permissions based on Android version
    private val blePermissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        arrayOf(
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.ACCESS_FINE_LOCATION
        )
    } else {
        arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startListening") {
                if (!hasPermissions()) {
                    // Trigger the system permission popup
                    ActivityCompat.requestPermissions(this, blePermissions, 101)
                    result.error("PERMISSION_DENIED", "Permissions required for BLE", null)
                } else {
                    // Permissions granted, start the scanner logic
                    try {
                        VolunteerBleScanner(this) { lat, lng ->
                            runOnUiThread {
                                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                                    .invokeMethod("onLocation", mapOf("lat" to lat, "lng" to lng))
                            }
                        }.startScanning()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("BLE_ERROR", e.message, null)
                    }
                }
            }
        }
    }

    private fun hasPermissions(): Boolean {
        return blePermissions.all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    // Handle the result of the permission request
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 101) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                println("✅ Bluetooth permissions granted by user")
            }
        }
    }
}