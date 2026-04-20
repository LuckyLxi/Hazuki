package com.lxi.hazuki

import android.os.Bundle
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private lateinit var displayModeManager: DisplayModeManager
    private lateinit var privacyManager: PrivacyManager
    private lateinit var flutterChannels: MainActivityChannels

    private var isFirstLaunch = true
    private var wasInBackground = false

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
        super.onCreate(savedInstanceState)

        displayModeManager = DisplayModeManager(this)
        privacyManager = PrivacyManager(this)

        displayModeManager.applyHighRefreshRateMode()
        privacyManager.onActivityCreated()
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
}
