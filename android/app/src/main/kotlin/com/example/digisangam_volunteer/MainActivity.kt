package com.example.digisangam_volunteer

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import com.example.digisangam_volunteer.sos.BleSosReceiver

class MainActivity : FlutterActivity() {

    private lateinit var bleReceiver: BleSosReceiver

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        requestPermissionsIfNeeded()

        bleReceiver = BleSosReceiver(this)

        bleReceiver.startListening {
            Log.d("MAIN", "🚨 VOLUNTEER RECEIVED SOS")
        }
    }

    private fun requestPermissionsIfNeeded() {

        val permissions = arrayOf(
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.ACCESS_FINE_LOCATION
        )

        val missing = permissions.filter {
            ContextCompat.checkSelfPermission(this, it)
            != PackageManager.PERMISSION_GRANTED
        }

        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                missing.toTypedArray(),
                101
            )
        }
    }
}
