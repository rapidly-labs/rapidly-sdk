//
//  RapidlyEngine.swift
//  RapidlyEngine
//
//  Copyright (c) 2026 Rapidly Labs AS.
//
//  You are not allowed to use, distribute or modify this code without
//  a written permission from Rapidly Labs AS.
//
//  Swift-native API for the Rapidly SDK. Ships as a SwiftPM source
//  target on top of the binary RapidlyEngineC xcframework. Customers
//  who add the Rapidly SDK via SwiftPM get this Swift class plus the
//  re-exported C API in a single `import RapidlyEngine`.
//

import Foundation
@_exported import RapidlyEngineC
import RapidlyEngineC.Private  // internal Obj-C++ adapter; not re-exported to consumers

/// Swift-native audio processor wrapping the Rapidly C engine.
///
/// ## Threading
///
/// A `RapidlyEngine` instance is **not safe to call concurrently from
/// multiple threads** at any moment. The class follows the same
/// concurrency model as Apple's `AVAudioEngine` and similar real-time
/// audio types: the customer is responsible for serialising access.
///
/// Apps that route audio through a render callback on a high-priority
/// audio thread should follow this exact stop sequence:
///
/// 1. Stop your audio session / unit / render callback first. After
///    this returns, the audio thread is guaranteed not to be inside
///    `addAudio*`, `getAudio*`, `getProcessorInfo()`, etc.
/// 2. Call `close()` on this engine.
/// 3. Release the engine reference.
///
/// **Calling `close()` while another thread is mid-call into the same
/// engine is undefined behaviour** — it can crash, corrupt memory, or
/// behave unpredictably. This is consistent with how every real-time
/// audio SDK on Apple platforms behaves; coordinating thread lifecycle
/// is a customer responsibility, not the SDK's.
///
/// Under Swift 6 strict concurrency, `RapidlyEngine` is intentionally
/// NOT declared `Sendable` for the same reason — sending it across
/// actor boundaries without serialising access is unsafe. If you must
/// share the engine across actors, wrap it in your own
/// `@unchecked Sendable` adapter and serialise access in that wrapper.
///
/// ## Lifetime
///
/// Construction loads the model file and (per the global licence pool
/// at that moment) bakes in the watermarked-or-not state for the lifetime
/// of the instance. Call `RapidlyEngine.addLicense(_:)` BEFORE
/// construction to avoid watermarking.
///
/// For real-time audio (the dominant use case), explicit `close()` is
/// effectively required. ARC-only release is safe only in contexts
/// where no audio thread can possibly still be in flight (e.g.,
/// short-lived offline processing). The `deinit` calls `close()`
/// defensively, but its timing relative to your audio session is not
/// deterministic. Follow the stop sequence above for safe release from
/// real-time audio contexts.
public class RapidlyEngine {
    
    public struct ProcessorInfo {
        public var sampleRate: Double
        public var numOfModelChannels: Int
        public var latencyInSamples: Int
    }

    public enum Parameters: UInt32 {
        /** The maximum attenuation of the unwanted signal in dB. The
             valid value range is <-inf, 0] */
        case maximumAttenuation = 0x0001
        /** The sensitivity of the processing in percent ranging from
             -100% to 100%. 0% is neutral and positive values will increase
             the amount of reduction. */
        case sensitivity = 0x0002
        /** Enables or disables mask frequency extrapolation. When using
             models that aren't trained on the full frequency band, this setting
             determines if the output audio should be band-limited to the
             frequency range of the model or if the high-frequency masks should
             be extrapolated. Settings below 0.5 disables the extrapolaion
             while settings equal or above 0.5 enables it.  */
        case maskExtrapolation = 0x0003
        /** The stem dependent sensitivities of the processing in
             percent ranging from -100% to 100%. 0% is neutral and positive
             values will increase the amount of reduction. You can set
             individual stems by adding the model index to the define, so
             firstModelSensitivity will be the first model,
             firstModelSensitivity + 1 the second, and so forth. */
        case firstModelSensitivity = 0x1000
    }
   
