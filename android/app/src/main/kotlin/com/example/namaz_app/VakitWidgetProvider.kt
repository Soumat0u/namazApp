package com.example.namaz_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.util.Calendar

/**
 * Ana ekran widget'ı: sıradaki vakit, saati ve geri sayım.
 * Uygulama bugünün ve yarının vakitlerini kaydeder; sıradaki vakit burada hesaplanır,
 * böylece uygulama açılmasa da widget doğru kalır. Vakit değişince kendini yeniden günceller.
 */
class VakitWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val sonraki = sonrakiVakit(widgetData)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.vakit_widget)
            val acIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widget_kok, acIntent)

            if (sonraki == null) {
                views.setTextViewText(R.id.widget_vakit, "Takva Yolum")
                views.setTextViewText(R.id.widget_saat, "Vakitler için uygulamayı açın")
                views.setViewVisibility(R.id.widget_geri_sayim, View.GONE)
            } else {
                views.setTextViewText(R.id.widget_vakit, "Sıradaki: ${sonraki.ad}")
                views.setTextViewText(R.id.widget_saat, sonraki.saat)
                views.setViewVisibility(R.id.widget_geri_sayim, View.VISIBLE)
                val kalanMs = sonraki.zaman - System.currentTimeMillis()
                views.setChronometer(R.id.widget_geri_sayim, SystemClock.elapsedRealtime() + kalanMs, null, true)
                views.setChronometerCountDown(R.id.widget_geri_sayim, true)
            }
            val bilgi = widgetData.getString("widget_alt_bilgi", "") ?: ""
            views.setTextViewText(R.id.widget_alt, bilgi)
            appWidgetManager.updateAppWidget(id, views)
        }
        if (sonraki != null) yenilemeKur(context, sonraki.zaman + 1000)
    }

    private data class Vakit(val ad: String, val saat: String, val zaman: Long)

    private fun sonrakiVakit(prefs: SharedPreferences): Vakit? {
        val ham = prefs.getString("widget_vakitler", null) ?: return null
        return try {
            val gunler = JSONObject(ham) // "yyyy-MM-dd" -> { "Sabah": "05:30", ... }
            val simdi = System.currentTimeMillis()
            val sira = listOf("Sabah", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı")
            val anahtarlar = gunler.keys().asSequence().sorted().toList()
            for (gun in anahtarlar) {
                val v = gunler.getJSONObject(gun)
                val p = gun.split("-").map { it.toInt() }
                for (ad in sira) {
                    val s = v.optString(ad, "")
                    if (s.isEmpty()) continue
                    val hm = s.split(" ")[0].split(":").map { it.toInt() }
                    val cal = Calendar.getInstance().apply {
                        set(p[0], p[1] - 1, p[2], hm[0], hm[1], 0)
                        set(Calendar.MILLISECOND, 0)
                    }
                    if (cal.timeInMillis > simdi) return Vakit(ad, s.split(" ")[0], cal.timeInMillis)
                }
            }
            null
        } catch (e: Exception) {
            null
        }
    }

    /** Sıradaki vakit girince widget'ı yeniden hesaplat */
    private fun yenilemeKur(context: Context, zaman: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val ids = AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, VakitWidgetProvider::class.java))
        val intent = Intent(context, VakitWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        val pi = PendingIntent.getBroadcast(
            context, 4242, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        // Tam alarm izni gerekmeyen, uyku modunda da çalışan yaklaşık alarm yeterli
        am.setAndAllowWhileIdle(AlarmManager.RTC, zaman, pi)
    }
}
