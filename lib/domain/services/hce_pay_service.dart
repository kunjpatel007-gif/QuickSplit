import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

class HcePayService {
  static const _channel = MethodChannel('com.campusquicksplit/nfc');

  /// Check if NFC hardware is available and enabled
  static Future<bool> isNfcAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isNfcAvailable');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open Android NFC Settings screen
  static Future<void> openNfcSettings() async {
    try {
      await _channel.invokeMethod('openNfcSettings');
    } catch (_) {}
  }

  /// Start HCE broadcast (makes this phone appear as an NFC card)
  static Future<void> startBroadcasting({
    required String userName,
    required String upiId,
  }) async {
    await _channel.invokeMethod('startBroadcast', {
      'userName': userName,
      'upiId': upiId,
    });
  }

  /// Stop HCE broadcast
  static Future<void> stopBroadcasting() async {
    await _channel.invokeMethod('stopBroadcast');
  }

  /// Start NFC reader mode to detect a peer's HCE card.
  /// When detected, calls [onPeerDetected] with the peer's userName and upiId.
  static Future<void> startReading({
    required void Function(String userName, String upiId) onPeerDetected,
  }) async {
    NfcManager.instance.startSession(
      pollingOptions: NfcPollingOption.values.toSet(),
      onDiscovered: (NfcTag tag) async {
        try {
          final isoDep = IsoDepAndroid.from(tag);
          if (isoDep == null) return;

          // Send SELECT AID command for our custom AID F222222222
          final selectCommand = Uint8List.fromList([
            0x00, 0xA4, 0x04, 0x00, // SELECT command
            0x05, // Length of AID
            0xF2, 0x22, 0x22, 0x22, 0x22, // AID: F222222222
            0x00, // Le: accept any length response
          ]);

          final response = await isoDep.transceive(selectCommand);

          // Response is payload bytes + 2 status bytes (90 00)
          if (response.length > 2) {
            final statusWord = response.sublist(response.length - 2);
            if (statusWord[0] == 0x90 && statusWord[1] == 0x00) {
              final payloadBytes = response.sublist(0, response.length - 2);
              final payloadString = String.fromCharCodes(payloadBytes);
              final parts = payloadString.split('|');
              if (parts.length >= 2) {
                onPeerDetected(parts[0], parts[1]);
              }
            }
          }
        } catch (e) {
          // NFC read failed, show error on screen to debug
          // We can't easily setState from here without a callback, so let's use the onPeerDetected with a special error flag.
          onPeerDetected('ERROR', e.toString());
        }
      },
    );
  }

  /// Stop NFC reader mode
  static Future<void> stopReading() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }
}
