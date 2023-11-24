#pragma once
#include <stdint.h>
#include <gbdk/platform.h>

extern uint8_t PSGMusicStatus; // are we playing a background music?
extern uint8_t* PSGMusicStart; //the pointer to the beginning of music
extern uint8_t* PSGMusicPointer; //the pointer to the current
extern uint8_t* PSGMusicLoopPoint; //the pointer to the loop begin
extern uint8_t PSGMusicSkipFrames; //the frames we need to skip
extern uint8_t PSGLoopFlag; //the tune should loop or not (flag)

extern void PSGInit(void);
extern void PSGPlayNoRepeat(uint8_t* music) Z88DK_FASTCALL;
extern void PSGPlay(uint8_t* music) Z88DK_FASTCALL;
extern void PSGStop(void);
extern void PSGCancelLoop(void);
extern void PSGFrame(void);