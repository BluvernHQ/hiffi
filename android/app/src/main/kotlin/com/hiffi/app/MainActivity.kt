package com.hiffi.app

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.hiffi.app/pip"

    // Whether a video is actively playing – set from Flutter side.
    private var isPlayerActive = false

    // Cached MethodChannel for pushing events back to Flutter.
    private var pipChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        pipChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "updatePlayerStatus" -> {
                    isPlayerActive = call.arguments as Boolean
                    // On Android 12+ keep the PiP params live so the OS can
                    // auto-enter PiP on Home press without a round-trip.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        updatePipParams()
                    }
                    result.success(null)
                }
                "enterPiP" -> {
                    enterPipIfNeeded()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // Builds PiP params with 16:9 aspect ratio.
    private fun buildPipParams(): PictureInPictureParams {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                // Auto-enter on Android 12+ so onUserLeaveHint is not needed.
                .setAutoEnterEnabled(isPlayerActive)
                .build()
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
        } else {
            // Should never reach here but satisfies the compiler.
            PictureInPictureParams.Builder().build()
        }
    }

    // Keeps the system-level PiP params fresh so auto-enter works.
    private fun updatePipParams() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                setPictureInPictureParams(buildPipParams())
            } catch (e: Exception) {
                // Ignore – device may not support PiP.
            }
        }
    }

    private fun enterPipIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !isInPictureInPictureMode) {
            try {
                enterPictureInPictureMode(buildPipParams())
            } catch (e: Exception) {
                // Device might not support PiP or aspect ratio is invalid.
            }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration?
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        // Tell Flutter so it can update UI accordingly.
        pipChannel?.invokeMethod("onPictureInPictureModeChanged", isInPictureInPictureMode)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Fallback for Android < 12 where autoEnterEnabled is not available.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S && isPlayerActive) {
            enterPipIfNeeded()
        }
    }
}
