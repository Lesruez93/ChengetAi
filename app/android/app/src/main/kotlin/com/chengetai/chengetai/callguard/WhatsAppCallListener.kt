package com.chengetai.chengetai.callguard

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Best-effort screening of incoming WhatsApp calls.
 *
 * **Read this before trusting or extending it.** WhatsApp calls are VoIP
 * inside WhatsApp's own process. They never pass through Telecom, so
 * [ScamCallScreeningService] cannot see them, and no Android API exposes a
 * WhatsApp caller to a third-party app. Reading WhatsApp's own incoming-call
 * notification is the only route that exists, and it is materially weaker than
 * the carrier-call path in three ways:
 *
 * 1. **Usually there is no number.** WhatsApp shows a saved contact's name,
 *    and a name cannot be looked up against a reputation database keyed by
 *    MSISDN. Screening therefore only produces a verdict for calls from
 *    numbers not in the user's contacts — which, to be fair, is where the
 *    scams are, but it means silence on a compromised contact.
 * 2. **It depends on WhatsApp's notification format.** Nothing here is a
 *    contract. A WhatsApp update that changes its title text or notification
 *    category silently ends the feature, with no crash and no error — which
 *    is exactly why every outcome is written to the screening history, so the
 *    app can show that WhatsApp screening has gone quiet.
 * 3. **The permission is heavy.** BIND_NOTIFICATION_LISTENER_SERVICE grants
 *    read access to *every* notification on the device. This class therefore
 *    filters to WhatsApp call notifications as its first action and ignores
 *    everything else without inspecting it.
 *
 * Treat this as a supplement to carrier-call screening, never a replacement.
 */
class WhatsAppCallListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName !in WHATSAPP_PACKAGES) return

        val notification = sbn.notification ?: return
        if (notification.category != Notification.CATEGORY_CALL) return

        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()

        // Only incoming calls. An ongoing or outgoing call notification shares
        // the same category, and warning someone about a call they placed
        // themselves would be noise that teaches them to ignore the warning.
        if (!text.contains("incoming", ignoreCase = true) &&
            !title.contains("incoming", ignoreCase = true) &&
            !text.contains("calling", ignoreCase = true)
        ) {
            return
        }

        // The title is the caller as WhatsApp displays it: a phone number for
        // an unknown caller, a contact name for a known one. ThreatScreener
        // records "no_number_available" for the latter rather than guessing.
        val caller = title.trim()
        if (caller.isEmpty()) return

        ThreatScreener.screenAsync(
            applicationContext,
            ThreatChannel.WHATSAPP_CALL,
            caller,
        )
    }

    companion object {
        /** WhatsApp and WhatsApp Business ship as separate packages. */
        private val WHATSAPP_PACKAGES = setOf("com.whatsapp", "com.whatsapp.w4b")

        /**
         * Whether the user has granted notification access to this listener.
         *
         * Read from Settings.Secure rather than from the service itself: the
         * service is only instantiated *after* access is granted, so asking it
         * would always answer "no" on the screen where the user needs to see
         * the state.
         */
        fun isEnabled(context: Context): Boolean {
            val flat = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners",
            ) ?: return false
            val expected = ComponentName(context, WhatsAppCallListener::class.java)
            return flat.split(':').any {
                ComponentName.unflattenFromString(it) == expected
            }
        }
    }
}
