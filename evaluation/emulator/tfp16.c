/* tfp16.c -- batched TangramFP FP16 (1:p:q) dot-product emulator.
 *
 * Same semantics as kacy_f16_main() in sw/tangram16/c_src/kacy16.c (group mode
 * selection against the largest exponent in the group, products accumulated in
 * binary32), but operating on whole matrices and with selectable AC / Skip-BD
 * correction variants.
 */
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <omp.h>
#include <immintrin.h>

enum { AC_TRUNC = 0, AC_RTE_ORIG = 1, AC_RTE = 2, AC_MSB = 3 };
enum { ST_ZS = 0, ST_FULL, ST_SKIPBD, ST_AC, ST_SKIP, ST_OVF, ST_N };

typedef struct { uint16_t man; int8_t exp; int8_t flags; } op_t; /* flags: 1 zero/subnormal, 2 negative, 4 out of FP16 range */

static inline uint32_t as_uint(float f) { uint32_t u; memcpy(&u, &f, 4); return u; }

/* float_to_half() of fp16.c, without the saturation to 0x7FFF */
static inline op_t to_op(float x) {
    op_t o; uint32_t b = as_uint(x) + 0x00001000u;
    uint32_t e = (b & 0x7F800000u) >> 23, m = b & 0x007FFFFFu;
    o.flags = (b >> 31) ? 2 : 0;
    if (e > 142) { o.flags |= 4; o.man = 0; o.exp = 0; return o; }
    if (e > 112) { o.man = 0x400 | (m >> 13); o.exp = (int8_t)(e - 112); return o; }
    o.flags |= 1; o.man = 0; o.exp = 0; return o;      /* zero or subnormal: flushed */
}

/* IEEE round-to-nearest-even to binary16 and back (F16C); overflow saturates to the largest FP16 */
static inline float round16(float x) {
    float r = _cvtsh_ss(_cvtss_sh(x, _MM_FROUND_TO_NEAREST_INT | _MM_FROUND_NO_EXC));
    if (__builtin_isinf(r) && !__builtin_isinf(x)) r = x > 0 ? 65504.0f : -65504.0f;
    return r;
}

/* s >= g_thr2 selects Null mode; 11 in the original emulator (MAN_FULL) */
static int g_thr2 = 11;
void tfp_set_thr2(int t) { g_thr2 = t; }

static float scale[64];
static int scale_ok = 0;
static void init_scale(void) { for (int i = 0; i < 64; i++) scale[i] = ldexpf(1.0f, i - 50); scale_ok = 1; }

static inline uint32_t mul_core(uint32_t u, uint32_t v, int mode, int cut, int acv, int bdv) {
    const int p = 10 - cut, q = cut;
    uint32_t _u = u & 0x3FF, _v = v & 0x3FF;
    uint32_t a = _u >> q, c = _v >> q, b = _u & ((1u << q) - 1), d = _v & ((1u << q) - 1);
    uint32_t mb = b >> (q - 1), md = d >> (q - 1);
    uint32_t r = (1u << 20) + ((_u + _v) << 10);
    if (mode == ST_FULL) return r + ((a * c) << (2 * q)) + ((a * d + c * b) << q) + b * d;
    if (mode == ST_SKIPBD) {
        r += ((a * c) << (2 * q)) + ((a * d + c * b) << q);
        if (bdv) r += (mb & md) << (2 * q - 2);
        return r;
    }
    switch (acv) {                                      /* AC mode */
    case AC_RTE_ORIG: return r + (((a + mb) * (c + mb)) << (2 * q));
    case AC_RTE:      return r + (((a + mb) * (c + md)) << (2 * q));
    case AC_MSB:      return r + ((a * c) << (2 * q)) +
                             ((((a >> (p - 1)) & md) + ((c >> (p - 1)) & mb)) << (p + 2 * q - 2));
    default:          return r + ((a * c) << (2 * q));
    }
}

/* out[m*N+n] = sum_k W[m*K+k] * Xt[n*K+k], evaluated in groups of `chunk` MACs.
 * stats: ST_N counters. force_full: every non-zero product in Full mode (FP16 baseline).
 * acc16: the running sum is rounded to FP16 after every group (with chunk = 1: a chain of
 * FP16 fused MACs); otherwise it is kept in binary32 as in the original emulator. */