    /// Which activation mode is in use.
    public enum ActivationMode: Int {
        /// No activation key in use.
        case none = 0
        /// The engine checks with the key itself.
        case server = 1
        /// Checks go through the activation request handler.
        case client = 2
    }

    /// Activation state, from `RapidlyEngine.activationStatus()`.
    public struct ActivationStatus {
        /// True when the activation licence currently allows clean output.
        public var authorized: Bool
        public var mode: ActivationMode
        /// Unix seconds when the licence stops working without a successful check, 0 when none.
        public var expiresAt: Int64
        public var checkIntervalSeconds: Int64
        public var offlinePeriodSeconds: Int64
        /// Unix seconds of the last check sent, 0 when none.
        public var lastCheckAt: Int64
        /// Unix seconds of the last successful check, 0 when none.
        public var lastSuccessAt: Int64
        /// Code of a standing refusal, for example "device_deactivated", or nil.
        public var lastRefusalCode: String?
        /// Where the device id came from: "os", "host" or "generated".
        public var idSource: String
        /// First 8 characters of the device hash, as shown in the dashboard.
        public var deviceHashPrefix: String
    }

    /// Hands the engine your backend's reply to an activation request: the HTTP status and the raw
    /// body, unchanged. Use status 0 when the backend could not be reached. Callable from any thread.
    public typealias ActivationSubmit = (_ httpStatus: Int, _ body: String?) -> Void

    private var engineAdapter: EngineAdapterObjC

    /**
     * Creates an audio processor, loads a model file and returns a processor instance if successful.
     * - Parameters:
     *     - modelFilepath: Pointer to a string containing the file path of the model file to load.
     *     - numOfChannels: The number of channels in the audio to process.
     *     - sampleRate: The sample rate of the audio to process.
     * - Returns: A valid object on success. Returns `nil` only if the model file is missing or
     *   unreadable. Licence coverage never causes `nil`: a model your licence does not cover (or
     *   any model loaded with no licence) still constructs successfully, but its output is watermarked.
     */
    public init?(modelFilepath: String, numOfChannels: UInt32, sampleRate: Double) {
        guard let adapter = EngineAdapterObjC(modelFilepaths: [modelFilepath], numOfChannels: numOfChannels, sampleRate: sampleRate) else {
            return nil
        }
        self.engineAdapter = adapter
    }
    
    /**
     * Creates a processor that performs stem separation, loads a set of model files and returns a processor instance if successful.
     * The number of stems is derived from modelFilepaths.count -- the array already carries its length.
     * - Parameters:
     *     - modelFilepaths: An array of strings containing the file paths of the model files to load.
     *     - numOfChannels: The number of channels in the audio to process.
     *     - sampleRate: The sample rate of the audio to process.
     * - Returns: A valid object on success. Returns `nil` only if a model file is missing or
     *   unreadable. Licence coverage never causes `nil`: a model your licence does not cover (or
     *   any model loaded with no licence) still constructs successfully, but its output is watermarked.
     */
    public init?(modelFilepaths: [String], numOfChannels: UInt32, sampleRate: Double) {
        guard let adapter = EngineAdapterObjC(modelFilepaths: modelFilepaths, numOfChannels: numOfChannels, sampleRate: sampleRate) else {
            return nil
        }
        self.engineAdapter = adapter
    }
    
    /**
     Adds a license key to the Rapidly SDK. Licence state is global, so this must be called
     BEFORE constructing any `RapidlyEngine` instance. Without a covering licence, the SDK
     operates in a watermarked demo mode that audibly degrades its output, and that state is
     baked into each processor at creation time -- a later licence call does not retroactively
     un-watermark already-created processors.
     - Parameters:
        - licenseString: A string containing a license received from Rapidly.
     - Returns: `true` if the license check succeeded, otherwise `false`.
    */
    public static func addLicense(_ licenseString: String) -> Bool {
        return EngineAdapterObjC.addLicense(licenseString)
    }

