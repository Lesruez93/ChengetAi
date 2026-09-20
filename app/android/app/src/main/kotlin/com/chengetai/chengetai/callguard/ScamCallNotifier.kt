package com.chengetai.chengetai.callguard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.chengetai.chengetai.MainActivity
import com.chengetai.chengetai.R

/**
 * Posts the scam warning for a screened call, SMS or WhatsApp call.
 *
 * A notification rather than a full-screen overlay: during an incoming call
 * the dialer already owns the screen, and an app that draws over it is both
 * fragile across OEM skins and indistinguishable, to a wary user, from the
 * overlay-based scams this product exists to warn about. A high-importance
 * heads-up notification lands above the call UI on every Android 10+ device
 * without SYSTEM_ALERT_WINDOW.
 */
object ScamCallNotifier {

    private const val CHANNEL_ID = "chengetai.scam_warnings"
    private const val NOTIFICATION_ID_BASE = 4200

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Scam warnings",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Warns you when a call or message comes from a number reported for scams."
            enableVibration(true)
        }
        context.getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    /**
     * @param senderVerdict the reputation verdict, or null when the sender is
     *   clean or unresolvable and the warning rests on the message alone.
     * @param messageVerdict the classifier's read on an SMS body, if any.
     * @return true if the warning was actually posted. False when the user has
     *   not granted POST_NOTIFICATIONS, which on Android 13+ is silent — the
     *   caller records it so the app can explain why no warning appeared
     *   rather than leaving the user to assume it works.
     */
    fun warn(
        context: Context,
        channel: ThreatChannel,
        sender: String,
        senderVerdict: NumberVerdict?,
        messageVerdict: MessageVerdict?,
        simulated: Boolean,
    ): Boolean {
        ensureChannel(context)
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            return false
        }

        val title = buildTitle(channel, senderVerdict, messageVerdict)
        val body = buildBody(sender, senderVerdict, messageVerdict)
        val advice = adviceFor(channel)

        val openApp = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(if (simulated) "$title (test)" else title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText("$body\n\n$advice"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(
                if (channel == ThreatChannel.SMS) Notification.CATEGORY_MESSAGE
                else Notification.CATEGORY_CALL,
            )
            .setAutoCancel(true)
            .setContentIntent(openApp)
            .build()

        return try {
            // Distinct IDs per sender and channel so a second warning doesn't
            // silently replace an unread one from the first.
            val id = NOTIFICATION_ID_BASE + ((sender + channel.key).hashCode() and 0xFF)
            NotificationManagerCompat.from(context).notify(id, notification)
            true
        } catch (e: SecurityException) {
            // areNotificationsEnabled() can race a permission revocation.
            false
        }
    }

    private fun buildTitle(
        channel: ThreatChannel,
        senderVerdict: NumberVerdict?,
        messageVerdict: MessageVerdict?,
    ): String {
        val subject = when (channel) {
            ThreatChannel.CALL -> "caller"
            ThreatChannel.WHATSAPP_CALL -> "WhatsApp caller"
            ThreatChannel.SMS -> "message"
        }
        val severe = senderVerdict?.riskLevel == "high" || messageVerdict?.verdict == "scam"
        return if (severe) {
            if (channel == ThreatChannel.SMS) "Likely scam message" else "Likely scam $subject"
        } else {
            if (channel == ThreatChannel.SMS) "Suspicious message" else "This $subject was reported"
        }
    }

    private fun buildBody(
        sender: String,
        senderVerdict: NumberVerdict?,
        messageVerdict: MessageVerdict?,
    ): String {
        val parts = mutableListOf<String>()
        senderVerdict?.let { v ->
            parts += if (v.reportCount == 1) "1 report" else "${v.reportCount} reports"
            v.topCategory?.let { parts += humanizeCategory(it) }
        }
        // Naming the classifier separately keeps the two signals legible: a
        // clean number sending a known script is a different situation from a
        // number the community already flagged, and the user's next move
        // differs accordingly.
        messageVerdict?.takeIf { it.shouldWarn }?.let {
            parts += "message reads as ${it.verdict}"
        }
        return if (parts.isEmpty()) sender else "$sender — ${parts.joinToString(" · ")}"
    }

    private fun adviceFor(channel: ThreatChannel): String = when (channel) {
        ThreatChannel.SMS ->
            "Don't tap links or send codes. Check your balance in your wallet app, not from this message."
        else ->
            "Don't share codes or PINs, and don't reverse any payment they ask about."
    }

    /**
     * Mirrors `humanizeCategory` in lib/core/constants.dart for the handful of
     * categories, falling back to a title-cased key so a category added on the
     * backend still reads legibly here without an app release.
     */
    private fun humanizeCategory(key: String): String = when (key) {
        "mobile_money_reversal" -> "Wrong deposit / reversal"
        "fake_job" -> "Fake job or recruitment"
        "fake_investment" -> "Fake investment"
        "fake_loan_aid" -> "Fake loan or grant"
        "sim_swap" -> "SIM swap"
        "otp_phishing" -> "OTP or PIN phishing"
        "impersonation" -> "Bank or telco impersonation"
        "faith_seed" -> "Faith-based 'seed' request"
        else -> key.split("_").filter { it.isNotEmpty() }.joinToString(" ") { part ->
            part.replaceFirstChar { it.uppercase() }
        }
    }
}
