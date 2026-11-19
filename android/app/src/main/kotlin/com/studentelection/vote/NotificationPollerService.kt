package com.studentelection.vote

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

/**
 * Lightweight background poller that checks `/student/overview` while the
 * student is signed in and posts local notifications when an election opens
 * or results are published.
 */
class NotificationPollerService : Service() {
    companion object {
        private const val ACTION_START = "com.studentelection.vote.NOTIFY_START"
        private const val ACTION_STOP = "com.studentelection.vote.NOTIFY_STOP"
        private const val EXTRA_TOKEN = "token"
        private const val EXTRA_API_BASE = "apiBase"
        private const val CHANNEL_ID = "elections"
        private const val PREFS = "election_notify_state"

        fun start(context: Context, token: String, apiBase: String) {
            if (token.isBlank() || apiBase.isBlank()) return
            val intent = Intent(context, NotificationPollerService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TOKEN, token)
                putExtra(EXTRA_API_BASE, apiBase)
            }
            context.startService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, NotificationPollerService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private val executor = Executors.newSingleThreadScheduledExecutor()
    private var task: ScheduledFuture<*>? = null
    private var token: String = ""
    private var apiBase: String = ""

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                task?.cancel(true)
                task = null
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                token = intent.getStringExtra(EXTRA_TOKEN).orEmpty()
                apiBase = intent.getStringExtra(EXTRA_API_BASE).orEmpty().trimEnd('/')
                ensureChannel()
                task?.cancel(true)
                task = executor.scheduleWithFixedDelay(
                    { pollOnce() },
                    5,
                    60,
                    TimeUnit.SECONDS
                )
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        task?.cancel(true)
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    getString(R.string.notif_channel_elections),
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = getString(R.string.notif_channel_elections_desc)
                }
                nm.createNotificationChannel(channel)
            }
        }
    }

    private fun pollOnce() {
        if (token.isBlank() || apiBase.isBlank()) return
        try {
            val conn = (URL("$apiBase/student/overview").openConnection() as HttpURLConnection).apply {
                connectTimeout = 10_000
                readTimeout = 10_000
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Accept", "application/json")
            }
            val code = conn.responseCode
            if (code !in 200..299) return
            val body = conn.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(body)
            val elections = json.optJSONArray("elections") ?: return
            val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            for (i in 0 until elections.length()) {
                val e = elections.optJSONObject(i) ?: continue
                val id = e.optString("id")
                val status = e.optString("status")
                val title = e.optString("title")
                if (id.isBlank() || status.isBlank()) continue
                val prev = prefs.getString("status_$id", null)
                if (prev != status && (status == "ACTIVE" || status == "PUBLISHED")) {
                    val text = if (status == "ACTIVE") "Voting is now open." else "Results have been published."
                    postNotification(id.hashCode(), title, text)
                }
                prefs.edit().putString("status_$id", status).apply()
            }
        } catch (_: Throwable) {
            // Network errors are transient; retry on the next tick.
        }
    }

    private fun postNotification(id: Int, title: String, text: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pending = if (launch != null) {
            PendingIntent.getActivity(
                this,
                id,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(text)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        nm.notify(id, notification)
    }
}
