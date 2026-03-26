# Awesome Audio — Design Specification

## Overview

**Product:** Awesome Audio — a native macOS application for automated podcast and voiceover audio processing.

**Problem:** Content creators recording podcasts and YouTube voiceovers need to process raw audio before publishing: remove background noise, even out dynamics, reduce sibilance, and hit platform loudness standards. Current solutions require cloud uploads and subscriptions (e.g., Auphonic). This app does it locally, offline, with no subscription.

**Target user:** Content creators who record voice audio with consumer microphones (e.g., wireless lavaliers) and need broadcast-ready output without audio engineering expertise.

**Platform:** macOS 14+, Apple Silicon and Intel (universal binary).

---

## User Workflow

1. Launch app → single window with sidebar (presets/history) and main area (drop zone)
2. Drag and drop an audio file (WAV, MP3, M4A, AIFF) or click to browse
3. See file info (format, duration, size, current LUFS) and waveform preview
4. Select a preset or adjust processing settings
5. Click Process → progress bar with stage names and percentage
6. See results: before/after LUFS, true peak reading, processing time
7. Export processed audio as mono WAV (16-bit or 24-bit)

---

## Architecture

### Layer Overview

```
┌─────────────────────────────────────────────────────┐
│  SwiftUI App Layer                                  │
│  ContentView │ DropZone │ Sidebar │ Processing │    │
│  Results                                            │
├─────────────────────────────────────────────────────┤
│  State & Coordination                               │
│  ProcessingCoordinator │ PresetManager               │
├─────────────────────────────────────────────────────┤
│  Audio Format Adapter                               │
│  Decode → Resample (48kHz) → Downmix (mono)        │
├─────────────────────────────────────────────────────┤
│  Pass 1: Stream + Analyze                           │
│  HPF → DeepFilterNet → De-ess → Compress → LUFS    │
│  → writes Float32 CAF temp file                     │
├─────────────────────────────────────────────────────┤
│  Pass 2: Apply + Finalize                           │
│  Gain → True Peak Limiter → Delay Comp → Write WAV │
├─────────────────────────────────────────────────────┤
│  Native Foundations                                 │
│  DeepFilterNet │ Accelerate │ AVFoundation │        │
│  libebur128 │ SwiftData                             │
└─────────────────────────────────────────────────────┘
```

### Product Decisions

- **Mono pipeline.** Input is decoded, resampled to 48 kHz, and downmixed to mono. Output is always mono WAV. This is a deliberate product decision for podcast/voiceover content, not an engine limitation workaround. Stereo preservation is out of scope for v1.
- **Two-pass processing.** LUFS normalization requires measuring the entire file before applying gain. Pass 1 streams through processors and writes a Float32 CAF temp file while measuring LUFS. Pass 2 reads the temp file, applies gain normalization and true peak limiting, and writes the final WAV.
- **File-backed intermediate.** The Pass 1 output is a Float32 CAF file in `NSTemporaryDirectory()`, not RAM. A 1-hour file at 48 kHz mono Float32 is ~660 MB. CAF format chosen over WAV to avoid the 4 GB size limit.
- **Offline processing only.** No real-time preview. Processing runs on a background actor with progress published via AsyncSequence.

### Protocol Design

Three distinct protocols separate streaming transforms from analysis from analysis-derived processing:

```swift
/// In-place, stateful, chunked audio transform
protocol StreamingProcessor {
    var sampleRate: Double { get }
    var latencySamples: Int { get }
    func process(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int)
    func reset()
}

/// Whole-file analysis that produces a measurement
protocol AudioAnalyzer {
    func analyze(_ buffer: UnsafePointer<Float>, frameCount: Int)
    func finalize() -> AnalysisResult
    func reset()
}

/// Configured from analysis results, then streams like a processor
protocol AnalysisDerivedProcessor: StreamingProcessor {
    func configure(from result: AnalysisResult)
}
```

The `ProcessingCoordinator` manages the pipeline:
- Chains StreamingProcessors in order for Pass 1
- Feeds each chunk to the AudioAnalyzer concurrently
- Computes `totalLatency = sum(processor.latencySamples)` across all StreamingProcessors in both passes
- Trims `totalLatency` leading samples from the final output (single trim at end, not per-stage)

### Processing Pipeline

**Pass 1 — Stream + Analyze:**

