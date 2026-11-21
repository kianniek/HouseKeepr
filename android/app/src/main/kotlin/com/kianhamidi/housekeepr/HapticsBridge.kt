package com.kianhamidi.housekeepr

import android.app.Activity
import android.os.Build
import android.view.HapticFeedbackConstants
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object HapticsBridge {
    const val CHANNEL_NAME = "housekeepr/haptics"

    fun onMethodCall(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "perform") {
            result.notImplemented()
            return
        }

        val type = call.argument<String>("type") ?: "tick"
        val constant = mapTypeToConstant(type)
        val decorView = activity.window?.decorView
        val performed = decorView?.performHapticFeedback(constant) ?: false
        result.success(performed)
    }

    private fun mapTypeToConstant(type: String): Int = when (type) {
        "confirm" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            HapticFeedbackConstants.CONFIRM
        } else {
            HapticFeedbackConstants.VIRTUAL_KEY
        }
        "reject" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            HapticFeedbackConstants.REJECT
        } else {
            HapticFeedbackConstants.LONG_PRESS
        }
        "toggleOn" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            HapticFeedbackConstants.TOGGLE_ON
        } else {
            HapticFeedbackConstants.CLOCK_TICK
        }
        "toggleOff" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            HapticFeedbackConstants.TOGGLE_OFF
        } else {
            HapticFeedbackConstants.CLOCK_TICK
        }
        "segmentTick" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            HapticFeedbackConstants.SEGMENT_TICK
        } else {
            HapticFeedbackConstants.CLOCK_TICK
        }
        "gestureStart" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            HapticFeedbackConstants.GESTURE_START
        } else {
            HapticFeedbackConstants.KEYBOARD_TAP
        }
        "gestureEnd" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            HapticFeedbackConstants.GESTURE_END
        } else {
            HapticFeedbackConstants.KEYBOARD_TAP
        }
        "longPress" -> HapticFeedbackConstants.LONG_PRESS
        else -> HapticFeedbackConstants.CLOCK_TICK
    }
}
