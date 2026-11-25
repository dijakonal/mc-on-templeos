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

#define MC_GRAVITY      26.0
#define MC_JUMP_VEL     8.2
#define MC_WALK_SPEED   4.3
#define MC_FLY_SPEED    9.0
#define MC_SWIM_SPEED   2.6
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
#define B_COUNT         10

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

class CBlockInfo {
  U8 *name;
  U8 top_a, top_b;      // lit / shade dither colors for the top face
  U8 side_a, side_b;    // ... for the sides
  U8 bot_a, bot_b;      // ... for the bottom
  U8 solid;             // blocks movement
  U8 targetable;        // can be hit by the crosshair ray
};

class CPlayer {
  F64 x, y, z;          // feet position
  F64 vx, vy, vz;
  F64 yaw, pitch;
  Bool on_ground, flying;
};

CBlockInfo blkinfo[B_COUNT];
CPlayer    P;

U8 world[MC_WORLD_SX * MC_WORLD_SZ * MC_WORLD_SY];
U8 colmax[MC_WORLD_SX * MC_WORLD_SZ];   // top solid block + 1, per column

I64 hotbar_items[6];
I64 hotbar_sel;

// ---- tiny math helpers (named to avoid clobbering TempleOS builtins) ----
I64 IAbs(I64 v)
{
  if (v < 0) return -v;
  return v;
}
F64 FClamp(F64 v, F64 a, F64 b) { if (v < a) v = a; if (v > b) v = b; return v; }
I64 IClamp(I64 v, I64 a, I64 b) { if (v < a) v = a; if (v > b) v = b; return v; }

I64 Hash2i(I64 x, I64 z)
{
  I64 h = x * 374761393 + z * 668265263 + 1442695040;
  h = (h ^ (h >> 13)) * 1274126177;
  h = h ^ (h >> 16);
  return h;
}

F64 Hash2f(I64 x, I64 z)
{
  return (Hash2i(x, z) & 0xFFFF) / 65535.0;
}

// ---- world access ----
I64 WIdx(I64 x, I64 y, I64 z)
{
  return x + z * MC_WORLD_SX + y * MC_WORLD_SX * MC_WORLD_SZ;
}

I64 GetBlock(I64 x, I64 y, I64 z)
{
  if (y < 0) return B_BEDROCK;
  if (y >= MC_WORLD_SY) return B_AIR;
  if (x < 0 || x >= MC_WORLD_SX || z < 0 || z >= MC_WORLD_SZ)
    return B_STONE;                     // world border acts solid
  return world[WIdx(x, y, z)];
}

Bool IsSolid(I64 x, I64 y, I64 z)
{
  I64 b = GetBlock(x, y, z);
  return b != B_AIR && b != B_WATER;
}

U0 SetBlockRaw(I64 x, I64 y, I64 z, I64 b)
{
  if (x < 0 || x >= MC_WORLD_SX || z < 0 || z >= MC_WORLD_SZ || y < 0 || y >= MC_WORLD_SY)
    return;
  world[WIdx(x, y, z)] = b;
}

U0 RecalcCol(I64 x, I64 z)
{
  I64 y;
  for (y = MC_WORLD_SY - 1; y >= 0; y--)
    if (world[WIdx(x, y, z)] != B_AIR)
      break;
  colmax[x + z * MC_WORLD_SX] = y + 1;
}

U0 SetBlockUpdate(I64 x, I64 y, I64 z, I64 b)
{
  SetBlockRaw(x, y, z, b);
  if (x >= 0 && x < MC_WORLD_SX && z >= 0 && z < MC_WORLD_SZ)
    RecalcCol(x, z);
}

