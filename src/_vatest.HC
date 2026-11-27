extern "c" I64 printf(I8 *fmt, ...);
class CP { F64 x, y, z; };
CP g;
U0 va_t(U8 *fmt, ...)
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
  printf("direct: %.2f %.2f %.2f\n", g.x, g.y, g.z);
}
I64 main()
{
  g.x = 45.5;  g.y = 16.0;  g.z = 49.5;
  va_t("fmt", 7, g.x, g.y, g.z);
  return 0;
}
