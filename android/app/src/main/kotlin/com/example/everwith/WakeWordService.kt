package com.example.everwith

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.auth.FirebaseAuth
import io.flutter.plugin.common.EventChannel
import java.util.Locale

// ─────────────────────────────────────────────────────────────────────────────
//  WakeWordService
//
//  A foreground service that continuously listens for a set of wake phrases
//  using the device's built-in SpeechRecognizer (free, no third-party SDK).
//
//  Wake phrases (any match triggers activation):
//    • "hey companion"
//    • "i need help"
//    • "hey helper"
//    • "ok companion"
//
//  When a phrase is detected the service fires the Flutter EventChannel so the
//  app can respond (e.g. open the mic / navigate to home).
// ─────────────────────────────────────────────────────────────────────────────
class WakeWordService : Service() {

    companion object {
        const val TAG = "WakeWordService"
        const val CHANNEL_ID = "everwith_wake_word"
        const val ALERT_CHANNEL_ID = "everwith_wake_alert"
        const val NOTIFICATION_ID = 2001
        const val ALERT_NOTIFICATION_ID = 2002
        const val ERROR_NETWORK_CONNECTIVITY = 11  // Undocumented error code observed on network disconnect

        /** Event sink injected by MainActivity via the EventChannel stream handler. */
        @Volatile
        var eventSink: EventChannel.EventSink? = null

        /** Live instance — set in onCreate/cleared in onDestroy. */
        @Volatile
        var serviceInstance: WakeWordService? = null

        // Full phrases for exact-contains matching
        val WAKE_PHRASES = listOf(
            "hey companion",
            "i need help",
            "hey helper",
            "ok companion",
        )

        // First-word triggers: fires as soon as these token sequences appear in partials
        // e.g. ["hey","companion"] matches partial "hey comp" via startsWith logic
        val WAKE_TOKENS = listOf(
            listOf("hey", "companion"),
            listOf("hey", "helper"),
            listOf("ok", "companion"),
            listOf("i", "need", "help"),
        )
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var speechRecognizer: SpeechRecognizer? = null
    private var audioManager: AudioManager? = null
    private var tts: TextToSpeech? = null
    @Volatile private var active = false
    @Volatile private var paused = false
    @Volatile private var recognizerBusy = false
    @Volatile private var volumeMuted = false
    @Volatile private var lastFireTimeMs = 0L

    override fun onCreate() {
        super.onCreate()
        serviceInstance = this
        createNotificationChannel()
        try {
            startForeground(NOTIFICATION_ID, buildNotification())
        } catch (e: SecurityException) {
            Log.e(TAG, "startForeground denied — RECORD_AUDIO not granted yet: ${e.message}")
            stopSelf()
            return
        }
        tts = TextToSpeech(this) { /* init callback – no action needed */ }
        audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!active) {
            active = true
            startListening()
        }
        return START_STICKY  // restart automatically if killed by the system
    }

    override fun onDestroy() {
        active = false
        serviceInstance = null
        tearDownRecognizer()
        mainHandler.removeCallbacksAndMessages(null)
        tts?.stop()
        tts?.shutdown()
        audioManager = null
        super.onDestroy()
    }

    /** Release the mic without stopping the service. Flutter calls this before using STT. */
    fun pauseListening() {
        paused = true
        mainHandler.removeCallbacksAndMessages(null)
        tearDownRecognizer()
        Log.d(TAG, "Wake word paused (mic released)")
    }

