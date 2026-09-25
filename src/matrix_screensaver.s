;
; ============================================================
;  C64 "Full Matrix" — v22 (VICE-friendly hotkeys + status OSD)
;  - Robust keys: each frame call CLRCHN ($FFCC) + SCNKEY ($FF9F) then GETIN.
;  - Live hotkeys: 1/2/3/4 speed, I toggle IRQ, F toggle font ($14↔$16), C churn.
;  - Status line on row 24 shows: SPD, IRQ ON/OFF, FONT 14/16, CHURN ON/OFF.
;  - Matrix glyphs default ($14), white head → light green → green fade.
; ============================================================

AUTO_RUN        = 1

SPAWN_RATE_MASK = $01
TAIL_LENGTH_MIN = 10
TAIL_LENGTH_MAX = 20
HEAD_WHITE      = 1
SPEED_MAX_DIV   = 1
RAIN_ROWS        = 24            ; rows 0..23; row 24 is reserved for status
HEAD_PENDING     = $FE
HEAD_INACTIVE    = $FF

COL_BG    = $00
COL_HEAD  = $01
COL_LGRN  = $0D
COL_GRN   = $05
COL_OSD   = $01  ; white

; Upper/graphics screen codes used by the direct screen-RAM status display.
SC_C = 3
SC_D = 4
SC_F = 6
SC_H = 8
SC_I = 9
SC_N = 14
SC_O = 15
SC_P = 16
SC_Q = 17
SC_R = 18
SC_S = 19
SC_T = 20
SC_U = 21

; ---------------------- Addresses ---------------------------
SCREEN    = $0400
COLORRAM  = $D800
CHARSET   = $1000
CODEBASE  = $2000

VIC_BORD  = $D020
VIC_BG    = $D021
VIC_BANK  = $DD00
VIC_CTRL1 = $D011
VIC_CTRL2 = $D016
VIC_RASTER= $D012
VIC_MEM   = $D018
VIC_IRQ   = $D019
VIC_IRQEN = $D01A
PROC_PORT = $0001

; KERNAL routines
GETIN     = $FFE4
SCNKEY    = $FF9F
CLRCHN    = $FFCC

; ---------------------- Zero Page ---------------------------
PtrScr   = $FB
PtrCol   = $FD
SrcLo    = $F7
SrcHi    = $F8
DstLo    = $F9
DstHi    = $FA
PageCnt  = $02
ColIdx   = $03

; ---------------------- BASIC stub --------------------------
* = $0801
!if AUTO_RUN = 1 {
  !word nextline
  !word 10
  !byte $9e
  !text "8192"
  !byte 0
nextline:
  !word 0
} else {
  !word $0801, 0
}

; ---------------------- Program -----------------------------
* = CODEBASE

Start:
  sei
  ; Bank 0
  lda VIC_BANK
  and #%11111100
  ora #%00000011
  sta VIC_BANK

  ; Text mode, 25x40
  lda #%00011011         ; $1B
  sta VIC_CTRL1
  lda #%00001000         ; $08
  sta VIC_CTRL2

  ; Colors
  lda #COL_BG
  sta VIC_BORD
  sta VIC_BG

  ; Copy char ROM -> RAM ($1000-$1FFF)
  jsr CopyCharset

  ; UPPER/GRAPHICS ($1000) for Matrix glyphs
  lda #$14
  sta VIC_MEM
  sta CurrD018

  ; Clear
  jsr ClearScreen

  ; RNG
  lda #$91
  sta Rand
  lda #$27
  sta Rand2

  ; Seed all columns active
  ldx #39