| Stage | Type | Implementation | Key Parameters |
|---|---|---|---|
| High-Pass Filter | StreamingProcessor | vDSP biquad, 2nd order Butterworth | Cutoff: 60-120 Hz (default 80 Hz), Q=0.7071 |
| Noise Reduction | StreamingProcessor | DeepFilterNet C API (vendor fork) | Attenuation limit via `df_set_atten_lim()` — see NR Strength Mapping below |
| De-esser | StreamingProcessor | Split-band dynamic EQ, vDSP biquad sidechain | Center: 6.5 kHz, Q=2, max reduction -6 dB, attack 0.5 ms, release 20 ms, 2 ms lookahead |
| Compressor | StreamingProcessor | Single-band feed-forward, soft knee | Configurable via presets (see Presets section), 3 ms lookahead, auto makeup gain |
| LUFS Measurement | AudioAnalyzer | libebur128 (via spfk-loudness SPM package) | EBU R128 integrated loudness + true peak dBTP measurement |

Output: Float32 CAF temp file + `AnalysisResult { measuredLUFS: Float, measuredTruePeak: Float }`

**Pass 2 — Apply + Finalize:**

| Stage | Type | Implementation | Key Parameters |
|---|---|---|---|
| Gain Normalization | AnalysisDerivedProcessor | Linear gain from LUFS offset | `gainDB = targetLUFS - measuredLUFS + overshootLU` |
| True Peak Limiter | StreamingProcessor | Custom: 4x oversampling FIR (BS.1770, 48 taps) + 5 ms lookahead buffer | Ceiling: -1.0 dBTP (configurable), instant attack, 50 ms release |
| Write Output | — | ExtAudioFile | Int16 or Int24 WAV, mono, 48 kHz — writes to **temp final WAV** in `NSTemporaryDirectory()` |

**Post-processing verification:** Re-measure the temp final WAV's integrated LUFS and true peak via libebur128. Display actual measured values in the results view.

**Save/export flow:** Pass 2 writes to a second temp file (the final WAV), not to the user's chosen location. The results view shows before/after stats from this temp file. When the user clicks "Save As...", the app presents NSSavePanel, checks output volume space, and copies/moves the temp WAV to the chosen destination. This decouples processing from export — the user sees results before committing to a save location.

### Noise Reduction Strength Mapping

The UI exposes a 0-100% slider. DeepFilterNet's native control is `atten_lim` (attenuation limit in dB), set via `df_set_atten_lim(st, lim_db)`. This controls how aggressively noise is suppressed:

- `atten_lim = 100 dB` → maximum suppression (near-silent noise floor)
- `atten_lim = 0 dB` → no suppression (passthrough)

**Transfer function (UI % → engine dB):**

```
atten_lim_db = uiStrength * 100.0
```

Linear mapping: 0% → 0 dB (off), 50% → 50 dB, 100% → 100 dB. This is intentionally simple. The DeepFilterNet engine handles the nonlinear perceptual behavior internally — the attenuation limit is already a perceptually meaningful parameter.

**Persistence:** Both `noiseReductionStrength` (UI value, 0.0-1.0) and the computed `atten_lim_db` are stored in `PresetSnapshot` so history records are reproducible even if the mapping function changes in a future version.

### LUFS Overshoot Compensation

The true peak limiter reduces peaks, which lowers integrated LUFS from the target. To compensate:

- Apply a tunable overshoot offset (initial default: +0.3 LU) when computing gain in Pass 2
- The overshoot value is a calibration parameter tuned during development against reference material — not a fixed architectural constant
- Final measured LUFS (re-measured after export) is always the source of truth shown to the user
- Tolerance: ±0.5 LUFS of target is acceptable (matches industry practice)
- If outside tolerance: display actual value with a note, do not re-iterate (avoids gain/limit oscillation)

### Audio Format Adapter

Handles the gap between arbitrary input formats and the 48 kHz mono Float32 pipeline:

1. **Decode**: AVAudioFile reads WAV, MP3, M4A, AIFF → Float32 PCM
2. **Resample**: If input sample rate != 48 kHz, resample via AVAudioConverter
3. **Downmix**: If stereo, average L+R channels to mono (`(L + R) / 2`)

Output from the adapter is always 48 kHz, mono, Float32 — ready for the processing pipeline.

### Export Quantization

