package com.campusquicksplit.campus_quicksplit

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.nfc.NfcAdapter

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.campusquicksplit/nfc"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNfcAvailable" -> {
                    val nfcAdapter = NfcAdapter.getDefaultAdapter(this)
                    result.success(nfcAdapter != null && nfcAdapter.isEnabled)
                }
                "startBroadcast" -> {
                    val userName = call.argument<String>("userName") ?: ""
                    val upiId = call.argument<String>("upiId") ?: ""
                    NfcCardService.payload = "$userName|$upiId"
                    result.success(true)
                }
                "stopBroadcast" -> {
                    NfcCardService.payload = ""
                    result.success(true)
                }
                "openNfcSettings" -> {
                    try {
                        startActivity(android.content.Intent(android.provider.Settings.ACTION_NFC_SETTINGS))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
