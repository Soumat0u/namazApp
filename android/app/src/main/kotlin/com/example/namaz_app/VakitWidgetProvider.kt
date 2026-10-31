package com.example.namaz_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Locale

/** Küçük widget: sıradaki vakit, saati, geri sayım ve bugünkü 5 vaktin durumu (altın nokta = kılındı). */
class VakitWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val sonraki = WidgetVerisi.sonraki(widgetData)
        val kilinan = WidgetVerisi.kilinanlar(widgetData)
        val seri = WidgetVerisi.seri(widgetData)
        val noktalar = listOf(R.id.nokta_0, R.id.nokta_1, R.id.nokta_2, R.id.nokta_3, R.id.nokta_4)
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.vakit_widget)
            v.setOnClickPendingIntent(R.id.widget_kok, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            if (sonraki == null) {
                v.setTextViewText(R.id.widget_vakit, "TAKVA YOLUM")
                v.setTextViewText(R.id.widget_saat, "--:--")
                v.setViewVisibility(R.id.widget_geri_sayim, View.GONE)
            } else {
                v.setTextViewText(R.id.widget_vakit, sonraki.ad.uppercase(Locale("tr")))
                v.setTextViewText(R.id.widget_saat, sonraki.saat)
                v.setViewVisibility(R.id.widget_geri_sayim, View.VISIBLE)
                v.setChronometer(R.id.widget_geri_sayim, SystemClock.elapsedRealtime() + (sonraki.zaman - System.currentTimeMillis()), null, true)
                v.setChronometerCountDown(R.id.widget_geri_sayim, true)
            }
            WidgetVerisi.NAMAZLAR.forEachIndexed { i, ad ->
                v.setImageViewResource(noktalar[i], if (ad in kilinan) R.drawable.widget_nokta_dolu else R.drawable.widget_nokta_bos)
            }
            v.setTextViewText(R.id.widget_alt, if (seri > 0) "🔥 $seri" else "${kilinan.size}/5")
            appWidgetManager.updateAppWidget(id, v)
        }
        WidgetVerisi.yenilemeKur(context, sonraki?.zaman)
    }
}
