# Ear-Test Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Awesome Audio sound closer to the user's Audacity reference by reducing perceived peaking, restoring brightness, and avoiding avoidable stereo collapse.

**Architecture:** Keep the day-1 export fix intact and treat this as a processing-design correction. Split the work into measurement first, then safer gain staging, then a new mastering-oriented path that can bypass speech-enhancement stages when they hurt the material.

**Tech Stack:** Swift, AVFoundation, Accelerate, Swift Testing, ffmpeg/ffprobe for fixture analysis

---

## File Map

- Modify: `AwesomeAudio/Audio/ProcessingCoordinator.swift`
- Modify: `AwesomeAudio/Audio/AudioFormatAdapter.swift`
- Modify: `AwesomeAudio/Audio/Processors/GainProcessor.swift`
- Modify: `AwesomeAudio/Audio/Processors/TruePeakLimiter.swift`
- Modify: `AwesomeAudio/Audio/Processors/DeEsser.swift`
- Modify: `AwesomeAudio/Models/Preset.swift`
- Modify: `AwesomeAudio/ViewModels/AudioProcessingViewModel.swift`
- Modify: `AwesomeAudio/Views/ProcessingControlsView.swift`
- Create: `AwesomeAudio/Audio/Processors/ToneShaper.swift`
- Create: `AwesomeAudioTests/Audio/ProcessingCoordinatorEarTests.swift`
- Create: `AwesomeAudioTests/Audio/Processors/ToneShaperTests.swift`
- Modify: `AwesomeAudioTests/Models/PresetTests.swift`
- Modify: `README.md`

### Task 1: Capture The Ear-Test Failure In Measurements

**Files:**
- Create: `AwesomeAudioTests/Audio/ProcessingCoordinatorEarTests.swift`
- Modify: `AwesomeAudioTests/TestHelpers/AudioTestHelpers.swift`

- [ ] **Step 1: Add helper assertions for tone and headroom checks**

Add helpers to compare:
- peak and true-peak margin
- simple band-energy ratios for `2 kHz - 10 kHz` versus `80 Hz - 2 kHz`
- mono/stereo metadata where available

- [ ] **Step 2: Write a failing regression for over-pushed output**

Create a coordinator test using a speech-like synthetic fixture or committed short fixture and assert:
- output true peak stays below the intended ceiling with margin
- output is not driven above target LUFS by overshoot

- [ ] **Step 3: Write a failing regression for tonal dullness**

Add a test that demonstrates the current chain reduces high-band energy too aggressively when denoise + de-ess are enabled together.

- [ ] **Step 4: Run the new targeted tests and verify they fail**

Run: `swift test --filter ProcessingCoordinatorEarTests`
Expected: FAIL on peak margin and/or high-band retention assertions.

- [ ] **Step 5: Commit the red tests**

```bash
git add AwesomeAudioTests/Audio/ProcessingCoordinatorEarTests.swift AwesomeAudioTests/TestHelpers/AudioTestHelpers.swift
git commit -m "test: capture ear-test regressions"
```

### Task 2: Fix Gain Staging Before Tonal Changes

**Files:**
- Modify: `AwesomeAudio/Audio/ProcessingCoordinator.swift`
- Modify: `AwesomeAudio/Audio/Processors/GainProcessor.swift`
- Modify: `AwesomeAudio/Audio/Processors/TruePeakLimiter.swift`
- Test: `AwesomeAudioTests/Audio/ProcessingCoordinatorEarTests.swift`

- [ ] **Step 1: Remove loudness overshoot from pass 2**

Change the coordinator so final gain targets the requested LUFS directly instead of adding the current `+0.3 LU` overshoot.

- [ ] **Step 2: Revisit limiter recovery and ceiling defaults**

Set a more conservative default ceiling for mastering-style presets, likely around `-2.0 dBTP`, and verify limiter release behavior is not audibly pumping or shaving transients too late.

- [ ] **Step 3: Re-run targeted ear tests**

Run: `swift test --filter ProcessingCoordinatorEarTests`
Expected: peak/headroom assertions pass or move materially closer.

- [ ] **Step 4: Run the full test suite**

Run: `swift test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AwesomeAudio/Audio/ProcessingCoordinator.swift AwesomeAudio/Audio/Processors/GainProcessor.swift AwesomeAudio/Audio/Processors/TruePeakLimiter.swift AwesomeAudioTests/Audio/ProcessingCoordinatorEarTests.swift
git commit -m "fix: reduce loudness-stage peaking"
```

### Task 3: Add A Mastering-Oriented Tonal Path

