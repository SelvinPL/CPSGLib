;================================================================
; PSGlib - Programmable Sound Generator audio library - by sverx
;          https://github.com/sverx/PSGlib
;================================================================
;*** *** *** *** this is the minimalistic version *** *** *** ***
;================================================================

; NOTE: this uses a WLA-DX 'ramsection' at slot 3
;       If you want to change or remove that,
;       see the note at the end of this file

.title			"PSGLib-minimal"
.module			psglib-minimal
.area			_CODE
PSG_STOPPED         =0
PSG_PLAYING         =1

PSGDataPort         =0x7f

PSGLatch            =0x80
PSGData             =0x40

PSGChannel0         =0b00000000
PSGChannel1         =0b00100000
PSGChannel2         =0b01000000
PSGChannel3         =0b01100000
PSGVolumeData       =0b00010000

PSGWait             =0x38
PSGSubString        =0x08
PSGLoop             =0x01
PSGEnd              =0x00
.globl _PSGMusicStatus
.globl _PSGMusicStart
.globl _PSGMusicPointer
.globl _PSGMusicLoopPoint
.globl _PSGMusicSkipFrames
.globl _PSGLoopFlag

.globl _PSGMusicSubstringLen
.globl _PSGMusicSubstringRetAddr


; ************************************************************************************
; initializes the PSG 'engine'
; destroys AF
_PSGInit::
  xor a                           ; ld a,PSG_STOPPED
  ld (_PSGMusicStatus),a           ; set music status to PSG_STOPPED
  ret

; ************************************************************************************
; receives in HL the address of the PSG to start playing
; destroys AF
_PSGPlayNoRepeat::
  xor a                           ; We don't want the song to loop
  jp .skip$
_PSGPlay::
  ld a,#1                         ; the song can loop when finished
.skip$:
  ld (_PSGLoopFlag),a
  call _PSGStop                    ; if there's a tune already playing, we should stop it!
  ld (_PSGMusicStart),hl           ; store the begin point of music
  ld (_PSGMusicPointer),hl         ; set music pointer to begin of music
  ld (_PSGMusicLoopPoint),hl       ; looppointer points to begin too
  xor a
  ld (_PSGMusicSkipFrames),a       ; reset the skip frames
  ld (_PSGMusicSubstringLen),a     ; reset the substring len (for compression)
  ld a, #PSG_PLAYING
  ld (_PSGMusicStatus),a           ; set status to PSG_PLAYING
  ret


; ************************************************************************************
; stops the music (leaving the SFX on, if it's playing)
; destroys AF
_PSGStop::
  ld a,(_PSGMusicStatus)                         ; if it's already stopped, leave
  or a
  ret z
  ld a,#PSGLatch|#PSGChannel0|#PSGVolumeData|#0x0F   ; latch channel 0, volume=0xF (silent)
  out (PSGDataPort),a
  ld a,#PSGLatch|#PSGChannel1|#PSGVolumeData|0x0F   ; latch channel 1, volume=0xF (silent)
  out (PSGDataPort),a
  ld a,#PSGLatch|#PSGChannel2|#PSGVolumeData|#0x0F   ; latch channel 2, volume=0xF (silent)
  out (PSGDataPort),a
  ld a,#PSGLatch|#PSGChannel3|#PSGVolumeData|#0x0F   ; latch channel 3, volume=0xF (silent)
  xor a                                         ; ld a,PSG_STOPPED
  ld (_PSGMusicStatus),a                         ; set status to PSG_STOPPED
  ret


; ************************************************************************************
; sets the currently looping music to no more loops after the current
; destroys AF
_PSGCancelLoop::
  xor a
  ld (_PSGLoopFlag),a
  ret

; ************************************************************************************
; gets the current status of music into register A
;_PSGGetStatus:
;  ld a,(_PSGMusicStatus)
;  ret


; ************************************************************************************
; processes a music frame
; destroys AF,HL,BC
_PSGFrame::
  ld a,(_PSGMusicStatus)          ; check if we have got to play a tune
  or a
  ret z

  ld a,(_PSGMusicSkipFrames)      ; check if we havve got to skip frames
  or a
  jp z,100$
  dec a                          ; skip this frame and ret
  ld (_PSGMusicSkipFrames),a
  ret

100$:
  ld hl,(_PSGMusicPointer)        ; read current address

_intLoop:
  ld b,(hl)                      ; load PSG byte (in B)
  inc hl                         ; point to next byte
  ld a,(_PSGMusicSubstringLen)    ; read substring len
  or a
  jr z,_continue                 ; check if it is 0 (we are not in a substring)
  dec a                          ; decrease len
  ld (_PSGMusicSubstringLen),a    ; save len
  jr nz,_continue
  ld hl,(_PSGMusicSubstringRetAddr)  ; substring is over, retrieve return address

_continue:
  ld a,b                         ; copy PSG byte into A
101$:
  cp #PSGData                     ; is it a command (<$40)??
  jr c,102$                         ; it is not, output it!
  out (PSGDataPort),a
  jr _intLoop

102$:
  cp #PSGWait
  jr z,_done                     ; no additional frames
  jr c,_otherCommands            ; other commands?
  and #0x07                        ; take only the last 3 bits for skip frames
  ld (_PSGMusicSkipFrames),a      ; we got additional frames
_done:
  ld (_PSGMusicPointer),hl        ; save current address
  ret                            ; frame done

_otherCommands:
  cp #PSGSubString
  jr nc,_substring
  cp #PSGEnd
  jr z,_musicLoop
  cp #PSGLoop
  jr z,_setLoopPoint

  ; ***************************************************************************
  ; we should never get here!
  ; if we do, it means the PSG file is probably corrupted, so we just RET
  ; ***************************************************************************

  ret

_setLoopPoint:
  ld (_PSGMusicLoopPoint),hl
  jp _intLoop

_musicLoop:
  ld a,(_PSGLoopFlag)               ; looping requested?
  or a
  jp z, _PSGStop                     ; No:stop it! (tail call optimization)
  ld hl,(_PSGMusicLoopPoint)
  jp _intLoop

_substring:
  sub #PSGSubString-4                  ; len is value - $08 + 4
  ld (_PSGMusicSubstringLen),a         ; save len
  ld c,(hl)                           ; load substring address (offset)
  inc hl
  ld b,(hl)
  inc hl
  ld (_PSGMusicSubstringRetAddr),hl    ; save return address
  ld hl,(_PSGMusicStart)
  add hl,bc                           ; make substring current
  jp _intLoop

; NOTE: if you don't want to use a ramsection,
;       comment the ".ramsection" line and
;       uncomment the next ".enum" one,
;       setting .enum start RAM address
;       according to your needs.
;       Also change ".ends" into ".ende" at end of this file

.area _DATA
  ; fundamental vars
_PSGMusicStatus:
    .db 1    ; are we playing a background music?
_PSGMusicStart:
    .dw 1   ; the pointer to the beginning of music
_PSGMusicPointer:
    .dw 1    ; the pointer to the current
_PSGMusicLoopPoint:
    .dw 1    ; the pointer to the loop begin
_PSGMusicSkipFrames:
    .db 1    ; the frames we need to skip
_PSGLoopFlag:
    .db 1    ; the tune should loop or not (flag)

  ; decompression vars
_PSGMusicSubstringLen:
    .db 1    ; lenght of the substring we are playing
_PSGMusicSubstringRetAddr:
    .dw 1    ; return to this address when substring is over