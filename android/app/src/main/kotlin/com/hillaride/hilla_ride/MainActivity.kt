package com.hillaride.hilla_ride

import android.content.Context
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import java.util.Locale

class MainActivity : FlutterActivity() {
    override fun attachBaseContext(newBase: Context) {
        val locale = Locale.forLanguageTag("ar-IQ")
        Locale.setDefault(locale)
        val config = newBase.resources.configuration
        config.setLocale(locale)
        super.attachBaseContext(newBase.createConfigurationContext(config))
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
}
