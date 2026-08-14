package com.chengetai.chengetai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Screens incoming SMS: sender against the synced blocklist, body against the
 * local [SmsHeuristics] phrase list.
 *
 * This is a passive listener on `SMS_RECEIVED`, not the default SMS handler —
 * it reads the broadcast and warns, and never deletes, hides, or replies to
 * anything. Messages still arrive in the user's normal messaging app exactly as
 * before.
 *
 * Nothing here touches the network. The sender's number and the message body
 * are matched on-device and then dropped; only the verdict reaches
 * [ProtectionStore]'s log.
 */
class SmsScamReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        try {
            val store = ProtectionStore(context)
            if (!store.smsScreeningEnabled()) return

            // A long SMS arrives as several parts in one broadcast; concatenate
            // per sender so a scam phrase split across the part boundary still
            // matches.
            val bodies = HashMap<String, StringBuilder>()
            for (message in Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return) {
                val sender = message.displayOriginatingAddress ?: message.originatingAddress ?: continue
                bodies.getOrPut(sender) { StringBuilder() }.append(message.displayMessageBody ?: "")
            }

            for ((sender, body) in bodies) {
                screen(context, store, sender, body.toString())
            }
        } catch (e: Exception) {
            // A crash in a broadcast receiver surfaces to the user as "ChengetAI
            // has stopped" with no context. Screening failing quietly is the
            // lesser harm.
        }
    }

    private fun screen(context: Context, store: ProtectionStore, sender: String, body: String) {
        val msisdn = Msisdn.normalize(sender)
        val flagged = msisdn?.let { store.lookup(it) }
        val signals = SmsHeuristics.scan(body)

        // Warn if the sender is known-bad, or if the text alone is suspicious
        // enough on two independent signals. Alphanumeric senders ("EcoCash")
        // normalize to null and so can only ever trip the heuristic path — which
        // is right, since those are trivially spoofable and can't be reported as
        // a number in the first place.
        val senderIsFlagged = flagged != null
        if (!senderIsFlagged && !SmsHeuristics.isSuspicious(signals)) return

        ProtectionAlerts.warnAboutSms(context, sender, flagged, signals)
        store.recordDetection(
            type = ProtectionStore.TYPE_SMS,
            msisdn = msisdn ?: sender,
            riskLevel = flagged?.riskLevel ?: "suspicious",
            action = ProtectionStore.ACTION_WARNED,
            reportCount = flagged?.reportCount ?: 0,
            topCategory = flagged?.topCategory ?: "unknown",
            signals = signals,
        )
    }
}
