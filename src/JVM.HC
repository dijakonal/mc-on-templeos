// HolyJVM v0.1 — a Java bytecode interpreter for TempleOS.
//
// Parses real javac-compiled .class files (embedded below as bytes) and
// executes the JVM instruction set with an explicit call-frame stack.
// Scope v0.1: int arithmetic, static fields, int/boolean arrays, static
// method calls with recursion, Hos.print/println builtins.  No objects,
// longs, or verifier — this is proof that Java bytecode runs natively on
// TempleOS, not a HotSpot.

#define JVM_CP_MAX     512
#define JVM_M_MAX      32
#define JVM_SF_MAX     32
#define JVM_FRAMES     64
#define JVM_STACK      8192
#define JVM_STEPLIMIT  500000000

U8  *kbuf;
I64  klen;

I64  cp_count;
I64  cp_tag[JVM_CP_MAX];
U8  *cp_str[JVM_CP_MAX];               // Utf8 text
I64  cp_num[JVM_CP_MAX];               // Integer / Long payload
I64  cp_a[JVM_CP_MAX];                 // Class: name idx; Refs: class idx; NAT: name idx; String: utf8 idx
I64  cp_b[JVM_CP_MAX];                 // Refs: NAT idx; NAT: desc idx

I64  m_count;
I64  m_name[JVM_M_MAX];                // utf8 idx
I64  m_desc[JVM_M_MAX];                // utf8 idx
U8  *m_code[JVM_M_MAX];
I64  m_clen[JVM_M_MAX];
I64  m_maxl[JVM_M_MAX];
I64  m_maxs[JVM_M_MAX];

I64  sf_count;
U8  *sf_name[JVM_SF_MAX];
I64  sf_val[JVM_SF_MAX];

// interpreter state
I64  jvm_dbg;
U8  *ex_code;
I64  ex_clen;
I64  ex_pc;
I64  ex_sp;
I64  ex_nloc;
I64 *ex_locals;
I64  ex_stack[JVM_STACK];
I64  csp;
U8  *c_code[JVM_FRAMES];
I64  c_clen[JVM_FRAMES];
I64  c_pc[JVM_FRAMES];
I64  c_sp[JVM_FRAMES];
I64  c_nloc[JVM_FRAMES];
I64 *c_loc[JVM_FRAMES];
I64  jvm_steps;

// Backend-agnostic output: hcc has no Print, TempleOS has no printf.
#ifdef __HCC__
U0 DbgStrLn(U8 *s) { printf("%s\n", s); }
U0 Dbg2(U8 *a, U8 *b) { printf("%s.%s\n", a, b); }
U0 DbgInt(I64 v) { printf("%d", v); }
U0 DbgResult(I64 v) { printf("HolyJVM: run() returned %d\n", v); }
U0 DbgErr2(U8 *a, U8 *b) { printf("HolyJVM: method not found: %s.%s\n", a, b); }
U0 DbgErr1(U8 *s) { printf("HolyJVM: %s\n", s); }
#else
U0 DbgStrLn(U8 *s) { Print("%s\n", s); }
U0 Dbg2(U8 *a, U8 *b) { Print("%s.%s\n", a, b); }
U0 DbgInt(I64 v) { Print("%d", v); }
U0 DbgResult(I64 v) { Print("HolyJVM: run() returned %d\n", v); }
U0 DbgErr2(U8 *a, U8 *b) { Print("HolyJVM: method not found: %s.%s\n", a, b); }
U0 DbgErr1(U8 *s) { Print("HolyJVM: %s\n", s); }
#endif

I64 RdU1(I64 i)
{
  return kbuf[i];
}

I64 RdU2(I64 i)
{
  return (kbuf[i] << 8) | kbuf[i + 1];
}

I64 RdU4(I64 i)
{
  return (kbuf[i] << 24) | (kbuf[i + 1] << 16) | (kbuf[i + 2] << 8) | kbuf[i + 3];
}

// JVM ints are 32-bit: sign-extend after arithmetic.
I64 S32(I64 x)
{
  return (x << 32) >> 32;
}

U8 *CpUtf8(I64 i)
{
  if (i >= 1 && i < cp_count && cp_tag[i] == 1) return cp_str[i];
  return "";
}

