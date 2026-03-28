package com.aspiredesignovation.everwith

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "com.aspiredesignovation.everwith/wake_word"
        const val EVENT_CHANNEL  = "com.aspiredesignovation.everwith/wake_word_events"
        const val OVERLAY_REQUEST_CODE = 1001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Control channel (start / stop service) ───────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        requestOverlayPermissionIfNeeded()
                        startWakeWordService()
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, WakeWordService::class.java))
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
        if (i.getBooleanExtra("from_wake_word", false) &&
            i.getBooleanExtra("auto_listen", false)) {
            // Post slightly so HomeScreen initState finishes subscribing first
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                deliverWakeWordEvent(i)
                // Clear flag so rotating / resuming doesn't re-fire
                i.removeExtra("from_wake_word")
            }, 600L)
        }
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
            )
            startActivityForResult(intent, OVERLAY_REQUEST_CODE)
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

