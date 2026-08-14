package com.chengetai.chengetai

import android.Manifest
import android.app.Activity
import android.app.role.RoleManager
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The Dart <-> native bridge for call/SMS screening.
 *
 * Everything screening-related that Flutter cannot do itself lives behind this
 * one channel: reading the role/permission state, requesting it, pushing a
 * freshly-synced blocklist into native storage, and reading back what was
 * detected while the app was closed.
 *
 * Role and permission prompts are answered asynchronously by the OS, so a
 * request parks its [MethodChannel.Result] in [pendingResult] and
 * [MainActivity] hands the answer back through [onActivityResult] /
 * [onRequestPermissionsResult]. Every one of those paths resolves with the same
 * full status map, so Dart never has to reason about which prompt it was.
 */
class ProtectionChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {

    private val store = ProtectionStore(activity)
    private var pendingResult: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.success(status())

            "syncFlaggedNumbers" -> {
                val raw = call.argument<List<Map<String, Any?>>>("numbers") ?: emptyList()
                val version = call.argument<String>("version") ?: ""
                store.replaceFlagged(
                    raw.map {
                        FlaggedNumber(
                            msisdn = it["msisdn"] as? String ?: "",
                            riskLevel = it["risk_level"] as? String ?: "medium",
                            reportCount = (it["report_count"] as? Number)?.toInt() ?: 0,
                            topCategory = it["top_category"] as? String ?: "other",
                        )
                    }.filter { it.msisdn.isNotEmpty() },
                    version,
                )
                result.success(status())
            }

            "setSetting" -> {
                val key = call.argument<String>("key")
                val enabled = call.argument<Boolean>("enabled")
                if (key == null || enabled == null) {
                    result.error("bad_args", "setSetting requires 'key' and 'enabled'.", null)
                    return
                }
                try {
                    store.setSetting(key, enabled)
                    result.success(status())
                } catch (e: IllegalArgumentException) {
                    result.error("bad_args", e.message, null)
                }
            }

            "requestCallScreeningRole" -> requestCallScreeningRole(result)
            "requestSmsPermission" -> requestPermission(
                Manifest.permission.RECEIVE_SMS, REQUEST_SMS_PERMISSION, result,
            )
            "requestNotificationPermission" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                    result.success(status()) // granted at install time before API 33
                } else {
                    requestPermission(
                        Manifest.permission.POST_NOTIFICATIONS, REQUEST_NOTIFICATION_PERMISSION, result,
                    )
                }
            }

            "getDetections" -> result.success(store.recentDetections().toString())
            "clearDetections" -> {
                store.clearDetections()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    // -- state --

    private fun status(): Map<String, Any> = mapOf(
        "callScreeningSupported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && roleAvailable()),
        "callScreeningRoleHeld" to roleHeld(),
        "smsPermissionGranted" to hasPermission(Manifest.permission.RECEIVE_SMS),
        "notificationsGranted" to (
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                hasPermission(Manifest.permission.POST_NOTIFICATIONS)
            ),
        "callScreeningEnabled" to store.callScreeningEnabled(),
        "smsScreeningEnabled" to store.smsScreeningEnabled(),
        "blockHighRiskCalls" to store.blockHighRiskCalls(),
        "flaggedCount" to store.flaggedCount(),
        "flaggedVersion" to store.version(),
        "syncedAt" to store.syncedAt(),
    )

    private fun roleManager(): RoleManager? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            activity.getSystemService(RoleManager::class.java)
        } else {
            null
        }

    private fun roleAvailable(): Boolean =
        roleManager()?.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) ?: false

    private fun roleHeld(): Boolean =
        roleManager()?.isRoleHeld(RoleManager.ROLE_CALL_SCREENING) ?: false

    private fun hasPermission(permission: String): Boolean =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    // -- prompts --

    private fun requestCallScreeningRole(result: MethodChannel.Result) {
        val manager = roleManager()
        if (manager == null || !manager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
            // Pre-Android 10, or a device whose dialer doesn't expose the role.
            // Not an error the user can act on, so report state rather than throw.
            result.success(status())
            return
        }
        if (manager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
            result.success(status())
            return
        }
        if (!park(result)) return

        activity.startActivityForResult(
            manager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING),
            REQUEST_CALL_SCREENING_ROLE,
        )
    }

    private fun requestPermission(permission: String, requestCode: Int, result: MethodChannel.Result) {
        if (hasPermission(permission)) {
            result.success(status())
            return
        }
        if (!park(result)) return
        activity.requestPermissions(arrayOf(permission), requestCode)
    }

    /** Parks [result] until the OS answers. Returns false (and fails the call)
     *  if another prompt is already outstanding — resolving a
     *  [MethodChannel.Result] twice crashes the engine. */
    private fun park(result: MethodChannel.Result): Boolean {
        if (pendingResult != null) {
            result.error("busy", "Another permission request is already in progress.", null)
            return false
        }
        pendingResult = result
        return true
    }

    private fun resolvePending() {
        val result = pendingResult ?: return
        pendingResult = null
        result.success(status())
    }

    fun onActivityResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_CALL_SCREENING_ROLE) return false
        // The result code is ignored on purpose: a user who declines, or backs
        // out, leaves the role unheld, and re-reading the real state is more
        // trustworthy than trusting RESULT_OK.
        resolvePending()
        return true
    }

    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_SMS_PERMISSION && requestCode != REQUEST_NOTIFICATION_PERMISSION) {
            return false
        }
        resolvePending()
        return true
    }

    companion object {
        const val CHANNEL = "chengetai/protection"

        private const val REQUEST_CALL_SCREENING_ROLE = 7301
        private const val REQUEST_SMS_PERMISSION = 7302
        private const val REQUEST_NOTIFICATION_PERMISSION = 7303
    }
}
