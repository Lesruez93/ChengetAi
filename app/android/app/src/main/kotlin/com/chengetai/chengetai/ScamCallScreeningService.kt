package com.chengetai.chengetai

import android.annotation.TargetApi
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService

/**
 * Screens incoming calls against the locally-synced blocklist.
 *
 * `CallScreeningService` is the sanctioned way to do this: the platform hands
 * us the number, we answer, and we never need `READ_CALL_LOG` or
 * `READ_PHONE_STATE` — which is also why this passes Play Store review where
 * polling the call log would not. It only runs while the user holds
 * `ROLE_CALL_SCREENING`, which they grant (and can revoke) from the Protection
 * screen.
 *
 * The service is started by the OS per call, in a process that may have no
 * Flutter engine at all, so everything it needs is read from
 * [ProtectionStore]'s native `SharedPreferences`.
 */
@TargetApi(Build.VERSION_CODES.N)
class ScamCallScreeningService : CallScreeningService() {

    override fun onScreenCall(callDetails: Call.Details) {
        // Whatever happens below, the platform needs an answer. Without one the
        // call stays silently suppressed until the framework times us out, so
        // the response is built defensively and always sent.
        var response = CallResponse.Builder().build()

        try {
            response = screen(callDetails)
        } catch (e: Exception) {
            // Fail open: a bug in our screening must never swallow a real call.
        } finally {
            respondToCall(callDetails, response)
        }
    }

    private fun screen(callDetails: Call.Details): CallResponse {
        val allow = CallResponse.Builder().build()

        val store = ProtectionStore(this)
        if (!store.callScreeningEnabled()) return allow

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            callDetails.callDirection != Call.Details.DIRECTION_INCOMING
        ) {
            return allow
        }

        // `handle` is a tel: URI; withheld/unknown callers give us nothing to
        // match on, and short codes normalize to null.
        val msisdn = Msisdn.normalize(callDetails.handle?.schemeSpecificPart) ?: return allow
        val flagged = store.lookup(msisdn) ?: return allow

        val block = flagged.riskLevel == "high" && store.blockHighRiskCalls()
        ProtectionAlerts.warnAboutCall(this, flagged, blocked = block)
        store.recordDetection(
            type = ProtectionStore.TYPE_CALL,
            msisdn = msisdn,
            riskLevel = flagged.riskLevel,
            action = if (block) ProtectionStore.ACTION_BLOCKED else ProtectionStore.ACTION_WARNED,
            reportCount = flagged.reportCount,
            topCategory = flagged.topCategory,
        )

        if (!block) return allow

        return CallResponse.Builder()
            .setDisallowCall(true)
            .setRejectCall(true)
            // Keep the call in the log and let the missed-call notification
            // through: a blocked call the user can't see afterwards is a call
            // they can't second-guess us about.
            .setSkipCallLog(false)
            .setSkipNotification(false)
            .build()
    }
}
