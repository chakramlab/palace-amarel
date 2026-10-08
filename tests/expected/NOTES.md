# Smoke test: cylinder cavity (Palace shipped example)

**Why this run exists:** first-ever Palace solve on Amarel after the from-source Spack build.
Proves the binary + MPI launch + eigen solver + loss post-processing all work, against a
geometry with a closed-form answer.

**Result: PASS.**
- All 15 requested modes (18 found incl. degenerate partners) within +100…+400 ppm of the
  analytic TE/TM frequencies. Errors are all positive and small — the hex mesh's polygonal
  approximation of the curved wall makes the discrete cavity slightly stiffer; shrinks with
  refinement per the docs' convergence study. Not a bug.
- Q = 2500.000 on every mode = 1/tanδ (tanδ = 4e-4 fill). The energy-participation → Q
  pipeline is exact for a 100%-participation dielectric. This is the mechanism our whole loss
  program uses, so it matters more than the frequencies.
- Degenerate pairs agree to ~1e-5 relative.
- 8 ranks, 43 s wall.

**Build-path lessons (recorded in cluster/README.md and spack_bootstrap.sh):**
compute image lacks cmake + dev headers (login has them) → let spack build them; pin
target=x86_64_v3 for the heterogeneous `main` partition; `palace` is a launcher (uses -np),
don't wrap in mpirun.

**Next:** sim/benchmarks/cpw — our own geometry through Gmsh → Palace, compared to the SQDMetal
paper's CPW convergence numbers, then interface participation on.
