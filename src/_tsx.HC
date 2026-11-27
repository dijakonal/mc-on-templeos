#ifdef __HCC__
#include "compat_hcc.HC"
#endif
class CP {
  F64 x, y;
  I64 n;
};
CP g;
U0 Step(F64 dt)
{
  g.x += 1.5 * dt;
  g.n = g.n + 2;
}
I64 AddUp(I64 a, I64 b)
{
  I64 i;
  I64 s = 0;
  for (i = a; i <= b; i++) s += i;
  return s;
}
U0 Runner()
{
  Step(0.5);
  Print("sum\n");
}
Runner;
