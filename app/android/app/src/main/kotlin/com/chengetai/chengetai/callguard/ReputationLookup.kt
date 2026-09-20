package com.chengetai.chengetai.callguard

import android.net.Uri
import org.json.JSONObject
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * The reputation verdict for one caller, reduced to what a call banner needs.
 *
 * This is deliberately a much smaller shape than `NumberReputationResponse` in
 * backend/app/schemas/reputation.py. A notification that appears for two
 * seconds while a phone is ringing can carry a risk level, a count and one
 * category — the full category/country breakdown belongs in the Lookup screen,
 * which the notification links to.
 */
data class NumberVerdict(
    val msisdn: String,
    val riskLevel: String,
    val reportCount: Int,
    val isPubliclyFlagged: Boolean,
    val topCategory: String?,
) {
    /**
     * Whether this verdict justifies interrupting someone mid-call.
     *
     * Gated on `is_publicly_flagged`, not on report count, so the threshold
     * stays a single backend decision (NUMBER_PUBLIC_FLAG_THRESHOLD). Warning
     * on a number that one hostile reporter flagged would make the product a
     * defamation vector, and the backend already encodes where that line sits.
     */
    val shouldWarn: Boolean
        get() = isPubliclyFlagged && riskLevel != "unknown" && riskLevel != "low"
}

/**
 * The classifier's read on an SMS body, from `POST /classify`.
 *
 * SMS screening has two independent signals — who sent it and what it says —
 * and they catch different attacks. A brand-new scammer number has no
 * reputation yet but sends the same reversal script; a legitimate number that
 * has been SIM-swapped keeps its clean history. Warning on either alone is the
 * point of checking both.
 */
data class MessageVerdict(
    val verdict: String,
    val confidence: Double,
    val matchedCategory: String?,
) {
    /**
     * Only a "scam" verdict warns. "suspicious" is deliberately excluded.
     *
     * This looks over-strict until you measure the baseline classifier on
     * ordinary traffic: it returns "suspicious" for most normal conversation
     * ("Happy birthday! Have a great day." scores suspicious at 0.39). On a
     * sample of 5 known scam scripts and 7 benign messages, warning on
     * scam-only caught 5/5 with 0 false positives, while including
     * "suspicious" caught the same 5 and added 6 false positives.
     *
     * A warning on nearly every personal text is worse than no warning at
     * all: it trains the user to dismiss the banner, so the one that matters
     * gets swiped away with the rest. "suspicious" is still recorded on the
     * event and shown in the history — it just doesn't interrupt anyone.
     */
    val shouldWarn: Boolean
        get() = verdict == "scam"
}

sealed interface LookupResult {
    data class Found(val verdict: NumberVerdict) : LookupResult

    /**
     * The backend rejected the caller ID as unparseable (HTTP 422) — a short
     * code, a withheld number, or an international number from a market we
     * don't cover. Distinct from [Failed] because it is a permanent answer for
     * this caller, not a transient outage worth retrying or reporting.
     */
    data object NotApplicable : LookupResult

    data class Failed(val reason: String) : LookupResult
}

/**
 * Blocking HTTP lookup against `GET /numbers/{msisdn}`.
 *
 * Uses HttpURLConnection rather than adding OkHttp/Retrofit: this is one GET
 * on a path that must stay alive in a call-screening process, and a new
 * transitive dependency tree is a worse trade than 40 lines of stdlib.
 *
 * Timeouts are short on purpose. The screening service has already responded
 * to Telecom by the time this runs, so a slow answer can't delay the call —
 * but it can arrive after the phone has stopped ringing, at which point the
 * warning is useless. Better to give up and log a miss.
 */
object ReputationLookup {
    private const val CONNECT_TIMEOUT_MS = 4_000
    private const val READ_TIMEOUT_MS = 4_000

    fun lookup(baseUrl: String, msisdn: String, countryCode: String?): LookupResult {
        val url = buildUrl(baseUrl, msisdn, countryCode)
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                setRequestProperty("Accept", "application/json")
            }
            when (val status = connection.responseCode) {
                in 200..299 -> LookupResult.Found(parse(connection.inputStream.readText()))
                422 -> LookupResult.NotApplicable
                else -> LookupResult.Failed("HTTP $status")
            }
        } catch (e: Exception) {
            // Any transport failure is the same outcome for the caller: we do
            // not know, so we stay silent rather than guess. The reason is kept
            // for the screening log so a persistently broken base URL is
            // visible in the app instead of looking like "no scam calls".
            LookupResult.Failed(e.javaClass.simpleName + (e.message?.let { ": $it" } ?: ""))
        } finally {
            connection?.disconnect()
        }
    }

    /**
     * `POST /classify` for an SMS body.
     *
     * Returns null on any failure rather than a result type: unlike the
     * reputation lookup, a failed classification has no outcome of its own to
     * report — the sender lookup still runs, and SMS screening degrades to
     * reputation-only rather than going silent.
     */
    fun classify(baseUrl: String, text: String, countryCode: String?): MessageVerdict? {
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL("${baseUrl.trimEnd('/')}/classify").openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept", "application/json")
            }
            val payload = JSONObject().apply {
                // The backend caps `text` at 4000 chars; a concatenated
                // multipart SMS can exceed that, and a 422 here would lose the
                // classification entirely. The scam script is always at the
                // start, so truncating the tail loses nothing that matters.
                put("text", text.take(MAX_CLASSIFY_CHARS))
                countryCode?.takeIf { it.isNotBlank() }?.let { put("country", it) }
            }
            connection.outputStream.use { it.write(payload.toString().toByteArray()) }

            if (connection.responseCode !in 200..299) return null
            val json = JSONObject(connection.inputStream.readText())
            MessageVerdict(
                verdict = json.optString("verdict", "safe"),
                confidence = json.optDouble("confidence", 0.0),
                matchedCategory = json.optString("matched_category").takeIf {
                    it.isNotEmpty() && it != "null"
                },
            )
        } catch (e: Exception) {
            null
        } finally {
            connection?.disconnect()
        }
    }

    private const val MAX_CLASSIFY_CHARS = 4_000

    private fun buildUrl(baseUrl: String, msisdn: String, countryCode: String?): String {
        val trimmedBase = baseUrl.trimEnd('/')
        val encoded = Uri.encode(msisdn)
        // `country` only disambiguates a local-format number; the backend
        // ignores it for an international one. Sending it always is harmless
        // and means a local-format caller ID still resolves.
        val query = countryCode?.takeIf { it.isNotBlank() }?.let { "?country=${Uri.encode(it)}" } ?: ""
        return "$trimmedBase/numbers/$encoded$query"
    }

    private fun parse(body: String): NumberVerdict {
        val json = JSONObject(body)
        val categories = json.optJSONObject("categories")
        return NumberVerdict(
            msisdn = json.optString("msisdn"),
            riskLevel = json.optString("risk_level", "unknown"),
            reportCount = json.optInt("report_count", 0),
            isPubliclyFlagged = json.optBoolean("is_publicly_flagged", false),
            topCategory = categories?.highestCountKey(),
        )
    }

    /** The category a number is reported for most, used as the warning's "why". */
    private fun JSONObject.highestCountKey(): String? {
        var best: String? = null
        var bestCount = -1
        for (key in keys()) {
            val count = optInt(key, 0)
            if (count > bestCount) {
                best = key
                bestCount = count
            }
        }
        return best
    }

    private fun InputStream.readText(): String = bufferedReader().use { it.readText() }
}
