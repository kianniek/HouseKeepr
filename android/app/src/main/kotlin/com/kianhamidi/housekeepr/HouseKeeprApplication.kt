package com.kianhamidi.housekeepr

import android.content.Context
import com.google.android.play.core.splitcompat.SplitCompat
import io.flutter.FlutterInjector
import io.flutter.app.FlutterApplication

class HouseKeeprApplication : FlutterApplication() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        SplitCompat.install(this)
    }

    override fun onCreate() {
        val deferredManager = FeatureDeliveryDeferredComponentManager(this, null)
        FlutterInjector.setInstance(
            FlutterInjector.Builder()
                .setDeferredComponentManager(deferredManager)
                .build()
        )
        super.onCreate()
    }
}
