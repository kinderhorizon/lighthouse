package org.kinderhorizon.lighthouse

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the `lighthouse/wifi` platform channel that reads the current Wi-Fi
 * SSID for the bandit's environmental context (ADR 0016).
 *
 * This lives in the Android host only: there is deliberately no iOS handler,
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, wifiChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getWifiSsid" -> result.success(currentSsid())
                    else -> result.notImplemented()
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
}