U0 InitBlocks()
{
  blkinfo[B_AIR].name = "Air";
  blkinfo[B_AIR].solid = FALSE;    blkinfo[B_AIR].targetable = FALSE;

  blkinfo[B_GRASS].name = "Grass";
  blkinfo[B_GRASS].top_a  = GREEN;  blkinfo[B_GRASS].top_b  = LTGREEN;
  blkinfo[B_GRASS].side_a = BROWN;  blkinfo[B_GRASS].side_b = GREEN;
  blkinfo[B_GRASS].bot_a  = BROWN;  blkinfo[B_GRASS].bot_b  = BROWN;
  blkinfo[B_GRASS].solid = TRUE;   blkinfo[B_GRASS].targetable = TRUE;

  blkinfo[B_DIRT].name = "Dirt";
  blkinfo[B_DIRT].top_a  = BROWN;  blkinfo[B_DIRT].top_b  = BROWN;
  blkinfo[B_DIRT].side_a = BROWN;  blkinfo[B_DIRT].side_b = BROWN;
  blkinfo[B_DIRT].bot_a  = BROWN;  blkinfo[B_DIRT].bot_b  = BROWN;
  blkinfo[B_DIRT].solid = TRUE;    blkinfo[B_DIRT].targetable = TRUE;

  blkinfo[B_STONE].name = "Stone";
  blkinfo[B_STONE].top_a  = LTGRAY; blkinfo[B_STONE].top_b  = DKGRAY;
  blkinfo[B_STONE].side_a = DKGRAY; blkinfo[B_STONE].side_b = LTGRAY;
  blkinfo[B_STONE].bot_a  = BLACK;  blkinfo[B_STONE].bot_b  = DKGRAY;
  blkinfo[B_STONE].solid = TRUE;   blkinfo[B_STONE].targetable = TRUE;

  blkinfo[B_SAND].name = "Sand";
  blkinfo[B_SAND].top_a  = YELLOW; blkinfo[B_SAND].top_b  = LTGRAY;
  blkinfo[B_SAND].side_a = LTGRAY; blkinfo[B_SAND].side_b = YELLOW;
  blkinfo[B_SAND].bot_a  = BROWN;  blkinfo[B_SAND].bot_b  = BROWN;
  blkinfo[B_SAND].solid = TRUE;    blkinfo[B_SAND].targetable = TRUE;

  blkinfo[B_WATER].name = "Water";
  blkinfo[B_WATER].top_a  = LTBLUE; blkinfo[B_WATER].top_b  = BLUE;
  blkinfo[B_WATER].side_a = BLUE;   blkinfo[B_WATER].side_b = LTBLUE;
  blkinfo[B_WATER].bot_a  = BLUE;   blkinfo[B_WATER].bot_b  = BLUE;
  blkinfo[B_WATER].solid = FALSE;  blkinfo[B_WATER].targetable = FALSE;

  blkinfo[B_WOOD].name = "Wood";
  blkinfo[B_WOOD].top_a  = BROWN;  blkinfo[B_WOOD].top_b  = DKGRAY;
  blkinfo[B_WOOD].side_a = BROWN;  blkinfo[B_WOOD].side_b = DKGRAY;
  blkinfo[B_WOOD].bot_a  = BROWN;  blkinfo[B_WOOD].bot_b  = BROWN;
  blkinfo[B_WOOD].solid = TRUE;    blkinfo[B_WOOD].targetable = TRUE;

  blkinfo[B_LEAVES].name = "Leaves";
  blkinfo[B_LEAVES].top_a  = GREEN;  blkinfo[B_LEAVES].top_b  = DKGRAY;
  blkinfo[B_LEAVES].side_a = GREEN;  blkinfo[B_LEAVES].side_b = BLACK;
  blkinfo[B_LEAVES].bot_a  = GREEN;  blkinfo[B_LEAVES].bot_b  = BLACK;
  blkinfo[B_LEAVES].solid = TRUE;   blkinfo[B_LEAVES].targetable = TRUE;

  blkinfo[B_SNOW].name = "Snow";
  blkinfo[B_SNOW].top_a  = WHITE;  blkinfo[B_SNOW].top_b  = LTCYAN;
  blkinfo[B_SNOW].side_a = WHITE;  blkinfo[B_SNOW].side_b = LTGRAY;
  blkinfo[B_SNOW].bot_a  = WHITE;  blkinfo[B_SNOW].bot_b  = LTGRAY;
  blkinfo[B_SNOW].solid = TRUE;    blkinfo[B_SNOW].targetable = TRUE;

  blkinfo[B_BEDROCK].name = "Bedrock";
  blkinfo[B_BEDROCK].top_a  = DKGRAY; blkinfo[B_BEDROCK].top_b  = BLACK;
  blkinfo[B_BEDROCK].side_a = DKGRAY; blkinfo[B_BEDROCK].side_b = BLACK;
  blkinfo[B_BEDROCK].bot_a  = DKGRAY; blkinfo[B_BEDROCK].bot_b  = BLACK;
  blkinfo[B_BEDROCK].solid = TRUE;   blkinfo[B_BEDROCK].targetable = FALSE;

  hotbar_items[0] = B_GRASS;
  hotbar_items[1] = B_DIRT;
  hotbar_items[2] = B_STONE;
  hotbar_items[3] = B_SAND;
  hotbar_items[4] = B_WOOD;
  hotbar_items[5] = B_LEAVES;
  hotbar_sel      = 0;
}

// =============================== TERRAIN =================================

// 2D value noise + fBm, hashed so the world is the same every run.
F64 VNoise(F64 x, F64 z)
{
  I64 x0 = ToI64(Floor(x)), z0 = ToI64(Floor(z));
  F64 xf = x - x0, zf = z - z0;
  F64 u = xf * xf * (3.0 - 2.0 * xf);
  F64 v = zf * zf * (3.0 - 2.0 * zf);
  F64 a = Hash2f(x0,     z0);
  F64 b = Hash2f(x0 + 1, z0);
  F64 c = Hash2f(x0,     z0 + 1);
  F64 d = Hash2f(x0 + 1, z0 + 1);
  return (a * (1.0 - u) + b * u) * (1.0 - v) + (c * (1.0 - u) + d * u) * v;
}

F64 Fbm(F64 x, F64 z)
{
  F64 s = 0, amp = 1, f = 1, norm = 0;
  I64 i;
  for (i = 0; i < 4; i++) {
    s += amp * VNoise(x * f, z * f);
    norm += amp;
    amp *= 0.5;
    f *= 2.0;
  }
  return s / norm;
}

U0 PlantTree(I64 x, I64 y, I64 z, I64 th)
{
  I64 dy, dx, dz, r;
  for (dy = 0; dy < th; dy++)
    SetBlockRaw(x, y + dy, z, B_WOOD);
  for (dy = th - 2; dy <= th + 1; dy++) {
    if (dy <= th - 1) r = 2; else r = 1;
    for (dx = -r; dx <= r; dx++)
      for (dz = -r; dz <= r; dz++) {
        if (dx == 0 && dz == 0 && dy < th) {
          // trunk goes here
        } else if (IAbs(dx) == r && IAbs(dz) == r && (dy >= th || (Hash2i(x + dx * 3 + dy, z + dz * 5 - dy) & 1))) {
          // ragged corners
        } else if (GetBlock(x + dx, y + dy, z + dz) == B_AIR) {
          SetBlockRaw(x + dx, y + dy, z + dz, B_LEAVES);
        }
      }
  }
}

U0 GenWorld()
{
  I64 x, z, y, h, th;
  F64 n1, n2;
  for (x = 0; x < MC_WORLD_SX; x++)
    for (z = 0; z < MC_WORLD_SZ; z++) {
      n1 = Fbm(x * 0.030,           z * 0.030);
      n2 = Fbm(x * 0.008 + 41.3,    z * 0.008 + 87.9);
      h  = 3 + n1 * 22 + n2 * 15;
      h  = IClamp(h, 1, MC_WORLD_SY - 10);
      for (y = 0; y <= h; y++) {
        if (y == 0)
          SetBlockRaw(x, y, z, B_BEDROCK);
        else if (y == h) {
          if (h <= MC_SEA + 1) SetBlockRaw(x, y, z, B_SAND);
          else if (h >= 26)    SetBlockRaw(x, y, z, B_SNOW);
          else                 SetBlockRaw(x, y, z, B_GRASS);
        } else if (y >= h - 3) {
          if (h <= MC_SEA + 1) SetBlockRaw(x, y, z, B_SAND);
          else                 SetBlockRaw(x, y, z, B_DIRT);
        }
        else
          SetBlockRaw(x, y, z, B_STONE);
      }
      for (y = h + 1; y <= MC_SEA; y++)
        SetBlockRaw(x, y, z, B_WATER);
      RecalcCol(x, z);
    }
  for (x = 2; x < MC_WORLD_SX - 2; x++)
    for (z = 2; z < MC_WORLD_SZ - 2; z++) {
      if ((Hash2i(x, z) & 63) == 0) {
        h = colmax[x + z * MC_WORLD_SX] - 1;
        if (GetBlock(x, h, z) == B_GRASS) {
          th = 4 + (Hash2i(x + 7, z + 3) & 1);
          if (h + th + 2 < MC_WORLD_SY)
            PlantTree(x, h + 1, z, th);
        }
      }
    }
}

