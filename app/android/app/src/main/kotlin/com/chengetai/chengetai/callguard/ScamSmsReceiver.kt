package com.chengetai.chengetai.callguard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Screens incoming SMS against both the sender's reputation and the message
 * classifier.
 *
 * SMS is the richer channel of the three. A call gives one signal — who is
 * calling — but a text gives two independent ones, and they catch different
 * attacks: a freshly-bought number has no reputation yet but sends the same
 * reversal script, while a SIM-swapped line keeps its clean history. Both run,
 * and either can trigger the warning.
 *
 * This receiver is passive: it never reads stored messages, never writes to
 * the SMS database, and never becomes the default SMS handler. It only reacts
 * to the broadcast it is handed. That matters for Play Store review, where
 * RECEIVE_SMS needs a declared use case — "caller ID and spam" covers this,
 * but only for an app that does not hoard message content. Bodies are sent to
 * the classifier and are never stored on the device: [ScreenedEvent] keeps the
 * verdict, not the text.
 */
class ScamSmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (messages.isEmpty()) return

        // A long SMS arrives as several parts in one broadcast. They share a
        // sender, and the scam script only makes sense reassembled — screening
        // each part alone would classify fragments and warn several times for
        // one message.
        val sender = messages.first().displayOriginatingAddress ?: return
        val body = messages.joinToString("") { it.displayMessageBody ?: "" }
        if (sender.isBlank()) return

        // goAsync keeps the process alive past onReceive's main-thread budget.
        // The PendingResult is finished from the screening thread, not here —
        // releasing it now would let Android kill the process while the
        // lookup is still in flight, which fails silently and intermittently.
        val pending = goAsync()
        ThreatScreener.screenAsync(
            context.applicationContext,
            ThreatChannel.SMS,
            sender,
            messageBody = body,
            onComplete = { pending.finish() },
        )
    }
}
