package com.bt.engine

/**
 * LibTorrent session 参数配置
 */
object SessionConfig {

    /** 默认监听端口范围起始 */
    const val LISTEN_PORT_START = 6881

    /** 默认监听端口范围结束 */
    const val LISTEN_PORT_END = 6899

    /** 最大连接数 (WiFi) */
    const val MAX_CONNECTIONS_WIFI = 200

    /** 最大连接数 (蜂窝网络) */
    const val MAX_CONNECTIONS_CELLULAR = 50

    /** 最大并发下载数 */
    const val MAX_ACTIVE_DOWNLOADS = 3

    /** 最大做种数 */
    const val MAX_ACTIVE_SEEDS = 5

    /** 默认下载限速 (bytes/sec, 0 = 不限速) */
    const val DEFAULT_DOWNLOAD_RATE_LIMIT = 0

    /** 默认上传限速 (bytes/sec) */
    const val DEFAULT_UPLOAD_RATE_LIMIT = 102400 // 100KB/s

    /** Alert 轮询间隔 (毫秒) */
    const val ALERT_POLL_INTERVAL_MS = 1000L

    /** Piece 下载通知批量间隔 */
    const val PIECE_NOTIFY_BATCH_MS = 500L

    /** DHT 默认启用 */
    const val DHT_ENABLED = false

    /** LSD 默认启用 */
    const val LSD_ENABLED = true

    /** uTP 默认启用 */
    const val UTP_ENABLED = true

    /** 加密策略: mixed mode */
    const val ENCRYPTION_MIXED = true

    /** Resume 数据保存间隔 (秒) */
    const val RESUME_SAVE_INTERVAL_SEC = 30

    /** 低电量阈值 */
    const val LOW_BATTERY_THRESHOLD = 0.2f

    /** 低电量时最大连接数 */
    const val MAX_CONNECTIONS_LOW_BATTERY = 50
}
