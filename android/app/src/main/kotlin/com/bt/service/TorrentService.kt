package com.bt.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.bt.engine.TorrentEngine
import kotlinx.coroutines.*

/**
 * BT 下载前台服务
 * 运行在独立进程 android:process=":engine" 中
 * 即使 UI 进程被销毁，下载仍在后台继续
 */
class TorrentService : Service() {

    companion object {
        private const val TAG = "TorrentService"
        const val CHANNEL_ID = "bt_download_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_STOP = "com.bt.action.STOP_SERVICE"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private lateinit var engine: TorrentEngine
    private var notificationManager: NotificationManager? = null

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "TorrentService 创建")

        engine = TorrentEngine.getInstance(this)

        scope.launch {
            engine.initialize()
            engine.start()
        }

        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        startForeground(NOTIFICATION_ID, buildNotification("准备就绪", 0, 0))

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.i(TAG, "TorrentService 销毁")
        scope.launch {
            engine.destroy()
        }
        scope.cancel()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // 用户从最近任务中划掉 App
        // 保持服务运行
        Log.i(TAG, "Task removed, 服务继续运行")
        super.onTaskRemoved(rootIntent)
    }

    /** 更新通知 */
    fun updateNotification(
        title: String,
        downloadCount: Int,
        downloadSpeed: Long,
    ) {
        val notification = buildNotification(title, downloadCount, downloadSpeed)
        notificationManager?.notify(NOTIFICATION_ID, notification)
    }

    private fun buildNotification(
        title: String,
        downloadCount: Int,
        downloadSpeed: Long,
    ): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, TorrentService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(
                if (downloadCount > 0) {
                    "$downloadCount 个下载任务 · ${formatSpeed(downloadSpeed)}"
                } else {
                    "引擎已就绪"
                }
            )
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .addAction(android.R.drawable.ic_media_pause, "停止", stopIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "下载任务",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "BT 下载进度通知"
                setShowBadge(false)
            }
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun formatSpeed(bytesPerSec: Long): String {
        if (bytesPerSec < 1024) return "$bytesPerSec B/s"
        if (bytesPerSec < 1024 * 1024) {
            return "${"%.1f".format(bytesPerSec / 1024.0)} KB/s"
        }
        return "${"%.1f".format(bytesPerSec / (1024.0 * 1024.0))} MB/s"
    }
}
