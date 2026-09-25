# Changelog

## 0.0.2 — 2026-09-25

Audit and correctness release.

- Added virtual off-screen tail draining, so every stream fades out and clears
  instead of leaving stale characters after its head exits the screen.
- Made tail lengths uniformly selectable across the full configured 10–20 range.
- Reworked IRQ mode into a short raster frame scheduler; rendering no longer
  runs inside the IRQ handler.
- Preserved CIA/KERNAL timing and the original VIC IRQ state, then chained
  through the saved IRQ vector instead of assuming the stock KERNAL entry.
- Replaced unreliable direct VICE PRG autostart in `make run` with a
  deterministic post-boot VICE monitor script.
- Expanded source-level audit coverage and refreshed the verified VICE capture.

## 0.0.1 — 2026-09-25

Initial independent release of C64 Matrix Screensaver.

- Corrected charset copy, spawn state, status row, screen-code, and IRQ-vector
  defects.
- Added repeatable build and source-audit commands.
- Added usage and rendering documentation.
