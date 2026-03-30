package com.aspiredesignovation.everwith

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.telephony.SmsManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "com.aspiredesignovation.everwith/wake_word"
        const val EVENT_CHANNEL  = "com.aspiredesignovation.everwith/wake_word_events"
        const val SMS_CHANNEL    = "com.aspiredesignovation.everwith/sms"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── SMS channel (send SMS via device SIM) ────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSms" -> {
                        val phone = call.argument<String>("phone")
                        val message = call.argument<String>("message")
                        if (phone.isNullOrBlank() || message.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Phone and message are required", null)
                            return@setMethodCallHandler
                        }
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS)
                            != PackageManager.PERMISSION_GRANTED) {
                            result.error("NO_PERMISSION", "SEND_SMS permission not granted", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                getSystemService(SmsManager::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                SmsManager.getDefault()
                            }
                            // Split long messages into parts
                            val parts = smsManager.divideMessage(message)
                            smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SMS_FAILED", e.message, null)
                        }
                    }
                    "hasSmsPermission" -> {
                        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) ==
                            PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Control channel (start / stop service) ───────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        startWakeWordService()
                        // Request overlay permission separately — do NOT block service start
                        requestOverlayPermissionIfNeeded()
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, WakeWordService::class.java))
                        result.success(null)
                    }
                    "pause" -> {
                        // Stop only the recognizer — service stays alive, no expensive restart
                        WakeWordService.serviceInstance?.pauseListening()
                        result.success(null)
                    }
                    "resume" -> {
                        WakeWordService.serviceInstance?.resumeListening()
                        result.success(null)
                    }
                    "requestOverlayPermission" -> {
                        requestOverlayPermissionIfNeeded()
                        result.success(null)
                    }
                    "hasOverlayPermission" -> {
                        result.success(Settings.canDrawOverlays(this))
                    }
                    // Returns true if this launch came from a wake word with auto_listen=true
                    "getAutoListen" -> {
                        val fromWake = intent?.getBooleanExtra("from_wake_word", false) ?: false
                        val autoListen = intent?.getBooleanExtra("auto_listen", false) ?: false
                        result.success(fromWake && autoListen)
                    }
                    // Returns true if launched from wake word but user was NOT logged in
                    "getNotLoggedIn" -> {
                        val fromWake = intent?.getBooleanExtra("from_wake_word", false) ?: false
                        val autoListen = intent?.getBooleanExtra("auto_listen", false) ?: false
                        result.success(fromWake && !autoListen)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Event channel (wake word detections → Flutter stream) ────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    WakeWordService.eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    WakeWordService.eventSink = null
                }
            })
    }

    // Called when app is brought to foreground via startActivity (FLAG_REORDER_TO_FRONT)
    // or when singleTop prevents a new instance. Fire the EventSink here because
    // Flutter is guaranteed to be rendering by the time this is called.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        deliverWakeWordEvent(intent)
    }

    // Also handle the cold-start case: if the app was fully dead and relaunched
    // by wake word, deliver via onResume (Flutter engine fully ready by then).
    override fun onResume() {
        super.onResume()
        val i = intent ?: return
        // Guard: only deliver if this is genuinely a wake-word cold-start launch,
        // not a return from the overlay-permission settings screen.
        if (!i.getBooleanExtra("from_wake_word", false)) return
        if (!i.getBooleanExtra("auto_listen", false)) return
        // Ensure Flutter engine is attached before touching the event sink
        if (flutterEngine == null) return
        Handler(Looper.getMainLooper()).postDelayed({
            if (!isFinishing && !isDestroyed) {
                deliverWakeWordEvent(i)
                // Clear flag so rotating / resuming doesn't re-fire
                i.removeExtra("from_wake_word")
            }
        }, 600L)
    }

    private fun deliverWakeWordEvent(intent: Intent) {
        if (!intent.getBooleanExtra("from_wake_word", false)) return
        val autoListen = intent.getBooleanExtra("auto_listen", false)
        if (!autoListen) return
        val phrase = intent.getStringExtra("wake_phrase") ?: "hey companion"
        WakeWordService.eventSink?.success(phrase)
    }

    private fun requestOverlayPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !Settings.canDrawOverlays(this)) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            try {
                startActivity(intent)
            } catch (e: Exception) {
                android.util.Log.w("MainActivity", "Could not open overlay settings: ${e.message}")
            }
        }
    }

    private fun startWakeWordService() {
        val intent = Intent(this, WakeWordService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}

