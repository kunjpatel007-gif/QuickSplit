package com.campusquicksplit.campus_quicksplit

import android.nfc.cardemulation.HostApduService
import android.os.Bundle

class NfcCardService : HostApduService() {
    companion object {
        var payload: String = ""
        
        // AID: F222222222
        private val SELECT_AID = byteArrayOf(
            0x00.toByte(), 0xA4.toByte(), 0x04.toByte(), 0x00.toByte(),
            0x05.toByte(), // length of AID
            0xF2.toByte(), 0x22.toByte(), 0x22.toByte(), 0x22.toByte(), 0x22.toByte()
        )
        
        private val STATUS_SUCCESS = byteArrayOf(0x90.toByte(), 0x00.toByte())
        private val STATUS_FAILED = byteArrayOf(0x6A.toByte(), 0x82.toByte())
    }
    
    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        // Check if the command starts with SELECT AID header (00 A4 04 00)
        if (commandApdu.size >= 2 && commandApdu[0] == 0x00.toByte() && commandApdu[1] == 0xA4.toByte()) {
            if (payload.isNotEmpty()) {
                val payloadBytes = payload.toByteArray(Charsets.UTF_8)
                return payloadBytes + STATUS_SUCCESS
            }
            return STATUS_FAILED
        }
        return STATUS_FAILED
    }
    
    override fun onDeactivated(reason: Int) {
        // No-op
    }
}