U0 ParseClass()
{
  I64 i, tag, len, n, mi, ai, di, alen, an2, al2, acnt2, k2, k3, codelen, acc2, namei, desci, cnt;
  U8 *keep;
  i = 8;                                // magic + version
  cp_count = RdU2(i);
  i += 2;
  for (n = 1; n < cp_count; n++) {
    tag = RdU1(i);
    i += 1;
    cp_tag[n] = tag;
    if (tag == 1) {                     // Utf8
      len = RdU2(i);
      i += 2;
      cp_str[n] = MAlloc(len + 1);
      for (mi = 0; mi < len; mi++) cp_str[n][mi] = kbuf[i + mi];
      cp_str[n][len] = 0;
      i += len;
    } else if (tag == 3) {              // Integer
      cp_num[n] = RdU4(i);
      i += 4;
    } else if (tag == 4) {              // Float (kept raw)
      cp_num[n] = RdU4(i);
      i += 4;
    } else if (tag == 5) {              // Long (occupies two CP slots)
      cp_num[n] = RdU4(i) << 32 | RdU4(i + 4);
      i += 8;
      n++;
    } else if (tag == 6) {              // Double (occupies two CP slots)
      cp_num[n] = RdU4(i) << 32 | RdU4(i + 4);
      i += 8;
      n++;
    } else if (tag == 7) {              // Class
      cp_a[n] = RdU2(i);
      i += 2;
    } else if (tag == 8) {              // String (utf8 index, resolved lazily)
      cp_a[n] = RdU2(i);
      i += 2;
    } else if (tag == 9 || tag == 10 || tag == 11) {  // field/method/iface refs
      cp_a[n] = RdU2(i);
      cp_b[n] = RdU2(i + 2);
      i += 4;
    } else if (tag == 12) {             // NameAndType
      cp_a[n] = RdU2(i);
      cp_b[n] = RdU2(i + 2);
      i += 4;
    } else if (tag == 15) {             // MethodHandle
      i += 3;
    } else if (tag == 16) {             // MethodType
      i += 2;
    } else if (tag == 17 || tag == 18) {// Dynamic / InvokeDynamic
      i += 4;
    } else {                            // Module / Package / unknown
      i += 2;
    }
  }
  i += 2;                               // access flags
  i += 2;                               // this class
  i += 2;                               // super class
  cnt = RdU2(i);                        // interfaces
  i += 2 + cnt * 2;
  cnt = RdU2(i);                        // fields
  i += 2;
  sf_count = 0;
  for (n = 0; n < cnt; n++) {
    acc2 = RdU2(i);
    ai = RdU2(i + 2);
    i += 6;                             // access + name + desc
    alen = RdU2(i);
    i += 2 + alen;                      // skip field attributes
    if (acc2 & 0x0008 && sf_count < JVM_SF_MAX) {
      sf_name[sf_count] = CpUtf8(ai);
      sf_val[sf_count] = 0;
      sf_count++;
    }
  }
  m_count = 0;
  cnt = RdU2(i);                        // methods
  i += 2;
  for (n = 0; n < cnt && m_count < JVM_M_MAX; n++) {
    acc2  = RdU2(i);
    namei = RdU2(i + 2);
    desci = RdU2(i + 4);
    i += 6;
    acnt2 = RdU2(i);
    i += 2;
    keep = 0;
    codelen = 0;
    for (k2 = 0; k2 < acnt2; k2++) {
      an2 = RdU2(i);
      al2 = RdU4(i + 2);
      i += 6;
      if (StrCmp(CpUtf8(an2), "Code") == 0) {
        m_maxs[m_count] = RdU2(i);
        m_maxl[m_count] = RdU2(i + 2);
        codelen = RdU4(i + 4);
        keep = MAlloc(codelen);
        for (k3 = 0; k3 < codelen; k3++) keep[k3] = kbuf[i + 8 + k3];
      }
      i += al2;
    }
    if (keep) {
      m_name[m_count] = namei;
      m_desc[m_count] = desci;
      m_code[m_count] = keep;
      m_clen[m_count] = codelen;
      m_count++;
    }
  }
}

I64 FindMethod(I64 name_utf, I64 desc_utf)
{
  I64 i;
  for (i = 0; i < m_count; i++)
    if (m_name[i] == name_utf && m_desc[i] == desc_utf) return i;
  return -1;
}

I64 FindMethodByName(U8 *name, U8 *desc)
{
  I64 i;
  for (i = 0; i < m_count; i++)
    if (StrCmp(CpUtf8(m_name[i]), name) == 0 && StrCmp(CpUtf8(m_desc[i]), desc) == 0)
      return i;
  return -1;
}

I64 GetStatic(U8 *name)
{
  I64 i;
  for (i = 0; i < sf_count; i++)
    if (StrCmp(sf_name[i], name) == 0) return sf_val[i];
  return 0;
}

U0 PutStatic(U8 *name, I64 v)
{
  I64 i;
  for (i = 0; i < sf_count; i++)
    if (StrCmp(sf_name[i], name) == 0) sf_val[i] = v;
}

// number of argument slots a descriptor's parameter list occupies
I64 DescArgs(U8 *d)
{
  I64 i = 1, n = 0;
  while (d[i] != ')') {
    if (d[i] == 'L') {
      n++;
      while (d[i] != ';') i++;
    } else if (d[i] == '[') {
      n++;
      while (d[i] == '[') i++;
      if (d[i] == 'L')
        while (d[i] != ';') i++;
    } else {
      n++;
    }
    i++;
  }
  return n;
}

I64 NewArray(I64 len)
{
  I64 *a;
  if (len < 0) len = 0;
  a = MAlloc((len + 1) * 8);
  a[0] = len;
  return a;
}

I64 RdC2(I64 i)
{
  return (ex_code[i] << 8) | ex_code[i + 1];
}

