; Celebi flies across the title screen in front of the running Suicune.
CELEBI_GFX_TILE EQU 60   ; first sprite tile id: just past the 60 crystal tiles in vTiles0
CELEBI_START_X  EQU 168  ; OAM x: off the right edge of the screen
CELEBI_HOVER_X  EQU 28   ; OAM x: hover ahead of (to the left of) the leftward-running Suicune
CELEBI_BASE_Y   EQU 108  ; OAM y: base hover height, level with Suicune's head
CELEBI_OAM_ATTR EQU 1    ; OBJ palette 1, drawn in front of the background

_TitleScreen:
	call ClearBGPalettes
	call ClearSprites
	call ClearTilemap

; Turn BG Map update off
	xor a
	ldh [hBGMapMode], a

; Reset timing variables
	ld hl, wJumptableIndex
	ld [hli], a ; wJumptableIndex
	ld [hli], a ; wTitleScreenSelectedOption
	ld [hli], a ; wTitleScreenTimer
	ld [hl], a  ; wTitleScreenTimer + 1

; Turn LCD off
	call DisableLCD

; VRAM bank 1
	ld a, 1
	ldh [rVBK], a

; Decompress running Suicune gfx
	ld hl, TitleSuicuneGFX
	ld de, vTiles1
	call Decompress

; Clear screen palettes
	hlbgcoord 0, 0
	ld bc, 20 * BG_MAP_WIDTH
	xor a
	call ByteFill

; Fill tile palettes:

; BG Map 1:

; line 0 (copyright)
	hlbgcoord 0, 0, vBGMap1
	ld bc, BG_MAP_WIDTH
	ld a, 7 ; palette
	call ByteFill

; BG Map 0:

; Apply logo gradient:

; lines 3-4
	hlbgcoord 0, 3
	ld bc, 2 * BG_MAP_WIDTH
	ld a, 2
	call ByteFill
; line 5
	hlbgcoord 0, 5
	ld bc, BG_MAP_WIDTH
	ld a, 3
	call ByteFill
; line 6
	hlbgcoord 0, 6
	ld bc, BG_MAP_WIDTH
	ld a, 4
	call ByteFill
; line 7
	hlbgcoord 0, 7
	ld bc, BG_MAP_WIDTH
	ld a, 5
	call ByteFill
; lines 8-9
	hlbgcoord 0, 8
	ld bc, 2 * BG_MAP_WIDTH
	ld a, 6
	call ByteFill

; 'CRYSTAL VERSION'
	hlbgcoord 5, 9
	ld bc, 11 ; length of version text
	ld a, 1
	call ByteFill

; 'TIMELESS' bar at screen row 10:
;   cols 6-11 (TIMELESS letters + clock left border) = palette 1
;   col 12 (clock tile) = palette 7 (so hand pixels can be opaque black)
;   col 13 (right border) = palette 1
	hlbgcoord 6, 10
	ld bc, 6
	ld a, 1
	call ByteFill

	hlbgcoord 12, 10
	ld bc, 1
	ld a, 7
	call ByteFill

	hlbgcoord 13, 10
	ld bc, 1
	ld a, 1
	call ByteFill

; Clock bottom border at screen row 11 col 12 (palette 1, for the red top row)
	hlbgcoord 12, 11
	ld bc, 1
	ld a, 1
	call ByteFill

; Suicune gfx
	hlbgcoord 0, 12
	ld bc, 6 * BG_MAP_WIDTH ; the rest of the screen
	ld a, 0 | VRAM_BANK_1
	call ByteFill

; Back to VRAM bank 0
	ld a, 0
	ldh [rVBK], a

; Decompress logo
	ld hl, TitleLogoGFX
	ld de, vTiles1
	call Decompress

; Decompress background crystal
	ld hl, TitleCrystalGFX
	ld de, vTiles0
	call Decompress

; Decompress Celebi into the free vTiles0 space right after the crystal
	ld hl, TitleCelebiGFX
	ld de, vTiles0 + CELEBI_GFX_TILE tiles
	call Decompress

; Clear screen tiles
	hlbgcoord 0, 0
	ld bc, 64 * BG_MAP_WIDTH
	ld a, " "
	call ByteFill

; Draw Pokemon logo
	hlcoord 0, 3
	lb bc, 7, 20
	ld d, $80
	ld e, 20
	call DrawTitleGraphic

