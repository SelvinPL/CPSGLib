;================================================================
; PSGlib - Programmable Sound Generator audio library - by sverx
;          https://github.com/sverx/PSGlib
;================================================================
;*** *** *** *** this is the minimalistic version *** *** *** ***
;================================================================

; NOTE: this uses a WLA-DX 'ramsection' at slot 3
;       If you want to change or remove that,
;       see the note at the end of this file

.title			"PSGLib_minimal"
.module			psglib_minimal
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
  jp .play$
_PSGPlay::
  ld a,#1                         ; the song can loop when finished
.play$:
  ld (.PSGLoopFlag),a
  call _PSGStop                    ; if there's a tune already playing, we should stop it!
  ld (.PSGMusicStart),hl           ; store the begin point of music
  ld (.PSGMusicPointer),hl         ; set music pointer to begin of music
  ld (.PSGMusicLoopPoint),hl       ; looppointer points to begin too
  xor a
  ld (.PSGMusicSkipFrames),a       ; reset the skip frames
  ld (.PSGMusicSubstringLen),a     ; reset the substring len (for compression)
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
  ld (.PSGLoopFlag),a
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

  ld a,(.PSGMusicSkipFrames)      ; check if we havve got to skip frames
  or a
  jp z,100$
  dec a                          ; skip this frame and ret
  ld (.PSGMusicSkipFrames),a
  ret

100$:
  ld hl,(.PSGMusicPointer)        ; read current address

.intLoop:
  ld b,(hl)                      ; load PSG byte (in B)
  inc hl                         ; point to next byte
  ld a,(.PSGMusicSubstringLen)    ; read substring len
  or a
  jr z,.continue                 ; check if it is 0 (we are not in a substring)
  dec a                          ; decrease len
  ld (.PSGMusicSubstringLen),a    ; save len
  jr nz,.continue
  ld hl,(.PSGMusicSubstringRetAddr)  ; substring is over, retrieve return address

.continue:
  ld a,b                         ; copy PSG byte into A
  cp #PSGData                     ; is it a command (<$40)??
  jr c,102$                         ; it is not, output it!
  out (PSGDataPort),a
  jr .intLoop

102$:
  cp #PSGWait
  jr z,.done                     ; no additional frames
  jr c,.otherCommands            ; other commands?
  and #0x07                        ; take only the last 3 bits for skip frames
  ld (.PSGMusicSkipFrames),a      ; we got additional frames
.done:
  ld (.PSGMusicPointer),hl        ; save current address
  ret                            ; frame done

.otherCommands:
  cp #PSGSubString
  jr nc,.substring
  cp #PSGEnd
  jr z,.musicLoop
  cp #PSGLoop
  jr z,.setLoopPoint

  ; ***************************************************************************
  ; we should never get here!
  ; if we do, it means the PSG file is probably corrupted, so we just RET
  ; ***************************************************************************

  ret

.setLoopPoint:
  ld (.PSGMusicLoopPoint),hl
  jp .intLoop

.musicLoop:
  ld a,(.PSGLoopFlag)               ; looping requested?
  or a
  jp z, _PSGStop                     ; No:stop it! (tail call optimization)
  ld hl,(.PSGMusicLoopPoint)
  jp .intLoop

.substring:
  sub #PSGSubString-4                  ; len is value - $08 + 4
  ld (.PSGMusicSubstringLen),a         ; save len
  ld c,(hl)                           ; load substring address (offset)
  inc hl
  ld b,(hl)
  inc hl
  ld (.PSGMusicSubstringRetAddr),hl    ; save return address
  ld hl,(.PSGMusicStart)
  add hl,bc                           ; make substring current
  jp .intLoop

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
.PSGMusicStart:
    .dw 1   ; the pointer to the beginning of music
.PSGMusicPointer:
    .dw 1    ; the pointer to the current
.PSGMusicLoopPoint:
    .dw 1    ; the pointer to the loop begin
.PSGMusicSkipFrames:
    .db 1    ; the frames we need to skip
.PSGLoopFlag:
    .db 1    ; the tune should loop or not (flag)

  ; decompression vars
.PSGMusicSubstringLen:
    .db 1    ; lenght of the substring we are playing
.PSGMusicSubstringRetAddr:
    .dw 1    ; return to this address when substring is over