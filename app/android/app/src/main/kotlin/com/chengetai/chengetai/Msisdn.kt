package com.chengetai.chengetai

/**
 * MSISDN normalization, mirroring `normalize_msisdn` in
 * `backend/app/services/reputation.py`.
 *
 * The two must agree exactly, because the backend hands us a blocklist keyed by
 * its own normalized form and we match incoming call/SMS handles against it
 * locally. A mismatch here is silent: the number simply never matches and the
 * user gets no warning.
 *
 * The one deliberate difference is the leading "00" international prefix, which
 * the backend never sees (users type "+263..." or "077...") but the telephony
 * stack can deliver.
 */
object Msisdn {
    private val LOCAL_FORMAT = Regex("^0\\d{9}$")

    /** Returns the canonical `0XXXXXXXXX` form, or null if this isn't a
     *  Zimbabwean mobile number we can reason about (short codes, withheld
     *  numbers, and foreign numbers all land here). */
    fun normalize(raw: String?): String? {
        if (raw.isNullOrBlank()) return null

        var digits = raw.filter { it.isDigit() }
        if (digits.startsWith("00")) digits = digits.substring(2)
        if (digits.startsWith("263")) digits = "0" + digits.substring(3)

        return if (LOCAL_FORMAT.matches(digits)) digits else null
    }
}
