# AGENTS.md — integration guide for AI coding agents

This file is read by AI coding tools (Claude Code, Cursor, GitHub Copilot, Continue, Aider, etc.) when assisting a customer who has added the Rapidly SDK to their project. It tells the agent what the SDK is, how to integrate it correctly, and what to avoid.

## What the Rapidly SDK is

A native, cross-platform C++ library that ships a set of AI models for real-time audio separation (speech denoise, dereverb, and related models). Designed to process audio on-device, no GPU required; audio never leaves the device. Licence keys need no network; subscription and activation keys contact Rapidly's API for licensing and billing only. Customers embed the SDK binary into their own application and call into it from C, C++, Python, or any language with a C-FFI.

## Quickstart

1. Choose a binary for the customer's platform from `bin/`. v1.2 ships: `bin/linux-x64/`, `bin/linux-arm64/`, `bin/windows-x64/`, `bin/windows-x86/`, `bin/macos/`, `bin/ios/`, `bin/android-arm64/`. For Apple platforms, prefer the signed `bin/RapidlyEngine.xcframework` (also exposed as a Swift Package via `Package.swift` at the distribution root -- Xcode → Add Package Dependencies). For Android Kotlin, prefer the `.aar` (`implementation("io.rapidly:rapidly-sdk:1.2.0")` from Maven Central, or `rapidly-sdk-1.2.0.aar` in the GitHub release) -- bundles `arm64-v8a` and exposes the `io.rapidly.engine.RapidlyEngine` Kotlin class. Embed the appropriate artefact into the customer's application. WebAssembly is coming in a future release. See `CHANGELOG.md`.
2. Include the public header `include/RapidlyEngine.h` for C / C++. On Apple platforms: `import RapidlyEngine` via SwiftPM, or `import RapidlyEngineC` via drag-and-drop xcframework. On Android Kotlin: `import io.rapidly.engine.RapidlyEngine`.
3. At application startup, register the customer's key with `rapidlyAddLicense(const char* licenseString)`. Rapidly issues three kinds of key: licence keys (`lk_…`), subscription keys (`sk_…`) and activation keys (`ak_…`); the section "Keys, and server mode versus client mode" below says what each one needs. The customer pastes the key from their dashboard or build configuration. Multiple keys may be registered by calling `rapidlyAddLicense` repeatedly.
4. Load a model file from `models/` with `rapidlyCreateProcessor(const char* modelFilepath, int32_t numOfChannels, double sampleRate)`. The model file extension is `.rapidly`.
5. Feed audio in with `rapidlyAddAudioInterleaved`. Processing adds latency and releases output in model-sized hops, so call `rapidlyGetNumOfPendingSamples` and read exactly that many samples with `rapidlyGetAudioInterleaved`; a read that asks for more than is pending returns `false` and writes nothing. See `examples/process-file/` for a working CLI demo.

## Keys, and server mode versus client mode

Every key is registered the same way: `rapidlyAddLicense` (Swift and Kotlin `RapidlyEngine.addLicense`, Python `add_license`) at application startup, before any processor is created. The SDK accepts whichever kind of key the customer has; which kind that is was agreed with Rapidly, not decided in code.

The two networked keys (subscription and activation) run in one of two modes. The mode follows from where the SDK runs:

- **Server mode.** The SDK runs on the customer's own servers. The key is passed to `rapidlyAddLicense` and the SDK talks to Rapidly itself.
- **Client mode.** The SDK runs inside an app on end users' devices. The key stays on the customer's backend and is never shipped in the app; the SDK reaches Rapidly only through that backend, using the calls named below.

### Licence key (`lk_…`)

Verified on the device, no network. Covers a fixed set of models and latency variants. For desktop and embedded products licensed per product or per site. No modes: register it and go.

### Subscription key (`sk_…`)

Usage-based. Each end user's processing is bracketed with `rapidlyStartSession` and `rapidlyStopSession`; the session is the unit that is billed, in both modes.

- *Server mode:* `rapidlyAddLicense("sk_…")`, then sessions.
- *Client mode:* the key stays on the backend, which mints short-lived tokens: `POST https://api.rapidly.io/sdk/v1/token` with the key in the `X-Auth-Key` header and a JSON body `{"external_user_id": "<your id for this end user>", "aud": ["session", "pulse", "telemetry"]}`; the reply is `{"token": "…", "expires_at": …}` and a token lives for an hour. The app registers `rapidlySetTokenProvider`: when the SDK needs a token it calls the provider on a background thread; the provider fetches one from the backend and returns it, or nothing, which the SDK treats as offline. A non-zero `forceRefresh` means the previous token was rejected and a new one must be minted. Then sessions as above. The token provider is C API only in this version; the Swift, Kotlin and Python bindings do not expose it.

### Activation key (`ak_…`)

One licence per device. The SDK checks in at app start and on a regular interval, and the device stays licensed offline for the key's offline period after the last successful check.

- *Server mode:* `rapidlyAddLicense("ak_…")`; the SDK checks in by itself.
- *Client mode:* register `rapidlySetActivationRequestHandler`. When a check is due, the SDK hands the handler a request; the backend forwards it unchanged as the body of `POST https://api.rapidly.io/sdk/v1/activation/check` with the key in the `X-Auth-Key` header, and the app passes the reply to `rapidlySubmitActivationResponse`. `rapidlyGetActivationStatus` reports whether the device is licensed, when the licence expires and any refusal code. The Swift, Kotlin and Python bindings expose the same calls plus a refresh; see each binding's README.

In every mode, a model the key does not cover still loads and runs, with watermarked output.

## Python quickstart

