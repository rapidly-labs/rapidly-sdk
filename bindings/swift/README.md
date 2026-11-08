# Rapidly SDK — Swift / Apple

Real-time audio separation for iOS and macOS apps, via Swift Package Manager.

## Install

In Xcode: **File → Add Package Dependencies** → paste:

```
https://github.com/rapidly-labs/rapidly-sdk
```

Pick the latest version. Supports iOS 14+ and macOS 11+.

Or in a `Package.swift`-based project:

```swift
.package(url: "https://github.com/rapidly-labs/rapidly-sdk", from: "1.2.0")
```

## Use

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

## Activation keys

On your own servers, pass the key to `RapidlyEngine.addLicense("ak_...")`.

In an app shipped to end users, keep the key on your backend and register a
handler. The SDK calls it when a check is due. Send `request` unchanged, as the
body of `POST https://api.rapidly.io/sdk/v1/activation/check` with the key in the
`X-Auth-Key` header and `Content-Type: application/json`, then pass the reply to
`submit` (HTTP status and body; status `0` when your backend was unreachable).
The handler runs on the engine's check thread: return within 60 seconds, use a
request timeout in your backend call, or reply later with `submit`, which can be
called from any thread.

```swift
RapidlyEngine.setActivationRequestHandler { request, submit in
    myBackend.forward(request) { status, body in submit(status, body) }
}
```

There is also `setActivationRequestHandlerAsync`, which takes an async closure
returning the reply. Pass `nil` to either to remove the handler.

`RapidlyEngine.activationStatus()` returns whether the device is licensed, when the
licence expires and any refusal code (`nil` when no activation is in use).
`RapidlyEngine.refreshActivation()` runs the next check now.

See the root `README.md` for the model list and the licence model, and
`AGENTS.md` for AI-assisted integration guidance.
