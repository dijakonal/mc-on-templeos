extern "c" I64 printf(I8 *fmt, ...);
class CP { F64 x, y, z; };
class CDC { I64 color; U8 *body; I64 wi; I64 w; I64 h; };
CDC dc;
CP g;
U0 gp(CDC *d, I64 x, I64 y, U8 *fmt, ...)
{
  I64 iv;
  F64 a;
  F64 b;
  F64 c;
  iv = argv[0];
  a = argv[1](F64);
  b = argv[2](F64);
  c = argv[3](F64);
  printf("iv=%lld a=%.2f b=%.2f c=%.2f\n", iv, a, b, c);
}
I64 main()
{
  dc.color = 15;
  g.x = 45.5;  g.y = 16.0;  g.z = 49.5;
  gp(&dc, 4, 4, "fmt", 7, g.x, g.y, g.z);
  return 0;
}
