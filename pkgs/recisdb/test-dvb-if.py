"""Exercise real dvb-sat.c functions with simulated frontend/SEC operations."""

import pathlib
import re
import shlex
import subprocess
import sys


def function(source, name):
    match = re.search(r"(?:static )?int " + name + r"\([^;]*?\)\n\{", source)
    if not match:
        raise ValueError(f"Cannot find upstream function {name}")
    start = match.start()
    pos = match.end()
    depth = 1
    while depth:
        depth += (source[pos] == "{") - (source[pos] == "}")
        pos += 1
    return source[start:pos]


PRELUDE = r"""
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define ARRAY_SIZE(x) (sizeof(x) / sizeof((x)[0]))
#define _(x) (x)
#define dvb_log(...) ((void)0)
#define dvb_logerr(...) (++errors)
#define CHECK(x) do { if (!(x)) { \
    fprintf(stderr, "line %d: %s\n", __LINE__, #x); exit(1); \
} } while (0)
enum { SYS_DVBS, SYS_DVBS2, SYS_TURBO, SYS_ISDBS, SYS_ISDBT };
enum { DTV_FREQUENCY, DTV_POLARIZATION };
enum dvb_sat_polarization {
    POLARIZATION_OFF, POLARIZATION_H, POLARIZATION_V, POLARIZATION_L, POLARIZATION_R
};
struct dvb_sat_lnb { const char *name; };
struct dvbsat_freqrange_priv {
    unsigned low, high, int_freq, rangeswitch;
    enum dvb_sat_polarization pol;
};
struct dvb_sat_lnb_priv {
    struct dvb_sat_lnb desc;
    struct dvbsat_freqrange_priv freqrange[4];
};
struct dvb_v5_fe_parms {
    unsigned current_sys, verbose, freq_bpf;
    const struct dvb_sat_lnb *lnb;
};
struct dvb_v5_fe_parms_priv {
    struct dvb_v5_fe_parms p;
    int freq_offset, high_band;
    uint32_t frequency, stream_id;
};
static unsigned errors, sec_calls;
static int sec_error;
static int dvb_fe_is_satellite(unsigned sys)
{
    return sys == SYS_DVBS || sys == SYS_DVBS2 || sys == SYS_TURBO || sys == SYS_ISDBS;
}
static int dvb_fe_retrieve_parm(struct dvb_v5_fe_parms *p, unsigned key, void *value)
{
    struct dvb_v5_fe_parms_priv *parms = (void *)p;
    *(uint32_t *)value = key == DTV_FREQUENCY ? parms->frequency : POLARIZATION_R;
    return 0;
}
static int dvb_fe_store_parm(struct dvb_v5_fe_parms *p, unsigned key, uint32_t value)
{
    CHECK(key == DTV_FREQUENCY);
    ((struct dvb_v5_fe_parms_priv *)p)->frequency = value;
    return 0;
}
static int dvbsat_diseqc_set_input(struct dvb_v5_fe_parms_priv *p, uint16_t t)
{
    (void)p; (void)t;
    sec_calls++;
    return sec_error;
}
"""

