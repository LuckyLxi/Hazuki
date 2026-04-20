package com.lxi.hazuki

import android.content.Context
import android.content.res.Configuration

private const val APPEARANCE_PREFS = "FlutterSharedPreferences"
private const val THEME_MODE_KEY = "flutter.appearance_theme_mode"
private const val OLED_PURE_BLACK_KEY = "flutter.appearance_oled_pure_black"

fun MainActivity.applyLaunchThemeFromAppearance() {
    val prefs = getSharedPreferences(APPEARANCE_PREFS, Context.MODE_PRIVATE)
    val modeRaw = prefs.getString(THEME_MODE_KEY, "system") ?: "system"
    val oledPureBlack = prefs.getBoolean(OLED_PURE_BLACK_KEY, false)

    val themeRes = when (modeRaw) {
        "light" -> R.style.LaunchTheme_Light
        "dark" -> if (oledPureBlack) R.style.LaunchTheme_Oled else R.style.LaunchTheme_Dark
        else -> {
            val isSystemDark =
                (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                    Configuration.UI_MODE_NIGHT_YES
            if (isSystemDark) {
                if (oledPureBlack) R.style.LaunchTheme_Oled else R.style.LaunchTheme_Dark
            } else {
                R.style.LaunchTheme_Light
            }
        }
    }
    setTheme(themeRes)
}