Bool SpawnOK(I64 x, I64 z, I64 *h_out)
{
  I64 h, y, b, dx, dz;
  if (x < 2 || x >= MC_WORLD_SX - 2 || z < 2 || z >= MC_WORLD_SZ - 2)
    return FALSE;
  h = MC_WORLD_SY - 1;
  while (h >= 0 && world[WIdx(x, h, z)] == B_AIR) h--;
  if (h < MC_SEA + 2 || h > MC_WORLD_SY - 8) return FALSE;
  for (y = h + 1; y <= h + 12; y++)
    for (dx = -2; dx <= 2; dx++)
      for (dz = -2; dz <= 2; dz++) {
        b = GetBlock(x + dx, y, z + dz);
        if (b == B_WOOD || b == B_LEAVES) return FALSE;  // no tree overhead
      }
  *h_out = h;
  return TRUE;
}

U0 SpawnPlayer()
{
  I64 cx = MC_WORLD_SX / 2, cz = MC_WORLD_SZ / 2;
  I64 h = MC_SEA + 1, r, dx, dz, sx = cx, sz = cz, found = FALSE;
  for (r = 0; r <= 14 && !found; r++)
    for (dx = -r; dx <= r && !found; dx++)
      for (dz = -r; dz <= r && !found; dz++)
        if (IAbs(dx) == r || IAbs(dz) == r)
          if (SpawnOK(cx + dx, cz + dz, &h)) {
            sx = cx + dx;  sz = cz + dz;  found = TRUE;
          }
  P.x = sx + 0.5;  P.y = h + 1.01;  P.z = sz + 0.5;
  P.vx = P.vy = P.vz = 0;
  P.yaw = 0.8;  P.pitch = -0.55;
  P.on_ground = FALSE;
  P.flying = FALSE;
}

// =============================== PHYSICS =================================

// Move along one axis and push out of any solid blocks we overlap.
U0 MoveAxis(I64 axis, F64 delta)
{
  F64 x0, x1, y0, y1, z0, z1, cx, cy, cz, peps = 0.001;
  I64 ix, iy, iz, hit;
  I64 gx0, gx1, gy0, gy1, gz0, gz1;
  if (axis == 0) P.x += delta;
  if (axis == 1) P.y += delta;
  if (axis == 2) P.z += delta;
  x0 = P.x - MC_HALF; x1 = P.x + MC_HALF;
  y0 = P.y + peps;     y1 = P.y + MC_HEIGHT;
  z0 = P.z - MC_HALF; z1 = P.z + MC_HALF;
  hit = FALSE;
  for (ix = ToI64(Floor(x0)); ix <= Floor(x1); ix++)
    for (iy = ToI64(Floor(y0)); iy <= Floor(y1); iy++)
      for (iz = ToI64(Floor(z0)); iz <= Floor(z1); iz++) {
        if (IsSolid(ix, iy, iz)) {
          hit = TRUE;
        if (axis == 0) {
          if (delta > 0) P.x = ix - MC_HALF - peps;
          else           P.x = ix + 1 + MC_HALF + peps;
          P.vx = 0;
        }
        if (axis == 1) {
          if (delta > 0) { P.y = iy - MC_HEIGHT - peps; P.vy = 0; }
          else           { P.y = iy + 1.0 + peps;       P.vy = 0;
                           P.on_ground = TRUE; }
        }
        if (axis == 2) {
          if (delta > 0) P.z = iz - MC_HALF - peps;
          else           P.z = iz + 1 + MC_HALF + peps;
          P.vz = 0;
        }
          x0 = P.x - MC_HALF; x1 = P.x + MC_HALF;
          y0 = P.y + peps;     y1 = P.y + MC_HEIGHT;
          z0 = P.z - MC_HALF; z1 = P.z + MC_HALF;
        }
      }
  if (hit && axis == 0) P.vx = 0;
  if (hit && axis == 2) P.vz = 0;
}

