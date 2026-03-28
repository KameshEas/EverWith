package com.aspiredesignovation.everwith

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Restarts the WakeWordService after the device boots or after the app is updated.
 * This ensures "Hey Companion" keeps working without the user having to open the app.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val serviceIntent = Intent(context, WakeWordService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }
}