- **24-bit (default):** Direct Float32 → Int24 truncation. 144 dB dynamic range makes truncation noise inaudible.
- **16-bit:** Apply TPDF (Triangular Probability Density Function) dithering before truncation. Two uniform random values scaled to 1 LSB summed and added to each sample before quantizing. No noise shaping in v1.
- Dithering is the absolute last operation — after true peak limiting, before integer conversion.

### Delay Compensation

Every StreamingProcessor declares its `latencySamples`. The ProcessingCoordinator sums all latency across both passes and trims that many leading samples from the final output. This handles:

- DeepFilterNet: STFT windowing + model lookahead (runtime value from `df_get_delay_samples()`)
- De-esser: 2 ms lookahead (~96 samples at 48 kHz)
- Compressor: 3 ms lookahead (~144 samples at 48 kHz)
- True Peak Limiter: 5 ms lookahead (~240 samples at 48 kHz)
- HPF: 0 (IIR filter, no lookahead)

### Disk Space Management

**Preflight check before processing:**

```
tempSpace = inputDuration × 48000 × 4 bytes    // Float32 CAF (always 48 kHz mono)
outputSpace = inputDuration × 48000 × (bitDepth / 8)  // WAV (always 48 kHz mono — matches pipeline output rate)
margin = 50 MB

Check temp volume: FileManager.attributesOfFileSystem(forPath: NSTemporaryDirectory())
```

Before processing: check temp volume only (output path not yet chosen).
At export time (NSSavePanel): check output volume before writing. If insufficient, show error and let user choose a different location.

Display estimated temp storage in the file info bar before the user clicks Process.

**Temp cleanup:**
- **On cancel or processing failure:** Delete all session temp files (Pass 1 CAF + Pass 2 temp WAV if it exists) immediately. Do not wait for quit or launch sweep.
- On successful export (Save As): delete both temp files immediately after copy/move completes.
- On app quit: delete any remaining temp files from the current session.
- **On app launch:** Scan `NSTemporaryDirectory()` for `AwesomeAudio_*.caf` and `AwesomeAudio_*.wav` files older than 1 hour. Delete them. Covers crashes, force quits, and interrupted processing.

---

## DeepFilterNet Integration

### Approach

Use the existing C API (`libDF/src/capi.rs`) built as a static library. Not a custom Rust FFI bridge — the project already exposes `df_create`, `df_process_frame`, `df_free` etc. via `cbindgen`.

### Vendor Fork

- Fork `Rikorose/DeepFilterNet` to project GitHub org
- Pin to v0.5.6 release tag + one patch: add `df_get_delay_samples(st) -> usize` export to `capi.rs`
- **Update policy:** Check upstream quarterly. If upstream adds the export or equivalent, switch back. If upstream makes breaking C API changes, evaluate before updating.
- Document the patch diff in `vendor/deepfilternet/PATCH.md`
- The fork exists solely for this one export — no other modifications

### Build

- Rust toolchain required at build time (not at runtime)
- `cargo build --release --features capi` produces static library (`.a`) and header (`.h`)
- Universal binary: build for `aarch64-apple-darwin` and `x86_64-apple-darwin`, `lipo` to combine
- Model file bundled in app resources (loaded by `df_create` at init)
- Xcode build phase runs the Rust build and copies artifacts

### Effort Estimate (Separated)

| Work Item | Estimate |
|---|---|
| Integration coding: build static lib, generate header, write Swift wrapper, test | 1-2 days |
| Build pipeline: CI Rust toolchain, universal binary, model bundling, Xcode build phase | 1-2 days |
| Signing/notarization: verify static lib compatibility with hardened runtime and notarization | 0.5-1 day |
| **Total** | **3-5 days** |

---

## True Peak Limiter — Technical Risk

The custom true peak limiter is the riskiest bespoke DSP component in the project. It requires:

- 4x oversampling via BS.1770 polyphase FIR interpolation (48 filter taps)
- Lookahead buffer management (5 ms / 240 samples)
- Gain reduction smoothing (instant attack, 50 ms release)
- Correct behavior at edge cases: DC offset, sustained near-0 dBFS content, very short transients

### Mitigation

