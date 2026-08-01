package com.bt.engine

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import java.io.File

/**
 * Android 分区存储适配器
 * - 下载中：使用 app 私有目录
 * - 下载完成：移动到 MediaStore（用户可见）
 */
class FileManager(private val context: Context) {

    companion object {
        private const val TAG = "FileManager"
        private const val DOWNLOAD_SUBDIR = "downloads"
    }

    /** 获取下载中文件目录 (app 私有) */
    fun getInProgressDir(): File {
        return File(context.getExternalFilesDir(null), DOWNLOAD_SUBDIR).also {
            if (!it.exists()) it.mkdirs()
        }
    }

    /** 获取下载中文件的路径 */
    fun getInProgressPath(fileName: String): File {
        return File(getInProgressDir(), fileName)
    }

    /** 获取默认下载目录 */
    fun getDefaultDownloadDir(): File {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ 使用 MediaStore
            getInProgressDir()
        } else {
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        }
    }

    /** 将下载完成的文件移动到 MediaStore */
    fun moveToMediaStore(sourceFile: File, displayName: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return try {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, displayName)
                    put(MediaStore.Downloads.MIME_TYPE, "application/octet-stream")
                    put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }

                val resolver = context.contentResolver
                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)

                if (uri != null) {
                    resolver.openOutputStream(uri)?.use { output ->
                        sourceFile.inputStream().use { input ->
                            input.copyTo(output)
                        }
                    }

                    values.clear()
                    values.put(MediaStore.Downloads.IS_PENDING, 0)
                    resolver.update(uri, values, null, null)

                    // 删除源文件
                    sourceFile.delete()
                    Log.i(TAG, "文件已移动到 MediaStore: $displayName")
                    true
                } else {
                    Log.e(TAG, "创建 MediaStore 条目失败")
                    false
                }
            } catch (e: Exception) {
                Log.e(TAG, "移动到 MediaStore 失败", e)
                false
            }
        } else {
            // Android 9 及以下直接使用公共目录
            val destFile = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                displayName
            )
            return sourceFile.renameTo(destFile)
        }
    }

    /** 删除文件 */
    fun deleteFile(file: File): Boolean {
        return file.deleteRecursively()
    }

    /** 获取可用空间 (bytes) */
    fun getAvailableSpace(): Long {
        return getInProgressDir().freeSpace
    }

    /** 分配稀疏文件（预分配磁盘空间） */
    fun allocateSparseFile(file: File, size: Long): Boolean {
        return try {
            if (!file.exists()) {
                file.parentFile?.mkdirs()
                file.createNewFile()
            }
            // 使用 RandomAccessFile 设置文件大小
            java.io.RandomAccessFile(file, "rw").apply {
                setLength(size)
                close()
            }
            Log.d(TAG, "预分配文件: ${file.name} (${size} bytes)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "预分配文件失败", e)
            false
        }
    }
}
