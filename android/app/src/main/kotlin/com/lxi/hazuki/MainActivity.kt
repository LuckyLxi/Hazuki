package com.lxi.hazuki

import android.content.Intent
import android.os.Bundle
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

private const val SEARCH_SHORTCUT_URI = "hazuki://shortcut/search"

class MainActivity : FlutterFragmentActivity() {
    private lateinit var displayModeManager: DisplayModeManager
    private lateinit var privacyManager: PrivacyManager
    private lateinit var flutterChannels: MainActivityChannels

    private var isFirstLaunch = true
    private var wasInBackground = false
    private var pendingInitialLaunchAction: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterChannels = MainActivityChannels(
            activity = this,
            privacyManager = privacyManager,
            displayModeManager = displayModeManager
        )
        flutterChannels.register(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        applyLaunchThemeFromAppearance()
        pendingInitialLaunchAction = resolveLaunchAction(intent)
        super.onCreate(savedInstanceState)

        displayModeManager = DisplayModeManager(this)
        privacyManager = PrivacyManager(this)

        displayModeManager.applyHighRefreshRateMode()
        privacyManager.onActivityCreated()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val launchAction = resolveLaunchAction(intent) ?: return
        if (::flutterChannels.isInitialized) {
            flutterChannels.emitLaunchAction(launchAction)
            return
        }
        pendingInitialLaunchAction = launchAction
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (::flutterChannels.isInitialized && flutterChannels.handleReaderVolumeButtonKeyEvent(event)) {
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        if (::flutterChannels.isInitialized && flutterChannels.handleReaderVolumeButtonKeyEvent(event)) {
            return true
        }
        return super.onKeyUp(keyCode, event)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        privacyManager.applyRecentsBlackoutIfEnabled()
    }

    override fun onPause() {
        super.onPause()
        privacyManager.applyRecentsBlackoutIfEnabled()
    }

    override fun onStop() {
        super.onStop()
        wasInBackground = true
        privacyManager.markUnauthenticated()
    }

    override fun onResume() {
        super.onResume()
        privacyManager.onResume(
            isFirstLaunch = isFirstLaunch,
            wasInBackground = wasInBackground
        )
        isFirstLaunch = false
        wasInBackground = false
    }

    fun consumeInitialLaunchAction(): String? {
        val launchAction = pendingInitialLaunchAction
        pendingInitialLaunchAction = null
        return launchAction
    }

    private fun resolveLaunchAction(intent: Intent?): String? {
        val data = intent?.dataString ?: return null
        return when (data) {
            SEARCH_SHORTCUT_URI -> "search"
            else -> null
        }
    }
}
