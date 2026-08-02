package com.bt.engine

import android.content.Context
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.libtorrent4j.Sha1Hash
import org.libtorrent4j.SessionManager
import org.libtorrent4j.SessionParams
import org.libtorrent4j.SettingsPack
import org.libtorrent4j.TorrentHandle
import org.libtorrent4j.swig.remove_flags_t
import org.libtorrent4j.swig.settings_pack
import org.libtorrent4j.swig.torrent_flags_t
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/**
 * BT 引擎 singleton
 * 管理 libtorrent4j session 生命周期
 */
class TorrentEngine private constructor(private val context: Context) {

    companion object {
        private const val TAG = "TorrentEngine"
        private const val POLL_INTERVAL_MS = 1000L

        @Volatile
        private var instance: TorrentEngine? = null

        fun getInstance(context: Context): TorrentEngine {
            return instance ?: synchronized(this) {
                instance ?: TorrentEngine(context.applicationContext).also { instance = it }
            }
        }
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val sessions = ConcurrentHashMap<String, TorrentSession>()
    private val fileManager = FileManager(context)

    /** 引擎状态事件流 */
    private val _engineEvents = MutableSharedFlow<EngineEvent>(extraBufferCapacity = 64)
    val engineEvents: SharedFlow<EngineEvent> = _engineEvents

    private var sessionManager: SessionManager? = null
    private var isInitialized = false
    private var isRunning = false

    /** 初始化引擎 */
    suspend fun initialize(): Result<Unit> {
        if (isInitialized) return Result.success(Unit)

        return try {
            Log.i(TAG, "初始化 BT 引擎...")

            val settings = SettingsPack().apply {
                // 并发限制
                setInteger(settings_pack.int_types.active_downloads.swigValue(), 3)
                setInteger(settings_pack.int_types.active_limit.swigValue(), 200)
                setInteger(settings_pack.int_types.active_dht_limit.swigValue(), 88)
                // DHT / LSD
                setBoolean(settings_pack.bool_types.enable_dht.swigValue(), true)
                setBoolean(settings_pack.bool_types.enable_lsd.swigValue(), true)
                setBoolean(settings_pack.bool_types.enable_upnp.swigValue(), false)
                setBoolean(settings_pack.bool_types.enable_natpmp.swigValue(), false)
                // 加密
                setBoolean(settings_pack.bool_types.prefer_rc4.swigValue(), true)
            }

            val manager = SessionManager()
            manager.start(SessionParams(settings))
            sessionManager = manager

            isInitialized = true
            _engineEvents.emit(EngineEvent.Initialized)
            Log.i(TAG, "BT 引擎初始化完成")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "BT 引擎初始化失败", e)
            Result.failure(e)
        }
    }

    /** 启动引擎（开始进度轮询） */
    suspend fun start(): Result<Unit> {
        if (!isInitialized) {
            val initResult = initialize()
            if (initResult.isFailure) {
                return Result.failure(
                    initResult.exceptionOrNull() ?: Exception("引擎初始化失败")
                )
            }
        }

        if (isRunning) return Result.success(Unit)

        Log.i(TAG, "启动 BT 引擎...")
        isRunning = true
        _engineEvents.emit(EngineEvent.Started)

        // 每秒轮询所有 session 进度
        scope.launch {
            while (isActive && isRunning) {
                sessions.values.forEach { session ->
                    val prev = session.status.value
                    session.refreshFromHandle()
                    if (session.status.value == TorrentSession.Status.COMPLETED &&
                        prev != TorrentSession.Status.COMPLETED
                    ) {
                        // 在线播放会话只做临时缓存，不导出到公共目录
                        if (!session.isStreaming) {
                            exportFilesToPublic(session)
                        }
                        _engineEvents.emit(EngineEvent.TorrentFinished(session.infoHash))
                    }
                }
                delay(POLL_INTERVAL_MS)
            }
        }

        return Result.success(Unit)
    }

    /** 暂停引擎 */
    suspend fun pause(): Result<Unit> {
        Log.i(TAG, "暂停 BT 引擎")
        isRunning = false
        sessionManager?.pause()
        _engineEvents.emit(EngineEvent.Paused)
        return Result.success(Unit)
    }

