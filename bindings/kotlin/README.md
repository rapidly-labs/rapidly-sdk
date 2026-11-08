# Rapidly SDK — Kotlin / Android

Real-time audio separation for Android apps, via Maven Central.

## Install

In `app/build.gradle.kts`:

```kotlin
dependencies {
    implementation("io.rapidly:rapidly-sdk:1.2.0")
}
```

`minSdk` 26 (Android 8.0). Bundles `arm64-v8a`. The `.aar` is also attached
as a downloadable artefact in the GitHub Release for `libs/`-based installs:

```kotlin
dependencies {
    implementation(files("libs/rapidly-sdk-1.2.0.aar"))
}
```

## Use

```kotlin
import io.rapidly.engine.RapidlyEngine

RapidlyEngine.addLicense("lk_...")                            // licence first
val engine = RapidlyEngine.create(
    modelFilepath = modelPathOnDisk,                          // copy from assets to cacheDir first
    numOfChannels = 2,
    sampleRate = 48000.0,
)
engine?.addAudioInterleaved(inputBuffer, numSamples)
// Processing adds latency and releases output in model-sized hops, so ask how
// many samples are ready and read exactly that many (outputBuffer must hold
// channels * pending floats). Asking for more returns false and writes nothing.
val pending = engine?.getNumOfPendingSamples() ?: 0
if (pending > 0) engine?.getAudioInterleaved(outputBuffer, pending)
engine?.close()
```

Audio buffers must be direct
(`ByteBuffer.allocateDirect(n * 4).order(ByteOrder.nativeOrder()).asFloatBuffer()`)
for the zero-copy JNI path. The model path must be a filesystem path; ship
the `.rapidly` model in `assets/` and copy it to `context.cacheDir` on
first use.

## Activation keys

Call `RapidlyEngine.initialize(context)` once at startup (for example in
`Application.onCreate`). On your own servers, pass the key to
`RapidlyEngine.addLicense("ak_...")`.

In an app shipped to end users, keep the key on your backend and register a
handler. The SDK calls it on a background thread when a check is due. Send
`request` unchanged, as the body of
`POST https://api.rapidly.io/sdk/v1/activation/check` with the key in the
`X-Auth-Key` header and `Content-Type: application/json`, then pass the reply to
`submit` (HTTP status and body; status `0` when your backend was unreachable).
The handler runs on the engine's check thread: return within 60 seconds, use a
request timeout in your backend call, or reply later with `submit`, which can be
called from any thread.

```kotlin
RapidlyEngine.setActivationRequestHandler { request, submit ->
    myBackend.forward(request) { status, body -> submit(status, body) }
}
```

Pass `null` to remove the handler. `RapidlyEngine.getActivationStatus()` returns
whether the device is licensed, when the licence expires and any refusal code
(`null` when no activation is in use). `RapidlyEngine.refreshActivation()` runs
the next check now.

See the root `README.md` for the model list and the licence model, and
`AGENTS.md` for AI-assisted integration guidance.
