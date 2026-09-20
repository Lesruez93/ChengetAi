package com.chengetai.chengetai.callguard

import android.content.Context
import android.util.Log

/**
 * The screening pipeline shared by every channel.
 *
 * Extracted from the individual entry points (call screening service, SMS
 * receiver, WhatsApp notification listener) so all three converge on one
 * lookup, one warning threshold and one history. Testing this feature against
 * real traffic is slow and needs a second handset, and the parts most likely
 * to break — base URL, country resolution, the notification permission — are
 * identical across channels. So the app's "send a test" button drives this
 * same object; a test that exercised a different path than production would
 * be worse than no test.
 */
object ThreatScreener {

    private const val TAG = "ChengetAiCallGuard"

    /**
     * @param onComplete run once screening has finished, on the worker thread.
     *   A BroadcastReceiver must use this to release its `goAsync` result:
     *   its process is only guaranteed to survive until the PendingResult is
     *   finished, so finishing before the lookup returns would let Android
     *   kill the screening mid-flight.
     */
    fun screenAsync(
        context: Context,
        channel: ThreatChannel,
        sender: String,
        messageBody: String? = null,
        simulated: Boolean = false,
        onComplete: (() -> Unit)? = null,
    ) {
        // A plain thread rather than WorkManager or a coroutine scope: these
        // are short HTTP calls that are worthless if they land after the phone
        // stops ringing or the user has already acted on a text, so they must
        // not be deferred, retried or queued.
        Thread(
            {
                try {
                    screen(context, channel, sender, messageBody, simulated)
                } finally {
                    onComplete?.invoke()
                }
            },
            "chengetai-screen-${channel.key}",
        ).start()
    }

    private fun screen(
        context: Context,
        channel: ThreatChannel,
        sender: String,
        messageBody: String?,
        simulated: Boolean,
    ) {
        val store = CallGuardStore(context)
        val screenedAt = System.currentTimeMillis()

        fun record(
            outcome: String,
            warned: Boolean = false,
            riskLevel: String? = null,
            reportCount: Int? = null,
            topCategory: String? = null,
            messageVerdict: String? = null,
        ) {
            store.recordScreenedEvent(
                ScreenedEvent(
                    channel = channel,
                    sender = sender,
                    screenedAtMillis = screenedAt,
                    outcome = outcome,
                    riskLevel = riskLevel,
                    reportCount = reportCount,
                    topCategory = topCategory,
                    messageVerdict = messageVerdict,
                    wasWarned = warned,
                    wasSimulated = simulated,
                ),
            )
        }

        if (!store.isEnabled) {
            record("skipped_disabled")
            return
        }

        // A WhatsApp call often yields a saved contact's display name rather
        // than a number (see WhatsAppCallListener). There is nothing to look
        // up, and guessing would be worse than admitting it.
        if (!looksLikePhoneNumber(sender)) {
            record("no_number_available")
            return
        }

        val lookup = ReputationLookup.lookup(store.apiBaseUrl, sender, store.countryCode)

        // Only SMS carries a body to classify. Run it even when the sender
        // lookup failed — the two signals are independent, and a brand-new
        // scammer number has no reputation but still sends the known script.
        val messageVerdict = messageBody
            ?.takeIf { it.isNotBlank() }
            ?.let { ReputationLookup.classify(store.apiBaseUrl, it, store.countryCode) }

        when (lookup) {
            is LookupResult.Found -> {
                val v = lookup.verdict
                val senderFlagged = v.shouldWarn
                val messageFlagged = messageVerdict?.shouldWarn == true
                val warned = (senderFlagged || messageFlagged) &&
                    ScamCallNotifier.warn(context, channel, sender, v.takeIf { senderFlagged }, messageVerdict, simulated)

                val outcome = when {
                    warned -> "warned"
                    // The distinction matters: "flagged but we couldn't tell
                    // you" is a bug the user can fix by granting
                    // notifications, whereas "clean" is the feature working.
                    senderFlagged || messageFlagged -> "flagged_notification_blocked"
                    else -> "clean"
                }
                record(
                    outcome = outcome,
                    warned = warned,
                    riskLevel = v.riskLevel,
                    reportCount = v.reportCount,
                    topCategory = v.topCategory,
                    messageVerdict = messageVerdict?.verdict,
                )
            }

            is LookupResult.NotApplicable -> {
                // A bank or telco shortcode reaches here. The sender can't be
                // looked up, but the body still can — and shortcode spoofing
                // is one of the most common phishing vectors in these markets,
                // so classifying it alone is worth more than giving up.
                val messageFlagged = messageVerdict?.shouldWarn == true
                val warned = messageFlagged &&
                    ScamCallNotifier.warn(context, channel, sender, null, messageVerdict, simulated)
                record(
                    outcome = when {
                        warned -> "warned"
                        messageFlagged -> "flagged_notification_blocked"
                        messageVerdict != null -> "clean"
                        else -> "not_a_mobile_number"
                    },
                    warned = warned,
                    messageVerdict = messageVerdict?.verdict,
                )
            }

            is LookupResult.Failed -> {
                Log.w(TAG, "Lookup failed for ${channel.key} from $sender: ${lookup.reason}")
                val messageFlagged = messageVerdict?.shouldWarn == true
                val warned = messageFlagged &&
                    ScamCallNotifier.warn(context, channel, sender, null, messageVerdict, simulated)
                record(
                    outcome = if (warned) "warned" else "lookup_failed",
                    warned = warned,
                    messageVerdict = messageVerdict?.verdict,
                )
            }
        }
    }

    /**
     * Whether a sender string is something the reputation API could resolve.
     *
     * Deliberately permissive about format — the backend does the real
     * normalisation and owns the per-market rules. This only filters out the
     * cases with no digits to work with at all, chiefly WhatsApp contact names
     * and alphanumeric sender IDs.
     */
    private fun looksLikePhoneNumber(sender: String): Boolean {
        val digits = sender.count { it.isDigit() }
        return digits >= MIN_DIGITS && sender.none { it.isLetter() }
    }

    private const val MIN_DIGITS = 5
}