    /** 设置下载限速 (bytes/sec, 0 = 不限速) */
    fun setDownloadRateLimit(bytesPerSec: Int) {
        sessionManager?.downloadRateLimit(bytesPerSec)
    }

    /** 设置上传限速 */
    fun setUploadRateLimit(bytesPerSec: Int) {
        sessionManager?.uploadRateLimit(bytesPerSec)
    }

    /** 添加下载任务（isStreaming = 在线播放临时会话） */
    suspend fun addTorrent(
        magnetUri: String,
        savePath: String,
        isStreaming: Boolean = false,
    ): Result<TorrentSession> {
        if (!isInitialized) {
            val initResult = initialize()
            if (initResult.isFailure) {
                return Result.failure(
                    initResult.exceptionOrNull() ?: Exception("引擎初始化失败")
                )
            }
        }
        if (!isRunning) {
            val startResult = start()
            if (startResult.isFailure) {
                return Result.failure(
                    startResult.exceptionOrNull() ?: Exception("引擎启动失败")
                )
            }
        }

        return try {
            Log.i(TAG, "添加下载: $magnetUri -> $savePath")

            val manager = sessionManager
                ?: throw Exception("session 未启动")

            // 保存目录必须存在（libtorrent 依赖 save_path 目录）
            val saveDir = File(savePath)
            if (!saveDir.exists() && !saveDir.mkdirs()) {
                throw Exception("无法创建保存目录: $savePath")
            }

            // 一次性添加磁力（默认 auto-managed，元数据就绪后自动开始下载）。
            // 不使用 fetchMagnet：它的临时 torrent 是异步移除的，紧接着再 download()
            // 会命中"同 hash 已存在"分支，任务从未真正添加（在线播放 piece 永远不来）。
            manager.download(magnetUri, saveDir, torrent_flags_t())

            val hashHex = extractInfoHash(magnetUri)
                ?: throw Exception("无法解析磁力链接 info_hash")
            val hash = Sha1Hash.parseHex(hashHex)

            // 等待元数据就绪（磁力链接从 DHT/peers 获取，最多 60 秒）
            val deadline = System.currentTimeMillis() + 60_000
            var handle = manager.find(hash)
            var lastStatusLogMs = 0L
            while (handle == null || !handle.isValid || handle.torrentFile() == null) {
                if (System.currentTimeMillis() >= deadline) {
                    // 超时：清理刚添加的 torrent，避免残留
                    if (handle != null && handle.isValid) {
                        try {
                            manager.remove(handle)
                        } catch (e: Exception) {
                            Log.w(TAG, "清理超时 torrent 失败: $e")
                        }
                    }
                    throw Exception("获取种子元数据超时：该资源可能无人做种")
                }
                // 每 5 秒记录一次连接状态，便于判断是资源无种还是网络问题
                if (System.currentTimeMillis() - lastStatusLogMs >= 5000) {
                    lastStatusLogMs = System.currentTimeMillis()
                    val statusDesc = if (handle != null && handle.isValid) {
                        val st = handle.status()
                        "state=${st.state()} peers=${st.numPeers()} " +
                            "seeds=${st.numSeeds()} rate=${st.downloadRate()}"
                    } else {
                        "handle 无效/未找到"
                    }
                    Log.i(TAG, "等待元数据中: $statusDesc")
                }
                delay(500)
                handle = manager.find(hash)
            }

            val ti = handle.torrentFile()
            val infoHash = ti.infoHash().toString()

            val session = TorrentSession(
                infoHash = infoHash,
                name = ti.name(),
                savePath = savePath,
                magnetUri = magnetUri,
            )
            if (handle != null) {
                session.attachHandle(handle)
            }
            session.isStreaming = isStreaming
            sessions[infoHash] = session

            _engineEvents.emit(EngineEvent.TorrentAdded(infoHash))
            Result.success(session)
        } catch (e: Exception) {
            Log.e(TAG, "添加下载失败", e)
            Result.failure(e)
        }
    }

    /** 从磁力链接提取 info_hash（40 位十六进制，v1） */
    private fun extractInfoHash(magnetUri: String): String? {
        val m = Regex("xt=urn:btih:([A-Fa-f0-9]{40})").find(magnetUri)
        return m?.groupValues?.get(1)?.lowercase()
    }

