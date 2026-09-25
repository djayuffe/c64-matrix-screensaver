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
- Preserved and restored the previous IRQ vector instead of forcing `$EA31`.

## Verification

`make audit` checks the key invariants in source form. `make build` assembles a
CBM PRG and verifies the expected BASIC `SYS 8192` loader.
