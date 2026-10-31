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

/** Namaz takibi: günlük seri ve bugünkü 5 vaktin kılınma durumu. */
class TakipWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val kilinan = WidgetVerisi.kilinanlar(widgetData)
        val seri = WidgetVerisi.seri(widgetData)
        val daireler = listOf(R.id.daire_0, R.id.daire_1, R.id.daire_2, R.id.daire_3, R.id.daire_4)
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.takip_widget)
            v.setOnClickPendingIntent(R.id.widget_kok, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            v.setTextViewText(R.id.takip_seri, "$seri")
            v.setTextViewText(R.id.takip_durum, when (kilinan.size) {
                5 -> "Bugün tamam, maşallah!"
                0 -> "Bugün henüz kılınmadı"
                else -> "Bugün ${kilinan.size}/5 kılındı"
            })
            WidgetVerisi.NAMAZLAR.forEachIndexed { i, ad ->
                val k = ad in kilinan
                v.setTextViewText(daireler[i], if (k) "✓" else ad.take(1))
                v.setInt(daireler[i], "setBackgroundResource", if (k) R.drawable.widget_daire_dolu else R.drawable.widget_daire_bos)
                v.setTextColor(daireler[i], if (k) Color.parseColor("#0B3D2E") else Color.parseColor("#CCFFFFFF"))
            }
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