// Execute method mi.  arg0 is placed in locals[0] (v0.1 carries at most
// one explicit argument; the demo entrypoint takes none).
I64 ExecRun(I64 mi, I64 arg0)
{
  I64 result, op, idx, cval, v, v2, aref, aidx, argn, k;
  I64 *aptr;
  result = 0;
  csp = 0;
  ex_locals = MAlloc(m_maxl[mi] * 8 + 8);
  for (k = 0; k < m_maxl[mi]; k++) ex_locals[k] = 0;
  ex_locals[0] = arg0;
  ex_nloc = m_maxl[mi];
  ex_code = m_code[mi];
  ex_clen = m_clen[mi];
  ex_pc = 0;
  ex_sp = 0;
  jvm_steps = 0;
  while (TRUE) {
    jvm_steps++;
    if (jvm_steps > JVM_STEPLIMIT) {
      DbgErr1("step limit exceeded");
      return 0;
    }
    if (ex_pc < 0 || ex_pc >= ex_clen) {
      DbgErr1("pc out of range");
      return 0;
    }
    op = ex_code[ex_pc];
    if (op == 0x00) {                   // nop
      ex_pc++;
    } else if (op == 0x01) {            // aconst_null
      ex_stack[ex_sp++] = 0;
      ex_pc++;
    } else if (op >= 0x02 && op <= 0x08) {   // iconst_m1..iconst_5
      ex_stack[ex_sp++] = op - 0x03;
      ex_pc++;
    } else if (op == 0x10) {            // bipush
      cval = ex_code[ex_pc + 1];
      if (cval >= 128) cval -= 256;
      ex_stack[ex_sp++] = cval;
      ex_pc += 2;
    } else if (op == 0x11) {            // sipush
      cval = (ex_code[ex_pc + 1] << 8) | ex_code[ex_pc + 2];
      if (cval >= 32768) cval -= 65536;
      ex_stack[ex_sp++] = cval;
      ex_pc += 3;
    } else if (op == 0x12) {            // ldc
      idx = ex_code[ex_pc + 1];
      if (cp_tag[idx] == 3) ex_stack[ex_sp++] = cp_num[idx];
      else if (cp_tag[idx] == 8) ex_stack[ex_sp++] = CpUtf8(cp_a[idx]);
      else ex_stack[ex_sp++] = 0;
      ex_pc += 2;
    } else if (op == 0x13) {            // ldc_w
      idx = RdC2(ex_pc + 1);
      if (cp_tag[idx] == 3) ex_stack[ex_sp++] = cp_num[idx];
      else if (cp_tag[idx] == 8) ex_stack[ex_sp++] = CpUtf8(cp_a[idx]);
      else ex_stack[ex_sp++] = 0;
      ex_pc += 3;
    } else if (op == 0x15) {            // iload
      ex_stack[ex_sp++] = ex_locals[ex_code[ex_pc + 1]];
      ex_pc += 2;
    } else if (op == 0x19) {            // aload
      ex_stack[ex_sp++] = ex_locals[ex_code[ex_pc + 1]];
      ex_pc += 2;
    } else if (op >= 0x1a && op <= 0x1d) {   // iload_0..3
      ex_stack[ex_sp++] = ex_locals[op - 0x1a];
      ex_pc++;
    } else if (op >= 0x2a && op <= 0x2d) {   // aload_0..3
      ex_stack[ex_sp++] = ex_locals[op - 0x2a];
      ex_pc++;
    } else if (op == 0x2e || op == 0x33) {   // iaload / baload
      aidx = ex_stack[ex_sp - 1];
      aref = ex_stack[ex_sp - 2];
      ex_sp -= 2;
      aptr = aref;
      if (aidx < 0 || aidx >= aptr[0]) {
        DbgErr1("array index out of range");
        return 0;
      }
      ex_stack[ex_sp++] = aptr[1 + aidx];
      ex_pc++;
    } else if (op == 0x36) {            // istore
      ex_locals[ex_code[ex_pc + 1]] = ex_stack[--ex_sp];
      ex_pc += 2;
    } else if (op == 0x3a) {            // astore
      ex_locals[ex_code[ex_pc + 1]] = ex_stack[--ex_sp];
      ex_pc += 2;
    } else if (op >= 0x3b && op <= 0x3e) {   // istore_0..3
      ex_locals[op - 0x3b] = ex_stack[--ex_sp];
      ex_pc++;
    } else if (op >= 0x4b && op <= 0x4e) {   // astore_0..3
      ex_locals[op - 0x4b] = ex_stack[--ex_sp];
      ex_pc++;
    } else if (op >= 0x4f && op <= 0x56) {   // iastore / bastore / castore / sastore
      v = ex_stack[ex_sp - 1];
      aidx = ex_stack[ex_sp - 2];
      aref = ex_stack[ex_sp - 3];
      ex_sp -= 3;
      aptr = aref;
      if (aidx < 0 || aidx >= aptr[0]) {
        DbgErr1("array index out of range");
        return 0;
      }
      aptr[1 + aidx] = v;
      ex_pc++;
    } else if (op == 0x57) {            // pop
      ex_sp--;
      ex_pc++;
    } else if (op == 0x59) {            // dup
      ex_stack[ex_sp] = ex_stack[ex_sp - 1];
      ex_sp++;
      ex_pc++;
    } else if (op == 0x60) {            // iadd
      v = S32(ex_stack[ex_sp - 2] + ex_stack[ex_sp - 1]);
      ex_sp -= 2;
      ex_stack[ex_sp++] = v;
      ex_pc++;
    } else if (op == 0x64) {            // isub
      v = S32(ex_stack[ex_sp - 2] - ex_stack[ex_sp - 1]);
      ex_sp -= 2;
      ex_stack[ex_sp++] = v;
      ex_pc++;
    } else if (op == 0x68) {            // imul
      v = S32(ex_stack[ex_sp - 2] * ex_stack[ex_sp - 1]);
      ex_sp -= 2;
      ex_stack[ex_sp++] = v;
      ex_pc++;
    } else if (op == 0x6c || op == 0x6e) {   // idiv / irem
      v = ex_stack[ex_sp - 1];
      v2 = ex_stack[ex_sp - 2];
      ex_sp -= 2;
      if (v == 0) {
        DbgErr1("division by zero");
        return 0;
      }
      if (op == 0x6c) v = S32(v2 / v);
      else            v = S32(v2 % v);
      ex_stack[ex_sp++] = v;
      ex_pc++;
    } else if (op == 0x70) {            // ineg
      ex_stack[ex_sp - 1] = S32(-ex_stack[ex_sp - 1]);
      ex_pc++;
    } else if (op == 0x78) {            // ishl
      v = ex_stack[ex_sp - 2] << (ex_stack[ex_sp - 1] & 31);
      ex_sp -= 2;
      ex_stack[ex_sp++] = S32(v);
      ex_pc++;
    } else if (op == 0x7a) {            // ishr
      v = ex_stack[ex_sp - 2] >> (ex_stack[ex_sp - 1] & 31);
      ex_sp -= 2;
      ex_stack[ex_sp++] = S32(v);
      ex_pc++;
    } else if (op == 0x7e) {            // iand
      v = ex_stack[ex_sp - 2] & ex_stack[ex_sp - 1];
      ex_sp -= 2;
      ex_stack[ex_sp++] = S32(v);
      ex_pc++;
    } else if (op == 0x80) {            // ior
      v = ex_stack[ex_sp - 2] | ex_stack[ex_sp - 1];
      ex_sp -= 2;
      ex_stack[ex_sp++] = S32(v);
      ex_pc++;
    } else if (op == 0x82) {            // ixor
      v = ex_stack[ex_sp - 2] ^ ex_stack[ex_sp - 1];
      ex_sp -= 2;
      ex_stack[ex_sp++] = S32(v);
      ex_pc++;
    } else if (op == 0x84) {            // iinc
      idx = ex_code[ex_pc + 1];
      cval = ex_code[ex_pc + 2];
      if (cval >= 128) cval -= 256;
      ex_locals[idx] = S32(ex_locals[idx] + cval);
      ex_pc += 3;
    } else if (op >= 0x99 && op <= 0x9e) {   // ifeq..ifle
      v = ex_stack[--ex_sp];
      cval = (ex_code[ex_pc + 1] << 8) | ex_code[ex_pc + 2];
      if (cval >= 32768) cval -= 65536;
      idx = 0;
      if (op == 0x99 && v == 0) idx = 1;   // ifeq
      if (op == 0x9a && v != 0) idx = 1;   // ifne
      if (op == 0x9b && v < 0) idx = 1;    // iflt
      if (op == 0x9c && v >= 0) idx = 1;   // ifge
      if (op == 0x9d && v > 0) idx = 1;    // ifgt
      if (op == 0x9e && v <= 0) idx = 1;   // ifle
      if (idx) ex_pc += cval;
      else ex_pc += 3;
    } else if (op >= 0x9f && op <= 0xa4) {   // if_icmpeq..le
      v2 = ex_stack[--ex_sp];
      v = ex_stack[--ex_sp];
      cval = (ex_code[ex_pc + 1] << 8) | ex_code[ex_pc + 2];
      if (cval >= 32768) cval -= 65536;
      idx = 0;
      if (op == 0x9f && v == v2) idx = 1;  // if_icmpeq
      if (op == 0xa0 && v != v2) idx = 1;  // if_icmpne
      if (op == 0xa1 && v < v2) idx = 1;   // if_icmplt
      if (op == 0xa2 && v >= v2) idx = 1;  // if_icmpge
      if (op == 0xa3 && v > v2) idx = 1;   // if_icmpgt
      if (op == 0xa4 && v <= v2) idx = 1;  // if_icmple
      if (idx) ex_pc += cval;
      else ex_pc += 3;
    } else if (op == 0xa7) {            // goto
      cval = (ex_code[ex_pc + 1] << 8) | ex_code[ex_pc + 2];
      if (cval >= 32768) cval -= 65536;
      ex_pc += cval;
    } else if (op == 0xac) {            // ireturn
      result = ex_stack[--ex_sp];
      Free(ex_locals);
      if (csp == 0) return result;
      csp--;
      ex_code = c_code[csp];
      ex_clen = c_clen[csp];
      ex_pc = c_pc[csp];
      ex_sp = c_sp[csp];
      ex_nloc = c_nloc[csp];
      ex_locals = c_loc[csp];
      ex_stack[ex_sp++] = result;
    } else if (op == 0xb1) {            // return
      Free(ex_locals);
      if (csp == 0) return 0;
      csp--;
      ex_code = c_code[csp];
      ex_clen = c_clen[csp];
      ex_pc = c_pc[csp];
      ex_sp = c_sp[csp];
      ex_nloc = c_nloc[csp];
      ex_locals = c_loc[csp];
    } else if (op == 0xb4) {            // getstatic
      idx = RdC2(ex_pc + 1);
      idx = cp_a[cp_b[idx]];            // NAT name idx
      ex_stack[ex_sp++] = GetStatic(CpUtf8(idx));
      ex_pc += 3;
    } else if (op == 0xb5) {            // putstatic
      idx = RdU2(ex_pc + 1);
      v = ex_stack[--ex_sp];
      idx = cp_a[cp_b[idx]];
      PutStatic(CpUtf8(idx), v);
      ex_pc += 3;
    } else if (op == 0xb8) {            // invokestatic
      idx = RdC2(ex_pc + 1);
      cval = cp_a[idx];                 // class idx
      k = cp_b[idx];                    // NAT idx
      if (StrCmp(CpUtf8(cp_a[cval]), "Hos") == 0) {
        // builtin: print / println on ints
        v = ex_stack[--ex_sp];
        if (StrCmp(CpUtf8(cp_a[k]), "print") == 0) DbgInt(v);
        else { DbgInt(v); DbgStrLn(""); }
        ex_pc += 3;
      } else {
        mi = FindMethod(cp_a[k], cp_b[k]);
        if (mi < 0) {
          DbgErr2(CpUtf8(cp_a[cval]), CpUtf8(cp_a[k]));
          return 0;
        }
        // switch frames; carry the top DescArgs arguments into locals
        c_code[csp] = ex_code;
        c_clen[csp] = ex_clen;
        c_pc[csp] = ex_pc + 3;
        c_sp[csp] = ex_sp - DescArgs(CpUtf8(m_desc[mi]));
        c_nloc[csp] = ex_nloc;
        c_loc[csp] = ex_locals;
        csp++;
        argn = DescArgs(CpUtf8(m_desc[mi]));
        ex_locals = MAlloc(m_maxl[mi] * 8 + 8);
        for (k = 0; k < m_maxl[mi]; k++) ex_locals[k] = 0;
        for (k = 0; k < argn; k++)
          ex_locals[k] = ex_stack[c_sp[csp - 1] + k];
        ex_sp = c_sp[csp - 1] + argn;
        ex_nloc = m_maxl[mi];
        ex_code = m_code[mi];
        ex_clen = m_clen[mi];
        ex_pc = 0;
      }
    } else if (op == 0xbc) {            // newarray
      aref = ex_stack[--ex_sp];
      ex_stack[ex_sp++] = NewArray(aref);
      ex_pc += 2;
    } else if (op == 0xbe) {            // arraylength
      aref = ex_stack[--ex_sp];
      aptr = aref;
      ex_stack[ex_sp++] = aptr[0];
      ex_pc++;
    } else {
      DbgErr1("unimplemented opcode");
      return 0;
    }
  }
}