- **Prototype early:** Build and test the limiter in isolation before integrating into the pipeline
- **Acceptance test:** Feed a 0 dBFS sine wave with known inter-sample peaks at +3 dBTP. Verify output never exceeds -1.0 dBTP as measured by libebur128's true peak measurement.
- **Fallback:** If the custom limiter proves too complex for v1, use Apple's `kAudioUnitSubType_PeakLimiter` Audio Unit for sample-peak limiting. This is not BS.1770 true-peak compliant (it operates on sample peaks, not inter-sample peaks), but it is functional. Document the compliance gap if using the fallback.
- **Budget:** 2-3 days specifically for limiter development + testing, separate from pipeline integration.

---

## Data Model

### Preset

```swift
@Model
class Preset {
    var id: UUID
    var name: String
    var isBuiltIn: Bool
    var createdAt: Date

    // Processing parameters
    var highPassCutoff: Float       // 60-120 Hz
    var noiseReductionStrength: Float // 0.0-1.0
    var deEssAmount: Float          // 0.0-1.0
    var compressionPreset: CompressionPreset  // .gentle, .medium, .heavy
    var targetLUFS: Float           // -16 or -14
    var truePeakCeiling: Float      // default -1.0 dBTP
    var outputBitDepth: Int         // 16 or 24
}

enum CompressionPreset: String, Codable {
    case gentle     // Threshold -20 dB, Ratio 2:1, Attack 20 ms, Release 200 ms
    case medium     // Threshold -24 dB, Ratio 3:1, Attack 10 ms, Release 100 ms
    case heavy      // Threshold -30 dB, Ratio 4:1, Attack 5 ms, Release 50 ms
}
```

### ProcessingRecord

```swift
@Model
class ProcessingRecord {
    var id: UUID
    var timestamp: Date
    var inputFileName: String
    var inputFileBookmark: Data?     // security-scoped bookmark for re-access
    var outputFileName: String?
    var outputFileBookmark: Data?

    // Settings used
    var presetName: String
    var presetSnapshot: PresetSnapshot  // frozen copy of settings at processing time (see below)
}

/// Frozen copy of preset settings at processing time, so history is accurate
/// even if the preset is later modified or deleted
struct PresetSnapshot: Codable {
    var highPassCutoff: Float
    var noiseReductionStrength: Float  // UI value 0.0-1.0
    var noiseReductionAttenLimitDB: Float  // engine-native value, for reproducibility
    var deEssAmount: Float
    var compressionPreset: CompressionPreset
    var targetLUFS: Float
    var truePeakCeiling: Float
    var outputBitDepth: Int

    // Results
    var beforeLUFS: Float
    var afterLUFS: Float
    var beforeTruePeak: Float
    var afterTruePeak: Float
    var processingDurationSeconds: Double
}
```

### Built-in Presets

| Preset | HPF | NR Strength | De-ess | Compression | Target LUFS | Bit Depth |
|---|---|---|---|---|---|---|
| Podcast Standard | 80 Hz | 70% | 50% | Medium | -16 LUFS | 24-bit |
| YouTube | 80 Hz | 70% | 50% | Medium | -14 LUFS | 24-bit |
| Noisy Environment | 100 Hz | 90% | 40% | Heavy | -16 LUFS | 24-bit |
| Minimal | 60 Hz | 30% | 30% | Gentle | -16 LUFS | 24-bit |

Built-in presets are read-only. Users can duplicate and modify them.

---

## UI Design

### Window Structure

Single window using `NavigationSplitView`:
- **Sidebar (220px):** Presets section (built-in + custom, "+" to create) and History section (recent files with date + preset used)
- **Detail area:** Context-dependent content based on app state

### App States

**Empty (no file loaded):**
- Large centered drop zone with dashed border
- "Drop audio file here" text + SF Symbol (waveform icon)
- "or choose file" button below
- Supported formats listed: WAV, MP3, M4A, AIFF

**File Loaded (ready to process):**
- File info bar: icon, filename, format details (sample rate, bit depth, channels → mono, duration, size), current LUFS (measured lazily in background on file load — shows spinner until ready; loading a new file cancels any in-progress analysis)
- Waveform preview (DSWaveformImage)
- Processing controls in 2x2 grid:
  - Noise Reduction: slider 0-100%
  - High-Pass Filter: slider 60-120 Hz
  - De-essing: slider 0-100%
  - Compression: segmented control (Gentle / Medium / Heavy)
- Target & Output row:
  - Target Loudness: segmented control (-16 LUFS / -14 LUFS)
  - Output: segmented control (16-bit WAV / 24-bit WAV)
- Estimated temp storage display
- "Process Audio" button (prominent, blue)