void tfp_matmul2(const float *W, const float *Xt, float *out, int M, int K, int N,
                 int chunk, int cut, int offset, int acv, int bdv, int force_full, int acc16,
                 long long *stats) {
    if (!scale_ok) init_scale();
    if (chunk <= 0 || chunk > K) chunk = K;
    op_t *w = (op_t *)__builtin_malloc((size_t)M * K * sizeof(op_t));
    op_t *x = (op_t *)__builtin_malloc((size_t)N * K * sizeof(op_t));
    #pragma omp parallel for schedule(static)
    for (long i = 0; i < (long)M * K; i++) w[i] = to_op(W[i]);
    #pragma omp parallel for schedule(static)
    for (long i = 0; i < (long)N * K; i++) x[i] = to_op(Xt[i]);
    const int thr1 = cut + offset, thr2 = g_thr2;
    long long tot[ST_N] = {0};
    #pragma omp parallel
    {
        long long st[ST_N] = {0};
        int ex[chunk];
        #pragma omp for schedule(dynamic, 1) collapse(2)
        for (int m = 0; m < M; m++) for (int n = 0; n < N; n++) {
            const op_t *wr = w + (size_t)m * K, *xr = x + (size_t)n * K;
            const float *Wf = W + (size_t)m * K, *Xf = Xt + (size_t)n * K;
            float sum = 0.0f;
            for (int k0 = 0; k0 < K; k0 += chunk) {
                int k1 = k0 + chunk > K ? K : k0 + chunk;
                op_t s = to_op(sum);
                int max_exp = (s.flags & 4) ? 31 : s.exp;   /* subnormal sum counts as exponent 0 */
                for (int k = k0; k < k1; k++) {
                    int ea = wr[k].exp + (wr[k].exp == 0), eb = xr[k].exp + (xr[k].exp == 0);
                    ex[k - k0] = ea + eb - 15;
                    if (max_exp <= ex[k - k0]) max_exp = ex[k - k0];
                }
                float c = 0.0f;
                for (int k = k0; k < k1; k++) {
                    int fl = wr[k].flags | xr[k].flags;
                    if (fl & 4) { st[ST_OVF]++; c += Wf[k] * Xf[k]; continue; }
                    if (fl & 1) { st[ST_ZS]++; continue; }
                    int diff = max_exp - ex[k - k0], mode;
                    if (force_full || diff == 0) mode = ST_FULL;
                    else if (diff < thr1) mode = ST_SKIPBD;
                    else if (diff < thr2) mode = ST_AC;
                    else mode = ST_SKIP;
                    st[mode]++;
                    if (mode == ST_SKIP) continue;
                    uint32_t pv = mul_core(wr[k].man, xr[k].man, mode, cut, acv, bdv);
                    float pf = (float)pv * scale[wr[k].exp + xr[k].exp];
                    c += ((wr[k].flags ^ xr[k].flags) & 2) ? -pf : pf;
                }
                sum = c + sum;
                if (acc16) sum = round16(sum);
            }
            out[(size_t)m * N + n] = sum;
        }
        #pragma omp critical
        for (int i = 0; i < ST_N; i++) tot[i] += st[i];
    }
    if (stats) for (int i = 0; i < ST_N; i++) stats[i] += tot[i];
    __builtin_free(w); __builtin_free(x);
}

void tfp_matmul(const float *W, const float *Xt, float *out, int M, int K, int N,
                int chunk, int cut, int offset, int acv, int bdv, int force_full, long long *stats) {
    tfp_matmul2(W, Xt, out, M, K, N, chunk, cut, offset, acv, bdv, force_full, 0, stats);
}

/* single product, for unit tests against kacy_fp16_mult() */
float tfp_mul1(float a, float b, int mode, int cut, int acv, int bdv) {
    if (!scale_ok) init_scale();
    op_t x = to_op(a), y = to_op(b);
    uint32_t pv = mul_core(x.man, y.man, mode, cut, acv, bdv);
    float pf = (float)pv * scale[x.exp + y.exp];
    return ((x.flags ^ y.flags) & 2) ? -pf : pf;
}