// ---- embedded demo class (javac --release 8 JvmDemo.java) ----------------
I64 kbytes_len = 668;
U8 kbytes[668];
  kbytes[0]=0xCA; kbytes[1]=0xFE; kbytes[2]=0xBA; kbytes[3]=0xBE; kbytes[4]=0x00; kbytes[5]=0x00; kbytes[6]=0x00; kbytes[7]=0x34;
  kbytes[8]=0x00; kbytes[9]=0x22; kbytes[10]=0x0A; kbytes[11]=0x00; kbytes[12]=0x02; kbytes[13]=0x00; kbytes[14]=0x03; kbytes[15]=0x07;
  kbytes[16]=0x00; kbytes[17]=0x04; kbytes[18]=0x0C; kbytes[19]=0x00; kbytes[20]=0x05; kbytes[21]=0x00; kbytes[22]=0x06; kbytes[23]=0x01;
  kbytes[24]=0x00; kbytes[25]=0x10; kbytes[26]=0x6A; kbytes[27]=0x61; kbytes[28]=0x76; kbytes[29]=0x61; kbytes[30]=0x2F; kbytes[31]=0x6C;
  kbytes[32]=0x61; kbytes[33]=0x6E; kbytes[34]=0x67; kbytes[35]=0x2F; kbytes[36]=0x4F; kbytes[37]=0x62; kbytes[38]=0x6A; kbytes[39]=0x65;
  kbytes[40]=0x63; kbytes[41]=0x74; kbytes[42]=0x01; kbytes[43]=0x00; kbytes[44]=0x06; kbytes[45]=0x3C; kbytes[46]=0x69; kbytes[47]=0x6E;
  kbytes[48]=0x69; kbytes[49]=0x74; kbytes[50]=0x3E; kbytes[51]=0x01; kbytes[52]=0x00; kbytes[53]=0x03; kbytes[54]=0x28; kbytes[55]=0x29;
  kbytes[56]=0x56; kbytes[57]=0x0A; kbytes[58]=0x00; kbytes[59]=0x08; kbytes[60]=0x00; kbytes[61]=0x09; kbytes[62]=0x07; kbytes[63]=0x00;
  kbytes[64]=0x0A; kbytes[65]=0x0C; kbytes[66]=0x00; kbytes[67]=0x0B; kbytes[68]=0x00; kbytes[69]=0x0C; kbytes[70]=0x01; kbytes[71]=0x00;
  kbytes[72]=0x07; kbytes[73]=0x4A; kbytes[74]=0x76; kbytes[75]=0x6D; kbytes[76]=0x44; kbytes[77]=0x65; kbytes[78]=0x6D; kbytes[79]=0x6F;
  kbytes[80]=0x01; kbytes[81]=0x00; kbytes[82]=0x03; kbytes[83]=0x66; kbytes[84]=0x69; kbytes[85]=0x62; kbytes[86]=0x01; kbytes[87]=0x00;
  kbytes[88]=0x04; kbytes[89]=0x28; kbytes[90]=0x49; kbytes[91]=0x29; kbytes[92]=0x49; kbytes[93]=0x0A; kbytes[94]=0x00; kbytes[95]=0x0E;
  kbytes[96]=0x00; kbytes[97]=0x0F; kbytes[98]=0x07; kbytes[99]=0x00; kbytes[100]=0x10; kbytes[101]=0x0C; kbytes[102]=0x00; kbytes[103]=0x11;
  kbytes[104]=0x00; kbytes[105]=0x12; kbytes[106]=0x01; kbytes[107]=0x00; kbytes[108]=0x03; kbytes[109]=0x48; kbytes[110]=0x6F; kbytes[111]=0x73;
  kbytes[112]=0x01; kbytes[113]=0x00; kbytes[114]=0x05; kbytes[115]=0x70; kbytes[116]=0x72; kbytes[117]=0x69; kbytes[118]=0x6E; kbytes[119]=0x74;
  kbytes[120]=0x01; kbytes[121]=0x00; kbytes[122]=0x04; kbytes[123]=0x28; kbytes[124]=0x49; kbytes[125]=0x29; kbytes[126]=0x56; kbytes[127]=0x0A;
  kbytes[128]=0x00; kbytes[129]=0x0E; kbytes[130]=0x00; kbytes[131]=0x14; kbytes[132]=0x0C; kbytes[133]=0x00; kbytes[134]=0x15; kbytes[135]=0x00;
  kbytes[136]=0x12; kbytes[137]=0x01; kbytes[138]=0x00; kbytes[139]=0x07; kbytes[140]=0x70; kbytes[141]=0x72; kbytes[142]=0x69; kbytes[143]=0x6E;
  kbytes[144]=0x74; kbytes[145]=0x6C; kbytes[146]=0x6E; kbytes[147]=0x0A; kbytes[148]=0x00; kbytes[149]=0x08; kbytes[150]=0x00; kbytes[151]=0x17;
  kbytes[152]=0x0C; kbytes[153]=0x00; kbytes[154]=0x18; kbytes[155]=0x00; kbytes[156]=0x0C; kbytes[157]=0x01; kbytes[158]=0x00; kbytes[159]=0x0A;
  kbytes[160]=0x73; kbytes[161]=0x69; kbytes[162]=0x65; kbytes[163]=0x76; kbytes[164]=0x65; kbytes[165]=0x43; kbytes[166]=0x6F; kbytes[167]=0x75;
  kbytes[168]=0x6E; kbytes[169]=0x74; kbytes[170]=0x01; kbytes[171]=0x00; kbytes[172]=0x04; kbytes[173]=0x43; kbytes[174]=0x6F; kbytes[175]=0x64;
  kbytes[176]=0x65; kbytes[177]=0x01; kbytes[178]=0x00; kbytes[179]=0x0F; kbytes[180]=0x4C; kbytes[181]=0x69; kbytes[182]=0x6E; kbytes[183]=0x65;
  kbytes[184]=0x4E; kbytes[185]=0x75; kbytes[186]=0x6D; kbytes[187]=0x62; kbytes[188]=0x65; kbytes[189]=0x72; kbytes[190]=0x54; kbytes[191]=0x61;
  kbytes[192]=0x62; kbytes[193]=0x6C; kbytes[194]=0x65; kbytes[195]=0x01; kbytes[196]=0x00; kbytes[197]=0x0D; kbytes[198]=0x53; kbytes[199]=0x74;
  kbytes[200]=0x61; kbytes[201]=0x63; kbytes[202]=0x6B; kbytes[203]=0x4D; kbytes[204]=0x61; kbytes[205]=0x70; kbytes[206]=0x54; kbytes[207]=0x61;
  kbytes[208]=0x62; kbytes[209]=0x6C; kbytes[210]=0x65; kbytes[211]=0x07; kbytes[212]=0x00; kbytes[213]=0x1D; kbytes[214]=0x01; kbytes[215]=0x00;
  kbytes[216]=0x02; kbytes[217]=0x5B; kbytes[218]=0x5A; kbytes[219]=0x01; kbytes[220]=0x00; kbytes[221]=0x03; kbytes[222]=0x72; kbytes[223]=0x75;
  kbytes[224]=0x6E; kbytes[225]=0x01; kbytes[226]=0x00; kbytes[227]=0x03; kbytes[228]=0x28; kbytes[229]=0x29; kbytes[230]=0x49; kbytes[231]=0x01;
  kbytes[232]=0x00; kbytes[233]=0x0A; kbytes[234]=0x53; kbytes[235]=0x6F; kbytes[236]=0x75; kbytes[237]=0x72; kbytes[238]=0x63; kbytes[239]=0x65;
  kbytes[240]=0x46; kbytes[241]=0x69; kbytes[242]=0x6C; kbytes[243]=0x65; kbytes[244]=0x01; kbytes[245]=0x00; kbytes[246]=0x0C; kbytes[247]=0x4A;
  kbytes[248]=0x76; kbytes[249]=0x6D; kbytes[250]=0x44; kbytes[251]=0x65; kbytes[252]=0x6D; kbytes[253]=0x6F; kbytes[254]=0x2E; kbytes[255]=0x6A;
  kbytes[256]=0x61; kbytes[257]=0x76; kbytes[258]=0x61; kbytes[259]=0x00; kbytes[260]=0x21; kbytes[261]=0x00; kbytes[262]=0x08; kbytes[263]=0x00;
  kbytes[264]=0x02; kbytes[265]=0x00; kbytes[266]=0x00; kbytes[267]=0x00; kbytes[268]=0x00; kbytes[269]=0x00; kbytes[270]=0x04; kbytes[271]=0x00;
  kbytes[272]=0x01; kbytes[273]=0x00; kbytes[274]=0x05; kbytes[275]=0x00; kbytes[276]=0x06; kbytes[277]=0x00; kbytes[278]=0x01; kbytes[279]=0x00;
  kbytes[280]=0x19; kbytes[281]=0x00; kbytes[282]=0x00; kbytes[283]=0x00; kbytes[284]=0x1D; kbytes[285]=0x00; kbytes[286]=0x01; kbytes[287]=0x00;
  kbytes[288]=0x01; kbytes[289]=0x00; kbytes[290]=0x00; kbytes[291]=0x00; kbytes[292]=0x05; kbytes[293]=0x2A; kbytes[294]=0xB7; kbytes[295]=0x00;
  kbytes[296]=0x01; kbytes[297]=0xB1; kbytes[298]=0x00; kbytes[299]=0x00; kbytes[300]=0x00; kbytes[301]=0x01; kbytes[302]=0x00; kbytes[303]=0x1A;
  kbytes[304]=0x00; kbytes[305]=0x00; kbytes[306]=0x00; kbytes[307]=0x06; kbytes[308]=0x00; kbytes[309]=0x01; kbytes[310]=0x00; kbytes[311]=0x00;
  kbytes[312]=0x00; kbytes[313]=0x01; kbytes[314]=0x00; kbytes[315]=0x09; kbytes[316]=0x00; kbytes[317]=0x0B; kbytes[318]=0x00; kbytes[319]=0x0C;
  kbytes[320]=0x00; kbytes[321]=0x01; kbytes[322]=0x00; kbytes[323]=0x19; kbytes[324]=0x00; kbytes[325]=0x00; kbytes[326]=0x00; kbytes[327]=0x3A;
  kbytes[328]=0x00; kbytes[329]=0x03; kbytes[330]=0x00; kbytes[331]=0x01; kbytes[332]=0x00; kbytes[333]=0x00; kbytes[334]=0x00; kbytes[335]=0x15;
  kbytes[336]=0x1A; kbytes[337]=0x05; kbytes[338]=0xA2; kbytes[339]=0x00; kbytes[340]=0x05; kbytes[341]=0x1A; kbytes[342]=0xAC; kbytes[343]=0x1A;
  kbytes[344]=0x04; kbytes[345]=0x64; kbytes[346]=0xB8; kbytes[347]=0x00; kbytes[348]=0x07; kbytes[349]=0x1A; kbytes[350]=0x05; kbytes[351]=0x64;
  kbytes[352]=0xB8; kbytes[353]=0x00; kbytes[354]=0x07; kbytes[355]=0x60; kbytes[356]=0xAC; kbytes[357]=0x00; kbytes[358]=0x00; kbytes[359]=0x00;
  kbytes[360]=0x02; kbytes[361]=0x00; kbytes[362]=0x1A; kbytes[363]=0x00; kbytes[364]=0x00; kbytes[365]=0x00; kbytes[366]=0x0A; kbytes[367]=0x00;
  kbytes[368]=0x02; kbytes[369]=0x00; kbytes[370]=0x00; kbytes[371]=0x00; kbytes[372]=0x03; kbytes[373]=0x00; kbytes[374]=0x07; kbytes[375]=0x00;
  kbytes[376]=0x04; kbytes[377]=0x00; kbytes[378]=0x1B; kbytes[379]=0x00; kbytes[380]=0x00; kbytes[381]=0x00; kbytes[382]=0x03; kbytes[383]=0x00;
  kbytes[384]=0x01; kbytes[385]=0x07; kbytes[386]=0x00; kbytes[387]=0x09; kbytes[388]=0x00; kbytes[389]=0x18; kbytes[390]=0x00; kbytes[391]=0x0C;
  kbytes[392]=0x00; kbytes[393]=0x01; kbytes[394]=0x00; kbytes[395]=0x19; kbytes[396]=0x00; kbytes[397]=0x00; kbytes[398]=0x00; kbytes[399]=0x87;
  kbytes[400]=0x00; kbytes[401]=0x03; kbytes[402]=0x00; kbytes[403]=0x05; kbytes[404]=0x00; kbytes[405]=0x00; kbytes[406]=0x00; kbytes[407]=0x39;
  kbytes[408]=0x1A; kbytes[409]=0x04; kbytes[410]=0x60; kbytes[411]=0xBC; kbytes[412]=0x04; kbytes[413]=0x4C; kbytes[414]=0x03; kbytes[415]=0x3D;
  kbytes[416]=0x05; kbytes[417]=0x3E; kbytes[418]=0x1D; kbytes[419]=0x1A; kbytes[420]=0xA3; kbytes[421]=0x00; kbytes[422]=0x2B; kbytes[423]=0x2B;
  kbytes[424]=0x1D; kbytes[425]=0x33; kbytes[426]=0x9A; kbytes[427]=0x00; kbytes[428]=0x1F; kbytes[429]=0x84; kbytes[430]=0x02; kbytes[431]=0x01;
  kbytes[432]=0x1D; kbytes[433]=0x1D; kbytes[434]=0x68; kbytes[435]=0x36; kbytes[436]=0x04; kbytes[437]=0x15; kbytes[438]=0x04; kbytes[439]=0x1A;
  kbytes[440]=0xA3; kbytes[441]=0x00; kbytes[442]=0x11; kbytes[443]=0x2B; kbytes[444]=0x15; kbytes[445]=0x04; kbytes[446]=0x04; kbytes[447]=0x54;
  kbytes[448]=0x15; kbytes[449]=0x04; kbytes[450]=0x1D; kbytes[451]=0x60; kbytes[452]=0x36; kbytes[453]=0x04; kbytes[454]=0xA7; kbytes[455]=0xFF;
  kbytes[456]=0xEF; kbytes[457]=0x84; kbytes[458]=0x03; kbytes[459]=0x01; kbytes[460]=0xA7; kbytes[461]=0xFF; kbytes[462]=0xD6; kbytes[463]=0x1C;
  kbytes[464]=0xAC; kbytes[465]=0x00; kbytes[466]=0x00; kbytes[467]=0x00; kbytes[468]=0x02; kbytes[469]=0x00; kbytes[470]=0x1A; kbytes[471]=0x00;
  kbytes[472]=0x00; kbytes[473]=0x00; kbytes[474]=0x22; kbytes[475]=0x00; kbytes[476]=0x08; kbytes[477]=0x00; kbytes[478]=0x00; kbytes[479]=0x00;
  kbytes[480]=0x07; kbytes[481]=0x00; kbytes[482]=0x06; kbytes[483]=0x00; kbytes[484]=0x08; kbytes[485]=0x00; kbytes[486]=0x08; kbytes[487]=0x00;
  kbytes[488]=0x09; kbytes[489]=0x00; kbytes[490]=0x0F; kbytes[491]=0x00; kbytes[492]=0x0A; kbytes[493]=0x00; kbytes[494]=0x15; kbytes[495]=0x00;
  kbytes[496]=0x0B; kbytes[497]=0x00; kbytes[498]=0x18; kbytes[499]=0x00; kbytes[500]=0x0C; kbytes[501]=0x00; kbytes[502]=0x31; kbytes[503]=0x00;
  kbytes[504]=0x09; kbytes[505]=0x00; kbytes[506]=0x37; kbytes[507]=0x00; kbytes[508]=0x0F; kbytes[509]=0x00; kbytes[510]=0x1B; kbytes[511]=0x00;
  kbytes[512]=0x00; kbytes[513]=0x00; kbytes[514]=0x14; kbytes[515]=0x00; kbytes[516]=0x04; kbytes[517]=0xFE; kbytes[518]=0x00; kbytes[519]=0x0A;
  kbytes[520]=0x07; kbytes[521]=0x00; kbytes[522]=0x1C; kbytes[523]=0x01; kbytes[524]=0x01; kbytes[525]=0xFC; kbytes[526]=0x00; kbytes[527]=0x12;
  kbytes[528]=0x01; kbytes[529]=0xFA; kbytes[530]=0x00; kbytes[531]=0x13; kbytes[532]=0xFA; kbytes[533]=0x00; kbytes[534]=0x05; kbytes[535]=0x00;
  kbytes[536]=0x09; kbytes[537]=0x00; kbytes[538]=0x1E; kbytes[539]=0x00; kbytes[540]=0x1F; kbytes[541]=0x00; kbytes[542]=0x01; kbytes[543]=0x00;
  kbytes[544]=0x19; kbytes[545]=0x00; kbytes[546]=0x00; kbytes[547]=0x00; kbytes[548]=0x6D; kbytes[549]=0x00; kbytes[550]=0x03; kbytes[551]=0x00;
  kbytes[552]=0x02; kbytes[553]=0x00; kbytes[554]=0x00; kbytes[555]=0x00; kbytes[556]=0x31; kbytes[557]=0x10; kbytes[558]=0x0F; kbytes[559]=0xB8;
  kbytes[560]=0x00; kbytes[561]=0x07; kbytes[562]=0xB8; kbytes[563]=0x00; kbytes[564]=0x0D; kbytes[565]=0x10; kbytes[566]=0x14; kbytes[567]=0xB8;
  kbytes[568]=0x00; kbytes[569]=0x07; kbytes[570]=0xB8; kbytes[571]=0x00; kbytes[572]=0x13; kbytes[573]=0x11; kbytes[574]=0x03; kbytes[575]=0xE8;
  kbytes[576]=0xB8; kbytes[577]=0x00; kbytes[578]=0x16; kbytes[579]=0xB8; kbytes[580]=0x00; kbytes[581]=0x0D; kbytes[582]=0x03; kbytes[583]=0x3B;
  kbytes[584]=0x04; kbytes[585]=0x3C; kbytes[586]=0x1B; kbytes[587]=0x10; kbytes[588]=0x64; kbytes[589]=0xA3; kbytes[590]=0x00; kbytes[591]=0x0F;
  kbytes[592]=0x1A; kbytes[593]=0x1B; kbytes[594]=0x1B; kbytes[595]=0x68; kbytes[596]=0x60; kbytes[597]=0x3B; kbytes[598]=0x84; kbytes[599]=0x01;
  kbytes[600]=0x01; kbytes[601]=0xA7; kbytes[602]=0xFF; kbytes[603]=0xF1; kbytes[604]=0x1A; kbytes[605]=0xAC; kbytes[606]=0x00; kbytes[607]=0x00;
  kbytes[608]=0x00; kbytes[609]=0x02; kbytes[610]=0x00; kbytes[611]=0x1A; kbytes[612]=0x00; kbytes[613]=0x00; kbytes[614]=0x00; kbytes[615]=0x1A;
  kbytes[616]=0x00; kbytes[617]=0x06; kbytes[618]=0x00; kbytes[619]=0x00; kbytes[620]=0x00; kbytes[621]=0x12; kbytes[622]=0x00; kbytes[623]=0x08;
  kbytes[624]=0x00; kbytes[625]=0x13; kbytes[626]=0x00; kbytes[627]=0x10; kbytes[628]=0x00; kbytes[629]=0x14; kbytes[630]=0x00; kbytes[631]=0x19;
  kbytes[632]=0x00; kbytes[633]=0x15; kbytes[634]=0x00; kbytes[635]=0x1B; kbytes[636]=0x00; kbytes[637]=0x16; kbytes[638]=0x00; kbytes[639]=0x2F;
  kbytes[640]=0x00; kbytes[641]=0x17; kbytes[642]=0x00; kbytes[643]=0x1B; kbytes[644]=0x00; kbytes[645]=0x00; kbytes[646]=0x00; kbytes[647]=0x0A;
  kbytes[648]=0x00; kbytes[649]=0x02; kbytes[650]=0xFD; kbytes[651]=0x00; kbytes[652]=0x1D; kbytes[653]=0x01; kbytes[654]=0x01; kbytes[655]=0xFA;
  kbytes[656]=0x00; kbytes[657]=0x11; kbytes[658]=0x00; kbytes[659]=0x01; kbytes[660]=0x00; kbytes[661]=0x20; kbytes[662]=0x00; kbytes[663]=0x00;
  kbytes[664]=0x00; kbytes[665]=0x02; kbytes[666]=0x00; kbytes[667]=0x21;
DbgStrLn("HolyJVM v0.1: Java bytecode interpreter on TempleOS");
kbuf = kbytes;
klen = kbytes_len;
ParseClass();
DbgStrLn("HolyJVM: class parsed");
jvm_dbg = 0;
while (jvm_dbg < m_count) {
  Dbg2(CpUtf8(m_name[jvm_dbg]), CpUtf8(m_desc[jvm_dbg]));
  jvm_dbg++;
}
DbgInt(m_count);
DbgStrLn(" methods parsed");
I64 jvm_entry = FindMethodByName("run", "()I");
DbgInt(jvm_entry);
DbgStrLn(" = jvm_entry");
I64 jvm_res = 0;
if (jvm_entry < 0) {
  DbgErr1("no run()I found");
} else {
  jvm_res = ExecRun(jvm_entry, 0);
  DbgResult(jvm_res);
  // park so the supervisor's post-compile DocClear doesn't erase the output
  while (TRUE) Sleep(100);
}
