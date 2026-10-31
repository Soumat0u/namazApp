package com.example.namaz_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Zikirmatik: widget'a dokundukça sayar, 33'te bir tur tamamlanır. Uygulama açılmadan çalışır;
 * sayaç telefonda widget'ın kendi kaydında tutulur.
 */
class ZikirWidgetProvider : android.appwidget.AppWidgetProvider() {
    companion object {
        private const val ARTIR = "com.example.namaz_app.ZIKIR_ARTIR"
        private const val SIFIRLA = "com.example.namaz_app.ZIKIR_SIFIRLA"
        private const val HEDEF = 33
        private val ZIKIRLER = listOf("Sübhânallah", "Elhamdülillah", "Allâhu Ekber")
    }

    private fun prefs(c: Context) = c.getSharedPreferences("zikir_widget", Context.MODE_PRIVATE)

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ARTIR -> prefs(context).edit().putInt("sayi", prefs(context).getInt("sayi", 0) + 1).apply()
            SIFIRLA -> prefs(context).edit().putInt("sayi", 0).apply()
            else -> return super.onReceive(context, intent)
        }
        val m = AppWidgetManager.getInstance(context)
        onUpdate(context, m, m.getAppWidgetIds(ComponentName(context, ZikirWidgetProvider::class.java)))
    }

    private fun yayin(c: Context, eylem: String, kod: Int) = PendingIntent.getBroadcast(
        c, kod, Intent(c, ZikirWidgetProvider::class.java).setAction(eylem),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val sayi = prefs(context).getInt("sayi", 0)
        val tur = sayi / HEDEF
        val turdaki = sayi % HEDEF
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.zikir_widget)
            v.setOnClickPendingIntent(R.id.widget_kok, yayin(context, ARTIR, 7001))
            v.setOnClickPendingIntent(R.id.zikir_sifirla, yayin(context, SIFIRLA, 7002))
            v.setTextViewText(R.id.zikir_sayi, "$turdaki")
            v.setTextViewText(R.id.zikir_ad, ZIKIRLER[tur % ZIKIRLER.size])
            v.setProgressBar(R.id.zikir_ilerleme, HEDEF, turdaki, false)
            v.setTextViewText(R.id.zikir_toplam, if (sayi == 0) "Saymak için dokun" else "Toplam $sayi • $tur tur")
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