U0 UpdatePlayer(F64 dt)
{
  F64 fwd_x, fwd_z, rgt_x, rgt_z, mx, mz, spd, k;
  I64 wbx, wby, wbz;
  Bool in_water;
  mx = 0; mz = 0;
  fwd_x = Sin(P.yaw);  fwd_z = Cos(P.yaw);
  rgt_x = Cos(P.yaw);  rgt_z = -Sin(P.yaw);
  if (Bt(kbd.down_bitmap, MC_SC_W)) { mx += fwd_x; mz += fwd_z; }
  if (Bt(kbd.down_bitmap, MC_SC_S)) { mx -= fwd_x; mz -= fwd_z; }
  if (Bt(kbd.down_bitmap, MC_SC_D)) { mx += rgt_x; mz += rgt_z; }
  if (Bt(kbd.down_bitmap, MC_SC_A)) { mx -= rgt_x; mz -= rgt_z; }
  wbx = P.x; wby = P.y + 0.4; wbz = P.z;
  in_water = GetBlock(wbx, wby, wbz) == B_WATER;
  if (P.flying) spd = MC_FLY_SPEED;
  else if (in_water) spd = MC_SWIM_SPEED;
  else spd = MC_WALK_SPEED;
  if (mx != 0.0 || mz != 0.0) {
    k = 1.0 / Sqrt(mx * mx + mz * mz);
    mx *= k * spd;  mz *= k * spd;
  }
  // accelerate toward the desired velocity
  k = FClamp(10.0 * dt, 0.0, 1.0);
  P.vx += (mx - P.vx) * k;
  P.vz += (mz - P.vz) * k;
  if (P.flying) {
    P.vy = 0;
    if (Bt(kbd.down_bitmap, MC_SC_SPACE)) P.vy =  MC_FLY_SPEED * 0.8;
    if (Bt(kbd.down_bitmap, SC_SHIFT))    P.vy = -MC_FLY_SPEED * 0.8;
  } else {
    if (in_water) {
      P.vy -= 6.0 * dt;
      if (P.vy < -2.0) P.vy = -2.0;
      if (Bt(kbd.down_bitmap, MC_SC_SPACE)) P.vy = MC_SWIM_SPEED;
    } else {
      P.vy -= MC_GRAVITY * dt;
      if (P.vy < -40.0) P.vy = -40.0;
      if (P.on_ground && Bt(kbd.down_bitmap, MC_SC_SPACE)) {
        P.vy = MC_JUMP_VEL;
        P.on_ground = FALSE;
      }
    }
  }
  P.on_ground = FALSE;
  MoveAxis(1, P.vy * dt);
  MoveAxis(0, P.vx * dt);
  MoveAxis(2, P.vz * dt);
  // stay inside the world
  P.x = FClamp(P.x, MC_HALF + 1, MC_WORLD_SX - MC_HALF - 1);
  P.z = FClamp(P.z, MC_HALF + 1, MC_WORLD_SZ - MC_HALF - 1);
  if (P.y < -10) SpawnPlayer;          // fell off the (patched) world
}

// =============================== RAYCAST =================================

// Amanatides & Woo voxel traversal. Returns hit block + the face normal.
Bool Raycast(I64 *hx, I64 *hy, I64 *hz, I64 *hface)
{
  F64 ox, oy, oz, dx, dy, dz, tmax[3], tdelta[3], t = 0, cp = Cos(P.pitch);
  I64 ix, iy, iz, step[3], axis, i;
  ox = P.x;  oy = P.y + MC_EYE;  oz = P.z;
  dx = cp * Sin(P.yaw);  dy = Sin(P.pitch);  dz = cp * Cos(P.yaw);
  ix = ToI64(Floor(ox));  iy = ToI64(Floor(oy));  iz = ToI64(Floor(oz));
  for (i = 0; i < 3; i++) tdelta[i] = 1e30;
  for (i = 0; i < 3; i++) step[i]   = 0;
  if (dx > 0) { step[0] = 1;  tmax[0] = (ix + 1 - ox) / dx; tdelta[0] = 1 / dx; }
  if (dx < 0) { step[0] = -1; tmax[0] = (ox - ix) / -dx;    tdelta[0] = 1 / -dx; }
  if (dy > 0) { step[1] = 1;  tmax[1] = (iy + 1 - oy) / dy; tdelta[1] = 1 / dy; }
  if (dy < 0) { step[1] = -1; tmax[1] = (oy - iy) / -dy;    tdelta[1] = 1 / -dy; }
  if (dz > 0) { step[2] = 1;  tmax[2] = (iz + 1 - oz) / dz; tdelta[2] = 1 / dz; }
  if (dz < 0) { step[2] = -1; tmax[2] = (oz - iz) / -dz;    tdelta[2] = 1 / -dz; }
  *hface = -1;
  while (t <= MC_REACH) {
    axis = 0;
    if (tmax[1] < tmax[axis]) axis = 1;
    if (tmax[2] < tmax[axis]) axis = 2;
    t = tmax[axis];
    if (axis == 0) {
      ix += step[0];
      if (step[0] > 0) *hface = D_NEGX; else *hface = D_POSX;
    }
    if (axis == 1) {
      iy += step[1];
      if (step[1] > 0) *hface = D_NEGY; else *hface = D_POSY;
    }
    if (axis == 2) {
      iz += step[2];
      if (step[2] > 0) *hface = D_NEGZ; else *hface = D_POSZ;
    }
    tmax[axis] += tdelta[axis];
    if (ix < 0 || ix >= MC_WORLD_SX || iz < 0 || iz >= MC_WORLD_SZ || iy < 0 || iy >= MC_WORLD_SY)
      return FALSE;
    if (blkinfo[world[WIdx(ix, iy, iz)]].targetable) {
      *hx = ix;  *hy = iy;  *hz = iz;
      return TRUE;
    }
  }
  return FALSE;
}

// =============================== RENDERER ================================

// Direct-pixel renderer: we write into gr.dc->body ourselves (640x480,
// 16 colors, one byte per pixel) for speed, and fill faces as convex
// polygons with 4x4 Bayer-dithered shading and fog.

U8  *db;                                // frame buffer pointer
I64  stride;                            // scanline stride
I64  scr_w, scr_h;

F64 bayer[16];                          // 4x4 ordered-dither matrix

// face buffer (painter's algorithm) -- MAlloc'd in InitRendererTables
#define MC_MAX_FACES 8000
I64  *fnverts;
F64  *fxs;                              // projected coords keep sub-pixel precision
F64  *fys;
U8   *fcolA;
U8   *fcolB;
U8   *fshadeT;                         // dither threshold 0..15
U8   *ffogT;                           // fog threshold 0..15
F64  *fdepth;
I64  fcount;

I64  *bhead, *bnext;                    // depth bucket sort lists

// cube corner offsets and the 4 corners of each face
F64 corn_x[8], corn_y[8], corn_z[8];
I64 face_corners[6][4];
F64 face_light[6];                      // 0 = fully lit .. 1 = fully shaded

