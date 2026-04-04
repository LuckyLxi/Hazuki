package com.lxi.hazuki.comics

import android.os.Build
import android.view.Display
import android.view.View
import android.view.WindowManager

class DisplayModeManager(
    private val activity: MainActivity,
) {
    private fun currentDisplay(): Display? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display
        } else {
            @Suppress("DEPRECATION")
            activity.windowManager.defaultDisplay
        }
    }

    private fun applyMode(mode: Display.Mode): Boolean {
        activity.window.attributes = activity.window.attributes.apply {
            preferredDisplayModeId = mode.modeId
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val decor = activity.window.decorView
            val targetRate = mode.refreshRate
            decor.post {
                try {
                    val method = View::class.java.getMethod(
                        "setFrameRate",
                        Float::class.javaPrimitiveType,
                        Int::class.javaPrimitiveType,
                    )
                    method.invoke(decor, targetRate, 0)
                } catch (_: Throwable) {
                }
            }
        }
        return true
    }

    fun getDisplayModes(): List<Map<String, Any>> {
        val display = currentDisplay() ?: return emptyList()
        val modes = display.supportedModes.toMutableList()
        modes.sortWith(
            compareByDescending<Display.Mode> { it.refreshRate }
                .thenByDescending { it.physicalWidth },
        )
        val activeId = display.mode.modeId
        val preferredId = activity.window.attributes.preferredDisplayModeId

        val result = mutableListOf<Map<String, Any>>()
        result.add(
            mapOf(
                "raw" to "native:auto",
                "label" to "自动",
                "refreshRate" to 0.0,
                "width" to 0,
                "height" to 0,
                "modeId" to 0,
                "isActive" to (preferredId == 0),
                "isPreferred" to (preferredId == 0),
            ),
        )
        for (mode in modes) {
            result.add(
                mapOf(
                    "raw" to "native:${mode.modeId}",
                    "label" to
                        "${mode.refreshRate.toInt()}Hz，${mode.physicalWidth}x${mode.physicalHeight}",
                    "refreshRate" to mode.refreshRate.toDouble(),
                    "width" to mode.physicalWidth,
                    "height" to mode.physicalHeight,
                    "modeId" to mode.modeId,
                    "isActive" to (mode.modeId == activeId),
                    "isPreferred" to (preferredId != 0 && mode.modeId == preferredId),
                ),
            )
        }
        return result
    }

    fun applyAutoDisplayMode() {
        activity.window.attributes = activity.window.attributes.apply {
            preferredDisplayModeId = 0
        }
    }

    fun applyDisplayModeRaw(raw: String?): Boolean {
        val value = raw ?: return false
        if (value == "native:auto") {
            applyAutoDisplayMode()
            return true
        }
        if (!value.startsWith("native:")) {
            return false
        }
        val modeId = value.removePrefix("native:").toIntOrNull() ?: return false
        val display = currentDisplay() ?: return false
        val mode = display.supportedModes.firstOrNull { it.modeId == modeId } ?: return false
        return applyMode(mode)
    }

    fun applyHighRefreshRateMode() {
        val display = currentDisplay() ?: return
        val mode = display.supportedModes.maxByOrNull { it.refreshRate } ?: return
        applyMode(mode)
    }

    fun setKeepScreenOnFlag(enabled: Boolean) {
        activity.runOnUiThread {
            if (enabled) {
                activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }

    fun setReaderBrightness(value: Double?): Boolean {
        return try {
            activity.runOnUiThread {
                val attrs = activity.window.attributes
                if (value == null) {
                    attrs.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                } else {
                    attrs.screenBrightness = value.toFloat().coerceIn(0.0f, 1.0f)
                }
                activity.window.attributes = attrs
            }
            true
        } catch (_: Throwable) {
            false
        }
    }
}