    /** 暂停下载 */
    fun pauseTorrent(infoHash: String): Result<Unit> {
        val session = sessions[infoHash] ?: return Result.failure(Exception("任务不存在"))
        session.pause()
        return Result.success(Unit)
    }

    /** 恢复下载 */
    fun resumeTorrent(infoHash: String): Result<Unit> {
        val session = sessions[infoHash] ?: return Result.failure(Exception("任务不存在"))
        session.resume()
        return Result.success(Unit)
    }

    /** 移除下载 */
    fun removeTorrent(infoHash: String, deleteFiles: Boolean): Result<Unit> {
        val session = sessions.remove(infoHash) ?: return Result.failure(Exception("任务不存在"))
        try {
            if (deleteFiles) {
                val dir = java.io.File(session.savePath)
                if (dir.exists()) dir.deleteRecursively()
            }
            val manager = sessionManager
            if (manager != null) {
                val handle = manager.find(Sha1Hash.parseHex(infoHash))
                if (handle != null) {
                    manager.remove(
                        handle,
                        remove_flags_t.from_int(if (deleteFiles) 1 else 0)
                    )
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "移除 handle 失败: $e")
        }
        session.close()
        _engineEvents.tryEmit(EngineEvent.TorrentRemoved(infoHash))
        return Result.success(Unit)
    }

    /** 获取下载任务 */
    fun getSession(infoHash: String): TorrentSession? = sessions[infoHash]

    /** 获取所有会话（进度推送需要包含在线播放会话） */
    fun getAllSessions(): List<TorrentSession> = sessions.values.toList()

    /** 将在线播放会话转存为正式下载任务 */
    fun convertToDownload(infoHash: String): Result<Unit> {
        val session = sessions[infoHash] ?: return Result.failure(Exception("任务不存在"))
        session.isStreaming = false
        Log.i(TAG, "会话已转存为正式下载: $infoHash")
        _engineEvents.tryEmit(EngineEvent.TorrentAdded(infoHash))
        return Result.success(Unit)
    }

    /** 下载完成后将文件导出到公共下载目录（文件管理器可见） */
    private fun exportFilesToPublic(session: TorrentSession) {
        try {
            val files = session.files.value
            if (files.isEmpty()) {
                // 兜底：导出目录下所有文件
                File(session.savePath).listFiles()?.forEach { f ->
                    if (f.isFile) fileManager.moveToMediaStore(f, f.name)
                }
            } else {
                files.forEach { info ->
                    val f = File(session.savePath, info.path)
                    if (f.exists()) fileManager.moveToMediaStore(f, f.name)
                }
            }
            Log.i(TAG, "文件已导出到公共下载目录: ${session.infoHash}")

            // 从 libtorrent 会话移除（文件已移走，不再做种），保留 UI 会话状态
            session.detachHandle()
            val manager = sessionManager
            if (manager != null) {
                val handle = manager.find(Sha1Hash.parseHex(session.infoHash))
                if (handle != null) manager.remove(handle)
            }
        } catch (e: Exception) {
            Log.e(TAG, "导出文件失败", e)
        }
    }

    /** 销毁引擎 */
    suspend fun destroy() {
        Log.i(TAG, "销毁 BT 引擎...")
        isRunning = false
        sessions.values.forEach { it.close() }
        sessions.clear()
        sessionManager?.let {
            try {
                it.stop()
            } catch (e: Exception) {
                Log.w(TAG, "停止 session 失败: $e")
            }
        }
        sessionManager = null
        scope.cancel()
        isInitialized = false
        instance = null
        _engineEvents.emit(EngineEvent.Destroyed)
    }
}

/** 引擎事件 */
sealed class EngineEvent {
    data object Initialized : EngineEvent()
    data object Started : EngineEvent()
    data object Paused : EngineEvent()
    data object Destroyed : EngineEvent()
    data class TorrentAdded(val infoHash: String) : EngineEvent()
    data class TorrentRemoved(val infoHash: String) : EngineEvent()
    data class TorrentFinished(val infoHash: String) : EngineEvent()
    data class TorrentError(val infoHash: String, val error: String) : EngineEvent()
}
