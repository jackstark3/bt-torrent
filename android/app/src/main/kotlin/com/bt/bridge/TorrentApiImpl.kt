package com.bt.bridge

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.bt.engine.EngineEvent
import com.bt.engine.TorrentEngine
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Pigeon 生成的 TorrentHostApi 的 Kotlin 实现
 */
class TorrentApiImpl(
    private val context: Context,
    binaryMessenger: BinaryMessenger,
) : TorrentHostApi {

    companion object {
        private const val TAG = "TorrentApiImpl"
        private const val PROGRESS_INTERVAL_MS = 1000L
    }

    private val engine = TorrentEngine.getInstance(context)
    private val flutterApi = TorrentFlutterApi(binaryMessenger)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var progressJob: Job? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /** 初始化引擎并启动进度上报 */
    fun start() {
        scope.launch {
            engine.initialize().onFailure { e ->
                Log.e(TAG, "引擎初始化失败", e)
            }
            engine.start()

            // 引擎事件 → 转发 Flutter
            engine.engineEvents.collect { event ->
                when (event) {
                    is EngineEvent.TorrentFinished ->
                        mainHandler.post {
                            flutterApi.onDownloadFinished(event.infoHash) {}
                        }
                    is EngineEvent.TorrentError ->
                        mainHandler.post {
                            flutterApi.onDownloadError(event.infoHash, event.error) {}
                        }
                    else -> Unit
                }
            }
        }

        progressJob?.cancel()
        progressJob = scope.launch {
            while (isActive) {
                engine.getAllSessions().forEach { session ->
                    try {
                        val progress = session.progress.value
                        val status = session.status.value
                        mainHandler.post {
                            flutterApi.onProgressChanged(
                                DownloadProgressData(
                                    infoHash = session.infoHash,
                                    name = session.name,
                                    totalBytes = progress.totalBytes,
                                    downloadedBytes = progress.downloadedBytes,
                                    uploadBytes = progress.uploadBytes,
                                    progressPercent = progress.progressPercent,
                                    downloadSpeed = progress.downloadSpeed,
                                    uploadSpeed = progress.uploadSpeed,
                                    etaSeconds = progress.etaSeconds,
                                    status = status.code.toLong(),
                                    connectedPeers = progress.connectedPeers.toLong(),
                                    connectedSeeds = progress.connectedSeeds.toLong(),
                                )
                            ) {}
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "上报进度失败: $e")
                    }
                }
                delay(PROGRESS_INTERVAL_MS)
            }
        }
    }

    fun dispose() {
        progressJob?.cancel()
        scope.cancel()
    }

    override fun startDownload(
        magnetUri: String,
        savePath: String,
        callback: (Result<String>) -> Unit,
    ) {
        Log.i(TAG, "startDownload: $magnetUri -> $savePath")
        scope.launch {
            callback(engine.addTorrent(magnetUri, savePath).map { it.infoHash })
        }
    }

    override fun pauseDownload(
        infoHash: String,
        callback: (Result<Unit>) -> Unit,
    ) {
        Log.i(TAG, "pauseDownload: $infoHash")
        callback(engine.pauseTorrent(infoHash))
    }

    override fun resumeDownload(
        infoHash: String,
        callback: (Result<Unit>) -> Unit,
    ) {
        Log.i(TAG, "resumeDownload: $infoHash")
        callback(engine.resumeTorrent(infoHash))
    }

    override fun removeDownload(
        infoHash: String,
        deleteFiles: Boolean,
        callback: (Result<Unit>) -> Unit,
    ) {
        Log.i(TAG, "removeDownload: $infoHash, deleteFiles=$deleteFiles")
        callback(engine.removeTorrent(infoHash, deleteFiles))
    }

    override fun getProgress(
        infoHash: String,
        callback: (Result<DownloadProgressData>) -> Unit,
    ) {
        val session = engine.getSession(infoHash)
        if (session == null) {
            callback(Result.failure(Exception("任务不存在: $infoHash")))
            return
        }
        val progress = session.progress.value
        val status = session.status.value
        callback(Result.success(
            DownloadProgressData(
                infoHash = infoHash,
                name = session.name,
                totalBytes = progress.totalBytes,
                downloadedBytes = progress.downloadedBytes,
                uploadBytes = progress.uploadBytes,
                progressPercent = progress.progressPercent,
                downloadSpeed = progress.downloadSpeed,
                uploadSpeed = progress.uploadSpeed,
                etaSeconds = progress.etaSeconds,
                status = status.code.toLong(),
                connectedPeers = progress.connectedPeers.toLong(),
                connectedSeeds = progress.connectedSeeds.toLong(),
            )
        ))
    }

    override fun getFiles(
        infoHash: String,
        callback: (Result<List<TorrentFileData>>) -> Unit,
    ) {
        val session = engine.getSession(infoHash)
        if (session == null) {
            callback(Result.failure(Exception("任务不存在: $infoHash")))
            return
        }
        callback(Result.success(
            session.files.value.map { file ->
                TorrentFileData(
                    index = file.index.toLong(),
                    path = file.path,
                    name = file.name,
                    sizeBytes = file.sizeBytes,
                )
            }
        ))
    }

    override fun setPiecePriority(
        infoHash: String,
        pieceIndex: Long,
        priority: Long,
        callback: (Result<Unit>) -> Unit,
    ) {
        engine.getSession(infoHash)?.setPiecePriority(pieceIndex.toInt(), priority.toInt())
        callback(Result.success(Unit))
    }

    override fun setPieceDeadline(
        infoHash: String,
        pieceIndex: Long,
        millis: Long,
        callback: (Result<Unit>) -> Unit,
    ) {
        engine.getSession(infoHash)?.setPieceDeadline(pieceIndex.toInt(), millis.toInt())
        callback(Result.success(Unit))
    }

    override fun readPiece(
        infoHash: String,
        pieceIndex: Long,
        callback: (Result<ByteArray>) -> Unit,
    ) {
        val data = engine.getSession(infoHash)?.readPiece(pieceIndex.toInt())
        if (data != null) {
            callback(Result.success(data))
        } else {
            callback(Result.failure(Exception("piece 未下载或任务不存在")))
        }
    }
}
