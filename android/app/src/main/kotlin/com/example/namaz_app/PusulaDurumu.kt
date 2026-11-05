package com.example.namaz_app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.EventChannel
import kotlin.math.sqrt

/**
 * lib/services/pusula_kalibrasyonu.dart için manyetometrenin kalibrasyon
 * durumu ve ölçtüğü alan şiddeti.
 *
 * flutter_compass_v2 "güvenilmez" (kalibrasyon bozuk) durumunu "bilinmiyor"
 * ile aynı değere çevirdiği için durum doğrudan buradan okunur. Her olay
 * {"durum": 0..3 (SENSOR_STATUS_*), "siddet": µT} gönderir.
 */
class PusulaDurumu(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val manyetometre: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
    private var sink: EventChannel.EventSink? = null
    private var sonGonderim = 0L
    private var sonDurum = -1

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        sonDurum = -1
        if (manyetometre == null) {
            events?.error("sensor_yok", "Manyetometre yok", null)
            return
        }
        sensorManager.registerListener(this, manyetometre, SensorManager.SENSOR_DELAY_UI)
    }

    override fun onCancel(arguments: Any?) {
        sensorManager.unregisterListener(this)
        sink = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        val now = System.currentTimeMillis()
        // Durum değişince hemen, yoksa saniyede ~5 kez
        if (event.accuracy == sonDurum && now - sonGonderim < 200) return
        sonGonderim = now
        sonDurum = event.accuracy
        val (x, y, z) = Triple(event.values[0], event.values[1], event.values[2])
        sink?.success(mapOf("durum" to event.accuracy, "siddet" to sqrt(x * x + y * y + z * z).toDouble()))
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {
        // Bir sonraki onSensorChanged olayı yeni durumu taşır
    }
}
