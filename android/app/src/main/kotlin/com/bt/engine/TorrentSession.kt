package com.bt.engine

import android.util.Log
import java.io.File
import java.io.RandomAccessFile
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.libtorrent4j.Priority
import org.libtorrent4j.TorrentHandle
import org.libtorrent4j.TorrentInfo
import org.libtorrent4j.TorrentStatus

/**
 * 单个种子下载会话
 * 封装一个 libtorrent torrent_handle，通过 StateFlow 暴露状态
 */
class TorrentSession(
    val infoHash: String,
    val name: String,
    val savePath: String,
    val magnetUri: String,
) {
    companion object {
        private const val TAG = "TorrentSession"
    }

    /** 下载状态枚举 */
    enum class Status(val code: Int) {
        QUEUED(0),
        CHECKING(1),
        DOWNLOADING(2),
        PAUSED(3),
        SEEDING(4),
        COMPLETED(5),
        ERROR(6);

        companion object {
            fun fromCode(code: Int): Status =
                entries.firstOrNull { it.code == code } ?: ERROR
        }
    }

    /** 文件信息 */
    data class FileInfo(
        val index: Int,
        val path: String,
        val name: String,
        val sizeBytes: Long,
        val selected: Boolean = true,
    )

    /** 下载进度数据 */
    data class Progress(
        val totalBytes: Long = 0,
        val downloadedBytes: Long = 0,
        val uploadBytes: Long = 0,
        val progressPercent: Double = 0.0,
        val downloadSpeed: Long = 0,
        val uploadSpeed: Long = 0,
        val etaSeconds: Long = 0,
        val connectedPeers: Int = 0,
        val connectedSeeds: Int = 0,
    )

    private val _progress = MutableStateFlow(Progress())
    val progress: StateFlow<Progress> = _progress.asStateFlow()

    private val _status = MutableStateFlow(Status.QUEUED)
    val status: StateFlow<Status> = _status.asStateFlow()

    private val _files = MutableStateFlow<List<FileInfo>>(emptyList())
    val files: StateFlow<List<FileInfo>> = _files.asStateFlow()

    @Volatile
    private var handle: TorrentHandle? = null

    /** piece 大小（元数据就绪后设置） */
    @Volatile
    var pieceLength: Long = 0
        private set

    /** piece 总数（元数据就绪后设置） */
    @Volatile
    var numPieces: Int = 0
        private set

    /** 是否为在线播放临时会话（不进下载管理、完成时不导出） */
    @Volatile
    var isStreaming: Boolean = false

    private var manualPaused = false

    /** 关联 libtorrent handle（元数据就绪后调用） */
    fun attachHandle(h: TorrentHandle) {
        if (!h.isValid) return
        handle = h
        val ti = h.torrentFile()
        if (ti != null) {
            pieceLength = ti.pieceLength().toLong()
            numPieces = ti.numPieces()
            updateFiles(loadFiles(ti))
            updateStatus(Status.DOWNLOADING)
        }
        Log.i(TAG, "handle 已关联: $infoHash")
    }

    fun detachHandle() {
        handle = null
    }

    private fun loadFiles(ti: TorrentInfo): List<FileInfo> {
        val files = ti.files()
        val count = files.numFiles()
        return (0 until count).map { i ->
            FileInfo(
                index = i,
                path = files.filePath(i),
                name = files.fileName(i),
                sizeBytes = files.fileSize(i),
            )
        }
    }

    /** 从 handle 刷新进度（由引擎轮询线程调用） */
    fun refreshFromHandle() {
        val h = handle ?: return
        if (!h.isValid) return

        try {
            val st = h.status()
            val total = st.totalWanted()
            val done = st.totalWantedDone()
            val progress = if (total > 0) done.toDouble() / total else 0.0
            val rate = st.downloadRate()
            val eta = if (rate > 0) (total - done) / rate else 0L

            _progress.value = Progress(
                totalBytes = total,
                downloadedBytes = done,
                uploadBytes = st.totalUpload(),
                progressPercent = progress.coerceIn(0.0, 1.0),
                downloadSpeed = rate.toLong(),
                uploadSpeed = st.uploadRate().toLong(),
                etaSeconds = eta,
                connectedPeers = st.numPeers(),
                connectedSeeds = st.numSeeds(),
            )

            val state = st.state()
            val newStatus = when {
                manualPaused -> Status.PAUSED
                // 下载完成后统一视为完成（做种状态也归入完成，触发导出）
                state == TorrentStatus.State.SEEDING ||
                    state == TorrentStatus.State.FINISHED ||
                    progress >= 1.0 -> Status.COMPLETED
                state == TorrentStatus.State.CHECKING_FILES ||
                    state == TorrentStatus.State.CHECKING_RESUME_DATA -> Status.CHECKING
                state == TorrentStatus.State.DOWNLOADING ||
                    state == TorrentStatus.State.DOWNLOADING_METADATA -> Status.DOWNLOADING
                else -> Status.DOWNLOADING
            }
            if (isStreaming) {
                if (newStatus != _status.value) {
                    Log.i(
                        TAG,
                        "流播状态变化: $infoHash ${_status.value} -> $newStatus, " +
                            "state=$state, peers=${st.numPeers()}, seeds=${st.numSeeds()}, " +
                            "进度=${(progress * 100).toInt()}%"
                    )
                }
                if (state == TorrentStatus.State.UNKNOWN) {
                    Log.e(
                        TAG,
                        "流播异常状态: $infoHash state=$state error=${st.errorCode().message}"
                    )
                }
            }
            _status.value = newStatus
        } catch (e: Exception) {
            Log.w(TAG, "刷新进度失败: $e")
        }
    }

    /** 暂停 */
    fun pause() {
        Log.d(TAG, "暂停: $infoHash")
        manualPaused = true
        handle?.pause()
        _status.value = Status.PAUSED
    }

    /** 恢复 */
    fun resume() {
        Log.d(TAG, "恢复: $infoHash")
        manualPaused = false
        handle?.resume()
        _status.value = Status.DOWNLOADING
    }

    /** 关闭 */
    fun close() {
        Log.d(TAG, "关闭: $infoHash")
        handle = null
    }

    /** 设置 piece 优先级 (0-7) */
    fun setPiecePriority(pieceIndex: Int, priority: Int) {
        handle?.piecePriority(pieceIndex, Priority.fromSwig(priority))
    }

    /** 设置 piece deadline (毫秒) */
    fun setPieceDeadline(pieceIndex: Int, millis: Int) {
        handle?.setPieceDeadline(pieceIndex, millis)
    }

    /** 清除所有 piece deadline */
    fun clearPieceDeadlines() {
        handle?.clearPieceDeadlines()
    }

    /** 同步读取已下载的 piece 数据（支持跨文件 piece 与子目录） */
    fun readPiece(pieceIndex: Int): ByteArray? {
        val h = handle ?: return null
        val ti = h.torrentFile() ?: return null
        if (!h.havePiece(pieceIndex)) return null

        val pieceSize = ti.pieceSize(pieceIndex)
        if (pieceSize <= 0) return null

        val pieceLength = ti.pieceLength()
        val pieceOffset = pieceIndex.toLong() * pieceLength
        val files = ti.files()
        val numFiles = files.numFiles()
        val buffer = ByteArray(pieceSize)
        var written = 0

        var acc = 0L
        for (i in 0 until numFiles) {
            val size = files.fileSize(i)
            val fileEnd = acc + size
            if (pieceOffset < fileEnd && pieceOffset + pieceSize > acc) {
                val startInFile = maxOf(0L, pieceOffset - acc)
                val endInFile = minOf(size, pieceOffset + pieceSize - acc)
                val file = File(savePath, files.filePath(i))
                if (!file.exists()) return null

                try {
                    RandomAccessFile(file, "r").use { raf ->
                        raf.seek(startInFile)
                        val count = (endInFile - startInFile).toInt()
                        raf.readFully(buffer, written, count)
                        written += count
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "读取 piece $pieceIndex 失败: $e")
                    return null
                }
            }
            acc = fileEnd
        }
        return if (written == pieceSize) buffer else null
    }

    /** 更新文件列表 */
    fun updateFiles(fileList: List<FileInfo>) {
        _files.value = fileList
    }

    /** 更新进度 (由引擎轮询线程调用) */
    fun updateProgress(newProgress: Progress) {
        _progress.value = newProgress
    }

    /** 更新状态 */
    fun updateStatus(newStatus: Status) {
        _status.value = newStatus
    }
}
