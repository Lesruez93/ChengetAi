package com.chengetai.chengetai

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/** One entry of the on-device blocklist, mirroring the backend's
 *  `FlaggedNumberItem` schema. */
data class FlaggedNumber(
    val msisdn: String,
    val riskLevel: String,
    val reportCount: Int,
    val topCategory: String,
)

/**
 * The handset-local state behind live call/SMS screening.
 *
 * This is read from three different places — the Flutter UI, a
 * [CallScreeningService], and an SMS [android.content.BroadcastReceiver] — the
 * last two of which run with no Flutter engine alive. That rules out the
 * `shared_preferences` plugin as the storage layer (its data is only reachable
 * from Dart), so the flagged-number set lives in its own native
 * `SharedPreferences` file that all three can reach, and Dart writes to it
 * through a MethodChannel rather than directly.
 *
 * Blocklist matching is done here, on the device, and never as a per-call
 * request to the backend — see the note on `GET /numbers/flagged/sync` in
 * `backend/app/routers/numbers.py` for why that distinction matters.
 */
class ProtectionStore(context: Context) {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // -- blocklist --

    /** Replaces the whole blocklist. Callers hand us the full set from
     *  `/numbers/flagged/sync`; there is no incremental/delta path, which keeps
     *  removals (a number that was disputed and cleared) working for free. */
    fun replaceFlagged(numbers: List<FlaggedNumber>, version: String) {
        val payload = JSONObject()
        for (n in numbers) {
            payload.put(
                n.msisdn,
                JSONObject()
                    .put(FIELD_RISK, n.riskLevel)
                    .put(FIELD_COUNT, n.reportCount)
                    .put(FIELD_CATEGORY, n.topCategory),
            )
        }
        prefs.edit()
            .putString(KEY_NUMBERS, payload.toString())
            .putString(KEY_VERSION, version)
            .putLong(KEY_SYNCED_AT, System.currentTimeMillis())
            .apply()

        synchronized(cacheLock) {
            cachedVersion = version
            cachedNumbers = null // force a re-parse on next lookup
        }
    }

    /** O(1) blocklist lookup for an already-normalized MSISDN. */
    fun lookup(msisdn: String): FlaggedNumber? {
        val entry = numbers().optJSONObject(msisdn) ?: return null
        return FlaggedNumber(
            msisdn = msisdn,
            riskLevel = entry.optString(FIELD_RISK, "medium"),
            reportCount = entry.optInt(FIELD_COUNT, 0),
            topCategory = entry.optString(FIELD_CATEGORY, "other"),
        )
    }

    fun flaggedCount(): Int = numbers().length()

    fun version(): String = prefs.getString(KEY_VERSION, "") ?: ""

    /** Epoch millis of the last successful sync, or 0 if never synced. */
    fun syncedAt(): Long = prefs.getLong(KEY_SYNCED_AT, 0L)

    /**
     * The parsed blocklist, memoized per sync version.
     *
     * A call-screening callback has a hard deadline before the platform gives
     * up and lets the call through, so re-parsing a few thousand entries on
     * every incoming call is worth avoiding. The memo is keyed by version so a
     * sync in the Flutter process is picked up by the service process on its
     * next event rather than being served stale.
     */
    private fun numbers(): JSONObject {
        val version = prefs.getString(KEY_VERSION, "") ?: ""
        synchronized(cacheLock) {
            val cached = cachedNumbers
            if (cached != null && cachedVersion == version) return cached

            val parsed = try {
                JSONObject(prefs.getString(KEY_NUMBERS, "{}") ?: "{}")
            } catch (e: Exception) {
                JSONObject() // corrupt blob: fail open (no warnings) rather than crash the dialer
            }
            cachedNumbers = parsed
            cachedVersion = version
            return parsed
        }
    }

    // -- user settings --

    /** Both screening features default to OFF. They are only ever switched on
     *  from the Protection screen, after the user has read what each one does
     *  and granted the underlying role/permission. */
    fun callScreeningEnabled(): Boolean = prefs.getBoolean(KEY_CALLS_ENABLED, false)

    fun smsScreeningEnabled(): Boolean = prefs.getBoolean(KEY_SMS_ENABLED, false)

    /** Auto-reject (rather than just warn about) high-risk callers. Off by
     *  default: silently rejecting a call on crowd-sourced evidence is a much
     *  bigger claim than showing a warning, so the user has to opt into it. */
    fun blockHighRiskCalls(): Boolean = prefs.getBoolean(KEY_BLOCK_HIGH_RISK, false)

    fun setSetting(key: String, value: Boolean) {
        val prefKey = when (key) {
            SETTING_CALLS -> KEY_CALLS_ENABLED
            SETTING_SMS -> KEY_SMS_ENABLED
            SETTING_BLOCK_HIGH_RISK -> KEY_BLOCK_HIGH_RISK
            else -> throw IllegalArgumentException("Unknown protection setting: $key")
        }
        prefs.edit().putBoolean(prefKey, value).apply()
    }

    // -- detection log --

    /**
     * Appends a screening event to the local log shown on the Protection screen.
     *
     * Records the sender and the verdict, never the message body — the whole
     * point of screening on-device is that message content stays on the handset,
     * and a log is still content if it holds the text.
     */
    fun recordDetection(
        type: String,
        msisdn: String,
        riskLevel: String,
        action: String,
        reportCount: Int,
        topCategory: String,
        signals: List<String> = emptyList(),
    ) {
        val entry = JSONObject()
            .put("type", type)
            .put("msisdn", msisdn)
            .put("risk_level", riskLevel)
            .put("action", action)
            .put("report_count", reportCount)
            .put("top_category", topCategory)
            .put("signals", JSONArray(signals))
            .put("detected_at", System.currentTimeMillis())

        val existing = recentDetections()
        val trimmed = JSONArray().put(entry)
        for (i in 0 until minOf(existing.length(), MAX_DETECTIONS - 1)) {
            trimmed.put(existing.get(i))
        }
        prefs.edit().putString(KEY_DETECTIONS, trimmed.toString()).apply()
    }

    /** Newest first. */
    fun recentDetections(): JSONArray = try {
        JSONArray(prefs.getString(KEY_DETECTIONS, "[]") ?: "[]")
    } catch (e: Exception) {
        JSONArray()
    }

    fun clearDetections() {
        prefs.edit().remove(KEY_DETECTIONS).apply()
    }

    companion object {
        private const val PREFS_NAME = "chengetai_protection"

        private const val KEY_NUMBERS = "flagged_numbers"
        private const val KEY_VERSION = "flagged_version"
        private const val KEY_SYNCED_AT = "flagged_synced_at"
        private const val KEY_CALLS_ENABLED = "screen_calls_enabled"
        private const val KEY_SMS_ENABLED = "screen_sms_enabled"
        private const val KEY_BLOCK_HIGH_RISK = "block_high_risk_calls"
        private const val KEY_DETECTIONS = "recent_detections"

        private const val FIELD_RISK = "r"
        private const val FIELD_COUNT = "n"
        private const val FIELD_CATEGORY = "c"

        private const val MAX_DETECTIONS = 50

        const val SETTING_CALLS = "screen_calls"
        const val SETTING_SMS = "screen_sms"
        const val SETTING_BLOCK_HIGH_RISK = "block_high_risk"

        const val TYPE_CALL = "call"
        const val TYPE_SMS = "sms"

        const val ACTION_WARNED = "warned"
        const val ACTION_BLOCKED = "blocked"

        private val cacheLock = Any()
        private var cachedNumbers: JSONObject? = null
        private var cachedVersion: String? = null
    }
}