SeedAll:
  lda #HEAD_PENDING
  sta HeadRow,x
  jsr Rand8
  and #SPEED_MAX_DIV
  clc
  adc #1
  sta SpeedDiv,x
  jsr Rand8
  and #((TAIL_LENGTH_MAX - TAIL_LENGTH_MIN) & $FF)
  clc
  adc #TAIL_LENGTH_MIN
  sta TailLen,x
  lda #0
  sta SpeedCtr,x
  dex
  bpl SeedAll

  ; Runtime flags
  lda #$00
  sta IrqEnabled
  lda #$02             ; default steps-per-frame = 2
  sta StepsPerFrame
  lda #$01             ; churn enabled by default
  sta ChurnEnabled
  lda #$01             ; force initial OSD draw
  sta StatusDirty

  cli                  ; enable KERNAL IRQs

Mainloop:
  jsr WaitFrame
  jsr PollKeys
  lda StatusDirty
  beq .nskip
  jsr DrawStatus
  lda #0
  sta StatusDirty
.nskip:
  lda IrqEnabled
  bne Mainloop         ; when IRQ is ON, updates happen in IRQ

  ; Otherwise, run N steps per frame here
  ldx StepsPerFrame
Mainloop_DoSteps:
  jsr UpdateRain
  dex
  bne Mainloop_DoSteps
  jmp Mainloop

; ---------------------- Draw status line (row 24) -----------
DrawStatus:
  ldy #24
  lda RowLo,y
  sta PtrScr
  lda RowHi,y
  sta PtrScr+1
  lda ColLo,y
  sta PtrCol
  lda ColHi,y
  sta PtrCol+1

  ; fill row with spaces + set color
  ldy #0
.ds_fill:
  lda #$20
  sta (PtrScr),y
  lda #COL_OSD
  sta (PtrCol),y
  iny
  cpy #40
  bne .ds_fill

  ; write "SPD:"
  ldy #0
  lda #SC_S
  sta (PtrScr),y
  iny
  lda #SC_P
  sta (PtrScr),y
  iny
  lda #SC_D
  sta (PtrScr),y
  iny
  lda #$3A  ; ':'
  sta (PtrScr),y
  iny
  ; digit StepsPerFrame (1..9) -> '1'..
  lda StepsPerFrame
  clc
  adc #$30
  sta (PtrScr),y

  ; "  IRQ:"
  ldy #6
  lda #$20
  sta (PtrScr),y
  iny
  sta (PtrScr),y
  iny
  lda #SC_I
  sta (PtrScr),y
  iny
  lda #SC_R
  sta (PtrScr),y
  iny
  lda #SC_Q
  sta (PtrScr),y
  iny
  lda #$3A  ; :
  sta (PtrScr),y
  iny
  lda #$20
  sta (PtrScr),y
  iny
  ; ON/OFF
  lda IrqEnabled
  beq .irq_off
  lda #SC_O
  sta (PtrScr),y
  iny
  lda #SC_N
  sta (PtrScr),y
  jmp .after_irq
.irq_off:
  lda #SC_O
  sta (PtrScr),y
  iny
  lda #SC_F
  sta (PtrScr),y
  iny
  lda #SC_F
  sta (PtrScr),y
.after_irq:

  ; "  FONT:" + "14"/"16"
  ldy #15
  lda #$20
  sta (PtrScr),y
  iny
  sta (PtrScr),y
  iny
  lda #SC_F
  sta (PtrScr),y
  iny
  lda #SC_O
  sta (PtrScr),y
  iny
  lda #SC_N
  sta (PtrScr),y
  iny
  lda #SC_T
  sta (PtrScr),y
  iny
  lda #$3A  ; :
  sta (PtrScr),y
  iny
  lda #$20
  sta (PtrScr),y
  iny
  lda CurrD018
  and #$02
  beq .font14
  ; -> $16
  lda #$31  ; '1'
  sta (PtrScr),y
  iny
  lda #$36  ; '6'
  sta (PtrScr),y
  jmp .after_font
.font14:
  lda #$31
  sta (PtrScr),y
  iny
  lda #$34
  sta (PtrScr),y