U0 InitRendererTables()
{
  I64 i, j;
  fnverts = MAlloc(MC_MAX_FACES * 8);
  fxs     = MAlloc(MC_MAX_FACES * 5 * 8);
  fys     = MAlloc(MC_MAX_FACES * 5 * 8);
  fcolA   = MAlloc(MC_MAX_FACES);
  fcolB   = MAlloc(MC_MAX_FACES);
  fshadeT = MAlloc(MC_MAX_FACES);
  ffogT   = MAlloc(MC_MAX_FACES);
  fdepth  = MAlloc(MC_MAX_FACES * 8);
  bhead   = MAlloc(256 * 8);
  bnext   = MAlloc(MC_MAX_FACES * 8);
  // 4x4 Bayer matrix
  for (i = 0; i < 4; i++)
    for (j = 0; j < 4; j++) {
      // standard Bayer values via bit interleave
      bayer[i * 4 + j] = (((j & 1) << 3) | ((i & 1) << 2) | ((j & 2) << 1) | (i & 2)) ^ 0xF;
    }
  corn_x[0] = 0; corn_y[0] = 0; corn_z[0] = 0;
  corn_x[1] = 1; corn_y[1] = 0; corn_z[1] = 0;
  corn_x[2] = 0; corn_y[2] = 1; corn_z[2] = 0;
  corn_x[3] = 1; corn_y[3] = 1; corn_z[3] = 0;
  corn_x[4] = 0; corn_y[4] = 0; corn_z[4] = 1;
  corn_x[5] = 1; corn_y[5] = 0; corn_z[5] = 1;
  corn_x[6] = 0; corn_y[6] = 1; corn_z[6] = 1;
  corn_x[7] = 1; corn_y[7] = 1; corn_z[7] = 1;
  face_corners[D_POSX][0] = 1; face_corners[D_POSX][1] = 3;
  face_corners[D_POSX][2] = 7; face_corners[D_POSX][3] = 5;
  face_corners[D_NEGX][0] = 0; face_corners[D_NEGX][1] = 2;
  face_corners[D_NEGX][2] = 6; face_corners[D_NEGX][3] = 4;
  face_corners[D_POSY][0] = 2; face_corners[D_POSY][1] = 6;
  face_corners[D_POSY][2] = 7; face_corners[D_POSY][3] = 3;
  face_corners[D_NEGY][0] = 0; face_corners[D_NEGY][1] = 1;
  face_corners[D_NEGY][2] = 5; face_corners[D_NEGY][3] = 4;
  face_corners[D_POSZ][0] = 4; face_corners[D_POSZ][1] = 5;
  face_corners[D_POSZ][2] = 7; face_corners[D_POSZ][3] = 6;
  face_corners[D_NEGZ][0] = 0; face_corners[D_NEGZ][1] = 2;
  face_corners[D_NEGZ][2] = 3; face_corners[D_NEGZ][3] = 1;
  face_light[D_POSX] = 0.70; face_light[D_NEGX] = 0.70;
  face_light[D_POSY] = 0.00; face_light[D_NEGY] = 0.90;
  face_light[D_POSZ] = 0.45; face_light[D_NEGZ] = 0.45;
}

// scanline fill of a convex polygon (3..5 verts)
U0 FillFace(I64 fi)
{
  I64 n, e, a, b2, y, ymin, ymax, x, x0, x1, row, u;
  F64 xl, xr, t, yy0, yy1, xa, xb;
  F64 fmin, fmax;
  U8 cA, cB, cFog, sT, fT;
  n = fnverts[fi];
  cA = fcolA[fi]; cB = fcolB[fi];
  sT = fshadeT[fi]; fT = ffogT[fi];
  cFog = LTBLUE;
  fmin = 1e30; fmax = -1e30;
  for (e = 0; e < n; e++) {
    if (fys[fi * 5 + e] < fmin) fmin = fys[fi * 5 + e];
    if (fys[fi * 5 + e] > fmax) fmax = fys[fi * 5 + e];
  }
  ymin = IClamp(ToI64(Ceil(fmin)), 0, scr_h - 1);
  ymax = IClamp(ToI64(Floor(fmax)), 0, scr_h - 1);
  for (y = ymin; y <= ymax; y++) {
    xl = 1e9; xr = -1e9;
    for (e = 0; e < n; e++) {
      a = e; b2 = (e + 1) % n;
      yy0 = fys[fi * 5 + a]; yy1 = fys[fi * 5 + b2];
      if (yy0 != yy1 && ((y >= yy0 && y < yy1) || (y >= yy1 && y < yy0))) {
        t = (y - yy0) / (yy1 - yy0);
        xa = fxs[fi * 5 + a]; xb = fxs[fi * 5 + b2];
        x = xa + (xb - xa) * t;
        if (x < xl) xl = x;
        if (x > xr) xr = x;
      }
    }
    if (xr >= xl) {
    x0 = IClamp(ToI64(Ceil(xl)), 0, scr_w - 1);
    x1 = IClamp(ToI64(Floor(xr)), 0, scr_w - 1);
    row = y * stride;
    if (cA == cB && sT == 0 && fT == 0)
      MemSet(db + row + x0, cA, x1 - x0 + 1);
    else
      for (x = x0; x <= x1; x++) {
        u = bayer[(x & 3) + ((y & 3) << 2)];
        if (u < fT)      db[row + x] = cFog;
        else if (u < sT) db[row + x] = cB;
        else             db[row + x] = cA;
      }
    }
  }
}

// camera basis for the current frame
F64 cam_ex, cam_ey, cam_ez;             // eye position
F64 cam_fx, cam_fy, cam_fz;             // forward
F64 cam_rx, cam_ry, cam_rz;             // right
F64 cam_ux, cam_uy, cam_uz;             // up

U0 UpdateCamera()
{
  F64 cp = Cos(P.pitch);
  cam_ex = P.x;      cam_ey = P.y + MC_EYE;  cam_ez = P.z;
  cam_fx = cp * Sin(P.yaw);  cam_fy = Sin(P.pitch);  cam_fz = cp * Cos(P.yaw);
  cam_rx = Cos(P.yaw);       cam_ry = 0;             cam_rz = -Sin(P.yaw);
  cam_ux = -Sin(P.pitch) * Sin(P.yaw);
  cam_uy = cp;
  cam_uz = -Sin(P.pitch) * Cos(P.yaw);
}

