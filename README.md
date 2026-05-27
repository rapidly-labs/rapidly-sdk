# Rapidly SDK

The Rapidly SDK is a set of AI models for audio separation, built to process audio on-device and in realtime. By [Rapidly Labs AS](https://rapidly.io).

A lean, cross-platform C++ library built for low latency and small footprint. Customer applications embed the engine binary and load Rapidly's pre-trained models to add real-time audio separation (speech denoise, dereverb, and more) to phone calls, broadcast audio, voice assistants, and other audio pipelines.

## Why use Rapidly?

- Small footprint
- Light on CPU
- No GPU requirements
- Low latency
- Cross-platform
- Easy to integrate

## Install

| Language | Instructions |
|---|---|
| C / C++ | Embed a binary from `bin/<platform>/` and include `include/RapidlyEngine.h`. See `examples/process-file/` for a CLI walkthrough. |
| Swift / iOS / macOS | In Xcode: **File → Add Package Dependencies** → paste `https://github.com/rapidly-labs/rapidly-sdk`, then `import RapidlyEngine` for the Swift-native `RapidlyEngine` class. Or drag `bin/RapidlyEngine.xcframework` into your Xcode project's Frameworks section and `import RapidlyEngineC` for the C API. |
| Kotlin / Android | In Gradle: `implementation("io.rapidly:engine:1.0")` from Maven Central, then `import io.rapidly.engine.RapidlyEngine` for the Kotlin-native class. Or download `rapidly-engine-1.0.aar` from the GitHub release into your app's `libs/` and add `implementation(files("libs/rapidly-engine-1.0.aar"))`. Bundles `arm64-v8a`. `minSdk` 26. |
| Python | `pip install rapidly` (PyPI). See `bindings/python/README.md`. |

Documentation: <https://rapidly.io/docs>

## Quickstart

### C / C++

```c
#include "RapidlyEngine.h"

rapidlyAddLicense("lk_...");                       // licence first
auto p = rapidlyCreateProcessor(
    "models/speech-denoise-32ms.v1.0.rapidly",     // model file
    2,                                             // channels
    44100                                          // sample rate
);
rapidlyAddAudioInterleaved(p, input,  numSamples);
rapidlyGetAudioInterleaved(p, output, numSamples);
```

### Swift (iOS / macOS)

```swift
import RapidlyEngine

RapidlyEngine.addLicense("lk_...")               // licence first
let engine = RapidlyEngine(
    modelFilepath: "models/speech-denoise-32ms.v1.0.rapidly",
    numOfChannels: 2,
    sampleRate: 44100
)
engine?.addAudioInterleaved(pcmChannels: inputBuffer, numOfSamples: numSamples)
engine?.getAudioInterleaved(pcmChannels: outputBuffer, numOfSamples: numSamples)
```

### Python

```python
import rapidly

engine = rapidly.RapidlyEngine()
engine.add_license("lk_...")
processor = engine.create_processor("models/speech-denoise-32ms.v1.0.rapidly", 2, 44100)
# feed audio in / out via processor methods
```

For AI-assisted integration, see [`AGENTS.md`](AGENTS.md).

## What's in this distribution

| Folder | Contents |
|---|---|
| `bin/` | Native binaries, one folder per platform, plus `RapidlyEngine.xcframework` for Apple |
| `include/` | Single public header `RapidlyEngine.h` |
| `models/` | Pre-trained Rapidly model files (`.rapidly`) |
| `bindings/swift/` | Swift wrapper source (canonical install: SwiftPM via `Package.swift` at repo root) |
| `bindings/kotlin/` | Kotlin wrapper source (canonical install: `implementation("io.rapidly:engine:1.0")` from Maven Central) |
| `bindings/python/` | Python wrapper (`pip install rapidly`) |
| `examples/` | Working integration demos: `process-file`, `raspberry-pi` |
| `Package.swift` | Swift Package Manager manifest (Apple platforms) |
| `LICENSE` | Commercial licence terms |
| `CHANGELOG.md` | Per-version release notes |
| `AGENTS.md` | AI agent integration guide |

## Models

The SDK ships with two model families.

**Speech denoise** removes background noise from speech and outputs cleaned dialogue and noise as separate busses.

**Speech denoise + dereverb** removes both background noise and room reverb, and outputs cleaned dialogue, reverb, and noise as separate busses. Use this when the input has significant room reverb that you want to suppress (or capture as a separate bus).

Each family ships at four latencies, plus a `micro` size variant of the 32 ms model for CPU-constrained scenarios. The size variant (`micro`) appears between the family name and the latency in the filename — e.g. `speech-denoise-micro-32ms.v1.0.rapidly`.

| Model file | Latency | File size | Real-time factor* | Output busses |
|---|---|---|---|---|
| `speech-denoise-11ms.v1.0.rapidly` | 11 ms | 615 KB | 13x | Dialogue, Noise |
| `speech-denoise-21ms.v1.0.rapidly` | 21 ms | 851 KB | 13x | Dialogue, Noise |
| `speech-denoise-32ms.v1.0.rapidly` | 32 ms | 854 KB | 27x | Dialogue, Noise |
| `speech-denoise-micro-32ms.v1.0.rapidly` | 32 ms (compact) | 241 KB | 125x | Dialogue, Noise |
| `speech-denoise-96ms.v1.0.rapidly` | 96 ms | 925 KB | 29x | Dialogue, Noise |
| `speech-denoise-dereverb-11ms.v1.0.rapidly` | 11 ms | 615 KB | 12x | Dialogue, Reverb, Noise |
| `speech-denoise-dereverb-21ms.v1.0.rapidly` | 21 ms | 851 KB | 12x | Dialogue, Reverb, Noise |
| `speech-denoise-dereverb-32ms.v1.0.rapidly` | 32 ms | 854 KB | 25x | Dialogue, Reverb, Noise |
| `speech-denoise-dereverb-micro-32ms.v1.0.rapidly` | 32 ms (compact) | 241 KB | 115x | Dialogue, Reverb, Noise |
| `speech-denoise-dereverb-96ms.v1.0.rapidly` | 96 ms | 926 KB | 27x | Dialogue, Reverb, Noise |

*Real-time factor measured on a single core of an AMD RYZEN AI MAX+ 395.

All models are trained on 48 kHz audio, but the engine accepts other sample rates.

### Picking a model

Choose by latency budget:

* **11 ms or 21 ms**: live communication, conferencing, real-time monitoring. Lowest delay; trades off some suppression strength.
* **32 ms**: balanced choice for most production use. Strong noise / reverb reduction with moderate latency.
* **`micro` 32 ms**: same latency as 32 ms but a compact 241 KB file with a 4-5x higher real-time factor. Choose this when you need to run many simultaneous streams per CPU.
* **96 ms**: highest fidelity. Best speech clarity; suitable for recording, post-production, and offline processing where latency does not matter.

Choose between `speech-denoise` and `speech-denoise-dereverb` by whether you want room reverb removed (or exposed as a separate bus). The dereverb family is a good fit for desktop microphones in untreated rooms and for archive cleanup; the plain denoise family preserves the room's natural reverb.

## Licences

The SDK enforces licence entitlements locally; no network access is required. A Rapidly licence (`lk_...`) is issued by Rapidly Labs and encodes which models and latency variants your application may use without a watermark. Licence coverage is a quality gate, not an availability gate: any model still loads and runs, but a model not covered by a valid licence (or any model used with no licence) operates in a watermarked demo mode that audibly degrades its output.

For commercial licensing enquiries: <sales@rapidly.io>
For technical support and licence issuance: <support@rapidly.io>

## Supported platforms

Linux x64, Linux arm64, Windows x64, Windows x86, macOS (universal), iOS, Android (arm64-v8a).

WebAssembly is coming in a future release. See `CHANGELOG.md` for the full v1.0 scope.
