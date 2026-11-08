/*

This file is part of the Rapidly SDK for cross-platform model inference.
Copyright (c) 2026 Rapidly Labs AS.

You are not allowed to use, distribute or modify this code without
a written permission from Rapidly Labs AS.

*/

//
//  Activation.kt
//  RapidlyEngine -- Kotlin / Android binding
//
//  Types for activation keys. Kept apart from RapidlyEngine.kt so the pure
//  Kotlin parts (request dispatch, status decoding) load without the native
//  libraries and can be unit tested on the host JVM.
//

package io.rapidly.engine

/**
 * Receives the engine's activation requests (client mode).
 *
 * The activation key stays on your backend. When a check is due the engine
 * calls [onRequest] on its check thread: return within 60 seconds, use a
 * request timeout in your backend call, or reply later with `submit`. Send [request] unchanged, byte
 * for byte, to your backend, which forwards it to Rapidly with the key, then
 * call `submit(httpStatus, body)` with the reply unchanged (use status 0 when
 * the backend could not be reached). `submit` may be called later and from
 * any thread.
 */
public fun interface ActivationRequestHandler {
    public fun onRequest(request: String, submit: (Int, String?) -> Unit)
}

/** Which activation mode is in use. */
public enum class ActivationMode {
    /** No activation key in use. */
    NONE,

    /** The engine checks with the key itself. */
    SERVER,

    /** Checks go through the [ActivationRequestHandler]. */
    CLIENT,
}

/** Activation state, from [RapidlyEngine.getActivationStatus]. */
public data class ActivationStatus(
    /** True when the activation licence currently allows clean output. */
    val authorized: Boolean,
    val mode: ActivationMode,
    /** Unix seconds when the licence stops working without a successful check, 0 when none. */
    val expiresAt: Long,
    /** How often an online device checks, from the licence. */
    val checkIntervalSeconds: Long,
    /** How long the licence lasts without a successful check. */
    val offlinePeriodSeconds: Long,
    /** Unix seconds of the last check sent, 0 when none. */
    val lastCheckAt: Long,
    /** Unix seconds of the last successful check, 0 when none. */
    val lastSuccessAt: Long,
    /** Code of a standing refusal, for example "device_deactivated", or null. */
    val lastRefusalCode: String?,
    /** Where the device id came from: "os", "host" or "generated". */
    val idSource: String,
    /** First 8 characters of the device hash, as shown in the dashboard. */
    val deviceHashPrefix: String,
) {
    internal companion object {
        /**
         * Decodes the ten fields the JNI layer returns, in order: authorized
         * (0 or 1), mode, expiresAt, checkIntervalSeconds,
         * offlinePeriodSeconds, lastCheckAt, lastSuccessAt, lastRefusalCode,
         * idSource, deviceHashPrefix.
         */
        fun fromNative(fields: Array<String>): ActivationStatus = ActivationStatus(
            authorized = fields[0] == "1",
            mode = ActivationMode.values().getOrNull(fields[1].toIntOrNull() ?: 0) ?: ActivationMode.NONE,
            expiresAt = fields[2].toLongOrNull() ?: 0L,
            checkIntervalSeconds = fields[3].toLongOrNull() ?: 0L,
            offlinePeriodSeconds = fields[4].toLongOrNull() ?: 0L,
            lastCheckAt = fields[5].toLongOrNull() ?: 0L,
            lastSuccessAt = fields[6].toLongOrNull() ?: 0L,
            lastRefusalCode = fields[7].ifEmpty { null },
            idSource = fields[8],
            deviceHashPrefix = fields[9],
        )
    }
}

/**
 * Routes a request arriving from the native layer to the current handler.
 * [sink] is what `submit` calls.
 */
internal class ActivationDispatcher(private val sink: (Int, String?) -> Unit) {

    @Volatile
    var handler: ActivationRequestHandler? = null

    fun dispatch(request: String) {
        val current = handler ?: return
        try {
            current.onRequest(request, sink)
        } catch (error: Throwable) {
            // A handler that throws has not reached its backend: tell the engine so.
            sink(0, null)
        }
    }
}
