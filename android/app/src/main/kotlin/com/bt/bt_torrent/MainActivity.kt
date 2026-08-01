package com.bt.bt_torrent

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import com.bt.bridge.TorrentApiImpl
import com.bt.bridge.TorrentHostApi
import com.bt.service.TorrentService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
    }

    private var torrentApi: TorrentApiImpl? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startTorrentService()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val api = TorrentApiImpl(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        TorrentHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, api)
        api.start()
        torrentApi = api
        Log.i(TAG, "TorrentHostApi 已注册")
    }

    override fun onDestroy() {
        torrentApi?.dispose()
        torrentApi = null
        super.onDestroy()
    }

    /** 启动前台下载服务（后台保活） */
    private fun startTorrentService() {
        val intent = Intent(this, TorrentService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}