// transform + near-clip + project one face; returns FALSE if it is culled
Bool EmitFace(I64 bx, I64 by, I64 bz, I64 dir)
{
  F64 cx[4], cy[4], cz[4], ox[5], oy[5], oz[5], t, wx, wy, wz, depth, fogt;
  F64 sxx, syy, mind;
  I64 i, j, nv, ci, cj, fi, cidx, x, y, sx, sy, xmin, xmax, ymin, ymax, st;
  CBlockInfo *bi;
  bi = &blkinfo[world[WIdx(bx, by, bz)]];
  if (dir == D_POSY)      { fcolA[fcount] = bi->top_a;  fcolB[fcount] = bi->top_b; }
  else if (dir == D_NEGY) { fcolA[fcount] = bi->bot_a;  fcolB[fcount] = bi->bot_b; }
  else                    { fcolA[fcount] = bi->side_a; fcolB[fcount] = bi->side_b; }
  // camera space
  for (i = 0; i < 4; i++) {
    cidx = face_corners[dir][i];
    wx = bx + corn_x[cidx] - cam_ex;
    wy = by + corn_y[cidx] - cam_ey;
    wz = bz + corn_z[cidx] - cam_ez;
    cx[i] = wx * cam_rx + wy * cam_ry + wz * cam_rz;
    cy[i] = wx * cam_ux + wy * cam_uy + wz * cam_uz;
    cz[i] = wx * cam_fx + wy * cam_fy + wz * cam_fz;
  }
  // clip against the near plane
  nv = 0;
  for (i = 0; i < 4; i++) {
    j = (i + 1) & 3;
    ci = cz[i] >= MC_NEAR;
    cj = cz[j] >= MC_NEAR;
    if (ci) {
      ox[nv] = cx[i]; oy[nv] = cy[i]; oz[nv] = cz[i]; nv++;
    }
    if (ci != cj) {
      t = (MC_NEAR - cz[i]) / (cz[j] - cz[i]);
      ox[nv] = cx[i] + (cx[j] - cx[i]) * t;
      oy[nv] = cy[i] + (cy[j] - cy[i]) * t;
      oz[nv] = MC_NEAR;
      nv++;
    }
  }
  if (nv < 3) return FALSE;
  // project
  depth = 0;
  for (i = 0; i < nv; i++) {
    sxx = scr_w * 0.5 + ox[i] * MC_FOCAL / oz[i];
    syy = scr_h * 0.5 - oy[i] * MC_FOCAL / oz[i];
    fxs[fcount * 5 + i] = sxx;
    fys[fcount * 5 + i] = syy;
    depth += oz[i];
  }
  depth /= nv;
  if (depth > MC_FOG_END * 1.02) return FALSE;          // fully fogged
  xmin = xmax = fxs[fcount * 5];
  ymin = ymax = fys[fcount * 5];
  for (i = 1; i < nv; i++) {
    x = fxs[fcount * 5 + i]; y = fys[fcount * 5 + i];
    if (x < xmin) xmin = x;  if (x > xmax) xmax = x;
    if (y < ymin) ymin = y;  if (y > ymax) ymax = y;
  }
  if (xmax < 0 || xmin >= scr_w || ymax < 0 || ymin >= scr_h)
    return FALSE;                                       // off screen
  // shading + fog thresholds
  st = face_light[dir] * 15;
  fogt = FClamp((depth - MC_FOG_START) / (MC_FOG_END - MC_FOG_START), 0.0, 1.0);
  fi = fcount;
  fnverts[fi] = nv;
  fshadeT[fi] = st;
  ffogT[fi]   = fogt * 15;
  fdepth[fi]  = depth;
  fcount++;
  return TRUE;
}

U0 BuildFaceList()
{
  I64 px, pz, x, z, y, ymax, b, dir, nb, i, buck, nx, ny, nz;
  F64 invspan;
  fcount = 0;
  px = ToI64(Floor(P.x));  pz = ToI64(Floor(P.z));
  for (x = px - MC_RENDER_DIST;
       x <= px + MC_RENDER_DIST && fcount < MC_MAX_FACES - 8; x++) {
    if (x >= 0 && x < MC_WORLD_SX) {
    for (z = pz - MC_RENDER_DIST;
         z <= pz + MC_RENDER_DIST && fcount < MC_MAX_FACES - 8; z++) {
      if (z >= 0 && z < MC_WORLD_SZ) {
      ymax = MC_WORLD_SY - 1;
      while (ymax >= 0 && world[WIdx(x, ymax, z)] == B_AIR) ymax--;
      for (y = 0; y <= ymax && fcount < MC_MAX_FACES - 8; y++) {
        b = world[WIdx(x, y, z)];
        if (b != B_AIR) {
        for (dir = 0; dir < 6; dir++) {
          nx = x + (dir == D_POSX) - (dir == D_NEGX);
          ny = y + (dir == D_POSY) - (dir == D_NEGY);
          nz = z + (dir == D_POSZ) - (dir == D_NEGZ);
          nb = GetBlock(nx, ny, nz);
          if (b == B_WATER) {
            if (nb == B_AIR) EmitFace(x, y, z, dir);    // only open water
          } else {
            if (nb == B_AIR || nb == B_WATER) EmitFace(x, y, z, dir);
          }
        }
        }
      }
      }
    }
    }
  }
  // painter's algorithm: bucket sort far -> near
  invspan = 1.0 / (MC_FOG_END - MC_NEAR);
  for (i = 0; i < 256; i++) bhead[i] = -1;
  for (i = 0; i < fcount; i++) {
    buck = IClamp(ToI64((fdepth[i] - MC_NEAR) * invspan * 255.0), 0, 255);
    bnext[i] = bhead[buck];
    bhead[buck] = i;
  }
}

U0 DrawWorld()
{
  I64 i, b;
  for (b = 255; b >= 0; b--)
    for (i = bhead[b]; i >= 0; i = bnext[i])
      FillFace(i);
}

// =============================== SKY / HUD ===============================

