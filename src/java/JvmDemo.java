public class JvmDemo {
  public static int fib(int n) {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
  }
  public static int sieveCount(int n) {
    boolean[] c = new boolean[n + 1];
    int count = 0;
    for (int i = 2; i <= n; i++) {
      if (!c[i]) {
        count++;
        for (int j = i * i; j <= n; j += i) c[j] = true;
      }
    }
    return count;
  }
  public static int run() {
    Hos.print(fib(15));
    Hos.println(fib(20));
    Hos.print(sieveCount(1000));
    int s = 0;
    for (int i = 1; i <= 100; i++) s += i * i;
    return s;
  }
}
