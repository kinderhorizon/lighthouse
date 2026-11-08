package org.kinderhorizon.lighthouse

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import kotlin.concurrent.thread

/**
 * Hosts two platform channels:
 * - `lighthouse/incoming_file`: board files opened with or shared to
 *   Lighthouse (ADR 0015 amendment, see [receive]);
 * - `lighthouse/wifi`, described below.
 *
 * `lighthouse/wifi` reads the current Wi-Fi SSID for the bandit's
 * environmental context (ADR 0016).
 *
 * The Wi-Fi channel lives in the Android host only: there is deliberately no
 * iOS handler for it,
 * so the iOS binary links no Wi-Fi / CoreLocation symbol and ships no location
 * disclosure. The Dart side (WifiSource.usesWifiContext) is Android-only and
 * never invokes the channel on iOS regardless.
 *
 * The raw SSID is hashed and discarded on the Dart side; it is never stored or
 * transmitted. The read is gated by ACCESS_FINE_LOCATION, which is requested
 * once from the parent-facing onboarding step (ADR 0016), never on a child tap.
 */
class MainActivity : FlutterActivity() {
    private val wifiChannelName = "lighthouse/wifi"

    /** Board files opened with Lighthouse (ADR 0015 amendment). */
    private val incomingChannelName = "lighthouse/incoming_file"
    private var incomingChannel: MethodChannel? = null

    /** The one copied file waiting for Dart to take it; newest wins. */
    private var pendingFile: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, wifiChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getWifiSsid" -> result.success(currentSsid())
                    else -> result.notImplemented()
                }
            }
        incomingChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, incomingChannelName)
                .also { channel ->
                    channel.setMethodCallHandler { call, result ->
                        when (call.method) {
                            "takePendingFile" -> {
                                result.success(pendingFile)
                                pendingFile = null
                            }
                            else -> result.notImplemented()
                        }
                    }
                }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A recreated activity still carries the intent that first opened it;
        // that file was already offered (or is gone), so only a fresh start
        // receives. A fresh start also removes any copy an earlier run left
        // behind (the app was closed before the parent answered): it is never
        // offered again.
        if (savedInstanceState == null) {
            File(cacheDir, INCOMING_DIR).deleteRecursively()
            receive(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receive(intent)
    }

    /**
     * Copies a board file handed to Lighthouse (Open with / Share) into the
     * cache, which is never backed up, and tells Dart. The copy runs off the
     * main thread because the file may come from a cloud provider. Only
     * content: URIs are read (a raw file: path would need storage permission
     * and could point anywhere). At most [MAX_BYTES] + 1 bytes are copied, so an
     * oversized file still arrives and the Dart loader rejects it with a
     * message instead of nothing happening.
     */
    private fun receive(intent: Intent?) {
        if (intent == null) return
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val uri: Uri = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
            else -> null
        } ?: return
        if (uri.scheme != ContentResolver.SCHEME_CONTENT) return
        val resolver = contentResolver
        val dir = File(cacheDir, INCOMING_DIR)
        thread(name = "lighthouse-incoming-file") {
            val dest = File(dir, "board_${UUID.randomUUID()}.json")
            val copy = try {
                dir.mkdirs()
                resolver.openInputStream(uri)?.use { input ->
                    dest.outputStream().use { output ->
                        val buffer = ByteArray(64 * 1024)
                        var total = 0L
                        while (total <= MAX_BYTES) {
                            val n = input.read(buffer)
                            if (n < 0) break
                            val keep = minOf(n.toLong(), MAX_BYTES + 1 - total).toInt()
                            output.write(buffer, 0, keep)
                            total += keep
                        }
                    }
                    dest
                }
            } catch (e: Exception) {
                dest.delete()
                null
            }
            runOnUiThread {
                if (copy == null) return@runOnUiThread
                pendingFile?.let { File(it).delete() }
                pendingFile = copy.path
                incomingChannel?.invokeMethod("fileReceived", null)
            }
        }
    }

    /**
     * Returns the current SSID (as the platform reports it, possibly wrapped in
     * double quotes; the Dart side strips them), or null when unavailable.
     *
     * WifiManager.connectionInfo is deprecated on API 31+ but remains the
     * broadest-compatibility read for our minSdk; the value is opaque to us
     * (hashed Dart-side). When location is off or the SSID is unknown the
     * platform returns the "<unknown ssid>" sentinel, which we map to null
     * (the Dart side guards this too).
     */
    @Suppress("DEPRECATION")
    private fun currentSsid(): String? {
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            ?: return null
        val ssid = wifi.connectionInfo?.ssid ?: return null
        if (ssid.isEmpty() || ssid == "<unknown ssid>") return null
        return ssid
    }

    private companion object {
        /** Mirrors BoardLoader.maxFileBytes (4 MB). */
        const val MAX_BYTES = 4L * 1024 * 1024

        /** cache/incoming: where received files wait for the parent. */
        const val INCOMING_DIR = "incoming"
    }
}
