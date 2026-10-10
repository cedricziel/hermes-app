package com.cedricziel.hermes_app

import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ClipboardFiles(applicationContext)
            .install(MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hermes_app/clipboard"))
    }
}

/**
 * Lets the composer paste images and files, which Flutter's clipboard cannot:
 * `hasFiles` reads the clip's description only, and `read` copies each item
 * into the cache.
 */
private class ClipboardFiles(private val context: Context) {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun install(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasFiles" -> result.success(hasFiles())
                "read" -> executor.execute {
                    val files = try {
                        read()
                    } catch (_: Exception) {
                        emptyList()
                    }
                    main.post { result.success(files) }
                }
                else -> result.notImplemented()
            }
        }
    }

    private val clipboard get() = context.getSystemService(ClipboardManager::class.java)

    private fun hasFiles(): Boolean {
        val description = clipboard?.primaryClipDescription ?: return false
        return (0 until description.mimeTypeCount)
            .map(description::getMimeType)
            .any(::isFile)
    }

    private fun read(): List<Map<String, String?>> {
        val clip = clipboard?.primaryClip ?: return emptyList()
        val folder = File(context.cacheDir, "pasted/${UUID.randomUUID()}")
        return (0 until clip.itemCount).mapNotNull { index ->
            val uri = clip.getItemAt(index).uri ?: return@mapNotNull null
            val type = context.contentResolver.getType(uri)
            if (type == null || !isFile(type)) return@mapNotNull null
            val name = displayName(uri)
            val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(type)
            val target = File(
                folder,
                File(name ?: "pasted-$index${extension?.let { ".$it" } ?: ""}").name,
            )
            folder.mkdirs()
            context.contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { input.copyTo(it) }
            } ?: return@mapNotNull null
            mapOf("path" to target.path, "name" to name, "mimeType" to type)
        }
    }

    private fun displayName(uri: Uri): String? =
        context.contentResolver
            .query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { if (it.moveToFirst()) it.getString(0) else null }

    /** Text, links and intents are all `text/` types, and pasted as text. */
    private fun isFile(mimeType: String) = !mimeType.startsWith("text/")
}