.after_font:

  ; "  CHURN:" + ON/OFF
  ldy #25
  lda #$20
  sta (PtrScr),y
  iny
  sta (PtrScr),y
  iny
  lda #SC_C
  sta (PtrScr),y
  iny
  lda #SC_H
  sta (PtrScr),y
  iny
  lda #SC_U
  sta (PtrScr),y
  iny
  lda #SC_R
  sta (PtrScr),y
  iny
  lda #SC_N
  sta (PtrScr),y
  iny
  lda #$3A  ; :
  sta (PtrScr),y
  iny
  lda #$20
  sta (PtrScr),y
  iny
  lda ChurnEnabled
  beq .ch_off
  lda #SC_O
  sta (PtrScr),y
  iny
  lda #SC_N
  sta (PtrScr),y
  jmp .after_ch
.ch_off:
  lda #SC_O
  sta (PtrScr),y
  iny
  lda #SC_F
  sta (PtrScr),y
  iny
  lda #SC_F
  sta (PtrScr),y
.after_ch:
  rts

; ---------------------- Hotkeys -----------------------------
PollKeys:
  jsr CLRCHN
  jsr SCNKEY

PollKeys_NextKey:
  jsr GETIN
  tax
  bne PollKeys_HaveKey
  jmp PollKeys_Done
PollKeys_HaveKey:
  ; digits 1..4
  cpx #'1'
  bne PollKeys_Chk2
  lda #1
  sta StepsPerFrame
  lda #1
  sta StatusDirty
  jmp PollKeys_NextKey
PollKeys_Chk2:
  cpx #'2'
  bne PollKeys_Chk3
  lda #2
  sta StepsPerFrame
  lda #1
  sta StatusDirty
  jmp PollKeys_NextKey
PollKeys_Chk3:
  cpx #'3'
  bne PollKeys_Chk4
  lda #3
  sta StepsPerFrame
  lda #1
  sta StatusDirty
  jmp PollKeys_NextKey
PollKeys_Chk4:
  cpx #'4'
  bne PollKeys_ChkI
  lda #4
  sta StepsPerFrame
  lda #1
  sta StatusDirty
  jmp PollKeys_NextKey
; toggle IRQ
PollKeys_ChkI:
  cpx #'I'
  beq PollKeys_Tirq
  cpx #'i'
  beq PollKeys_Tirq
  jmp PollKeys_ChkF
PollKeys_Tirq:
  lda IrqEnabled
  beq PollKeys_EnableIRQ
  jsr DisableIRQ
  lda #1
  sta StatusDirty
  jmp PollKeys_NextKey
PollKeys_EnableIRQ:
  jsr EnableIRQ
  lda #1
  sta StatusDirty
  jmp PollKeys_NextKey
; toggle font
PollKeys_ChkF:
  cpx #'F'
  beq PollKeys_Tfont
  cpx #'f'
  beq PollKeys_Tfont
  jmp PollKeys_ChkC
PollKeys_Tfont:
  lda CurrD018
  eor #$02            ; toggle $14 <-> $16
  sta CurrD018
  sta VIC_MEM
  lda #1
  sta StatusDirty
  jmp PollKeys_NextKey
; toggle churn
PollKeys_ChkC:
  cpx #'C'
  beq PollKeys_Tchurn
  cpx #'c'
  beq PollKeys_Tchurn
  jmp PollKeys_NextKey
PollKeys_Tchurn:
  lda ChurnEnabled
  eor #$01
  sta ChurnEnabled
  lda #1
  sta StatusDirty
  jmp PollKeys_NextKey

PollKeys_Done:
  rts

; ---------------------- Enable/Disable IRQ ------------------
EnableIRQ:
  sei
  lda IrqVectorSaved
  bne EnableIRQ_VectorSaved
  lda $0314
  sta SavedIrqLo
  lda $0315
  sta SavedIrqHi
  lda #$01
  sta IrqVectorSaved
EnableIRQ_VectorSaved:
  lda #$7F
  sta $DC0D
  sta $DD0D
  lda #$01
  sta VIC_IRQEN
  lda #$FA            ; raster 250
  sta VIC_RASTER
  lda VIC_CTRL1
  and #$7F
  sta VIC_CTRL1
  lda #$01
  sta VIC_IRQ
  lda #<IRQ
  sta $0314
  lda #>IRQ
  sta $0315
  lda #$01
  sta IrqEnabled
  cli
  rts

