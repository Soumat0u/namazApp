package com.example.namaz_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Günün ayeti widget'ı: meal ve kaynak; dokununca uygulama açılır. */
class AyetWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val meal = widgetData.getString("widget_ayet_meal", "") ?: ""
        val ref = widgetData.getString("widget_ayet_ref", "") ?: ""
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.ayet_widget)
            v.setOnClickPendingIntent(R.id.widget_kok, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            v.setTextViewText(R.id.ayet_meal, if (meal.isEmpty()) "Günün ayeti için uygulamayı açın." else "“$meal”")
            v.setTextViewText(R.id.ayet_ref, ref)
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
