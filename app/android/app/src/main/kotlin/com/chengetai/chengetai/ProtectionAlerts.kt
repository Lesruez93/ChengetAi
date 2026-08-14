package com.chengetai.chengetai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * The user-visible half of screening: a heads-up warning while the phone is
 * still ringing, or as the SMS lands.
 *
 * Wording matters here and is deliberately hedged. The blocklist is
 * crowd-sourced, so the honest claim is "this number has been reported N
 * times", never "this is a scammer" — the same restraint the backend applies
 * with its public-flag threshold, carried through to the one surface where the
 * user acts on it in a hurry.
 */
object ProtectionAlerts {

    private const val CHANNEL_CALLS = "chengetai_call_warnings"
    private const val CHANNEL_SMS = "chengetai_sms_warnings"

    private const val NOTIFICATION_ID_CALL = 4101
    private const val NOTIFICATION_ID_SMS = 4102

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return

        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_CALLS,
                "Scam call warnings",
                // HIGH so the warning can surface over the incoming-call screen,
                // which is the only moment it is useful.
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "Warns you when a reported number is calling." },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_SMS,
                "Scam SMS warnings",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "Warns you when a message looks like a known scam." },
        )
    }

    fun warnAboutCall(context: Context, flagged: FlaggedNumber, blocked: Boolean) {
        val title = if (blocked) "Call blocked: ${flagged.msisdn}" else "Warning: ${flagged.msisdn}"
        val text = buildString {
            append(reportSummary(flagged))
            append(if (blocked) " ChengetAI rejected this call." else " Be careful — do not send money or share an OTP.")
        }
        notify(context, CHANNEL_CALLS, NOTIFICATION_ID_CALL, title, text, Notification.CATEGORY_CALL)
    }

    fun warnAboutSms(context: Context, sender: String, flagged: FlaggedNumber?, signals: List<String>) {
        val title = if (flagged != null) "Message from a reported number" else "This message looks like a scam"
        val text = buildString {
            append("From $sender. ")
            if (flagged != null) {
                append(reportSummary(flagged))
                append(' ')
            }
            if (signals.isNotEmpty()) {
                append("Contains: ${signals.joinToString(", ")}. ")
            }
            append("Open ChengetAI to check the full message.")
        }
        notify(context, CHANNEL_SMS, NOTIFICATION_ID_SMS, title, text, Notification.CATEGORY_MESSAGE)
    }

    private fun reportSummary(flagged: FlaggedNumber): String {
        val plural = if (flagged.reportCount == 1) "time" else "times"
        val category = flagged.topCategory.replace('_', ' ')
        return "Reported ${flagged.reportCount} $plural by the community, mostly for $category."
    }

    private fun notify(
        context: Context,
        channelId: String,
        notificationId: Int,
        title: String,
        text: String,
        category: String,
    ) {
        ensureChannels(context)

        val launch = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
        }

        val notification = builder
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setCategory(category)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        // On API 33+ this is a no-op unless POST_NOTIFICATIONS was granted; the
        // Protection screen asks for it, and screening still logs the detection
        // either way.
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        manager.notify(notificationId, notification)
    }
}