U0 DrawSky()
{
  F64 sx, sy, u, v, t, cz;
  I64 y, row, x, horizon;
  // horizon = where eye-level rays hit the screen (rises as you look down)
  horizon = scr_h * 0.5 + Sin(P.pitch) / Cos(P.pitch) * MC_FOCAL;
  horizon = IClamp(horizon, -scr_h, 2 * scr_h);
  for (y = 0; y < scr_h; y++) {
    row = y * stride;
    if (y < horizon - 4)
      MemSet(db + row, LTBLUE, scr_w);
    else if (y <= horizon + 4)
      // dithered haze band at the horizon
      for (x = 0; x < scr_w; x++) {
        if (bayer[(x & 3) + ((y & 3) << 2)] < 8.0) db[row + x] = LTBLUE;
        else db[row + x] = CYAN;
      }
    else
      MemSet(db + row, CYAN, scr_w);
  }
  // sun
  cz = 0.45 * cam_fx + 0.75 * cam_fy + 0.45 * cam_fz;
  if (cz > 0.1) {
    sx = scr_w * 0.5 + (0.45 * cam_rx + 0.75 * cam_ry + 0.45 * cam_rz) * MC_FOCAL / cz;
    sy = scr_h * 0.5 - (0.45 * cam_ux + 0.75 * cam_uy + 0.45 * cam_uz) * MC_FOCAL / cz;
    for (v = -10; v <= 10; v++)
      for (u = -10; u <= 10; u++) {
        x = sx + u; y = sy + v;
        if (x >= 0 && x < scr_w && y >= 0 && y < scr_h) {
          t = Sqrt(u * u + v * v);
          if (t < 6.0) db[y * stride + x] = YELLOW;
          else if (bayer[(x & 3) + ((y & 3) << 2)] < 9.0) db[y * stride + x] = YELLOW;
          else db[y * stride + x] = LTBLUE;
        }
      }
  }
}

U0 DrawPixelLine(I64 x0, I64 y0, I64 x1, I64 y1, U8 c)
{
  I64 dx = IAbs(x1 - x0), dy = IAbs(y1 - y0), sx, sy, err, e2;
  if (x0 < x1) sx = 1; else sx = -1;
  if (y0 < y1) sy = 1; else sy = -1;
  err = dx - dy;
  while (TRUE) {
    if (x0 >= 0 && x0 < scr_w && y0 >= 0 && y0 < scr_h)
      db[y0 * stride + x0] = c;
    if (x0 == x1 && y0 == y1) break;
    e2 = 2 * err;
    if (e2 > -dy) { err -= dy; x0 += sx; }
    if (e2 <  dx) { err += dx; y0 += sy; }
  }
}

U0 DrawBoxWire(I64 bx, I64 by, I64 bz, U8 c)
{
  F64 vx[8], vy[8], vz[8], cx, cy, cz, sxx[8], syy[8];
  I64 i, j, x, y;
  I64 edges[24];
  edges[0] = 0;  edges[1] = 1;   edges[2] = 1;  edges[3] = 5;
  edges[4] = 5;  edges[5] = 4;   edges[6] = 4;  edges[7] = 0;
  edges[8] = 2;  edges[9] = 3;   edges[10] = 3; edges[11] = 7;
  edges[12] = 7; edges[13] = 6;  edges[14] = 6; edges[15] = 2;
  edges[16] = 0; edges[17] = 2;  edges[18] = 1; edges[19] = 3;
  edges[20] = 5; edges[21] = 7;  edges[22] = 4; edges[23] = 6;
  for (i = 0; i < 8; i++) {
    vx[i] = bx + corn_x[i] - cam_ex;
    vy[i] = by + corn_y[i] - cam_ey;
    vz[i] = bz + corn_z[i] - cam_ez;
    cz = vx[i] * cam_fx + vy[i] * cam_fy + vz[i] * cam_fz;
    if (cz < MC_NEAR) return;           // simple: only draw if fully visible
    cx = vx[i] * cam_rx + vy[i] * cam_ry + vz[i] * cam_rz;
    cy = vx[i] * cam_ux + vy[i] * cam_uy + vz[i] * cam_uz;
    sxx[i] = scr_w * 0.5 + cx * MC_FOCAL / cz;
    syy[i] = scr_h * 0.5 - cy * MC_FOCAL / cz;
  }
  for (j = 0; j < 12; j++)
    DrawPixelLine(ToI64(sxx[edges[j * 2]]), ToI64(syy[edges[j * 2]]), ToI64(sxx[edges[j * 2 + 1]]), ToI64(syy[edges[j * 2 + 1]]), c);
}

U0 DrawCrosshair()
{
  I64 cx = scr_w / 2, cy = scr_h / 2, i;
  for (i = -6; i <= 6; i++) {
    if (IAbs(i) > 2) {
      db[cy * stride + cx + i] = WHITE;
      db[(cy + i) * stride + cx] = WHITE;
    }
  }
}

U0 DrawHotbar()
{
  I64 i, x0, x, y, b;
  x0 = scr_w / 2 - 6 * 30 / 2;
  for (i = 0; i < 6; i++) {
    b = hotbar_items[i];
    for (y = 0; y < 24; y++)
      for (x = 0; x < 24; x++) {
        if (y == 0 || y == 23 || x == 0 || x == 23 || y == 3 || x == 3) {
          if (i == hotbar_sel) db[(scr_h - 30 + y) * stride + (x0 + i * 30 + x)] = WHITE;
          else db[(scr_h - 30 + y) * stride + (x0 + i * 30 + x)] = DKGRAY;
        } else {
          db[(scr_h - 30 + y) * stride + (x0 + i * 30 + x)] = blkinfo[b].side_a;
        }
      }
  }
}

U0 DrawHud(I64 fps)
{
  I64 hitx, hity, hitz, hitface;
  Bool hit;
  MemSet(db + 4 * stride, BLACK, scr_w * 12);
  gr.dc->color = WHITE;
  GrPrint(gr.dc, 4, 4, "HolyCraft  FPS %d  X %.1f Y %.1f Z %.1f", fps, P.x, P.y, P.z);
  if (P.flying) {
    gr.dc->color = YELLOW;
    GrPrint(gr.dc, 4, 16, "FLYING");
  }
  hit = Raycast(&hitx, &hity, &hitz, &hitface);
  if (hit) {
    gr.dc->color = WHITE;
    GrPrint(gr.dc, scr_w - 120, 4, "%s", blkinfo[world[WIdx(hitx, hity, hitz)]].name);
    DrawBoxWire(hitx, hity, hitz, WHITE);
  }
  DrawHotbar;
  DrawCrosshair();
}