    /** Reclaim the mic after Flutter STT is done. */
    fun resumeListening() {
        if (!active) return
        paused = false
        Log.d(TAG, "Wake word resuming…")
        mainHandler.postDelayed({ startListening() }, 400L)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── SpeechRecognizer management ──────────────────────────────────────────

    private fun startListening() {
        if (!active || recognizerBusy || paused) return

        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            Log.w(TAG, "SpeechRecognizer not available on this device")
            return
        }

        tearDownRecognizer()

        try {
            // TRY 1: Force on-device recognizer (API 33+) with try-catch for better error handling
            volumeMuted = false
            speechRecognizer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                try {
                    Log.d(TAG, "Attempting on-device recognizer (API 33+)...")
                    SpeechRecognizer.createOnDeviceSpeechRecognizer(this).also { sr ->
                        sr.setRecognitionListener(listener)
                        Log.i(TAG, "✅ Using on-device recognizer (offline, no server disconnect risk)")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "On-device recognizer failed: ${e.message} – falling back to network")
                    // Fallback to network recognizer (needs mute/restore)
                    muteBeep()
                    volumeMuted = true
                    SpeechRecognizer.createSpeechRecognizer(this).also { sr ->
                        sr.setRecognitionListener(listener)
                        Log.i(TAG, "Fallback: Using network recognizer")
                    }
                }
            } else {
                // API < 33: Use network recognizer (needs mute/restore)
                muteBeep()
                volumeMuted = true
                SpeechRecognizer.createSpeechRecognizer(this).also { sr ->
                    sr.setRecognitionListener(listener)
                    Log.i(TAG, "Using network recognizer (API < 33)")
                }
            }

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                // IMPROVED: Always try to prefer offline first
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                // IMPROVED: Increased silence timeouts to prevent premature server disconnects
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2_500L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 400L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1_500L)
            }

            speechRecognizer?.startListening(intent)
            recognizerBusy = true
            // Restore media volume after recognizer has started (only if we muted for network)
            if (volumeMuted) {
                mainHandler.postDelayed({ if (volumeMuted) restoreVolume() }, 800L)
            }
            Log.d(TAG, "📍 Listening for wake word…")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start listening: ${e.message}", e)
            recognizerBusy = false
            scheduleRestart(2_000L)
        }
    }

    /** Silence the media stream briefly to suppress the Google STT start-beep. */
    private fun muteBeep() {
        audioManager?.adjustStreamVolume(
            AudioManager.STREAM_MUSIC,
            AudioManager.ADJUST_MUTE,
            0
        )
    }

    private fun restoreVolume() {
        audioManager?.adjustStreamVolume(
            AudioManager.STREAM_MUSIC,
            AudioManager.ADJUST_UNMUTE,
            0
        )
    }

    private fun scheduleRestart(delayMs: Long = 300L) {
        recognizerBusy = false
        if (active) {
            mainHandler.postDelayed({ startListening() }, delayMs)
        }
    }

    private fun tearDownRecognizer() {
        speechRecognizer?.apply {
            stopListening()
            destroy()
        }
        speechRecognizer = null
        recognizerBusy = false
    }

    // ── RecognitionListener ──────────────────────────────────────────────────

    private val listener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            // Recognizer is live — restore volume only if we actually muted
            if (volumeMuted) {
                restoreVolume()
                volumeMuted = false
            }
        }
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onEvent(eventType: Int, params: Bundle?) {}

        override fun onPartialResults(partialResults: Bundle?) {
            // Ignore partials — only check final results to avoid debounce race conditions
        }

        override fun onResults(results: Bundle?) {
            val candidates = results
                ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?: emptyList()
            // Only check wake word on final results, not partials
            checkForWakeWord(candidates)
            scheduleRestart(300L)
        }

        override fun onError(error: Int) {
            // Restore volume immediately if suppressed (in case onReadyForSpeech never fired)
            if (volumeMuted) {
                restoreVolume()
                volumeMuted = false
            }
            val errorName = when (error) {
                SpeechRecognizer.ERROR_NO_MATCH               -> "ERROR_NO_MATCH"
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT         -> "ERROR_SPEECH_TIMEOUT"
                SpeechRecognizer.ERROR_AUDIO                  -> "ERROR_AUDIO"
                SpeechRecognizer.ERROR_NETWORK                -> "ERROR_NETWORK"
                SpeechRecognizer.ERROR_NETWORK_TIMEOUT        -> "ERROR_NETWORK_TIMEOUT"
                SpeechRecognizer.ERROR_SERVER                 -> "ERROR_SERVER"
                SpeechRecognizer.ERROR_CLIENT                 -> "ERROR_CLIENT"
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "ERROR_INSUFFICIENT_PERMISSIONS"
                SpeechRecognizer.ERROR_RECOGNIZER_BUSY        -> "ERROR_RECOGNIZER_BUSY"   // = 8
                ERROR_NETWORK_CONNECTIVITY                    -> "ERROR_NETWORK_CONNECTIVITY"
                else                                          -> "ERROR_$error"
            }
            val delayMs = when (error) {
                SpeechRecognizer.ERROR_NO_MATCH,
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT         -> 500L    // silence — short retry
                SpeechRecognizer.ERROR_AUDIO                  -> 1_000L
                SpeechRecognizer.ERROR_NETWORK,
                SpeechRecognizer.ERROR_NETWORK_TIMEOUT        -> 5_000L  // wait for connectivity
                SpeechRecognizer.ERROR_SERVER                 -> 5_000L
                ERROR_NETWORK_CONNECTIVITY                    -> 4_000L  // network disconnect — longer pause + full reset
                SpeechRecognizer.ERROR_RECOGNIZER_BUSY        -> 2_000L  // = 8, busy — wait longer
                else                                          -> 1_000L
            }
            Log.d(TAG, "Recognition $errorName ($error) – restarting in ${delayMs}ms")
            // IMPROVED: On server disconnect, fully tear down and recreate recognizer
            if (error == ERROR_NETWORK_CONNECTIVITY || error == SpeechRecognizer.ERROR_SERVER ||
                error == SpeechRecognizer.ERROR_CLIENT ||
                error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY ||
                error == SpeechRecognizer.ERROR_NETWORK) {
                tearDownRecognizer()
                Log.d(TAG, "Fully reset recognizer due to error $error")
            }
            scheduleRestart(delayMs)
        }
    }

    // ── Wake phrase matching ─────────────────────────────────────────────────

    /**
     * Returns true if a wake phrase was found.
     *
     * Two-pass strategy for speed and robustness:
     *  1. Exact contains — "hey companion" in full text
     *  2. Token prefix  — useful for partials where the last word is cut off,
     *     e.g. "hey comp" matched because "companion" starts with "comp"
     */
    private fun checkForWakeWord(candidates: List<String>): Boolean {
        val now = System.currentTimeMillis()
        if (now - lastFireTimeMs < 2_000L) return false  // debounce

        for (text in candidates) {
            val lower = text.lowercase(Locale.ENGLISH).trim()

            // Pass 1: exact substring
            val exact = WAKE_PHRASES.firstOrNull { lower.contains(it) }
            if (exact != null) {
                fireWakeWord(exact)
                return true
            }

            // Pass 2: token-prefix match (catches partials like "hey compan")
            val words = lower.split("\\s+".toRegex())
            for (phrase in WAKE_TOKENS) {
                if (words.size < phrase.size) continue
                val tail = words.takeLast(phrase.size)
                val allMatch = tail.zip(phrase).all { (word, token) ->
                    word == token || word.startsWith(token.take(4))
                }
                if (allMatch) {
                    fireWakeWord(phrase.joinToString(" "))
                    return true
                }
            }
        }
        return false
    }

    private fun fireWakeWord(phrase: String) {
        lastFireTimeMs = System.currentTimeMillis()
        Log.i(TAG, "🔔 Wake word: \"$phrase\"")

        val user = FirebaseAuth.getInstance().currentUser
        if (user != null) {
            // Authenticated — bring app to foreground; phrase delivered via onNewIntent
            mainHandler.post {
                launchApp(phrase = phrase, autoListen = true)
            }
        } else {
            // Not authenticated — speak a message and bring app to login screen
            speak("You are not logged into EverWith. Please open the app and sign in to use voice commands.") {
                mainHandler.post { launchApp(phrase = phrase, autoListen = false) }
            }
        }
    }

    private fun speak(text: String, onDone: (() -> Unit)? = null) {
        tts?.setOnUtteranceProgressListener(object : android.speech.tts.UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {}
            override fun onDone(utteranceId: String?) { onDone?.invoke() }
            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) { onDone?.invoke() }
        })
        val params = Bundle()
        params.putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, "wake_msg")
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, params, "wake_msg")
    }

    private fun launchApp(phrase: String, autoListen: Boolean) {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("from_wake_word", true)
            putExtra("auto_listen", autoListen)
            putExtra("wake_phrase", phrase)
        } ?: return

        val hasOverlay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            android.provider.Settings.canDrawOverlays(this)
        } else true

        Log.d(TAG, "launchApp: canDrawOverlays=$hasOverlay phrase=$phrase autoListen=$autoListen")

        // Always attempt startActivity first.
        // On Android 10+ without SYSTEM_ALERT_WINDOW this throws SecurityException.
        // On vivo/OEM devices canDrawOverlays() may lie — try regardless.
        try {
            startActivity(launchIntent)
            Log.i(TAG, "launchApp: ✅ direct startActivity succeeded")
            return  // opened — no notification needed
        } catch (e: SecurityException) {
            Log.w(TAG, "launchApp: ❌ SecurityException (no overlay permission): ${e.message}")
        } catch (e: Exception) {
            Log.w(TAG, "launchApp: ❌ startActivity failed: ${e.message}")
        }

        // ── Fallback: heads-up notification ──────────────────────────────────
        // Only reached if startActivity was blocked by the OS.
        // Also re-request the overlay permission so next time it works directly.
        Log.w(TAG, "launchApp: falling back to notification — overlay permission not effective")

        val pendingIntent = PendingIntent.getActivity(
            this,
            ALERT_NOTIFICATION_ID,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Intent to open the "Display over other apps" settings for this app
        val overlaySettingsIntent = android.content.Intent(
            android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            android.net.Uri.parse("package:$packageName")
        ).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK }
        val overlayPendingIntent = PendingIntent.getActivity(
            this, ALERT_NOTIFICATION_ID + 1, overlaySettingsIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val nm = getSystemService(NotificationManager::class.java)
        val alertTitle = if (autoListen) "👂 Wake word detected!" else "EverWith"
        val alertText  = if (autoListen) "Tap to open • Grant permission to auto-open" else "Please log in to use voice commands"

        val builder = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setContentTitle(alertTitle)
            .setContentText(alertText)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .addAction(
                android.R.drawable.ic_menu_manage,
                "Grant permission",
                overlayPendingIntent
            )

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE ||
            nm.canUseFullScreenIntent()) {
            builder.setFullScreenIntent(pendingIntent, true)
        }

        nm.notify(ALERT_NOTIFICATION_ID, builder.build())
        Log.d(TAG, "launchApp: alert notification posted")
    }

    // ── Persistent notification ──────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Low-priority persistent channel for the foreground service
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Wake Word Listener",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Listening for voice activation commands"
                setShowBadge(false)
            }

            // High-priority channel for the heads-up wake alert
            val alertChannel = NotificationChannel(
                ALERT_CHANNEL_ID,
                "Wake Word Alert",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Shown when wake word is detected"
                enableVibration(true)
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }

            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(serviceChannel)
            nm.createNotificationChannel(alertChannel)
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = packageManager
            .getLaunchIntentForPackage(packageName)
            ?.let {
                PendingIntent.getActivity(
                    this, 0, it,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
            }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("EverWith is listening")
            .setContentText("Say \"Hey Companion\" to activate")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(openIntent)
            .build()
    }
}