TESTS = r"""
static const struct dvb_sat_lnb_priv lnb = {
    .desc = { .name = "Japan 110BS/CS LNBf" },
    .freqrange = {{ 11710, 12751, 10678, 0, POLARIZATION_OFF }}
};

int main(void)
{
    /* Right/left BS and CS IF, including BS17 and the upper S3 channels. */
    const uint32_t frequencies[] = {
        1049480, 1356360, 1471440, 1613000, 2053000,
        2241660, 2471820, 2663620, 2726000, 2766000, 3206000
    };
    struct dvb_v5_fe_parms_priv parms = {0};
    /* Reproduce the reported 1356.36 MHz readback failure first. */
    parms.p.current_sys = SYS_ISDBS;
    parms.p.lnb = &lnb.desc;
    CHECK(dvb_sat_real_freq(&parms.p, 1356360) == 1356360);
    CHECK(errors == 0);
    for (unsigned with_lnb = 0; with_lnb < 2; with_lnb++) {
        parms.p.current_sys = SYS_ISDBS;
        parms.p.lnb = with_lnb ? &lnb.desc : NULL;
        for (unsigned i = 0; i < ARRAY_SIZE(frequencies); i++) {
            parms.frequency = frequencies[i];
            parms.stream_id = 0x4721;
            parms.freq_offset = 10678000;
            parms.high_band = 1;
            errors = sec_calls = 0;
            sec_error = -EIO; /* Even a device without SEC must support IF. */
            CHECK(dvb_sat_set_parms(&parms.p) == 0);
            CHECK(parms.frequency == frequencies[i]);
            CHECK(parms.stream_id == 0x4721);
            CHECK(parms.freq_offset == 0);
            CHECK(parms.high_band == 0);
            CHECK(sec_calls == 0 && errors == 0);
            CHECK(dvb_sat_real_freq(&parms.p, frequencies[i]) == (int)frequencies[i]);
            /* Stale state must not make readback convert IF to RF. */
            parms.freq_offset = 10678000;
            CHECK(dvb_sat_real_freq(&parms.p, frequencies[i]) == (int)frequencies[i]);
            CHECK(errors == 0);
        }
    }
    for (unsigned sys = SYS_DVBS; sys <= SYS_DVBS2; sys++) {
        parms.p.current_sys = sys;
        parms.p.lnb = &lnb.desc;
        parms.frequency = 12034360;
        parms.freq_offset = 0;
        errors = sec_calls = 0;
        sec_error = 0;
        CHECK(dvb_sat_set_parms(&parms.p) == 0);
        CHECK(parms.frequency == 1356360);
        CHECK(parms.freq_offset == 10678000);
        CHECK(sec_calls == 1 && errors == 0);
        CHECK(dvb_sat_real_freq(&parms.p, parms.frequency) == 12034360);
        CHECK(dvb_sat_real_freq(&parms.p, 9000000) == 0);
        CHECK(errors == 1);
        parms.frequency = 12034360;
        sec_error = -EIO;
        CHECK(dvb_sat_set_parms(&parms.p) == -EIO);
        parms.p.lnb = NULL;
        CHECK(dvb_sat_set_parms(&parms.p) == -EINVAL);
    }
    parms.p.current_sys = SYS_ISDBT;
    parms.p.lnb = &lnb.desc;
    CHECK(dvb_sat_real_freq(&parms.p, 473142857) == 473142857);
    puts("ISDB-S IF tune/readback and DVB-S/S2 RF/error regressions passed");
    return 0;
}
"""

source_path = pathlib.Path(sys.argv[1])
source = source_path.read_text()
code = PRELUDE + "\n".join(
    function(source, name)
    for name in ("dvb_sat_real_freq", "dvb_sat_get_freq", "dvb_sat_set_parms")
) + TESTS
# These are ordinary Nix build-directory outputs, cleaned by the builder.
c_path = pathlib.Path(source_path.stem + "-if-test.c")
exe = pathlib.Path(source_path.stem + "-if-test")
c_path.write_text(code)
# Upstream functions contain signed/unsigned comparisons; retain other warnings as errors.
subprocess.run(
    shlex.split(sys.argv[2]) + ["-std=c11", "-Wall", "-Wextra", "-Werror", "-Wno-sign-compare",
                              str(c_path), "-o", str(exe)], check=True
)
result = subprocess.run([str(exe.resolve())], capture_output=True, text=True)
print(result.stdout, end="")
print(result.stderr, end="", file=sys.stderr)
if "--expect-failure" in sys.argv:
    if result.returncode == 0:
        sys.exit("Unpatched baseline unexpectedly passed")
    print("Unpatched baseline rejected as expected")
elif result.returncode:
    sys.exit(result.returncode)
