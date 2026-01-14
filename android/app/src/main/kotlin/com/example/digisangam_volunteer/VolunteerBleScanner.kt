package com.example.digisangam_volunteer

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import java.util.UUID

class VolunteerBleScanner(
    private val context: Context,
    private val onLocationReceived: (Double, Double) -> Unit
) {

    private val scanner =
        BluetoothAdapter.getDefaultAdapter().bluetoothLeScanner

    private val SERVICE_UUID =
        ParcelUuid(
            UUID.fromString("0000aaaa-0000-1000-8000-00805f9b34fb")
        )

    fun startScanning() {

        val filter = ScanFilter.Builder()
            .setServiceUuid(SERVICE_UUID)
            .build()

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        scanner.startScan(
            listOf(filter),
            settings,
            scanCallback
        )

        Log.d("BLE", "🔍 Volunteer scanning started")
    }

    private val scanCallback = object : ScanCallback() {

        override fun onScanResult(
            callbackType: Int,
            result: ScanResult
        ) {
            Log.d("BLE", "📡 SOS detected, connecting...")

            scanner.stopScan(this)

            BleGattClientManager(
                context,
                onLocationReceived
            ).connect(result.device)
        }
    }
}
