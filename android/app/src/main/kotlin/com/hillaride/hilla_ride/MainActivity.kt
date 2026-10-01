package com.hillaride.hilla_ride

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var alarmPlayer: MediaPlayer? = null

    override fun attachBaseContext(newBase: Context) {
        val locale = Locale.forLanguageTag("ar-IQ")
        Locale.setDefault(locale)
        val config = newBase.resources.configuration
        config.setLocale(locale)
        super.attachBaseContext(newBase.createConfigurationContext(config))
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hilla_ride/ride_alert")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playLoudAlarm" -> {
                        val tone = call.argument<String>("tone") ?: "tone1"
                        val volume = call.argument<Double>("volume") ?: 1.0
                        playLoudAlarm(tone, volume.toFloat())
                        result.success(null)
                    }
                    "stopLoudAlarm" -> {
                        stopLoudAlarm()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            Settings.Secure.putInt(
                contentResolver,
                "show_ime_with_hard_keyboard",
                1,
            )
        } catch (_: Exception) {
        }
    }

    private fun playLoudAlarm(tone: String, volume: Float) {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val level = volume.coerceIn(0.2f, 1f)
        raiseStream(audioManager, AudioManager.STREAM_ALARM, level)
        raiseStream(audioManager, AudioManager.STREAM_NOTIFICATION, level)
        raiseStream(audioManager, AudioManager.STREAM_RING, level)
        stopLoudAlarm()
        val soundName = if (tone == "tone2") "ride_alert_chord" else "ride_alert_loud"
        val resId = resources.getIdentifier(soundName, "raw", packageName)
        if (resId == 0) return
        val player = MediaPlayer()
        player.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        val descriptor = resources.openRawResourceFd(resId)
        player.setDataSource(descriptor.fileDescriptor, descriptor.startOffset, descriptor.length)
        descriptor.close()
        player.isLooping = true
        player.setVolume(level, level)
        player.prepare()
        player.start()
        alarmPlayer = player
    }

    private fun stopLoudAlarm() {
        val player = alarmPlayer ?: return
        alarmPlayer = null
        try {
            if (player.isPlaying) player.stop()
        } catch (_: Exception) {
        }
        player.release()
    }

    private fun raiseStream(audioManager: AudioManager, stream: Int, level: Float) {
        try {
            val max = audioManager.getStreamMaxVolume(stream)
            if (max <= 0) return
            val target = (max * level).toInt().coerceAtLeast(1)
            audioManager.setStreamVolume(stream, target, 0)
        } catch (_: Exception) {
        }
    }
}
