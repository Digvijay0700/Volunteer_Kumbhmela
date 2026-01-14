package com.example.digisangam_volunteer

import android.bluetooth.*
import android.content.Context
import android.util.Log
import java.nio.ByteBuffer
import java.util.UUID

// ... existing imports ...

class BleGattClientManager(
    private val context: Context,
    private val onLocationReceived: (Double, Double) -> Unit
) {
    private var bluetoothGatt: BluetoothGatt? = null

    // MUST MATCH THE PILGRIM APP EXACTLY
    private val SERVICE_UUID = UUID.fromString("0000aaaa-0000-1000-8000-00805f9b34fb")
    private val LAT_UUID     = UUID.fromString("0000aaab-0000-1000-8000-00805f9b34fb")
    private val LNG_UUID     = UUID.fromString("0000aaac-0000-1000-8000-00805f9b34fb")

    private var lastLat: Double? = null
    private var lastLng: Double? = null

    fun connect(device: BluetoothDevice) {
        // Use TRANSPORT_LE to ensure a stable connection on newer Androids
        bluetoothGatt = device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                Log.d("GATT", "✅ Connected to pilgrim. Discovering services...")
                gatt.discoverServices()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                Log.d("GATT", "❌ Disconnected from pilgrim")
                gatt.close()
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                val service = gatt.getService(SERVICE_UUID)
                if (service != null) {
                    val latChar = service.getCharacteristic(LAT_UUID)
                    Log.d("GATT", "Reading Latitude...")
                    gatt.readCharacteristic(latChar)
                } else {
                    Log.e("GATT", "Service not found!")
                }
            }
        }

        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                val value = ByteBuffer.wrap(characteristic.value).double
                
                if (characteristic.uuid == LAT_UUID) {
                    lastLat = value
                    Log.d("GATT", "Fetched Lat: $value. Now fetching Lng...")
                    // Now fetch longitude
                    val service = gatt.getService(SERVICE_UUID)
                    val lngChar = service.getCharacteristic(LNG_UUID)
                    gatt.readCharacteristic(lngChar)
                } else if (characteristic.uuid == LNG_UUID) {
                    lastLng = value
                    Log.d("GATT", "Fetched Lng: $value. SUCCESS!")
                    
                    if (lastLat != null && lastLng != null) {
                        onLocationReceived(lastLat!!, lastLng!!)
                        // Disconnect once we have the data to save battery
                        gatt.disconnect()
                    }
                }
            }
        }
    }
}