    /**
     Enables client-mode activation: the activation key stays on your backend and the engine
     reaches it through this handler. The handler runs on an engine background thread whenever a
     check is due. Send `request` unchanged, byte for byte, to your backend, which forwards it to
     Rapidly with the key, then call `submit` with the reply. The handler runs on the engine's
     check thread: return within 60 seconds, use a request timeout in your backend call, or
     reply later with `submit`. `submit` may be called later and from
     any thread. Pass `nil` to remove the handler.
     - Parameters:
        - handler: Receives the request body and the `submit` completion.
    */
    public static func setActivationRequestHandler(_ handler: ((_ request: String, _ submit: @escaping ActivationSubmit) -> Void)?) {
        guard let handler = handler else {
            EngineAdapterObjC.setActivationRequestHandler(nil)
            return
        }
        EngineAdapterObjC.setActivationRequestHandler { request in
            handler(request) { httpStatus, body in
                EngineAdapterObjC.submitActivationResponse(withStatus: httpStatus, body: body)
            }
        }
    }

    /**
     Async form of `setActivationRequestHandler(_:)`: return the backend's reply, or `nil` to send
     no reply now (call `submitActivationResponse(httpStatus:body:)` later). Pass `nil` to remove
     the handler.
    */
    public static func setActivationRequestHandlerAsync(_ handler: (@Sendable (_ request: String) async -> (status: Int, body: String?)?)?) {
        guard let handler = handler else {
            EngineAdapterObjC.setActivationRequestHandler(nil)
            return
        }
        EngineAdapterObjC.setActivationRequestHandler { request in
            Task {
                if let reply = await handler(request) {
                    EngineAdapterObjC.submitActivationResponse(withStatus: reply.status, body: reply.body)
                }
            }
        }
    }

    /// Hands the engine your backend's reply to the latest activation request. Callable from any thread.
    public static func submitActivationResponse(httpStatus: Int, body: String?) {
        EngineAdapterObjC.submitActivationResponse(withStatus: httpStatus, body: body)
    }

    /// Runs the next activation check now instead of on its schedule. Does not block.
    public static func refreshActivation() {
        EngineAdapterObjC.refreshActivation()
    }

    /// The activation state, or `nil` when no activation key or request handler is in use.
    public static func activationStatus() -> ActivationStatus? {
        guard let raw = EngineAdapterObjC.activationStatus() else { return nil }
        func int64(_ key: String) -> Int64 { (raw[key] as? NSNumber)?.int64Value ?? 0 }
        let refusal = raw["lastRefusalCode"] as? String ?? ""
        return ActivationStatus(
            authorized: (raw["authorized"] as? NSNumber)?.boolValue ?? false,
            mode: ActivationMode(rawValue: Int(int64("mode"))) ?? .none,
            expiresAt: int64("expiresAt"),
            checkIntervalSeconds: int64("checkIntervalSeconds"),
            offlinePeriodSeconds: int64("offlinePeriodSeconds"),
            lastCheckAt: int64("lastCheckAt"),
            lastSuccessAt: int64("lastSuccessAt"),
            lastRefusalCode: refusal.isEmpty ? nil : refusal,
            idSource: raw["idSource"] as? String ?? "",
            deviceHashPrefix: raw["deviceHashPrefix"] as? String ?? "")
    }

    /**
     * Adds floating point PCM encoded audio from separate channels to the Rapidly audio processor.
     * - Parameters:
     *     - pcmChannels: Pointer to an array of channel data pointers, each pointing to sampled PCM values as 32-bit floating point.
     *     - numOfSamples: The number of samples to add
     */
    public func addAudio(pcmChannels: [UnsafeMutableRawPointer?], numOfSamples: UInt32) {
        engineAdapter.addAudio(pcmChannels, numOfSamples:numOfSamples)
    }

