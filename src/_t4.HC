/*
                                    HolyCraft

        A Minecraft-like voxel game for TempleOS, written in HolyC.

        Not a port of Minecraft Java Edition -- TempleOS has no JVM,
        no networking and a 640x480 16-color screen, so this is a
        from-scratch, TempleOS-native reimplementation of the core
        Minecraft experience:

          * procedurally generated blocky terrain (hills, lakes,
            sand beaches, snowy peaks, trees)
          * first-person walking, jumping, gravity + swimming
          * fly mode (F)
          * block breaking and placing with a 6-slot hotbar
          * 3D raycast block targeting with highlight box
          * fog, dithered shading and a painter's-algorithm renderer

        INSTALL:  copy this file to your C:/ drive and include it
                  from the command line.  (On a live CD it runs
                  automatically at boot.)

        CONTROLS:
                    WASD ........ move
                    Mouse ....... look  (or arrow keys)
                    Left click .. break block
                    Right click . place block
                    1..6 ........ select hotbar block
                    Space ....... jump / swim up / fly up
                    Shift ....... fly down
                    F ........... toggle fly mode
                    ESC ......... quit
*/

#define MC_WORLD_SX     96              // world size in blocks
#define MC_WORLD_SZ     96
#define MC_WORLD_SY     40              // world height in blocks
#define MC_SEA          13              // sea level

#define MC_RENDER_DIST  13              // blocks around player to render
#define MC_FOG_START    (MC_RENDER_DIST * 0.45)
#define MC_FOG_END      (MC_RENDER_DIST * 0.95)
#define MC_FOCAL        450.0           // projection focal length in pixels

#define MC_GRAVITY      32.0            // Java Edition: -0.08 blocks/tick^2
#define MC_JUMP_VEL     8.4             // Java Edition: 0.42 blocks/tick
#define MC_WALK_SPEED   4.3             // Java Edition walking speed
#define MC_SPRINT_SPEED 5.6             // Java Edition sprint speed
#define MC_FLY_SPEED    9.0
#define MC_SWIM_SPEED   2.6
#define MC_TERMINAL_VY  48.0
#define MC_STEP_TIME    (1.0 / 30.0)    // physics substep, decoupled from FPS
#define MC_HALF         0.30            // player half-width
#define MC_HEIGHT       1.80            // player height
#define MC_EYE          1.62            // eye height above feet
#define MC_REACH        6.0             // block interaction distance
#define MC_NEAR         0.10            // near clipping plane

// ---- block ids ----
#define B_AIR           0
#define B_GRASS         1
#define B_DIRT          2
#define B_STONE         3
#define B_SAND          4
#define B_WATER         5
#define B_WOOD          6
#define B_LEAVES        7
#define B_SNOW          8
#define B_BEDROCK       9
#define B_GRAVEL        10
#define B_COAL_ORE      11
#define B_IRON_ORE      12
#define B_COUNT         13

// ---- face dirs ----
#define D_POSX  0
#define D_NEGX  1
#define D_POSY  2
#define D_NEGY  3
#define D_POSZ  4
#define D_NEGZ  5

// ---- scan codes (set 1) not predefined by TempleOS ----
#define MC_SC_W         0x11
#define MC_SC_A         0x1E
#define MC_SC_S         0x1F
#define MC_SC_D         0x20
#define MC_SC_F         0x21
#define MC_SC_1         0x02
#define MC_SC_2         0x03
#define MC_SC_3         0x04
#define MC_SC_4         0x05
#define MC_SC_5         0x06
#define MC_SC_6         0x07
#define MC_SC_SPACE     0x39




// hcc already knows Bool; TempleOS has it built in.
// The MCR_FS alias exists because hcc's parser walks even the dead #else
// branch and crashes on the Fs->win_inhibit property check; with the alias
// it sees an unknown symbol there and skips it.  TempleOS expands the macro

#ifndef __HCC__
#define MCR_FS Fs
#endif

#ifdef __HCC__
#include "compat_hcc.HC"
U0 SetWinInhibit(I64 x) {}
#else
U0 SetWinInhibit(I64 x) { MCR_FS->win_inhibit = x; }
#endif
U0 SetWinInhibit(I64 x) { MCR_FS->win_inhibit = x; }
#endif





class CBlockInfo {
  U8 *name;
  U8 top_a, top_b;      // lit / shade dither colors for the top face
  U8 side_a, side_b;    // ... for the sides
  U8 bot_a, bot_b;      // ... for the bottom
  U8 solid;             // blocks movement
  U8 targetable;        // can be hit by the crosshair ray
};
I64 _t(){return 0;}
