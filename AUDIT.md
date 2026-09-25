# Audit record

## Fixed defects

- Changed the charset-copy CPU port value from `$35` to `$31`; `$35` exposes
  I/O at `$D000`, while `$31` exposes the character ROM being copied.
- Repaired keyboard branches that exceeded the 6502 relative-branch range and
  prevented ACME from assembling the original source.
- Implemented explicit pending and inactive column states so initial `$FE`
  heads enter row 0 instead of being discarded as unsigned off-screen values.
- Reserved row 24 for the status display; rain now renders rows 0–23 only.
- Replaced direct PETSCII bytes in screen RAM with upper/graphics screen codes
  so status labels display as letters.
- Corrected the random-letter path to generate contiguous `A`–`Z` screen
  codes instead of a sparse unintended subset.
- Added a drain state so a stream tail keeps fading and clears completely after
  its head leaves the visible rows; it no longer freezes on screen.
- Replaced masked tail-length selection with rejection sampling, providing an
  unbiased value across every configured length from 10 through 20.
- Changed raster IRQ mode into a lightweight frame scheduler. Rendering now
  runs outside the interrupt handler, preventing long IRQ latency at higher
  update speeds.
- Preserved and restored the previous IRQ vector and VIC IRQ state. Raster mode
  now chains through the saved vector and leaves normal CIA/KERNAL timing
  enabled instead of silently disabling it.

## Verification

`make audit` checks the key invariants in source form, including tail draining,
unbiased tail selection, vector chaining, VIC-state restoration, and the
absence of rendering work inside the IRQ handler. `make build` assembles a CBM
PRG and verifies the expected BASIC `SYS 8192` loader.
