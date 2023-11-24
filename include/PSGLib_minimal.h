#pragma once
#include <stdint.h>
#include <gbdk/platform.h>

/** PSGMusicStatus
    are we playing a background music?
    0 - no
    1 - yes
 */
extern uint8_t const PSGMusicStatus;

extern void PSGInit(void) PRESERVES_REGS(b, c, d, e, h, l, iyh, iyl);
extern void PSGPlayNoRepeat(uint8_t* music) Z88DK_FASTCALL PRESERVES_REGS(b, c, d, e, h, l, iyh, iyl);
extern void PSGPlay(uint8_t* music) Z88DK_FASTCALL PRESERVES_REGS(b, c, d, e, h, l, iyh, iyl);
extern void PSGStop(void) PRESERVES_REGS(b, c, d, e, h, l, iyh, iyl);
extern void PSGCancelLoop(void) PRESERVES_REGS(b, c, d, e, h, l, iyh, iyl);
extern void PSGFrame(void) PRESERVES_REGS(d, e, iyh, iyl);