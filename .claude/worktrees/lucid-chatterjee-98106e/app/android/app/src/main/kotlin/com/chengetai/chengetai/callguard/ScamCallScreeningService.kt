package com.chengetai.chengetai.callguard

import android.annotation.TargetApi
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService

/**
 * Screens incoming phone calls against the number reputation API.
 *
 * Android calls [onScreenCall] for every incoming call once the user has
 * granted this app the call screening role. Two rules shape everything here:
 *
 * 1. **Respond first, look up second.** Telecom gives a screening service a
 *    few seconds to call `respondToCall` and holds the call until it does.
 *    A network round trip inside that window would delay every single
 *    incoming call by up to our HTTP timeout, and time out the screening
 *    request on a slow connection — turning a safety feature into a reason
 *    people miss calls. So we allow the call immediately and warn afterwards.
 *
 * 2. **Never reject a call.** `setDisallowCall` is deliberately not used even
 *    for a high-risk verdict. A false positive would silently swallow a real
 *    call from someone whose number was recycled or maliciously reported, and
 *    the user would have no way to know it happened. The product's job is to
 *    tell the user who is calling; the decision to answer stays theirs.
 *
 * Note this covers carrier calls only. A WhatsApp call never reaches Telecom's
 * screening API — see [WhatsAppCallListener].
 */
@TargetApi(Build.VERSION_CODES.N)
class ScamCallScreeningService : CallScreeningService() {

    override fun onScreenCall(callDetails: Call.Details) {
        // Rule 1: let the call through before doing anything that can block.
        respondToCall(callDetails, CallResponse.Builder().build())

        if (callDetails.callDirection != Call.Details.DIRECTION_INCOMING) return

        val number = callDetails.handle?.schemeSpecificPart
        if (number.isNullOrBlank()) {
            // Withheld or unknown caller ID. Nothing to look up, and nothing
            // useful to tell the user that the dialer isn't already showing.
            return
        }

        ThreatScreener.screenAsync(applicationContext, ThreatChannel.CALL, number)
    }
}
