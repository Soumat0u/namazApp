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

/** Oruç widget'ı: imsaka (sahur sonu) ya da iftara kalan süre. İmsak = Sabah, iftar = Akşam vakti. */
class OrucWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val hedef = WidgetVerisi.sonrakiOrucVakti(widgetData)
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.oruc_widget)
            v.setOnClickPendingIntent(R.id.widget_kok, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            if (hedef == null) {
                v.setTextViewText(R.id.oruc_baslik, "İFTAR • SAHUR")
                v.setTextViewText(R.id.oruc_saat, "--:--")
                v.setViewVisibility(R.id.oruc_geri_sayim, View.GONE)
            } else {
                val iftar = hedef.ad == "Akşam"
                v.setTextViewText(R.id.oruc_ikon, if (iftar) "🌙" else "🌅")
                v.setTextViewText(R.id.oruc_baslik, if (iftar) "İFTARA KALAN" else "İMSAKA KALAN")
                v.setTextViewText(R.id.oruc_saat, (if (iftar) "İftar " else "İmsak ") + hedef.saat)
                v.setViewVisibility(R.id.oruc_geri_sayim, View.VISIBLE)
                v.setChronometer(R.id.oruc_geri_sayim, SystemClock.elapsedRealtime() + (hedef.zaman - System.currentTimeMillis()), null, true)
                v.setChronometerCountDown(R.id.oruc_geri_sayim, true)
            }
            appWidgetManager.updateAppWidget(id, v)
        }
        WidgetVerisi.yenilemeKur(context, hedef?.zaman)
    }
}
