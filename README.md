# Awesome Audio

A native macOS app that processes podcast and voiceover audio to broadcast quality — offline, no subscriptions, no uploads.

![App Icon](AppIcon.png)

## What It Does

Drop in a raw recording, get back a cleaner spoken-word master. Awesome Audio applies a mastering-oriented processing chain:

1. **High-pass filter** — removes low-frequency rumble (HVAC, mic handling, traffic)
2. **ML noise reduction** — DeepFilterNet can reduce background noise when the source needs cleanup
3. **Gentle de-essing** — reduces harsh sibilance without aggressively dulling the top end
4. **Presence & air shaping** — restores brightness for spoken-word material after cleanup
5. **Compression** — evens out dynamics (quiet parts audible, loud parts controlled)
6. **Loudness normalization** — hits podcast (-16 LUFS) or YouTube (-14 LUFS) standards
7. **True peak limiting** — reins in final peaks with more conservative headroom

### Before & After

Your raw recording → broadcast-ready audio in one click. No audio engineering expertise required.

## Features

- **Drag and drop** — WAV, MP3, M4A, AIFF input
- **4 built-in presets** — Podcast Standard, YouTube, Noisy Environment, Minimal
- **Custom presets** — save your own processing settings
- **Presence & Air controls** — brighten spoken-word material without external EQ
- **Before/after comparison** — see LUFS and true peak measurements
- **Export as WAV** — 16-bit (with TPDF dithering) or 24-bit output
- **Fully offline** — no internet, no cloud, no subscription
- **Native macOS** — SwiftUI, light/dark mode, SF Symbols

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel Mac
- Rust toolchain (for building DeepFilterNet from source)

## Building

### Prerequisites

```bash
# Install Rust (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add x86_64-apple-darwin

# Install XcodeGen
brew install xcodegen
```

### Build DeepFilterNet

```bash
cd vendor/deepfilternet
./build-universal.sh
```

This builds the DeepFilterNet noise reduction engine as a universal static library (arm64 + x86_64).

### Generate Xcode Project & Build

```bash
xcodegen generate
open AwesomeAudio.xcodeproj
```

Then build and run in Xcode (Cmd+R).

### SPM Build (library only, no DeepFilterNet)

```bash
swift build
swift test  # 68 tests
```

## Architecture

Two-pass offline processing pipeline:

```
Input (WAV/MP3/M4A/AIFF)
  → Decode → Resample (48kHz) → Downmix (mono)
  → Pass 1: HPF → DeepFilterNet → De-ess → Tone shape → Compress → Measure LUFS
  → Pass 2: Gain normalize → True peak limit → Write WAV
  → Post-verify: Re-measure final LUFS
Output (mono WAV, 16/24-bit)
```

Current limitation: stereo sources are still downmixed to mono for processing, and the UI now warns about that explicitly.

### Tech Stack

| Component | Technology |
|---|---|
| UI | SwiftUI (macOS 14+) |
| Noise Reduction | [DeepFilterNet](https://github.com/Rikorose/DeepFilterNet) v0.5.6 (Rust, C API) |
| DSP | Accelerate/vDSP |
| Loudness | libebur128 (EBU R128) |
| Waveform | DSWaveformImage |

### Processing Chain

| Stage | Type | Implementation |
|---|---|---|
| High-Pass Filter | Butterworth biquad | vDSP.Biquad, 80Hz default |
| Noise Reduction | ML-based | DeepFilterNet C API |
| De-esser | Split-band dynamic EQ | 6.5kHz sidechain, gentler max attenuation |
| Tone Shaper | Presence bell + air shelf | mild spoken-word brightening |
| Compressor | Feed-forward, soft knee | 3ms lookahead, auto makeup |
| LUFS Measurement | EBU R128 | libebur128 |
| Gain Normalization | Linear gain | LUFS-derived offset |
| True Peak Limiter | 4x oversampling FIR | conservative defaults around -2.0 dBTP |

## Testing

68 tests across 14 suites covering DSP processors, export safety, tonal shaping, gain staging, format adaptation, and temp file management.

```bash
swift test
```

## Ear-Test Notes

- The current tuning removes the earlier loudness overshoot, lightens the de-esser, and adds restrained presence/air lift so spoken-word exports sound less pinched and less muffled than the day-1 fix.
- The sound is still not a drop-in clone of the referenced Audacity macro. DeepFilterNet remains a speech-cleanup model, so very clean narration may still sound more processed than a pure EQ/compression/soft-limit mastering chain.
- Best default for already-clean spoken-word material: start with `Minimal`, then add a small amount of `Presence` and `Air` only if the voice still feels dull.

## License

MIT

## Credits

- [DeepFilterNet](https://github.com/Rikorose/DeepFilterNet) by Hendrik Schroeter (MIT/Apache-2.0)
- [libebur128](https://github.com/jiixyj/libebur128) (MIT)
- [DSWaveformImage](https://github.com/dmrschmidt/DSWaveformImage) (MIT)