    /**
     * Adds floating point PCM encoded audio from a single channel-interleaved buffer to the Rapidly audio processor.
     * - Parameters:
     *     - pcmChannels: Pointer to a 32-bit floating point buffer containing channel-interleaved PCM audio (stereo audio will be in the form "Left Sample 1", "Right Sample 1", "Left Sample 2"...).
     *     - numOfSamples: The number of samples to add
     */
    public func addAudioInterleaved(pcmChannels: UnsafeMutableRawPointer?, numOfSamples: UInt32) {
        engineAdapter.addAudioInterleaved(pcmChannels, numOfSamples:numOfSamples)
    }

    /**
     * Returns the number of samples that are ready after model inference. If the end of the stream has been reached, endOfStream can
     * can be set to true to retrieve the number of remaining samples in the processing queue.
     * - Returns: Number of completed samples.
     */
    public func getNumOfPendingSamples() -> UInt32 {
        return engineAdapter.getNumOfPendingSamples()
    }

    /**
     * Gets floating point PCM encoded audio in separate channels after processing. The number of requested samples must be less or equal to the number of available samples as returned by ``getNumOfPendingSamples``.
     * - Parameters:
     *     - pcmChannels: Pointer to an array of channel data pointers, each receiving sampled PCM values as 32 bit floating point.
     *     - numOfSamples: The number of samples to retrieve
     */
    @discardableResult
    public func getAudio(pcmChannels: [UnsafeMutableRawPointer?], numOfSamples: UInt32) -> Bool {
        return engineAdapter.getAudio(pcmChannels, numOfSamples: numOfSamples)
    }

    /**
     * Gets floating point PCM encoded audio in a single channel-interleaved buffer after processing. The number of requested samples must be less or equal to the number of available samples as returned by ``getNumOfPendingSamples``.
     * - Parameters:
     *     - pcmChannels: Pointer to an array of channel data pointers, each receiving sampled PCM values as 32 bit floating point.
     *     - numOfSamples: The number of samples to retrieve
     */
    @discardableResult
    public func getAudioInterleaved(pcmChannels: UnsafeMutableRawPointer?, numOfSamples: UInt32) -> Bool {
        return engineAdapter.getAudioInterleaved(pcmChannels, numOfSamples:numOfSamples)
    }

    /**
     * Resets the processor state and clears all delay lines.
     */
    public func resetProcessorState() {
        engineAdapter.resetProcessorState()
    }

    /**
     * Get information about the Rapidly processor.
     - Returns: A RapidlyEngine.ProcessorInfo structure
     */
    public func getProcessorInfo() -> ProcessorInfo {
        let info = engineAdapter.getProcessorInfo()
        return ProcessorInfo(sampleRate: info.sampleRate, numOfModelChannels: Int(info.numOfModelChannels), latencyInSamples: Int(info.latencyInSamples))
    }
    
    /**
     * Returns a parameter value
     * - Parameters:
     *     - for: One of the RapidlyEngine.Parameters.
     * - Returns: The current parameter value.
     */
    public func getParameterValue(for param: Parameters) -> Float {
        return engineAdapter.getParameterValue(for: param.rawValue)
    }

    /**
     * Sets a parameter value
     * - Parameters:
     *     - for: One of the RapidlyEngine.Parameters.
     *     - to: The new parameter value.
     */
    public func setParameter(for param: Parameters, to value: Float) {
        engineAdapter.setParameterFor(param.rawValue, to: value)
    }

    /**
     Releases the underlying processor, freeing its resources. Safe to call
     multiple times. After `close`, all audio methods become no-ops and read
     methods return false / zero. For real-time audio, calling this from your
     audio-stop callback BEFORE releasing references to the engine is
     effectively required: it avoids a race where the audio thread is still
     inside `addAudio` / `getAudio` when the processor is freed. The engine's
     `deinit` also calls `close` defensively, but its timing relative to your
     audio session is not deterministic, so do not rely on it for real-time
     contexts.
    */
    public func close() {
        engineAdapter.close()
    }

}
