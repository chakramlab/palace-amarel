"""Check a Palace cylinder-cavity eigenmode result against the closed-form answer.

The shipped example (examples/cylinder/cavity_pec.json, Palace 0.16) is a PEC cylinder of radius
a = 2.74 cm and height d = 5.48 cm filled with a dielectric (eps_r = 2.08, tan delta = 4e-4).
Analytic frequencies: TM_nmp: f = c/(2 pi sqrt(eps_r)) * sqrt((x_nm/a)^2 + (p pi/d)^2) with x_nm the
m-th zero of J_n; TE_nmp the same with the zeros of J_n' and p >= 1. Every mode's Q must be
1/tan delta = 2500 because the dielectric fills the cavity (participation 1).

Usage: python check_cylinder.py <postpro folder containing eig.csv> [--tol-ppm 1000] [--qtol 1e-3]
Exit code 0 = PASS, 1 = FAIL. Needs numpy only (scipy if available, for the Bessel zeros; otherwise
a built-in table of the first zeros is used).
"""
import argparse
import csv
import pathlib
import sys

import numpy as np

C = 299792458.0
A, D, EPS_R, TAND = 0.0274, 0.0548, 2.08, 4e-4

# zeros of J_n (TM) and J_n' (TE) for n = 0..3, first 3 each (scipy values)
JZ = {0: [2.404826, 5.520078, 8.653728], 1: [3.831706, 7.015587, 10.173468], 2: [5.135622, 8.417244, 11.619841], 3: [6.380162, 9.761023, 13.015201]}
JPZ = {0: [3.831706, 7.015587, 10.173468], 1: [1.841184, 5.331443, 8.536316], 2: [3.054237, 6.706133, 9.969468], 3: [4.201189, 8.015237, 11.345924]}
try:
    from scipy.special import jn_zeros, jnp_zeros
    JZ = {n: list(jn_zeros(n, 3)) for n in range(4)}; JPZ = {n: list(jnp_zeros(n, 3)) for n in range(4)}
except ImportError:
    pass


def analytic(fmax_ghz=8.0):
    modes = []
    for n in range(4):
        for m, x in enumerate(JZ[n], 1):
            for p in range(0, 4):
                f = C / (2 * np.pi * np.sqrt(EPS_R)) * np.sqrt((x / A) ** 2 + (p * np.pi / D) ** 2) / 1e9
                if f < fmax_ghz: modes.append((f, f"TM{n}{m}{p}", 2 if n else 1))
        for m, x in enumerate(JPZ[n], 1):
            for p in range(1, 4):
                f = C / (2 * np.pi * np.sqrt(EPS_R)) * np.sqrt((x / A) ** 2 + (p * np.pi / D) ** 2) / 1e9
                if f < fmax_ghz: modes.append((f, f"TE{n}{m}{p}", 2 if n else 1))
    return sorted(modes)


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("postpro"); ap.add_argument("--tol-ppm", type=float, default=1000.0); ap.add_argument("--qtol", type=float, default=1e-3)
    a = ap.parse_args(); d = pathlib.Path(a.postpro)
    rows = [r for r in csv.reader(open(d / "eig.csv")) if r and r[0].strip() and not r[0].strip().startswith("m")]
    f_pal = np.array([float(r[1]) for r in rows]); q_pal = np.array([float(r[3]) for r in rows])
    ref = analytic(f_pal.max() * 1.02)
    # expand degeneracies so each computed mode has a partner
    ref_f = []; ref_n = []
    for f, name, mult in ref:
        for _ in range(mult): ref_f.append(f); ref_n.append(name)
    ref_f = np.array(ref_f)
    ok = True
    print(f"{'m':>3} {'Palace GHz':>11} {'analytic GHz':>13} {'mode':>7} {'err ppm':>9} {'Q':>10}")
    used = set()
    for i, (f, q) in enumerate(zip(f_pal, q_pal), 1):
        cand = [j for j in np.argsort(abs(ref_f - f)) if j not in used]
        j = cand[0]; used.add(j)
        ppm = 1e6 * (f - ref_f[j]) / ref_f[j]
        good = abs(ppm) < a.tol_ppm and abs(q * TAND - 1) < a.qtol
        ok &= good
        print(f"{i:3d} {f:11.6f} {ref_f[j]:13.6f} {ref_n[j]:>7} {ppm:9.0f} {q:10.3f} {'' if good else '  <-- FAIL'}")
    print(f"\n{len(f_pal)} modes; frequency tolerance {a.tol_ppm:.0f} ppm; Q must be 1/tan delta = {1/TAND:.0f} within {100*a.qtol:.2f} %")
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
