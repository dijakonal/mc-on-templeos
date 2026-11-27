extern "c" I64 printf(I8 *fmt, ...);
F64 gscale = 1e-9;
I64 main()
{
  F64 sec = 0.0;
  F64 nsec = 367496000.0;
  F64 r1;
  F64 r2;
  F64 r3;
  F64 a = 45.5;
  F64 b = 16.0;
  r1 = sec + nsec * 1e-9;
  r2 = nsec * 1e-9;
  r3 = nsec * gscale;
  printf("r1=%.6f r2=%.6f r3=%.6f\n", r1, r2, r3);
  printf("mul=%.4f div=%.4f add=%.4f\n", a * b, a / b, a + b);
  printf("sin=%.6f sqrt=%.6f\n", 0.5 + 0.5, a - b);
  return 0;
}
