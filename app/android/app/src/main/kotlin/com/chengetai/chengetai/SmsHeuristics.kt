package com.chengetai.chengetai

/**
 * A deliberately small on-device keyword scan for incoming SMS bodies.
 *
 * This is NOT the classifier. `POST /classify` (TF-IDF or LLM, see
 * `backend/app/services/classifier.py`) is the real thing, and it stays on the
 * server — which means it can only ever run on a message the user chose to
 * check. Auto-uploading the body of every SMS that arrives would turn a scam
 * warning into message interception, so the automatic path is limited to this
 * phrase list, which runs locally and tells the user *why* it spoke up.
 *
 * The phrases mirror `SCAM_KEYWORD_REASONS` in the backend classifier, and are
 * the same rules the backend uses for highlight extraction — not the trained
 * model's decision boundary. Expect false negatives; the Protection screen says
 * so, and the "check the full message" path exists for exactly that reason.
 */
object SmsHeuristics {

    private val SCAM_PHRASES: Map<String, String> = mapOf(
        "reverse" to "a request to reverse money",
        "wrong transfer" to "a 'wrong transfer' story",
        "registration fee" to "an upfront fee request",
        "processing fee" to "an upfront fee request",
        "activation fee" to "an upfront fee request",
        "otp" to "an OTP request",
        "pin" to "a request for your PIN",
        "seed" to "a 'sow a seed' appeal",
        "shortlisted" to "an unsolicited job offer",
        "forex" to "an unsolicited forex deal",
        "double your" to "a guaranteed-return offer",
        "urgent" to "manufactured urgency",
        "block" to "a threat to block your line",
    )

    /** Distinct human-readable reasons matched in [body], for the warning text. */
    fun scan(body: String): List<String> {
        val lowered = body.lowercase()
        return SCAM_PHRASES.entries
            .filter { lowered.contains(it.key) }
            .map { it.value }
            .distinct()
    }

    /**
     * Whether a body alone is worth a warning when the sender is not on the
     * blocklist.
     *
     * Two independent signals, not one: a single keyword fires on far too much
     * ordinary traffic ("urgent" in a message from your boss, "block" from your
     * own network operator) and a warning users learn to dismiss is worse than
     * no warning at all.
     */
    fun isSuspicious(signals: List<String>): Boolean = signals.size >= 2
}