DisableIRQ:
  sei
  lda #$00
  sta VIC_IRQEN
  lda #$01
  sta VIC_IRQ
  lda SavedIrqLo
  sta $0314
  lda SavedIrqHi
  sta $0315
  lda #$00
  sta IrqEnabled
  cli
  rts

; ---------------------- Wait for next video frame -----------
WaitFrame:
  lda #$F8
WaitFrame_WFH:
  lda VIC_RASTER
  cmp #$F8
  bcc WaitFrame_WFH
WaitFrame_WFL:
  lda VIC_RASTER
  cmp #$F8
  bcs WaitFrame_WFL
  rts

; ---------------------- IRQ handler -------------------------
IRQ:
  pha
  txa
  pha
  tya
  pha
  lda #$01
  sta VIC_IRQ
  ; run N steps per IRQ frame
  ldx StepsPerFrame
IRQ_Steps:
  jsr UpdateRain
  dex
  bne IRQ_Steps
  pla
  tay
  pla
  tax
  pla
  jmp $EA31

; ---------------------- Clear screen ------------------------
ClearScreen:
  lda #$20
  ldy #0
ClearScreen_Clr:
  sta SCREEN,y
  sta SCREEN+256,y
  sta SCREEN+512,y
  sta SCREEN+768,y
  lda #COL_BG
  sta COLORRAM,y
  sta COLORRAM+256,y
  sta COLORRAM+512,y
  sta COLORRAM+768,y
  iny
  bne ClearScreen_Clr
  rts

; ---------------------- Update columns ----------------------
UpdateRain:
  ldx #0
ColLoop:
  jsr AdvanceColumn
  inx
  cpx #40
  bne ColLoop
  rts

; ---------------------- Advance single column (X=index) -----
AdvanceColumn:
  ; speed divider
  lda SpeedCtr,x
  beq AdvanceColumn_Step
  dec SpeedCtr,x
  rts
AdvanceColumn_Step:
  lda SpeedDiv,x
  sta SpeedCtr,x

  ; Pending heads enter at row 0. Inactive columns respawn probabilistically.
  lda HeadRow,x
  cmp #HEAD_PENDING
  beq AdvanceColumn_Spawn
  cmp #HEAD_INACTIVE
  bne AdvanceColumn_NextRow
  jsr Rand8
  and #SPAWN_RATE_MASK
  bne AdvanceColumn_StayInactive
  jmp AdvanceColumn_Spawn
AdvanceColumn_StayInactive:
  rts
AdvanceColumn_Spawn:
  ldy #0
  jmp AdvanceColumn_InRange
AdvanceColumn_NextRow:
  clc
  adc #1
  tay
  cpy #RAIN_ROWS
  bcc AdvanceColumn_InRange
  ; went off-screen: reset inactive & maybe respawn
  lda #HEAD_INACTIVE
  sta HeadRow,x
  rts

AdvanceColumn_InRange:
  ; store new head row
  tya
  sta HeadRow,x

  ; Set row pointers
  lda RowLo,y
  sta PtrScr
  lda RowHi,y
  sta PtrScr+1
  lda ColLo,y
  sta PtrCol
  lda ColHi,y
  sta PtrCol+1

  ; column index
  txa
  sta ColIdx

  ; Write head glyph + color
  jsr RandGlyphMatrix
  ldy ColIdx
  sta (PtrScr),y
!if HEAD_WHITE = 1 {
  lda #COL_HEAD
} else {
  lda #COL_LGRN
}
  sta (PtrCol),y

  ; prev1 -> light green + optional churn
  ldy HeadRow,x
  dey
  bmi AdvanceColumn_Skip1
  lda ColLo,y
  sta PtrCol
  lda ColHi,y
  sta PtrCol+1
  lda RowLo,y
  sta PtrScr
  lda RowHi,y
  sta PtrScr+1
  ldy ColIdx
  lda #COL_LGRN
  sta (PtrCol),y
  ; churn only if enabled
  lda ChurnEnabled
  beq AdvanceColumn_Skip1
  jsr Rand8
  and #$03          ; churn ~1/4
  bne AdvanceColumn_Skip1
  jsr RandGlyphMatrix
  sta (PtrScr),y
