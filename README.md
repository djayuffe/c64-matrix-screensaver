# C64 Matrix Screensaver

A PAL-friendly Commodore 64 text-mode Matrix rain screensaver. It renders a
white-to-green character stream in all 40 columns while reserving the bottom
screen row for a live status display.

## Features

- 40 independent rain columns with seeded pseudo-random speed and tail length.
- Character ROM copied into RAM for matrix-style graphics glyphs.
- White head, light-green afterglow, green tail, and optional glyph churn.
- Bottom-row status display that remains protected from the rain renderer.
- VICE-friendly hotkeys, with polling in both frame-loop and raster-IRQ modes.
- IRQ mode preserves and restores the pre-existing KERNAL IRQ vector.

## Build and run

Install [ACME](https://sourceforge.net/projects/acme-crossass/) and VICE, then
run the following from the repository root:

```bash
make audit
make build
make run
```

The build produces `build/c64-matrix-screensaver.prg`, with a BASIC loader that
runs the program at `$2000` (`SYS 8192`). `make run` uses `x64sc`; set
`VICE=x64` if your installation uses that executable name.

## Controls

| Key | Action |
| --- | --- |
| `1`–`4` | Set rain update steps per frame. |
| `I` | Toggle raster-IRQ update mode. |
| `F` | Toggle between the two copied character-ROM font regions. |
| `C` | Toggle random tail-glyph churn. |

The status row reports the selected speed, IRQ mode, font region, and churn
setting. In VICE, use Symbolic keyboard mapping, focus the emulator window,
and avoid Warp Mode while testing input.

## Rendering model

The display uses VIC bank 0, screen RAM `$0400`, colour RAM `$D800`, and a
RAM copy of the C64 character ROM at `$1000`–`$1FFF`. Rain writes only rows
0–23. Row 24 is exclusively owned by `DrawStatus`, so animation cannot erase
the control feedback.

Each column transitions through three explicit states: pending spawn, active
head row, and inactive. A pending column enters at row 0; an inactive column
uses the PRNG and `SPAWN_RATE_MASK` to determine when to re-enter. This makes
the first frame visible and prevents the unsigned `$FE/$FF` spawn values from
being mistaken for off-screen rows.

## Project layout

- `src/matrix_screensaver.s` — complete 6502 assembly program.
- `tools/static_audit.py` — regression guards for memory mapping, spawn logic,
  status-row protection, and IRQ-vector restoration.
- `AUDIT.md` — concrete fixes made during the independent import.

## Limits

The program targets the standard single-VIC C64 text mode and is designed for
PAL-style frame timing. It does not include music, sprites, or a disk loader.

## Provenance

This independent repository was created from the supplied Matrix screensaver
source archive. No licence accompanied that archive; obtain permission from
the original author before redistributing outside your own account.