**Files:**
- Create: `AwesomeAudio/Audio/Processors/ToneShaper.swift`
- Modify: `AwesomeAudio/Audio/ProcessingCoordinator.swift`
- Modify: `AwesomeAudio/Models/Preset.swift`
- Modify: `AwesomeAudio/ViewModels/AudioProcessingViewModel.swift`
- Modify: `AwesomeAudio/Views/ProcessingControlsView.swift`
- Create: `AwesomeAudioTests/Audio/Processors/ToneShaperTests.swift`
- Modify: `AwesomeAudioTests/Models/PresetTests.swift`

- [ ] **Step 1: Write failing tests for a gentle presence/air shelf**

Create tests proving the tone shaper can add high-frequency lift without changing silence, DC, or clipping behavior.

- [ ] **Step 2: Implement a minimal tone shaper**

Implement a restrained mastering EQ stage with:
- optional low cut for rumble
- optional presence lift
- optional air lift

Avoid cloning the Audacity macro exactly. Match its intent with a simpler, safer implementation.

- [ ] **Step 3: Add a mastering-friendly preset path**

Introduce preset behavior that defaults to:
- denoise off or near-off
- lighter de-ess
- gentler compression
- conservative limiter ceiling
- mild brightness restoration

- [ ] **Step 4: Wire controls and snapshot serialization**

Expose only the minimum new controls needed to validate the sound direction without overcomplicating the UI.

- [ ] **Step 5: Run focused tests**

Run:
- `swift test --filter ToneShaperTests`
- `swift test --filter PresetTests`
- `swift test --filter ProcessingCoordinatorEarTests`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add AwesomeAudio/Audio/Processors/ToneShaper.swift AwesomeAudio/Audio/ProcessingCoordinator.swift AwesomeAudio/Models/Preset.swift AwesomeAudio/ViewModels/AudioProcessingViewModel.swift AwesomeAudio/Views/ProcessingControlsView.swift AwesomeAudioTests/Audio/Processors/ToneShaperTests.swift AwesomeAudioTests/Models/PresetTests.swift AwesomeAudioTests/Audio/ProcessingCoordinatorEarTests.swift
git commit -m "feat: add mastering-oriented tone shaping"
```

### Task 4: Stop Throwing Away Stereo By Default

**Files:**
- Modify: `AwesomeAudio/Audio/AudioFormatAdapter.swift`
- Modify: `AwesomeAudio/Audio/ProcessingCoordinator.swift`
- Modify: `AwesomeAudio/Models/Preset.swift`
- Modify: `README.md`
- Test: `AwesomeAudioTests/AudioFormatAdapterTests.swift`

- [ ] **Step 1: Decide the smallest safe stereo policy**

Implement one of these, in order of preference:
1. preserve stereo for non-denoise mastering mode
2. keep mono only for the speech-enhancement path
3. if full stereo is too risky, warn clearly in UI and docs

- [ ] **Step 2: Write or update tests for channel handling**

Extend adapter tests so stereo material is either preserved in mastering mode or explicitly documented and asserted as mono in enhancement mode.

- [ ] **Step 3: Implement the chosen policy**

Keep the change minimal and do not destabilize the day-1 export writer.

- [ ] **Step 4: Run channel-handling and full tests**

Run:
- `swift test --filter AudioFormatAdapter`
- `swift test`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AwesomeAudio/Audio/AudioFormatAdapter.swift AwesomeAudio/Audio/ProcessingCoordinator.swift AwesomeAudio/Models/Preset.swift README.md AwesomeAudioTests/AudioFormatAdapterTests.swift
git commit -m "fix: preserve stereo where processing allows"
```

### Task 5: Validate Against The User Reference

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-03-26-ear-test-fix-plan.md`

- [ ] **Step 1: Build a fresh Release app**

Run:
`xcodebuild -project AwesomeAudio.xcodeproj -scheme AwesomeAudio -configuration Release -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY='' build`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Process the user's sample through the new preset path**

Use the app or a targeted harness and compare against the user's reference criteria:
- less audible peaking
- less muffling
- acceptable brightness
- acceptable noise floor

- [ ] **Step 3: Record outcome notes**

Update `README.md` or release notes draft with:
- what changed
- what still differs from Audacity
- best preset for spoken-word mastering

- [ ] **Step 4: Run final verification**

Run: `swift test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/superpowers/plans/2026-03-26-ear-test-fix-plan.md
git commit -m "docs: record ear-test validation notes"
```

## Risks To Watch

- DeepFilterNet is still a speech-enhancement model and may remain a poor default for already-clean narration.
- Stereo preservation may require branching the pipeline, not a one-line fix.
- Tonal comparisons based only on synthetic fixtures can miss real spoken-word edge cases, so user sample checks remain required.

## Verification Checklist

- `swift test`
- Release build succeeds
- processed spoken-word sample no longer sounds obviously clipped or dulled
- release notes updated with both fixed defects and remaining concerns
