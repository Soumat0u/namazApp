package com.example.namaz_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Yaklaşan dini günler: ilki büyük geri sayımla, sonraki ikisi altta. */
class DiniGunWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val gunler = WidgetVerisi.diniGunler(widgetData)
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.dini_gun_widget)
            v.setOnClickPendingIntent(R.id.widget_kok, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            val ilk = gunler.firstOrNull()
            if (ilk == null) {
                v.setTextViewText(R.id.dini_ad, "Dini günler için uygulamayı açın")
                v.setTextViewText(R.id.dini_kalan, "")
                v.setTextViewText(R.id.dini_tarih, "")
            } else {
                v.setTextViewText(R.id.dini_ad, ilk.ad)
                v.setTextViewText(R.id.dini_kalan, if (ilk.kalan == 0) "Bugün" else if (ilk.kalan == 1) "Yarın" else "${ilk.kalan} gün")
                v.setTextViewText(R.id.dini_tarih, ilk.tarih)
            }
            val sonraki = gunler.drop(1).take(2).joinToString("   •   ") { "${it.ad} (${it.kalan} gün)" }
            v.setTextViewText(R.id.dini_sonraki, sonraki)
            v.setViewVisibility(R.id.dini_sonraki, if (sonraki.isEmpty()) View.GONE else View.VISIBLE)
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