// =============================== GAMEPLAY ================================

F64  last_dt;
Bool prev_lb, prev_rb, prev_f;
F64  last_mx, last_my;

U0 BreakOrPlace(Bool place)
{
  I64 hitx, hity, hitz, hitface, tx, ty, tz, b;
  if (!Raycast(&hitx, &hity, &hitz, &hitface))
    return;
  if (place) {
    tx = hitx + (hitface == D_POSX) - (hitface == D_NEGX);
    ty = hity + (hitface == D_POSY) - (hitface == D_NEGY);
    tz = hitz + (hitface == D_POSZ) - (hitface == D_NEGZ);
    b = GetBlock(tx, ty, tz);
    if (b != B_AIR && b != B_WATER) return;
    // don't build inside yourself
    if (P.x + MC_HALF > tx && P.x - MC_HALF < tx + 1 && P.y + MC_HEIGHT > ty && P.y < ty + 1 && P.z + MC_HALF > tz && P.z - MC_HALF < tz + 1)
      return;
    SetBlockUpdate(tx, ty, tz, hotbar_items[hotbar_sel]);
  } else {
    if (world[WIdx(hitx, hity, hitz)] == B_BEDROCK) return;
    SetBlockUpdate(hitx, hity, hitz, B_AIR);
  }
}

U0 HandleInput()
{
  I64 i;
  if (Bt(kbd.down_bitmap, SC_CURSOR_LEFT))  P.yaw -= 2.4 * last_dt;
  if (Bt(kbd.down_bitmap, SC_CURSOR_RIGHT)) P.yaw += 2.4 * last_dt;
  if (Bt(kbd.down_bitmap, SC_CURSOR_UP))    P.pitch += 1.8 * last_dt;
  if (Bt(kbd.down_bitmap, SC_CURSOR_DOWN))  P.pitch -= 1.8 * last_dt;
  // mouse look (relative to last frame's cursor position)
  P.yaw   += (ms.pos.x - last_mx) * 0.005;
  P.pitch -= (ms.pos.y - last_my) * 0.005;
  last_mx = ms.pos.x;  last_my = ms.pos.y;
  P.pitch = FClamp(P.pitch, -1.5, 1.5);
  if (P.yaw >= 6.2832) P.yaw -= 6.2832;
  if (P.yaw < 0.0)     P.yaw += 6.2832;
  // hotbar keys 1..6
  if (Bt(kbd.down_bitmap, MC_SC_1)) hotbar_sel = 0;
  if (Bt(kbd.down_bitmap, MC_SC_2)) hotbar_sel = 1;
  if (Bt(kbd.down_bitmap, MC_SC_3)) hotbar_sel = 2;
  if (Bt(kbd.down_bitmap, MC_SC_4)) hotbar_sel = 3;
  if (Bt(kbd.down_bitmap, MC_SC_5)) hotbar_sel = 4;
  if (Bt(kbd.down_bitmap, MC_SC_6)) hotbar_sel = 5;
  if (Bt(kbd.down_bitmap, MC_SC_F) && !prev_f)
    P.flying = !P.flying;
  prev_f = Bt(kbd.down_bitmap, MC_SC_F);
  // mouse buttons
  if (ms.lb && !prev_lb) BreakOrPlace(FALSE);
  if (ms.rb && !prev_rb) BreakOrPlace(TRUE);
  prev_lb = ms.lb;
  prev_rb = ms.rb;
}

F64 NowSecs()
{
  return tS();
}

U0 HolyCraft()
{
  Bool quit = FALSE, underwater;
  I64 fps = 0, frames = 0, x, y, u, bx, by, bz;
  F64 t0, t1, dt, fps_t;
  SettingsPush;
  Fs->win_inhibit = WIG_TASK_DFT;
  WinMax;
  DocCursor;
  DocClear;
  FlushMsgs;
  InitBlocks;
  InitRendererTables;
  GenWorld;
  SpawnPlayer;
  last_mx = ms.pos.x;  last_my = ms.pos.y;
  prev_lb = prev_rb = prev_f = FALSE;
  db = gr.dc->body;
  stride = gr.dc->width_internal;
  scr_w = gr.dc->width;
  scr_h = gr.dc->height;
  t0 = NowSecs();  fps_t = t0;
  try {
    while (!quit) {
      t1 = NowSecs();
      dt = t1 - t0;
      t0 = t1;
      if (dt < 0.0001) dt = 0.0001;
      if (dt > 0.1)    dt = 0.1;
      last_dt = dt;
      if (kbd.scan_code == SC_ESC) quit = TRUE;
      HandleInput;
      UpdatePlayer(dt);
      UpdateCamera;
      scr_w = gr.dc->width;
      scr_h = gr.dc->height;
      BuildFaceList;
      DrawSky;
      DrawWorld;
      bx = P.x; by = P.y + MC_EYE; bz = P.z;
      underwater = GetBlock(bx, by, bz) == B_WATER;
      if (underwater)
        for (y = 0; y < scr_h; y++)
          for (x = 0; x < scr_w; x++)
            if (bayer[(x & 3) + ((y & 3) << 2)] < 10.0) db[y * stride + x] = BLUE;
            else db[y * stride + x] = LTBLUE;
      frames++;
      if (t1 - fps_t >= 1.0) {
        fps = frames / (t1 - fps_t);
        frames = 0;
        fps_t = t1;
      }
      DrawHud(fps);
      Sleep(5);
    }
  } catch {
    PutExcept;
    quit = TRUE;
  }
  FlushMsgs;
  SettingsPop;
  DocClear;
  Print("HolyCraft closed.\n"
        "$FG,LTGREEN$Run it again by including MCRAFT.HC.$FG$\n");
}

HolyCraft;