**Processing:**
- Progress bar replaces Process button
- Current stage name + percentage (e.g., "Noise Reduction — 45%")
- Cancel button
- All controls disabled during processing

**Results:**
- Before/After comparison:
  - Integrated LUFS (before → after, with target shown)
  - True Peak dBTP (before → after)
  - Processing time
- "Save As..." button (NSSavePanel for choosing output location)
- "Process Another" button (returns to empty state)
- Auto-suggested filename: `{originalname}_processed.wav`

### Design Language

- Modern macOS aesthetic with `.ultraThinMaterial` sidebar
- Light and dark mode via system appearance
- SF Symbols throughout (waveform, gear, clock, checkmark)
- Native macOS controls (Slider, Picker, Button styles)
- Utility-style app — focused, single-purpose, no chrome

---

## Error Handling

| Error | Detection | User Message |
|---|---|---|
| Unsupported file format | AVAudioFile fails to open | "This file format isn't supported. Use WAV, MP3, M4A, or AIFF." |
| File too short (< 1s) | Frame count check after decode | "This file is too short to process (minimum 1 second)." |
| Insufficient disk space | Preflight check (both volumes) | "Not enough disk space. Need X GB, only Y GB available." |
| Output path not writable | File manager permission check | "Can't write to this location. Choose a different folder." |
| DeepFilterNet init failure | `df_create` returns null | "Audio processing engine failed to initialize. Try restarting the app." |
| Processing failure mid-stream | Try/catch around processor chain | "Processing failed at [stage name]. Original file is unchanged." |
| LUFS outside tolerance | Post-export re-measurement | Show actual LUFS with note: "Target was -16.0 LUFS, achieved -16.4 LUFS" |

Original files are never modified. All processing writes to new files.

---

## Technology Stack

| Component | Technology | Purpose |
|---|---|---|
| UI Framework | SwiftUI (macOS 14+) | All views, navigation, state binding |
| Noise Reduction | DeepFilterNet v0.5.6 (vendor fork, C API static lib) | ML-based noise suppression |
| DSP | Accelerate/vDSP | Biquad filters (HPF, de-esser), FIR interpolation (limiter), vector ops |
| LUFS/True Peak Measurement | spfk-loudness (SPM, wraps libebur128) | EBU R128 integrated loudness + true peak dBTP |
| True Peak Limiting | Custom StreamingProcessor | 4x oversampling FIR + lookahead limiter (BS.1770 compliant) |
| Waveform Visualization | DSWaveformImage (SPM) | Audio waveform rendering in SwiftUI |
| Persistence | SwiftData | Presets and processing history |
| Audio File I/O | AVAudioFile (read), AVAudioConverter (resample), ExtAudioFile (write) | Decode/encode all supported formats |
| Build | Xcode 15+, Swift 5.9+, Rust toolchain (build-time only) | Universal binary (arm64 + x86_64) |

### SPM Dependencies

- `spfk-loudness` — EBU R128 measurement
- `DSWaveformImage` — Waveform visualization

### Vendored Dependencies

- DeepFilterNet (Rust static lib, pinned fork)

---

## Quality Bar

The processed audio must:

- Have significantly reduced background noise without robotic/warbling artifacts
- Hit the target loudness within ±0.5 LUFS (verified by post-export re-measurement)
- Have no true peak exceeding the ceiling (-1.0 dBTP by default)
- Have no audible clipping, pumping, or lispy de-essing artifacts
- Sound comparable to the same file processed by Auphonic (full-pipeline comparison, not just noise reduction)

### Validation Plan

- 3+ reference recordings: clean room, moderate noise (AC/fan), challenging noise (outdoor/traffic)
- Before/after SNR measurement on each reference clip
- Blind A/B listening comparison against Auphonic output
- Artifact checklist per clip: warbling, musical noise, voice coloration, lispy sibilance, pumping, clipping
- LUFS accuracy verification: process 10+ files, verify all land within ±0.5 LUFS of target
- True peak compliance: verify no output exceeds ceiling via libebur128 measurement

---

## Out of Scope (v1)

- Batch processing multiple files
- Watch folder / auto-processing
- Menu bar mode
- Real-time audio preview
- Timeline/waveform editing
- Recording capability
- Silence removal / trimming
- Shortcuts/Automator integration
- Stereo output preservation
- Noise shaping for 16-bit dithering
