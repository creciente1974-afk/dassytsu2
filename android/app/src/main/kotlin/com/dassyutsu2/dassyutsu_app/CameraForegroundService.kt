package com.dassyutsu2.dassyutsu_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * カメラ撮影中のみ動作するForeground Service
 * アプリがキルされるのを防ぐために使用
 */
class CameraForegroundService : Service() {
    
    companion object {
        private const val CHANNEL_ID = "camera_foreground_service_channel"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_NAME = "カメラ撮影中"
        
        /**
         * 通知チャンネルを作成
         */
        fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_LOW // 低優先度で通知を表示
                ).apply {
                    description = "カメラ撮影中にアプリがキルされるのを防ぐための通知"
                    setShowBadge(false)
                }
                
                val notificationManager = context.getSystemService(NotificationManager::class.java)
                notificationManager.createNotificationChannel(channel)
            }
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel(this)
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 通知を表示してForeground Serviceとして開始
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        // サービスがキルされても再起動しない（STICKYではない）
        return START_NOT_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    /**
     * 通知を作成
     */
    private fun createNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("カメラ撮影中")
            .setContentText("画像認証のため、カメラ撮影を行っています")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentIntent(pendingIntent)
            .setOngoing(true) // ユーザーが削除できないようにする
            .setPriority(NotificationCompat.PRIORITY_LOW) // 低優先度
            .build()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // サービス停止時に通知を削除
        stopForeground(STOP_FOREGROUND_REMOVE)
    }
}
