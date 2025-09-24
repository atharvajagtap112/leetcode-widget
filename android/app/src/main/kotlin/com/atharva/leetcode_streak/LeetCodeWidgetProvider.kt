package com.atharva.leetcode_streak

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import com.atharva.leetcode_streak.R
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class LeetCodeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            val imagePath = widgetData.getString("filename", null)
            if (imagePath != null) {
                views.setImageViewBitmap(R.id.widget_image, BitmapFactory.decodeFile(imagePath))
            } else {
                // Optionally show a placeholder if you add one:
                // views.setImageViewResource(R.id.widget_image, R.drawable.widget_placeholder)
            }

            val clickIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,                // your Flutter activity
                 Uri.parse("homewidget://refresh") 
               
            )
                 views.setOnClickPendingIntent(R.id.widget_root, clickIntent)
            views.setOnClickPendingIntent(R.id.widget_image, clickIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}