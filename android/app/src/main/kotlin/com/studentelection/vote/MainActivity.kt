package com.studentelection.vote

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Hosts the Flutter UI and implements the `com.studentelection.vote/native`
 * MethodChannel for BLE polling-node discovery, Bluetooth state, app settings
 * and election-notification polling.
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.studentelection.vote/native"
        private const val REQ_BT_PERMS = 1001
        private const val REQ_ENABLE_BT = 1002

        /**
         * Polling-node BLE manufacturer ID. Update this constant if your
         * hardware beacon uses a different 16-bit company identifier.
         */
        private const val BEACON_MANUFACTURER_ID = 0xFFFF
        private const val MIN_PAYLOAD_BYTES = 16
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingScanResult: MethodChannel.Result? = null
    private var pendingEnableResult: MethodChannel.Result? = null
    private var activeScanCallback: ScanCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scan" -> handleScan(call, result)
                    "bluetoothStatus" -> result.success(currentBluetoothStatus())
                    "enableBluetooth" -> handleEnableBluetooth(result)
                    "openSettings" -> {
                        openAppSettings()
                        result.success(null)
                    }
                    "notifyStart" -> {
                        val token = call.argument<String>("token").orEmpty()
                        val apiBase = call.argument<String>("apiBase").orEmpty()
                        NotificationPollerService.start(this, token, apiBase)
                        result.success(null)
                    }
                    "notifyStop" -> {
                        NotificationPollerService.stop(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun bluetoothAdapter(): BluetoothAdapter? {
        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter
    }

    private fun currentBluetoothStatus(): Map<String, Any> {
        val adapter = bluetoothAdapter()
        val on = adapter?.isEnabled == true
        return mapOf("on" to on, "node" to false)
    }

    private fun requiredBlePermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    private fun hasBlePermissions(): Boolean {
        return requiredBlePermissions().all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun handleEnableBluetooth(result: MethodChannel.Result) {
        val adapter = bluetoothAdapter()
        if (adapter == null) {
            result.error("BLUETOOTH_OFF", "This device does not have Bluetooth.", null)
            return
        }
        if (adapter.isEnabled) {
            result.success(true)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(this, requiredBlePermissions(), REQ_BT_PERMS)
            result.error("PERMISSION_DENIED", "Allow Bluetooth permission to turn on Bluetooth.", null)
            return
        }
        pendingEnableResult = result
        @Suppress("DEPRECATION")
        startActivityForResult(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE), REQ_ENABLE_BT)
    }

    @SuppressLint("MissingPermission")
    private fun handleScan(call: MethodCall, result: MethodChannel.Result) {
        val adapter = bluetoothAdapter()
        if (adapter == null || !adapter.isEnabled) {
            result.error("BLUETOOTH_OFF", "Turn on Bluetooth to verify your presence.", null)
            return
        }
        if (!hasBlePermissions()) {
            ActivityCompat.requestPermissions(this, requiredBlePermissions(), REQ_BT_PERMS)
            result.error("PERMISSION_DENIED", "Allow Bluetooth permission to scan for the polling node.", null)
            return
        }
        val scanner: BluetoothLeScanner? = adapter.bluetoothLeScanner
        if (scanner == null) {
            result.error("BLUETOOTH_OFF", "Bluetooth scanner is unavailable.", null)
            return
        }

        val timeoutMs = (call.argument<Int>("timeoutMs") ?: 7000).toLong().coerceIn(2000L, 20000L)
        val found = LinkedHashMap<String, Pair<Int, Map<String, Any>>>()

        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, scanResult: ScanResult) {
                val claim = parseClaim(scanResult) ?: return
                val mac = scanResult.device?.address ?: return
                val existing = found[mac]
                if (existing == null || scanResult.rssi > existing.first) {
                    found[mac] = scanResult.rssi to claim
                }
            }

            override fun onScanFailed(errorCode: Int) {
                finishScan(scanner, result, emptyList())
            }
        }

        activeScanCallback?.let {
            try { scanner.stopScan(it) } catch (_: Throwable) {}
        }
        activeScanCallback = callback
        pendingScanResult = result

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        scanner.startScan(null, settings, callback)
        mainHandler.postDelayed({
            val claims = found.values
                .sortedByDescending { it.first }
                .map { it.second }
            finishScan(scanner, result, claims)
        }, timeoutMs)
    }

    @SuppressLint("MissingPermission")
    private fun finishScan(
        scanner: BluetoothLeScanner,
        result: MethodChannel.Result,
        claims: List<Map<String, Any>>
    ) {
        if (pendingScanResult !== result) return
        pendingScanResult = null
        val cb = activeScanCallback
        activeScanCallback = null
        if (cb != null) {
            try { scanner.stopScan(cb) } catch (_: Throwable) {}
        }
        result.success(claims)
    }

    /**
     * Extracts `{beaconId, bootNonce, counter, mac}` from manufacturer-specific
     * data:
     * - bytes 0..3 : uint32 LE beaconId
     * - bytes 4..11: 8-byte bootNonce (hex)
     * - bytes 12..15: uint32 LE counter
     */
    private fun parseClaim(scanResult: ScanResult): Map<String, Any>? {
        val data = scanResult.scanRecord?.getManufacturerSpecificData(BEACON_MANUFACTURER_ID)
            ?: return null
        if (data.size < MIN_PAYLOAD_BYTES) return null
        val buf = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN)
        val beaconId = buf.int.toLong() and 0xFFFFFFFFL
        val nonceBytes = ByteArray(8)
        buf.get(nonceBytes)
        val bootNonce = nonceBytes.joinToString("") { "%02x".format(it) }
        val counter = buf.int.toLong() and 0xFFFFFFFFL
        val mac = scanResult.device?.address ?: ""
        return mapOf(
            "beaconId" to beaconId,
            "bootNonce" to bootNonce,
            "counter" to counter,
            "mac" to mac
        )
    }

    private fun openAppSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", packageName, null)
        )
        startActivity(intent)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_ENABLE_BT) {
            val res = pendingEnableResult
            pendingEnableResult = null
            res?.success(bluetoothAdapter()?.isEnabled == true)
        }
    }
}
