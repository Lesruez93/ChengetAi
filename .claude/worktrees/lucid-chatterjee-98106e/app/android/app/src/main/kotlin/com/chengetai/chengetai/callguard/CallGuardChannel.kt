package com.chengetai.chengetai.callguard

import android.app.Activity
import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges the Flutter Call Guard screen to Android's screening permissions.
 *
 * Permission requests here deliberately ignore their results. The role dialog
 * and the notification-access settings screen do not report a trustworthy
 * grant signal (the former returns OK on some OEM builds regardless; the
 * latter returns nothing at all), so the Flutter side re-reads [status] when
 * the app resumes and trusts the system APIs themselves. One source of truth,
 * no result plumbing.
 */
class CallGuardChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL_NAME).apply {
        setMethodCallHandler(this@CallGuardChannel)
    }

    private val store = CallGuardStore(activity)

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status())

            "syncConfig" -> {
                val baseUrl = call.argument<String>("baseUrl")
                val countryCode = call.argument<String>("countryCode")
                if (baseUrl.isNullOrBlank() || countryCode.isNullOrBlank()) {
                    result.error("invalid_args", "baseUrl and countryCode are required.", null)
                    return
                }
                store.apiBaseUrl = baseUrl
                store.countryCode = countryCode
                ScamCallNotifier.ensureChannel(activity)
                result.success(null)
            }

            "setEnabled" -> {
                val enabled = call.argument<Boolean>("enabled")
                if (enabled == null) {
                    result.error("invalid_args", "enabled is required.", null)
                    return
                }
                store.isEnabled = enabled
                result.success(status())
            }

            "requestRole" -> {
                requestRole()
                result.success(null)
            }

            "requestSmsPermission" -> {
                requestSmsPermission()
                result.success(null)
            }

            "openNotificationAccessSettings" -> {
                // No runtime prompt exists for notification access; the user
                // must toggle it in Settings themselves.
                activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                result.success(null)
            }

            "requestNotificationPermission" -> {
                requestNotificationPermission()
                result.success(null)
            }

            "openNotificationSettings" -> {
                openNotificationSettings()
                result.success(null)
            }

            "screenedEvents" -> result.success(store.screenedEventsJson())

            "clearScreenedEvents" -> {
                store.clearScreenedEvents()
                result.success(null)
            }

            "simulateEvent" -> {
                val sender = call.argument<String>("sender")
                val channelKey = call.argument<String>("channel")
                val body = call.argument<String>("body")
                if (sender.isNullOrBlank()) {
                    result.error("invalid_args", "sender is required.", null)
                    return
                }
                val threatChannel = ThreatChannel.entries.firstOrNull { it.key == channelKey }
                    ?: ThreatChannel.CALL
                // Runs the exact production pipeline, so this exercises the
                // real base URL, country resolution, warning threshold and
                // notification permission rather than a stub of them.
                ThreatScreener.screenAsync(
                    activity.applicationContext,
                    threatChannel,
                    sender,
                    messageBody = body,
                    simulated = true,
                )
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun status(): Map<String, Any> = mapOf(
        // Call screening exists from API 24, but the role can only be
        // *requested* from an app on API 29+. Below that the user would have
        // to be talked through a settings path that differs per OEM, so the
        // feature reports itself unsupported rather than half-working.
        "isSupported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q),
        "hasRole" to hasRole(),
        "hasSmsPermission" to hasSmsPermission(),
        "hasWhatsAppAccess" to WhatsAppCallListener.isEnabled(activity),
        "isEnabled" to store.isEnabled,
        "hasNotificationPermission" to hasNotificationPermission(),
    )

    private fun hasRole(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val roleManager = activity.getSystemService(RoleManager::class.java) ?: return false
        return roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) &&
            roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
    }

    private fun requestRole() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val roleManager = activity.getSystemService(RoleManager::class.java) ?: return
        if (!roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) return
        if (roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) return
        activity.startActivityForResult(
            roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING),
            REQUEST_CODE_ROLE,
        )
    }

    private fun hasSmsPermission(): Boolean =
        activity.checkSelfPermission(android.Manifest.permission.RECEIVE_SMS) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestSmsPermission() {
        if (hasSmsPermission()) return
        activity.requestPermissions(
            arrayOf(android.Manifest.permission.RECEIVE_SMS),
            REQUEST_CODE_SMS,
        )
    }

    private fun hasNotificationPermission(): Boolean {
        // Below API 33 notifications need no runtime grant, but the user can
        // still have turned the app's notifications off in settings — which
        // fails the same way, so check the effective state rather than the
        // permission alone.
        if (!NotificationManagerCompat.from(activity).areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return activity.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            openNotificationSettings()
            return
        }
        activity.requestPermissions(
            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_CODE_NOTIFICATIONS,
        )
    }

    /**
     * Fallback for when the runtime prompt can no longer appear — the user has
     * denied it twice, or is on a version where it was never a runtime
     * permission. Without this the toggle would look broken with no recourse.
     */
    private fun openNotificationSettings() {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
        activity.startActivity(intent)
    }

    companion object {
        private const val CHANNEL_NAME = "chengetai/call_guard"
        private const val REQUEST_CODE_ROLE = 7301
        private const val REQUEST_CODE_NOTIFICATIONS = 7302
        private const val REQUEST_CODE_SMS = 7303
    }
}