; Draw copyright text (16 tiles wide for "©2026 SPP & ETM V1.1.2", centered)
	hlbgcoord 2, 0, vBGMap1
	lb bc, 1, 16
	ld d, $c
	ld e, 16
	call DrawTitleGraphic

; Draw TIMELESS bar at screen row 10 (tile ids $20..$27: 6 TIMELESS + 1 clock + 1 right-border)
	hlcoord 6, 10
	lb bc, 1, 8
	ld d, $20
	ld e, 20
	call DrawTitleGraphic

; Draw clock bottom-border tile at screen row 11 col 12 (tile id $28)
	hlcoord 12, 11
	lb bc, 1, 1
	ld d, $28
	ld e, 20
	call DrawTitleGraphic

; Initialize running Suicune?
	ld d, $0
	call LoadSuicuneFrame

; Initialize background crystal
	call InitializeBackground

; Update palette colors
	ldh a, [rSVBK]
	push af
	ld a, BANK(wBGPals1)
	ldh [rSVBK], a

	ld hl, TitleScreenPalettes
	ld de, wBGPals1
	ld bc, 16 palettes
	call CopyBytes

	ld hl, TitleScreenPalettes
	ld de, wBGPals2
	ld bc, 16 palettes
	call CopyBytes

	pop af
	ldh [rSVBK], a

; LY/SCX trickery starts here

	ldh a, [rSVBK]
	push af
	ld a, BANK(wLYOverrides)
	ldh [rSVBK], a

; Make alternating lines come in from opposite sides

; (This part is actually totally pointless, you can't
;  see anything until these values are overwritten!)

	ld b, 80 / 2 ; alternate for 80 lines
	ld hl, wLYOverrides
.loop
; $00 is the middle position
	ld [hl], +112 ; coming from the left
	inc hl
	ld [hl], -112 ; coming from the right
	inc hl
	dec b
	jr nz, .loop

; Make sure the rest of the buffer is empty
	ld hl, wLYOverrides + 80
	xor a
	ld bc, wLYOverridesEnd - (wLYOverrides + 80)
	call ByteFill

; Let LCD Stat know we're messing around with SCX
	ld a, LOW(rSCX)
	ldh [hLCDCPointer], a

	pop af
	ldh [rSVBK], a

; Reset audio
	call ChannelsOff
	call EnableLCD

; Set sprite size to 8x16
	ldh a, [rLCDC]
	set rLCDC_SPRITE_SIZE, a
	ldh [rLCDC], a

	ld a, +112
	ldh [hSCX], a
	ld a, 8
	ldh [hSCY], a
	ld a, 7
	ldh [hWX], a
	ld a, -112
	ldh [hWY], a

	ld a, TRUE
	ldh [hCGBPalUpdate], a

; Update BG Map 0 (bank 0)
	ldh [hBGMapMode], a

	xor a
	ld [wSuicuneFrame], a

; Start Celebi off-screen to the right, ready to fly in
	ld a, CELEBI_START_X
	ld [wCelebiX], a
	xor a
	ld [wCelebiBob], a

; Play starting sound effect
	call SFXChannelsOff
	ld de, SFX_TITLE_SCREEN_ENTRANCE
	call PlaySFX

	ret

SuicuneFrameIterator:
	ld hl, wSuicuneFrame
	ld a, [hl]
	ld c, a
	inc [hl]

; Only do this once every eight frames
	and %111
	ret nz

	ld a, c
	and %11000
	sla a
	swap a
	ld e, a
	ld d, 0
	ld hl, .Frames
	add hl, de
	ld d, [hl]
	xor a
	ldh [hBGMapMode], a
	call LoadSuicuneFrame
	ld a, $1
	ldh [hBGMapMode], a
	ld a, $3
	ldh [hBGMapThird], a
	ret

.Frames:
	db $80 ; vTiles3 tile $80
	db $88 ; vTiles3 tile $88
	db $00 ; vTiles5 tile $00
	db $08 ; vTiles5 tile $08

LoadSuicuneFrame:
	hlcoord 6, 12
	ld b, 6
.bgrows
	ld c, 8
.col
	ld a, d
	ld [hli], a
	inc d
	dec c
	jr nz, .col
	ld a, SCREEN_WIDTH - 8
	add l
	ld l, a
	ld a, 0
	adc h
	ld h, a
	ld a, 8
	add d
	ld d, a
	dec b
	jr nz, .bgrows
	ret

