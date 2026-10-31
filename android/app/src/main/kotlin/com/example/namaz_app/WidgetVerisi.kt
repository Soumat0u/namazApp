package com.example.namaz_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/** Widget'ların ortak verisi: uygulamanın kaydettiği vakitlerden sıradaki vakti ve bugünkü tabloyu çıkarır. */
object WidgetVerisi {
    val SIRA = listOf("Sabah", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı")
    val NAMAZLAR = listOf("Sabah", "Öğle", "İkindi", "Akşam", "Yatsı")

    data class Vakit(val ad: String, val saat: String, val zaman: Long)

    private fun gunAnahtari(cal: Calendar) = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(cal.time)
    private fun bugunAnahtari() = gunAnahtari(Calendar.getInstance())
    private fun dunAnahtari() = gunAnahtari(Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -1) })

    private fun json(prefs: SharedPreferences, ad: String): JSONObject? =
        prefs.getString(ad, null)?.let { try { JSONObject(it) } catch (e: Exception) { null } }

    private fun zaman(gun: String, saat: String): Long {
        val p = gun.split("-").map { it.toInt() }
        val hm = saat.split(" ")[0].split(":").map { it.toInt() }
        return Calendar.getInstance().apply {
            set(p[0], p[1] - 1, p[2], hm[0], hm[1], 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    fun sonraki(prefs: SharedPreferences): Vakit? {
        val gunler = json(prefs, "widget_vakitler") ?: return null
        val simdi = System.currentTimeMillis()
        return try {
            for (gun in gunler.keys().asSequence().sorted()) {
                val v = gunler.getJSONObject(gun)
                for (ad in SIRA) {
                    val s = v.optString(ad, "")
                    if (s.isEmpty()) continue
                    val z = zaman(gun, s)
                    if (z > simdi) return Vakit(ad, s.split(" ")[0], z)
                }
            }
            null
        } catch (e: Exception) { null }
    }

    /** Bugünün 6 vakti (saat yoksa "--:--") */
    fun bugun(prefs: SharedPreferences): List<Vakit> {
        val gun = bugunAnahtari()
        val v = json(prefs, "widget_vakitler")?.optJSONObject(gun)
        return SIRA.map { ad ->
            val s = v?.optString(ad, "") ?: ""
            if (s.isEmpty()) Vakit(ad, "--:--", 0) else Vakit(ad, s.split(" ")[0], zaman(gun, s))
        }
    }

    /** Bugün kılınan vakitler; kayıt dünden kalmışsa gece yarısından sonra boş sayılır */
    fun kilinanlar(prefs: SharedPreferences): Set<String> {
        if (prefs.getString("widget_kilinan_gun", "") != bugunAnahtari()) return emptySet()
        val j = json(prefs, "widget_kilinan") ?: return emptySet()
        return NAMAZLAR.filter { j.optBoolean(it, false) }.toSet()
    }

    /** Seri: dün ya da bugün güncellendiyse geçerli */
    fun seri(prefs: SharedPreferences): Int {
        val gun = prefs.getString("widget_kilinan_gun", "")
        if (gun != bugunAnahtari() && gun != dunAnahtari()) return 0
        return prefs.all["widget_seri"]?.toString()?.toIntOrNull() ?: 0
    }

    /** Vakit girince (en geç gece yarısı) bütün widget'ları yeniden çizdir */
    fun yenilemeKur(context: Context, sonraki: Long?) {
        val gece = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 5)
        }.timeInMillis
        val zaman = minOf(sonraki?.plus(1000) ?: gece, gece)
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(
            context, 4242, Intent(context, WidgetYenileyici::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        // Tam alarm izni gerekmeyen, uyku modunda da çalışan yaklaşık alarm yeterli
        am.setAndAllowWhileIdle(AlarmManager.RTC, zaman, pi)
    }

    fun hepsiniGuncelle(context: Context) {
        val m = AppWidgetManager.getInstance(context)
        for (c in listOf(VakitWidgetProvider::class.java, VakitlerWidgetProvider::class.java, AyetWidgetProvider::class.java)) {
            val ids = m.getAppWidgetIds(ComponentName(context, c))
            if (ids.isEmpty()) continue
            context.sendBroadcast(Intent(context, c).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            })
        }
    }
}

/** Alarm alıcısı: bütün widget türlerini tazeler */
class WidgetYenileyici : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = WidgetVerisi.hepsiniGuncelle(context)
}
