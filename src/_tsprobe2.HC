class timespec {
  I64 tv_sec;
  I64 tv_nsec;
};
extern "c" I32 clock_gettime(I32 clk_id, timespec *tp);
extern "c" I64 printf(I8 *fmt, ...);
extern "c" U0 SDL_Delay(U32 ms);
#define CLOCK_MONOTONIC 1
I64 main()
{
  timespec a;
  I64 i;
  for (i = 0; i < 3; i++) {
    clock_gettime(CLOCK_MONOTONIC, &a);
    printf("sec=%lld nsec=%lld\n", a.tv_sec, a.tv_nsec);
    SDL_Delay(50);
  }
  return 0;
}
