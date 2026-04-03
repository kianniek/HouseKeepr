package com.kianhamidi.housekeepr

import android.content.Context
import android.content.Intent
import android.widget.RemoteViewsService

/**
 * Service that provides the RemoteViewsFactory for the shopping list widget's ListView.
 */
class ShoppingListRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ShoppingListRemoteViewsFactory(applicationContext)
    }
}
