# Rapidly Engine SDK — Changelog

All notable changes to the Rapidly Engine SDK are documented here.
Versions follow [semantic versioning](https://semver.org).

## [1.0] — Unreleased

Initial public release.

### Added
- Cross-platform native binaries: Linux x64, Linux arm64, Windows x64, Windows x86.
- Speech denoise and speech denoise + dereverb model families, in 11 ms / 21 ms / 32 ms / 96 ms latency variants, plus a `micro` size variant of the 32 ms model.
- Offline licence-key verification (`lk_<base64url-payload>.<base64url-signature>`) via Ed25519 signature, with per-model and per-latency entitlement enforcement at model load.
- Python bindings (`bindings/python/`).
- Native C / C++ examples: `process-file`, `raspberry-pi`.

### Coming in a future release
- macOS and iOS binaries (pending Apple Developer Program enrolment + codesign / notarization wiring).
- Android arm64 binaries.
- WebAssembly build.
- Rapidly-Labs-signed Apple binaries and Swift framework distribution.

### Notes for integrators
- See `AGENTS.md` for AI-assisted integration guidance and `LICENSE` for the licence terms.
