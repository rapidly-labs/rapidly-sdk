# AGENTS.md — integration guide for AI coding agents

This file is read by AI coding tools (Claude Code, Cursor, GitHub Copilot, Continue, Aider, etc.) when assisting a customer who has added the Rapidly Engine SDK to their project. It tells the agent what the SDK is, how to integrate it correctly, and what to avoid.

## What the Rapidly Engine SDK is

A native, cross-platform C++ library that ships a set of AI models for real-time audio separation (speech denoise, dereverb, and related models). Designed to process audio on-device, no network or GPU required. Customers embed the SDK binary into their own application and call into it from C, C++, Python, or any language with a C-FFI.

## Quickstart

1. Choose a binary for the customer's platform from `bin/`. v1.0 ships: `bin/linux-x64/`, `bin/linux-arm64/`, `bin/windows-x64/`, `bin/windows-x86/`. Embed the dynamic library (`.so` / `.dll`) into the customer's application. macOS, iOS, Android arm64, and WebAssembly are coming in a future release — see `CHANGELOG.md`.
2. Include the public header `include/RapidlyEngine.h`.
3. At application startup, register the customer's licence key with `rapidlyAddLicense(const char* licenseString)`. The licence string is a `lk_<base64url-payload>.<base64url-signature>` token issued by Rapidly Labs AS — the customer pastes it from their dashboard or build configuration. Multiple licences may be registered by calling `rapidlyAddLicense` repeatedly.
4. Load a model file from `models/` with `rapidlyCreateProcessor(const char* modelFilepath, int32_t numOfChannels, double sampleRate)`. The model file extension is `.rapidly`.
5. Feed audio in with `rapidlyAddAudioInterleaved` and read processed audio out with `rapidlyGetAudioInterleaved`. See `examples/process-file/` for a working CLI demo.

## Python quickstart

```python
import rapidly

rapidly_engine = rapidly.RapidlyEngine()
rapidly_engine.add_license("lk_...")

processor = rapidly_engine.create_processor("models/speech-denoise-32ms.v1.0.rapidly", 2, 44100)
# feed audio buffers in / out via processor methods
```

See `bindings/python/examples.py` for a more complete walkthrough. The Python wrapper is `pip install rapidly`.

## Things to get right

- **Licence before model.** Always call `rapidlyAddLicense` before `rapidlyCreateProcessor`. A model loaded without a covering licence will produce watermarked (audibly degraded) output.
- **Per-(model_id, latency_ms) entitlement.** Each licence key encodes which models and which latency variants it permits. If the customer's licence covers `sdn-l` (legacy) but they try to load `sdn-v2.0-32ms.rapidly` (a newer model), it will fall through to the watermark path. This is by design.
- **Sample rate matching.** The processor is constructed for a specific sample rate. Re-create it if the customer's audio source changes rates.
- **Thread safety.** Each `processor` handle is intended to be used from a single audio thread at a time. Multiple threads need multiple processors.

## Common pitfalls

- "Output sounds distorted / has audible artifacts." → The licence path failed silently. Check that `rapidlyAddLicense` returned `true`, and that the loaded model's `model_id` is in the licence's entitlements.
- "Cannot load model file." → The file extension on disk should be `.rapidly`. Legacy `.hance` files are still loadable if the SDK has the compatibility shim — magic bytes inside the file determine format, the on-disk extension does not.
- "iOS app rejects unsigned binary." → The Phase 1 SDK ships unsigned `.dylib` for iOS and macOS. The customer's own app code-sign step (`codesign --deep`) covers the embedded binary at their app build time.

## API reference

Public symbols start with `rapidly` (functions) or `Rapidly` (types) — e.g., `rapidlyAddLicense`, `rapidlyCreateProcessor`, `RapidlyProcessorHandle`, `RAPIDLY_PARAM_MAXATTENUATION`. Full reference in the public header `include/RapidlyEngine.h`.

## Where to look up more

- `LICENSE` — licence terms.
- `CHANGELOG.md` — per-version release notes.
- `models/` — list of shipped model files; pick by latency / variant.
- `examples/` — working integration examples per platform.
- https://rapidly.io/docs — full online documentation.
- support@rapidly.io — technical support and licence-key issuance.