DrawTitleGraphic:
; input:
;   hl: draw location
;   b: height
;   c: width
;   d: tile to start drawing from
;   e: number of tiles to advance for each bgrows
.bgrows
	push de
	push bc
	push hl
.col
	ld a, d
	ld [hli], a
	inc d
	dec c
	jr nz, .col
	pop hl
	ld bc, SCREEN_WIDTH
	add hl, bc
	pop bc
	pop de
	ld a, e
	add d
	ld d, a
	dec b
	jr nz, .bgrows
	ret

InitializeBackground:
	ld hl, wVirtualOAMSprite00
	ld d, -$22
	ld e, $0
	ld c, 5
.loop
	push bc
	call .InitColumn
	pop bc
	ld a, $10
	add d
	ld d, a
	dec c
	jr nz, .loop
	ret

.InitColumn:
	ld c, $6
	ld b, $40
.loop2
	ld a, d
	ld [hli], a ; y
	ld a, b
	ld [hli], a ; x
	add $8
	ld b, a
	ld a, e
	ld [hli], a ; tile id
	inc e
	inc e
	ld a, 0 | PRIORITY
	ld [hli], a ; attributes
	dec c
	jr nz, .loop2
	ret

AnimateTitleCrystal:
; Move the title screen crystal downward until it's fully visible

; Stop at y=6
; y is really from the bottom of the sprite, which is two tiles high
	ld hl, wVirtualOAMSprite00YCoord
	ld a, [hl]
	cp 6 + 2 * TILE_WIDTH
	ret z

; Move all 30 parts of the crystal down by 2
	ld c, 30
.loop
	ld a, [hl]
	add 2
	ld [hli], a ; y
rept SPRITEOAMSTRUCT_LENGTH - 1
	inc hl
endr
	dec c
	jr nz, .loop

	ret

AnimateTitleCelebi:
; Fly Celebi in from the right edge, then have it hover and gently bob up and
; down in front of the running Suicune. Uses virtual OAM sprites 30-35.

; Advance x toward the hover position
	ld a, [wCelebiX]
	cp CELEBI_HOVER_X
	jr z, .hovering
	dec a
	ld [wCelebiX], a
.hovering
	ld b, a ; base x

; Advance the bob timer and look up the current vertical offset
	ld a, [wCelebiBob]
	inc a
	ld [wCelebiBob], a
	srl a
	srl a ; one step every 4 frames
	and %1111
	ld e, a
	ld d, 0
	ld hl, .BobTable
	add hl, de
	ld a, [hl]
	add CELEBI_BASE_Y
	ld c, a ; base y

; Write the six 8x16 sprites that make up Celebi
	ld hl, wVirtualOAMSprite30
	ld de, .Sprites
	ld a, 6
.loop
	push af
	ld a, [de] ; dy
	add c
	ld [hli], a ; y
	inc de
	ld a, [de] ; dx
	add b
	ld [hli], a ; x
	inc de
	ld a, [de] ; tile
	ld [hli], a ; tile id
	inc de
	ld a, CELEBI_OAM_ATTR
	ld [hli], a ; attributes
	pop af
	dec a
	jr nz, .loop
	ret

.Sprites:
	;  dy, dx, tile
	db  0,  0, CELEBI_GFX_TILE + 0
	db  0,  8, CELEBI_GFX_TILE + 2
	db  0, 16, CELEBI_GFX_TILE + 4
	db 16,  0, CELEBI_GFX_TILE + 6
	db 16,  8, CELEBI_GFX_TILE + 8
	db 16, 16, CELEBI_GFX_TILE + 10

.BobTable:
	db 0, 1, 2, 3, 3, 3, 2, 1, 0, -1, -2, -3, -3, -3, -2, -1

TitleSuicuneGFX:
INCBIN "gfx/title/suicune.2bpp.lz"

TitleLogoGFX:
INCBIN "gfx/title/logo.2bpp.lz"

TitleCrystalGFX:
INCBIN "gfx/title/crystal.2bpp.lz"

TitleCelebiGFX:
INCBIN "gfx/title/celebi.2bpp.lz"

TitleScreenPalettes:
INCLUDE "gfx/title/title.pal"
