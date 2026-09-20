package com.chengetai.chengetai.callguard

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/** Where a screened threat arrived from. */
enum class ThreatChannel(val key: String) {
    CALL("call"),
    SMS("sms"),

    /**
     * A WhatsApp voice/video call, observed through WhatsApp's own
     * notification. Kept as a separate channel rather than folded into [CALL]
     * because the signal available is fundamentally weaker — see
     * WhatsAppCallListener for what can and cannot be known.
     */
    WHATSAPP_CALL("whatsapp_call"),
}

/**
 * One screened event, as shown in the app's Call Guard history.
 *
 * [outcome] is the reason the event was or wasn't warned about, kept even for
 * silent outcomes. A history that only listed warnings would be
 * indistinguishable from a history where screening never ran at all — which is
 * the single most likely failure of this feature and the hardest to notice.
 */
data class ScreenedEvent(
    val channel: ThreatChannel,
    val sender: String,
    val screenedAtMillis: Long,
    val outcome: String,
    val riskLevel: String?,
    val reportCount: Int?,
    val topCategory: String?,
    /** Classifier verdict for an SMS body: scam / suspicious / safe. */
    val messageVerdict: String?,
    val wasWarned: Boolean,
    val wasSimulated: Boolean,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("channel", channel.key)
        put("sender", sender)
        put("screened_at_millis", screenedAtMillis)
        put("outcome", outcome)
        put("risk_level", riskLevel ?: JSONObject.NULL)
        put("report_count", reportCount ?: JSONObject.NULL)
        put("top_category", topCategory ?: JSONObject.NULL)
        put("message_verdict", messageVerdict ?: JSONObject.NULL)
        put("was_warned", wasWarned)
        put("was_simulated", wasSimulated)
    }
}

/**
 * Config and screening history shared between the Flutter UI and the
 * background screening components (call screening service, SMS receiver,
 * WhatsApp notification listener).
 *
 * Uses its own SharedPreferences file rather than reading the one the
 * `shared_preferences` plugin writes. That plugin's on-disk layout (file name,
 * `flutter.` key prefix, type-tagging of values) is an implementation detail
 * it is free to change; these components run in contexts where a silent
 * failure means no scam warning at all, which is exactly where we don't want
 * to depend on an undocumented format.
 */
class CallGuardStore(context: Context) {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /**
     * The API base URL the Flutter layer resolved, including any
     * `--dart-define=API_BASE_URL` override. Synced on app start so a debug
     * build pointed at a local backend screens against that same backend,
     * instead of silently checking production.
     */
    var apiBaseUrl: String
        get() = prefs.getString(KEY_API_BASE_URL, DEFAULT_API_BASE_URL) ?: DEFAULT_API_BASE_URL
        set(value) = prefs.edit().putString(KEY_API_BASE_URL, value).apply()

    /** The user's selected market, needed to resolve a local-format sender ID. */
    var countryCode: String
        get() = prefs.getString(KEY_COUNTRY_CODE, DEFAULT_COUNTRY_CODE) ?: DEFAULT_COUNTRY_CODE
        set(value) = prefs.edit().putString(KEY_COUNTRY_CODE, value).apply()

    /**
     * Whether the user has turned screening on in the app.
     *
     * Separate from holding the OS permissions: Android grants those to the
     * whole app, but someone may want to keep the app installed with warnings
     * off. Holding the call screening role without this flag means we still
     * receive calls (we must, to respond to Telecom) but never notify.
     */
    var isEnabled: Boolean
        get() = prefs.getBoolean(KEY_ENABLED, true)
        set(value) = prefs.edit().putBoolean(KEY_ENABLED, value).apply()

    fun recordScreenedEvent(event: ScreenedEvent) {
        val existing = readScreenedEvents()
        val updated = JSONArray().apply {
            put(event.toJson())
            // Newest first, capped — this is a debugging and reassurance
            // surface, not an audit log, and an unbounded list in
            // SharedPreferences would grow until reads get slow.
            for (i in 0 until minOf(existing.length(), MAX_HISTORY - 1)) {
                put(existing.getJSONObject(i))
            }
        }
        prefs.edit().putString(KEY_HISTORY, updated.toString()).apply()
    }

    fun screenedEventsJson(): String = readScreenedEvents().toString()

    fun clearScreenedEvents() {
        prefs.edit().remove(KEY_HISTORY).apply()
    }

    private fun readScreenedEvents(): JSONArray {
        val raw = prefs.getString(KEY_HISTORY, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (e: org.json.JSONException) {
            // Corrupt history is not worth crashing a call screen over.
            JSONArray()
        }
    }

    companion object {
        private const val PREFS_NAME = "chengetai_call_guard"
        private const val KEY_API_BASE_URL = "api_base_url"
        private const val KEY_COUNTRY_CODE = "country_code"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_HISTORY = "screened_events"
        private const val MAX_HISTORY = 40

        /**
         * Mirrors `AppConfig.apiBaseUrl` in lib/core/constants.dart. Only used
         * before the first sync from Flutter — in practice an event screened
         * after a fresh install but before the app has been opened once.
         */
        private const val DEFAULT_API_BASE_URL =
            "https://chengetai-backend-943314742820.europe-west4.run.app"
        private const val DEFAULT_COUNTRY_CODE = "ZW"
    }
}
