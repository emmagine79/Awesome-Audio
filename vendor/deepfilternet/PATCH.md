# DeepFilterNet Vendor Patch

**Base:** v0.5.6 (git tag)
**Patch date:** 2026-03-26

## Changes

### 1. Added `df_get_delay_samples()` to C API

**File:** `libDF/src/capi.rs`

Added a new exported function that returns the total algorithmic delay:

```rust
#[no_mangle]
pub unsafe extern "C" fn df_get_delay_samples(st: *mut DFState) -> usize {
    let state = st.as_ref().expect("Invalid pointer");
    let fft_size = state.0.fft_size;
    let hop_size = state.0.hop_size;
    let lookahead = state.0.lookahead;
    (fft_size - hop_size) + (lookahead * hop_size)
}
```

**Reason:** The existing C API only exposes `df_get_frame_length()` which returns
`hop_size`. For accurate delay compensation in offline processing, we need the
full delay: `(fft_size - hop_size) + (lookahead * hop_size)`.

### 2. Added `staticlib` crate-type

**File:** `libDF/Cargo.toml`

Added `crate-type = ["staticlib", "rlib"]` to `[lib]` section to enable building
as a static library for linking into the macOS app.

### 3. Updated `time` crate dependency

**File:** `Cargo.lock`

Updated `time` 0.3.28 → 0.3.44 to fix compilation with Rust 1.94+.

## Update Policy

- Check upstream quarterly
- If upstream adds `df_get_delay_samples()` or equivalent, switch back
- If upstream makes breaking C API changes, evaluate before updating
- The fork exists solely for these minor changes — no feature modifications
