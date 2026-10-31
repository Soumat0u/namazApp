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

/** Geniş widget: bugünün 6 vakti; sıradaki altın çerçeveli, geçenler soluk, kılınanlar işaretli. */
class VakitlerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val bugun = WidgetVerisi.bugun(widgetData)
        val sonraki = WidgetVerisi.sonraki(widgetData)
        val kilinan = WidgetVerisi.kilinanlar(widgetData)
        val seri = WidgetVerisi.seri(widgetData)
        val kutular = listOf(R.id.kutu_0, R.id.kutu_1, R.id.kutu_2, R.id.kutu_3, R.id.kutu_4, R.id.kutu_5)
        val adlar = listOf(R.id.ad_0, R.id.ad_1, R.id.ad_2, R.id.ad_3, R.id.ad_4, R.id.ad_5)
        val saatler = listOf(R.id.saat_0, R.id.saat_1, R.id.saat_2, R.id.saat_3, R.id.saat_4, R.id.saat_5)
        val isaretler = listOf(R.id.isaret_0, R.id.isaret_1, R.id.isaret_2, R.id.isaret_3, R.id.isaret_4, R.id.isaret_5)
        val simdi = System.currentTimeMillis()
        val altin = Color.parseColor("#FFD54F")
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.vakitler_widget)
            v.setOnClickPendingIntent(R.id.widget_kok, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            bugun.forEachIndexed { i, vakit ->
                val siradaki = sonraki != null && sonraki.zaman == vakit.zaman
                val gecti = vakit.zaman in 1 until simdi
                val kilindi = vakit.ad in kilinan
                v.setTextViewText(adlar[i], vakit.ad)
                v.setTextViewText(saatler[i], vakit.saat)
                v.setInt(kutular[i], "setBackgroundResource", if (siradaki) R.drawable.widget_kutu_aktif else R.drawable.widget_kutu)
                v.setTextColor(adlar[i], if (siradaki) altin else Color.parseColor("#CCFFFFFF"))
                v.setTextColor(saatler[i], if (siradaki) altin else if (gecti) Color.parseColor("#99FFFFFF") else Color.WHITE)
                v.setTextViewText(isaretler[i], if (vakit.ad == "Güneş") "☀" else if (kilindi) "✓" else "○")
                v.setTextColor(isaretler[i], if (kilindi) Color.parseColor("#A5D6A7") else Color.parseColor("#66FFFFFF"))
            }
            if (sonraki == null) {
                v.setViewVisibility(R.id.widget_geri_sayim, View.GONE)
                v.setTextViewText(R.id.widget_baslik, "Vakitler için uygulamayı açın")
            } else {
                v.setViewVisibility(R.id.widget_geri_sayim, View.VISIBLE)
                v.setTextViewText(R.id.widget_baslik, "${sonraki.ad} vaktine kalan")
                v.setChronometer(R.id.widget_geri_sayim, SystemClock.elapsedRealtime() + (sonraki.zaman - simdi), null, true)
                v.setChronometerCountDown(R.id.widget_geri_sayim, true)
            }
            v.setTextViewText(R.id.widget_alt, "${kilinan.size}/5 kılındı" + if (seri > 0) "   •   🔥 $seri günlük seri" else "")
            appWidgetManager.updateAppWidget(id, v)
        }
        WidgetVerisi.yenilemeKur(context, sonraki?.zaman)
    }
}
