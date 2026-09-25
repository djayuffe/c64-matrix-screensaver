#!/usr/bin/env python3
"""Source-level regression checks for C64 Matrix Screensaver."""
from pathlib import Path
import sys

source_path = Path(sys.argv[1]) if len(sys.argv) == 2 else Path('src/matrix_screensaver.s')
source = source_path.read_text(encoding='utf-8')

required = {
    'RAM character-ROM copy': 'lda #$31',
    'reserved status row': 'RAIN_ROWS        = 24',
    'pending head state': 'HEAD_PENDING     = $FE',
    'inactive head state': 'HEAD_INACTIVE    = $FF',
    'pending spawn handler': 'AdvanceColumn_Spawn:',
    'tail drain handler': 'AdvanceColumn_Drain:',
    'tail drain cell clear': 'jsr ClearRainCell',
    'uniform tail-length generator': 'RandTailLength:',
    'tail-length rejection sampling': 'cmp #TAIL_LENGTH_RANGE',
    'saved IRQ vector': 'IrqVectorSaved:!byte 0',
    'saved VIC IRQ mask': 'SavedVicIrqEn: !byte 0',
    'saved raster register': 'SavedRaster:   !byte 0',
    'saved VIC control register': 'SavedCtrl1:    !byte 0',
    'IRQ frame scheduler': 'FramePending:  !byte 0',
    'saved IRQ chain': 'jmp (SavedIrqLo)',
    'status screen code': 'SC_S = 19',
    'letter glyph range': 'adc #$01          ; screen codes for A..Z',
}

errors = [name for name, marker in required.items() if marker not in source]
if 'cpy #25\n  bcc AdvanceColumn_InRange' in source:
    errors.append('rain renderer can still overwrite row 24')
if 'lda #$35\n  sta PROC_PORT' in source:
    errors.append('charset copy still exposes I/O instead of character ROM')
if 'bne PollKeys_NextKey' in source:
    errors.append('out-of-range keyboard branch returned')
if 'jmp $EA31' in source:
    errors.append('IRQ handler bypasses the saved IRQ vector')
if 'jsr UpdateRain\n  dex\n  bne IRQ_Steps' in source:
    errors.append('full rain rendering still runs inside the IRQ handler')
if 'and #((TAIL_LENGTH_MAX - TAIL_LENGTH_MIN) & $FF)' in source:
    errors.append('tail-length generation still uses a biased bit mask')
if 'lda #$7F\n  sta $DC0D' in source:
    errors.append('IRQ setup still disables normal CIA/KERNAL timing')

if errors:
    print('STATIC AUDIT FAILED')
    for error in errors:
        print(f' - {error}')
    raise SystemExit(1)

print('STATIC AUDIT OK')
print('character ROM mapping, spawn/drain states, status row, IRQ restoration, and screen codes verified')