AdvanceColumn_Skip1:

  ; prev2 -> green
  ldy HeadRow,x
  dey
  dey
  bmi AdvanceColumn_Skip2
  lda ColLo,y
  sta PtrCol
  lda ColHi,y
  sta PtrCol+1
  ldy ColIdx
  lda #COL_GRN
  sta (PtrCol),y
AdvanceColumn_Skip2:

  ; far tail -> bg + space
  lda HeadRow,x
  sec
  sbc TailLen,x
  sbc #1
  bmi AdvanceColumn_Done
  tay
  lda ColLo,y
  sta PtrCol
  lda ColHi,y
  sta PtrCol+1
  lda RowLo,y
  sta PtrScr
  lda RowHi,y
  sta PtrScr+1
  ldy ColIdx
  lda #COL_BG
  sta (PtrCol),y
  lda #$20
  sta (PtrScr),y
AdvanceColumn_Done:
  rts

; ---------------------- PRNG & Glyphs -----------------------
Rand8:
  lda Rand
  beq Rand8_Doeor
  asl
  bcc Rand8_Noeor
Rand8_Doeor:
  eor #$1D
Rand8_Noeor:
  sta Rand
  lda Rand2
  beq Rand8_Doeor2
  asl
  bcc Rand8_Noeor2
Rand8_Doeor2:
  eor #$1D
Rand8_Noeor2:
  sta Rand2
  eor Rand
  rts

; Matrixy: mostly graphics (64..127), occasional letters
RandGlyphMatrix:
  jsr Rand8
  and #$07
  bne RGM_Gfx
  jsr Rand8
  and #$1F
  cmp #26
  bcs RGM_Gfx
  clc
  adc #$01          ; screen codes for A..Z
  rts
RGM_Gfx:
  jsr Rand8
  and #$3F
  ora #$40
  rts

; ---------------------- Charset copy ------------------------
CopyCharset:
  lda PROC_PORT
  sta SaveProc
  ; CHAREN=0 exposes the character ROM at $D000 to the CPU.
  lda #$31
  sta PROC_PORT
  lda #<$D000
  sta SrcLo
  lda #>$D000
  sta SrcHi
  lda #<$1000
  sta DstLo
  lda #>$1000
  sta DstHi
  lda #16
  sta PageCnt
CopyCharset_Page:
  ldy #0
CopyCharset_Byte:
  lda (SrcLo),y
  sta (DstLo),y
  iny
  bne CopyCharset_Byte
  inc SrcHi
  inc DstHi
  dec PageCnt
  bne CopyCharset_Page
  lda SaveProc
  sta PROC_PORT
  rts

; ---------------------- Data -------------------------------
SaveProc:      !byte 0
Rand:          !byte 0
Rand2:         !byte 0
IrqEnabled:    !byte 0
StepsPerFrame: !byte 2
CurrD018:      !byte $14
ChurnEnabled:  !byte 1
StatusDirty:   !byte 0
SavedIrqLo:    !byte $31
SavedIrqHi:    !byte $EA
IrqVectorSaved:!byte 0

HeadRow:   !fill 40, HEAD_PENDING
TailLen:   !fill 40, 12
SpeedDiv:  !fill 40, 2
SpeedCtr:  !fill 40, 0

RowLo:
!for i,0,24 { !byte <(SCREEN + i*40) }
RowHi:
!for i,0,24 { !byte >(SCREEN + i*40) }
ColLo:
!for i,0,24 { !byte <(COLORRAM + i*40) }
ColHi:
!for i,0,24 { !byte >(COLORRAM + i*40) }

; ============================================================
; End
; ============================================================
