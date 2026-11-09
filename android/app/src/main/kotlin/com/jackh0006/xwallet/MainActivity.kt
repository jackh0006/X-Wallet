package com.jackh0006.xwallet

import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.jackh0006.xwallet/files"
    private var pendingSave: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null
    private var pendingOpen: MethodChannel.Result? = null

    private val createDocument =
        registerForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")) { uri: Uri? ->
            val result = pendingSave
            val bytes = pendingSaveBytes
            pendingSave = null
            pendingSaveBytes = null
            if (result == null) return@registerForActivityResult
            if (uri == null) {
                result.success(false)
                return@registerForActivityResult
            }
            try {
                contentResolver.openOutputStream(uri)?.use { stream ->
                    stream.write(bytes ?: ByteArray(0))
                    stream.flush()
                } ?: throw IllegalStateException("Cannot open the selected file.")
                result.success(true)
            } catch (error: Exception) {
                result.error("write_failed", error.message, null)
            }
        }

    private val openDocument =
        registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
            val result = pendingOpen
            pendingOpen = null
            if (result == null) return@registerForActivityResult
            if (uri == null) {
                result.success(null)
                return@registerForActivityResult
            }
            try {
                val bytes = contentResolver.openInputStream(uri)?.use { stream ->
                    val out = ByteArrayOutputStream()
                    stream.copyTo(out)
                    out.toByteArray()
                } ?: throw IllegalStateException("Cannot open the selected file.")
                result.success(bytes)
            } catch (error: Exception) {
                result.error("read_failed", error.message, null)
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // FLAG_SECURE blocks screenshots and screen recording of wallet
        // secrets, recovery phrases and QR codes.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveBytes" -> {
                        if (pendingSave != null) {
                            result.error("busy", "A save dialog is already open.", null)
                            return@setMethodCallHandler
                        }
                        val name = call.argument<String>("name") ?: "x-wallet-file"
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null) {
                            result.error("bad_args", "Missing file bytes.", null)
                            return@setMethodCallHandler
                        }
                        pendingSave = result
                        pendingSaveBytes = bytes
                        createDocument.launch(name)
                    }
                    "openBytes" -> {
                        if (pendingOpen != null) {
                            result.error("busy", "A file dialog is already open.", null)
                            return@setMethodCallHandler
                        }
                        pendingOpen = result
                        openDocument.launch(arrayOf("*/*"))
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
