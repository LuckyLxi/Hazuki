package com.lxi.hazuki

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.core.content.edit
import androidx.core.graphics.drawable.toDrawable
import kotlin.system.exitProcess

class PrivacyManager(
    private val activity: MainActivity,
) {
    private val blackBackgroundDrawable = Color.BLACK.toDrawable()
    private var blurView: View? = null
    private var temporarySecureAppliedForRecents = false
    private var isAuthenticating = false
    private var isAuthenticated = false

    fun privacySettings(): Map<String, Boolean> {
        val prefs = activity.getSharedPreferences("hazuki_privacy", Context.MODE_PRIVATE)
        return mapOf(
            "blurBackground" to prefs.getBoolean("blurBackground", false),
            "biometricAuth" to prefs.getBoolean("biometricAuth", false),
            "authOnResume" to prefs.getBoolean("authOnResume", false),
            "passwordLockEnabled" to prefs.getBoolean("passwordLockEnabled", false),
        )
    }

    fun setBlurBackground(enabled: Boolean) {
        val prefs = activity.getSharedPreferences("hazuki_privacy", Context.MODE_PRIVATE)
        prefs.edit { putBoolean("blurBackground", enabled) }
        applyRecentsScreenshotPolicy()
        applySecureFlag()
        if (!enabled) {
            restoreWindowBackground()
            blurView?.visibility = View.GONE
            temporarySecureAppliedForRecents = false
        }
    }

    fun setBiometricAuth(enabled: Boolean) {
        val prefs = activity.getSharedPreferences("hazuki_privacy", Context.MODE_PRIVATE)
        prefs.edit { putBoolean("biometricAuth", enabled) }
    }

    fun setAuthOnResume(enabled: Boolean) {
        val prefs = activity.getSharedPreferences("hazuki_privacy", Context.MODE_PRIVATE)
        prefs.edit { putBoolean("authOnResume", enabled) }
    }

    fun setPasswordLockEnabled(enabled: Boolean) {
        val prefs = activity.getSharedPreferences("hazuki_privacy", Context.MODE_PRIVATE)
        prefs.edit { putBoolean("passwordLockEnabled", enabled) }
    }

    fun requireAuthCheck(): Boolean {
        val prefs = activity.getSharedPreferences("hazuki_privacy", Context.MODE_PRIVATE)
        return prefs.getBoolean("biometricAuth", false)
    }

    fun onActivityCreated() {
        applyRecentsScreenshotPolicy()
        applySecureFlag()
        initBlurView()

        val prefs = activity.getSharedPreferences("hazuki_privacy", Context.MODE_PRIVATE)
        if (prefs.getBoolean("biometricAuth", false) &&
            !prefs.getBoolean("passwordLockEnabled", false)
        ) {
            blurView?.visibility = View.VISIBLE
        }
    }

    fun markUnauthenticated() {
        isAuthenticated = false
    }

    fun applyRecentsBlackoutIfEnabled() {
        val prefs = activity.getSharedPreferences("hazuki_privacy", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("blurBackground", false)) {
            return
        }
        forceBlackWindowBackground()
        blurView?.visibility = View.VISIBLE
        temporarySecureAppliedForRecents = true
        applySecureFlag()
    }

    fun onResume(isFirstLaunch: Boolean, wasInBackground: Boolean) {
        if (temporarySecureAppliedForRecents) {
            temporarySecureAppliedForRecents = false
        }
        restoreWindowBackground()
        applySecureFlag()

        val prefs = activity.getSharedPreferences("hazuki_privacy", Context.MODE_PRIVATE)
        val biometricAuth = prefs.getBoolean("biometricAuth", false)
        val authOnResume = prefs.getBoolean("authOnResume", false)
        val passwordLockEnabled = prefs.getBoolean("passwordLockEnabled", false)
        val needsAuth =
            biometricAuth &&
                !passwordLockEnabled &&
                (isFirstLaunch || (authOnResume && wasInBackground))

        if (needsAuth) {
            blurView?.visibility = View.VISIBLE
            if (!isAuthenticated && !isAuthenticating) {
                activity.window.decorView.post {
                    if (!activity.isFinishing) {
                        authenticate(null, requireAuth = true)
                    }
                }
            }
        } else if (!isAuthenticating && blurView?.visibility == View.VISIBLE) {
            blurView?.visibility = View.GONE
        }
    }

    fun authenticate(flutterResult: io.flutter.plugin.common.MethodChannel.Result?, requireAuth: Boolean) {
        if (isAuthenticating) {
            return
        }
        isAuthenticating = true

        val executor = ContextCompat.getMainExecutor(activity)
        val biometricPrompt = BiometricPrompt(
            activity,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    isAuthenticating = false
                    if (requireAuth) {
                        activity.finishAffinity()
                        exitProcess(0)
                    } else {
                        flutterResult?.success(false)
                    }
                }

                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    super.onAuthenticationSucceeded(result)
                    isAuthenticating = false
                    isAuthenticated = true
                    blurView?.visibility = View.GONE
                    flutterResult?.success(true)
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    isAuthenticating = false
                    if (requireAuth) {
                        activity.finishAffinity()
                        exitProcess(0)
                    } else {
                        flutterResult?.success(false)
                    }
                }
            },
        )

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("安全访问保护")
            .setSubtitle("请完成指纹或面容认证以进入 Hazuki")
            .setNegativeButtonText(if (requireAuth) "退出应用" else "取消")
            .setConfirmationRequired(false)
            .build()

        biometricPrompt.authenticate(promptInfo)
    }

    private fun initBlurView() {
        if (blurView != null) {
            return
        }
        blurView = View(activity).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            setBackgroundColor(Color.BLACK)
            visibility = View.GONE
            z = 10000f
            elevation = 10000f
            setOnClickListener {
                val prefs =
                    activity.getSharedPreferences("hazuki_privacy", Context.MODE_PRIVATE)
                if (prefs.getBoolean("biometricAuth", false) &&
                    !prefs.getBoolean("passwordLockEnabled", false) &&
                    !isAuthenticated &&
                    !isAuthenticating
                ) {
                    authenticate(null, requireAuth = true)
                }
            }
        }
        val decorView = activity.window.decorView as ViewGroup
        decorView.addView(blurView)
    }

    private fun applySecureFlag() {
        val shouldSecure = temporarySecureAppliedForRecents
        if (shouldSecure) {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    private fun applyRecentsScreenshotPolicy() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            val prefs = activity.getSharedPreferences("hazuki_privacy", Context.MODE_PRIVATE)
            activity.setRecentsScreenshotEnabled(!prefs.getBoolean("blurBackground", false))
        }
    }

    private fun forceBlackWindowBackground() {
        activity.window.setBackgroundDrawable(blackBackgroundDrawable)
        activity.window.decorView.setBackgroundColor(Color.BLACK)
    }

    private fun restoreWindowBackground() {
        activity.window.setBackgroundDrawable(null)
        activity.window.decorView.setBackgroundColor(Color.TRANSPARENT)
    }
}