```python
import rapidly

rapidly_engine = rapidly.RapidlyEngine()
rapidly_engine.add_license("lk_...")

processor = rapidly_engine.create_processor("models/speech-denoise-32ms.v1.1.rapidly", 2, 48000)
# feed audio buffers in / out via processor methods
```

See `bindings/python/examples.py` for a more complete walkthrough. The Python wrapper is `pip install rapidly`.

## Swift quickstart (Apple platforms, SwiftPM install)

```swift
import RapidlyEngine

RapidlyEngine.addLicense("lk_...")               // licence first
let engine = RapidlyEngine(
    modelFilepath: "models/speech-denoise-32ms.v1.1.rapidly",
    numOfChannels: 2,
    sampleRate: 48000
)
engine?.addAudioInterleaved(pcmChannels: inputBuffer, numOfSamples: numSamples)
// Processing adds latency and releases output in model-sized hops, so ask how
// many samples are ready and read exactly that many (outputBuffer must hold
// channels * pending floats). Asking for more returns false and writes nothing.
if let pending = engine?.getNumOfPendingSamples(), pending > 0 {
    engine?.getAudioInterleaved(pcmChannels: outputBuffer, numOfSamples: pending)
}
```

The initialiser returns `nil` only if the model file is missing or unreadable. Licence coverage never affects whether a model loads, only whether the output is watermarked: a model that your licence does not cover (or any model loaded with no licence) still loads and runs, but its output is watermarked. Always call `RapidlyEngine.addLicense(...)` at app startup before creating any processor.

## Kotlin quickstart (Android, Gradle install)

```kotlin
import io.rapidly.engine.RapidlyEngine

RapidlyEngine.addLicense("lk_...")                            // licence first
val engine = RapidlyEngine.create(
    modelFilepath = modelPathOnDisk,                          // copy from assets to cacheDir first
    numOfChannels = 2,
    sampleRate = 48000.0,
)
engine?.addAudioInterleaved(inputBuffer, numSamples)          // direct FloatBuffer
// Processing adds latency and releases output in model-sized hops, so ask how
// many samples are ready and read exactly that many (outputBuffer must hold
// channels * pending floats). Asking for more returns false and writes nothing.
val pending = engine?.getNumOfPendingSamples() ?: 0
if (pending > 0) engine?.getAudioInterleaved(outputBuffer, pending)
engine?.close()
```

Audio buffers must be direct (`ByteBuffer.allocateDirect(n * 4).order(ByteOrder.nativeOrder()).asFloatBuffer()`) for the zero-copy JNI path. The model path must be a filesystem path; ship the `.rapidly` model in `assets/` and copy it to `context.cacheDir` on first use. `RapidlyEngine.create(...)` returns `null` only if the model file is missing or unreadable -- the parallel of Swift's `init?` returning `nil`. Licence semantics are identical to Swift: an uncovered model still loads and runs, but watermarked. `RapidlyEngine` implements `AutoCloseable`; prefer `engine.use { }` for short-lived processing, or call `close()` explicitly from your audio-stop path for real-time use.

## Things to get right

- **Licence before model.** Always call `rapidlyAddLicense` before `rapidlyCreateProcessor`. A model loaded without a covering licence will produce watermarked (audibly degraded) output.
- **Per-model and per-latency entitlement.** Each licence key encodes which models and which latency variants it permits. If the customer's licence covers `speech-denoise-96ms.v1.1.rapidly` but they try to load `speech-denoise-32ms.v1.1.rapidly`, it will fall through to the watermark path. This is by design.
- **Pending count before every read.** Output is not available right after `rapidlyAddAudioInterleaved`: the model latency is held back and output arrives in hops, so the queue holds either fewer or more samples than were just fed. Always read `rapidlyGetNumOfPendingSamples` (Swift `getNumOfPendingSamples()`, Kotlin `getNumOfPendingSamples()`) and request exactly that many. Reading the fed count instead fails on the first calls, fails again whenever the hop grid drifts past the block size, and leaves the output buffer unwritten each time.
- **Sample rate matching.** The processor is constructed for a specific sample rate. Re-create it if the customer's audio source changes rates.
- **Thread safety.** Each `processor` handle is intended to be used from a single audio thread at a time. Multiple threads need multiple processors. The Swift `RapidlyEngine` class follows the same model as `AVAudioEngine` (not `Sendable`). The Kotlin `RapidlyEngine` class follows the same model as `AudioTrack` / `AudioRecord` / Oboe (single-threaded access; not declared `Sendable`-equivalent). To stop deterministically: (1) stop the customer's audio session first so no render callback is in flight, (2) call `close()` on the engine, (3) release references. Calling `close()` while another thread is mid-call into the engine is undefined behaviour.

## Common pitfalls

- "Output sounds distorted / has audible artifacts." → The output is watermarked. Check that `rapidlyAddLicense` returned `true` and that the loaded model file is covered by the key's entitlements. With a subscription key, also check that a session was started (`rapidlyStartSession` returns `true` once the engine is authorized); with an activation key, call `rapidlyGetActivationStatus`: it shows whether the device is licensed, when the licence expires and any refusal code (for example a deactivated device).

## API reference

Public symbols start with `rapidly` (functions) or `Rapidly` (types) — e.g., `rapidlyAddLicense`, `rapidlyCreateProcessor`, `RapidlyProcessorHandle`, `RAPIDLY_PARAM_MAXATTENUATION`. Full reference in the public header `include/RapidlyEngine.h`.

## Where to look up more

- `LICENSE` — licence terms.
- `CHANGELOG.md` — per-version release notes.
- `models/` — list of shipped model files; pick by latency / variant.
- `examples/` — working integration examples per platform.
- https://rapidly.io/docs — full online documentation.
- support@rapidly.io — technical support and licence-key issuance.
