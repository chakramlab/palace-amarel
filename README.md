# Palace on Amarel

Build, test and run [Palace](https://github.com/awslabs/palace) (AWS Labs' open-source 3D
finite-element electromagnetics solver) on Rutgers' Amarel cluster, from a Windows or Linux laptop,
for any project. Everything here was worked out while porting a superconducting-circuit loss
simulation workflow from Ansys HFSS to Palace (chakram lab, September 2026) and is written so that
a new student can go from "I have an Amarel account" to "my first eigenmode solved and checked"
in an afternoon, most of which is waiting for the build.

Nothing in this repo is specific to one person: paths use your NetID (`$USER` on the cluster),
and the scripts refuse to run if they cannot work out where they are.

Contents
- [1. What you get](#1-what-you-get)
- [2. Before you start](#2-before-you-start)
- [3. Amarel facts that matter](#3-amarel-facts-that-matter)
- [4. Install, step by step](#4-install-step-by-step)
- [5. The smoke test and its expected result](#5-the-smoke-test-and-its-expected-result)
- [6. Running your own simulation](#6-running-your-own-simulation)
- [7. Meshing with Gmsh and looking at fields with ParaView](#7-meshing-with-gmsh-and-looking-at-fields-with-paraview)
- [8. Moving data and watching jobs from the laptop](#8-moving-data-and-watching-jobs-from-the-laptop)
- [9. Gotchas, each of which cost real time](#9-gotchas-each-of-which-cost-real-time)
- [10. Updating Palace](#10-updating-palace)
- [11. Troubleshooting](#11-troubleshooting)

---

## 1. What you get

| path | what |
|---|---|
| `cluster/env.sh` | the one place paths are defined (`/scratch/$USER/...`); every script sources it |
| `cluster/spack_bootstrap.sh` | phase A of the build, on a login node: installs Spack, pins the CPU target, prefetches all sources |
| `cluster/palace_build.sbatch` | phase B, a batch job: compiles Palace and its ~40 dependencies (about 25 min on 16 cores) |
| `cluster/palace_job.slurm` | the job template you submit every solve with; runs the solver under MPI and protects you from a known cluster quirk |
| `cluster/setup_gmsh_env.sh` | installs Miniconda in your scratch and a `mesh` environment with Gmsh, numpy, scipy |
| `cluster/setup_paraview.sh` | installs the headless ParaView binary for rendering fields on the cluster |
| `cluster/probe_node.sh` | checks whether a compute node mounts scratch normally (see 9.1) |
| `tests/smoke_cylinder.sh` | solves Palace's shipped cylinder-cavity example on the cluster |
| `tests/check_cylinder.py` | compares the result with the closed-form answer and prints PASS / FAIL |
| `tests/expected/` | our reference result from 2026-09-09 (frequencies, energies, job log, figures) |
| `windows/*.bat`, `windows/*.ps1` | one-click helpers for Windows laptops: VPN check, SSH setup, upload, build, status, smoke test, fetch |

## 2. Before you start

You need:

1. **An Amarel account** (your NetID). Request one through OARC (Office of Advanced Research
   Computing), https://oarc.rutgers.edu. Support: help@oarc.rutgers.edu.
2. **The Rutgers VPN** (Cisco AnyConnect). `amarel.rutgers.edu` only resolves through the DNS the
   VPN provides. If your laptop says *Could not resolve hostname* while the rest of the internet
   works, the VPN has dropped; nothing on the cluster is wrong. `windows\00_check_vpn.bat` tests
   exactly this.
3. **An SSH key and a host alias.** `windows\01_setup_ssh.ps1` creates a key if you have none, adds
   a block to `~/.ssh/config` so that `ssh amarel` just works, and prints the one command you run
   yourself to install the public key on the cluster (it asks for your password; the scripts never
   handle passwords). On Linux/macOS do the same by hand:
   ```
   Host amarel
     HostName amarel.rutgers.edu
     User <netid>
     IdentityFile ~/.ssh/id_ed25519_amarel
     ServerAliveInterval 60
   ```
4. **On Windows, Git for Windows** (gives you Git Bash, `ssh`, `scp`, `tar`). Note that `rsync` is
   not in Git Bash; the scripts use `tar` over `ssh` instead.
5. Optionally **ParaView 6.1.1 on the laptop** (same version as the cluster binary, which matters
   only if you ever run ParaView in client–server mode).

## 3. Amarel facts that matter

Checked September 2026; re-check after cluster maintenance.

- **OS and compilers.** RHEL 9.6 with system gcc 11.5 and cmake 3.26. The `module` tree is a
  legacy, pre-upgrade set (gcc ≤ 5.4, OpenMPI 2.1). Do not use it; the system compiler is newer.
- **Login image ≠ compute image.** Login nodes have internet access, cmake and development
  headers. Compute nodes have none of these. So: download and configure on a login node, compile
  in a batch job, and let Spack build cmake, OpenSSL and Python itself rather than registering the
  login node's copies as "external" (that mistake cost one failed build).
- **Partitions.** `main` (CPU, what Palace needs; Palace is MPI code, no GPU) and `mem` (large
  memory, used for a 400 GB run). `main` mixes CPU generations from Skylake to Emerald Rapids;
  a binary tuned for the login node's CPU can crash with "illegal instruction" on an older
  compute node. The bootstrap pins Spack's target to `x86_64_v3` (AVX2), which runs everywhere.
- **Slurm 23.02**, QOS submit cap around 200 tasks, queue wait anywhere from a minute to hours.
  Use `--requeue`.
- **Scratch.** `/scratch/$USER` is the large, not-backed-up working disk. Convention used here:
  `/scratch/$USER/quantum/` for the toolchain, `/scratch/$USER/logs/` for every job's output,
  `/scratch/$USER/GitHub/<repo>` for project clones, `/scratch/$USER/miniconda3` for conda.
- **Some nodes mount scratch through a delayed layer** (`/scache`). Jobs on them finish normally
  but their output appears on the login nodes about two hours later. See 9.1; the job template
  defends against it.
- **SSH sessions get reset** after a few minutes of silence. Anything longer than two minutes must
  be detached (`nohup ... &`) or run as a batch job; keep `ServerAliveInterval 60` in your config.

## 4. Install, step by step

Total wall time about an hour, almost all of it the batch build. From a Windows laptop the
numbered `.bat` files do each step; the commands they run are shown here so Linux/macOS users (and
curious Windows users) can run them by hand.

**Step 0. Get this repo onto the cluster.** Either clone it there (after it is on GitHub):
```
ssh amarel 'mkdir -p /scratch/$USER/GitHub && cd /scratch/$USER/GitHub && git clone https://github.com/chakramlab/palace-amarel.git'
```
or copy your local checkout (`windows\02_upload_and_bootstrap.bat` does this with `scp -r`).

**Step 1. Phase A: bootstrap Spack and fetch sources (login node, ~10 min).**
```
ssh amarel 'cd /scratch/$USER/GitHub/palace-amarel && nohup bash cluster/spack_bootstrap.sh > /scratch/$USER/logs/spack_bootstrap.log 2>&1 &'
```
What it does: clones Spack into `/scratch/$USER/quantum/spack`, lets Spack find the system gcc,
registers only `perl` and `pkgconf` as externals (the only things complete on the compute image),
pins the CPU target, concretizes the spec `palace ^openmpi schedulers=slurm +legacylaunchers`,
and downloads every source tarball so the compute node needs no network. Watch
`/scratch/$USER/logs/spack_bootstrap.log`; it ends with "bootstrap done".

**Step 2. Phase B: compile (batch job, ~25 min on 16 cores; allow up to 3 h).**
```
ssh amarel 'cd /scratch/$USER/GitHub/palace-amarel && sbatch cluster/palace_build.sbatch'
```
Log: `/scratch/$USER/logs/palace-build_<jobid>.out`. Success looks like
`=== palace at: /scratch/<you>/quantum/spack/.../bin/palace ===` followed by a version string.
`windows\04_status.bat` shows the queue and the tail of the newest build log.

**Step 3. Gmsh environment (login node, ~5 min).** Only needed if you will generate meshes on
the cluster (you can also mesh on the laptop; Gmsh is pip-installable).
```
ssh amarel 'cd /scratch/$USER/GitHub/palace-amarel && bash cluster/setup_gmsh_env.sh'
```
Installs Miniconda under `/scratch/$USER/miniconda3` if absent and creates env `mesh` with
Gmsh (conda-forge `python-gmsh`), numpy and scipy. Use it with
`source /scratch/$USER/miniconda3/etc/profile.d/conda.sh && conda activate mesh`.

**Step 4. ParaView (login node, ~2 min).** Only needed to render fields on the cluster.
```
ssh amarel 'cd /scratch/$USER/GitHub/palace-amarel && bash cluster/setup_paraview.sh'
```
Downloads Kitware's Linux binary (6.1.1, MPI, Python 3.12) to `/scratch/$USER/quantum/paraview/`.

**Step 5. Smoke test.** Section 5.

## 5. The smoke test and its expected result

Palace ships worked examples. The cylinder cavity is a closed PEC cylinder (radius 2.74 cm,
height 5.48 cm) filled with a dielectric of loss tangent 4e-4, so every mode has a closed-form
frequency and every mode's Q must equal 1/tanδ = 2500 exactly. It exercises the binary, MPI
launch, the eigen-solver and the loss post-processing in 43 seconds on 8 cores.

```
ssh amarel 'cd /scratch/$USER/GitHub/palace-amarel && bash tests/smoke_cylinder.sh'
```
This checks out the Palace source at the installed version into `/scratch/$USER/quantum/palace-src`,
copies `examples/cylinder` to `/scratch/$USER/palace-tests/cylinder/`, submits it through the job
template, and prints the job id. When the job is done (`squeue -u $USER` is empty for it):
```
ssh amarel 'cd /scratch/$USER/GitHub/palace-amarel && source /scratch/$USER/miniconda3/etc/profile.d/conda.sh && conda activate mesh && python tests/check_cylinder.py /scratch/$USER/palace-tests/cylinder/postpro/cavity_pec'
```
or fetch the `postpro` folder and run the check on the laptop (`windows\06_fetch_results.bat`
then `python tests\check_cylinder.py <folder>`; needs numpy).

**Expected** (our run, 2026-09-09, job 61334332, 8 ranks, 43 s; files in `tests/expected/`):
every mode within +100 to +400 ppm of the analytic TE/TM frequencies (all errors positive and
small: the straight-sided mesh makes the curved cavity slightly stiffer, and the error shrinks
with refinement), every Q equal to 2500.000, degenerate pairs equal to 1e-5. The checker passes
if all frequencies are within 0.1 % and all Q within 0.1 % of 2500.

| mode | analytic (GHz) | Palace (GHz) | error (ppm) | Q |
|---|---|---|---|---|
| TM010 | 2.903636 | 2.904770 | +390 | 2500.000 |
| TE111 (×2) | 2.922197 | 2.922855 | +225 | 2500.000 |
| TM011 | 3.468175 | 3.469124 | +274 | 2500.000 |
| TE211 (×2) | 4.146882 | 4.148170 | +311 | 2500.000 |
| TE112 (×2) | 4.396663 | 4.397103 | +100 | 2500.000 |
| … 18 modes to 5.42 GHz, all +100…+400 ppm, all Q = 2500.000 | | | | |

(`python tests/check_cylinder.py tests/expected` reproduces this table from our stored `eig.csv`.)

If your numbers match to this level the install is good.

## 6. Running your own simulation

A Palace run is a mesh file plus a JSON configuration. Keep both in a folder of your own under
`/scratch/$USER/`; the job template `cd`s into the config's folder and writes results to the
`Output` path named in the config (relative paths are relative to that folder).

```
ssh amarel 'cd /scratch/$USER/myproject && sbatch --job-name=mysim --ntasks=16 --mem=64G --time=02:00:00 \
   --output=/scratch/$USER/logs/mysim_%j.out /scratch/$USER/GitHub/palace-amarel/cluster/palace_job.slurm /scratch/$USER/myproject/config.json'
```

Sizing rules from experience with second-order elements:
- **Memory: about 55 GB per million tetrahedra.** A 1.4 M-cell eigenmode fits in 100 GB; a
  7.7 M-cell run needed 408 GB and the `mem` partition; a 3.3 M-cell attempt died at 200 GB.
- **Time:** a 1.4 M-cell eigenmode with 4 modes, 14 minutes on 40 cores; 0.6–0.85 M cells with 25
  modes, 45–60 minutes on 16 cores; a 2.5D electrostatic section of 200 k prisms, 20 seconds to a
  few minutes on 8 cores.
- **Ranks:** 50–100 k cells per MPI rank is a good range. More ranks than that stops helping.
- Always `palace --dry-run config.json` before submitting (from a shell that has done
  `spack load palace`); Palace's schema is strict and a misspelt key is rejected at start,
  cheaply, instead of after twenty minutes in the queue.

Mesh format: **MSH 2.2** (`Mesh.MshFileVersion = 2.2` in Gmsh). Palace's mesh library does not
read MSH 4.1. Write ASCII unless the file is huge.

## 7. Meshing with Gmsh and looking at fields with ParaView

**Gmsh** (Python API) in the `mesh` conda environment, or on the laptop. Pattern that works: one
Python script draws the geometry, tags physical groups, sets element sizes with `Distance` +
`Threshold` fields, writes the `.msh` and writes the Palace JSON with the matching attribute
numbers, so the two can never drift apart. Lessons: refine around edges and points, never whole
surfaces (a surface-keyed refinement produced 5 million cells for nothing); classify boundary
faces by adjacency or by the CAD operation's output map, never by centroid; a `Threshold` field
inside `Min` returns its SizeMax everywhere beyond DistMax, so SizeMax must be the far-field size;
use `Mesh.Algorithm = 5` (Delaunay) for extreme size gradations, `Mesh.Algorithm3D = 10` (HXT) for
speed on smooth geometry.

**ParaView** headless on the cluster, so the gigabytes of field files never travel:
```
PV=/scratch/$USER/quantum/paraview/ParaView-6.1.1-MPI-Linux-Python3.12-x86_64
$PV/bin/pvbatch --force-offscreen-rendering my_render_script.py <postpro>/paraview/eigenmode/eigenmode.pvd <outdir>
```
Each time step in the `.pvd` is one mode. Set the camera after the first `Render()` or ParaView
resets your view. A pattern that worked well: use `ResampleToImage` to sample |E| on a few planes
into small numpy arrays, copy those down (megabytes), and draw annotated figures on the laptop
with matplotlib. For interactive use, `pvserver` on a compute node plus an SSH tunnel to the
laptop's ParaView of the same version.

## 8. Moving data and watching jobs from the laptop

- **Code to the cluster:** `git push` from the laptop, `git pull` on the cluster. Keep the cluster
  copy a real clone (an SSH deploy key for the repo in `~/.ssh` on the cluster, with a
  `Host github.com` block in the cluster's `~/.ssh/config`).
- **Results to the laptop:** stream `tar` over `ssh`; it is far faster than `scp` of a tree and
  needs no `rsync`:
  ```
  ssh amarel 'cd /scratch/$USER/myproject/postpro && tar czf - run1 --exclude=paraview' | tar xzf - -C results/
  ```
  Exclude the `paraview/` folders unless you really want gigabytes.
- **Watching:** poll `squeue -h -j <jobid>` every few minutes from a background loop; when the job
  leaves the queue, read the log. Grep the log for `Error|Killed|OOM|DUE TO TIME` but not for the
  bare word "Error": Palace's result table header contains "Error (Bkwd.)".
- **Exit codes:** in any script that chains jobs, end with `wait $PID; R=$?; exit $R`. A trailing
  `echo` resets `$?` and an `afterok` dependency sails past a failed job.

## 9. Gotchas, each of which cost real time

1. **The `/scache` nodes.** The whole `halk*` and `memk*` node family mounts `/scratch` through a
   write-back layer. Jobs complete, but their logs and outputs reach the login nodes about two
   hours later. Watchers see "no output" and collectors fail. The job template excludes all 163 of
   them (list as of 2026-09-10) and has a guard: if a job lands on a node where `df /scratch` shows
   `/scache`, it records the node in `/scratch/$USER/logs/bad_scratch_nodes.txt` and resubmits
   itself with the node added to the exclusion. `cluster/probe_node.sh <node>` tests a node. An
   OARC ticket about this was filed on 2026-09-09.
2. **The `palace` launcher writes a hostfile into the current directory.** Two jobs started from
   the same folder clobber it ("All nodes ... already filled"). The template calls the binary
   directly: `mpirun -n $SLURM_NTASKS palace-x86_64.bin config.json`. Slurm-aware OpenMPI takes
   the allocation from the environment.
3. **`spack load` breaks Slurm commands in that shell** (`sbatch`/`squeue` fail with "DNS SRV
   lookup failed"). Submit from a clean shell; load Spack only inside job scripts or for a dry run.
4. **Compute nodes lack cmake and dev headers.** Never register them as externals; let Spack build them.
5. **Pin the CPU target** (`x86_64_v3`), or binaries built on the login node can hit "illegal
   instruction" on older compute nodes.
6. **Palace's JSON schema is strict.** No `_comment` keys, no unknown fields. Dry-run first.
7. **Electrostatic terminals are not driven at 1 V.** Read `terminal-V.csv` and divide energies by
   V² before combining with the capacitance matrix.
8. **Palace writes VTU files stamped version "2.2"**, which `meshio` refuses. ParaView reads them;
   if you must use meshio, patch the stamp to "1.0" in memory (identical payload).
9. **Long SSH sessions reset.** Detach anything over two minutes.
10. **VPN drop looks like DNS failure.** See 2.2.
11. **Never move or rename folders that running jobs read.** Drain or `scancel` first.

## 10. Updating Palace

Edit the version in `cluster/env.sh` (`PALACE_SPEC`, e.g. `palace@0.17.0`), rerun phase A and
phase B. Spack keeps the old install; `spack load palace@0.16.0` still works. The smoke test is the
regression test: run it after every update and compare with `tests/expected/`.

## 11. Troubleshooting

| symptom | cause | fix |
|---|---|---|
| `Could not resolve hostname amarel.rutgers.edu` | VPN dropped | reconnect the VPN |
| build job dies in seconds, "externals" in the log | an external in `packages.yaml` is missing on the compute image | remove it; let Spack build it |
| `Illegal instruction` at solve start | binary built for the login CPU | confirm `packages:all:target:[x86_64_v3]` and rebuild |
| job finished, no output files | landed on a `/scache` node | wait two hours, or check `bad_scratch_nodes.txt`; the template should have resubmitted |
| `All nodes ... already filled` | two jobs sharing a hostfile | use the template (direct `mpirun`) |
| `sbatch: error: ... DNS SRV lookup failed` | `spack load` in this shell | open a new shell |
| Palace exits at start with a schema error | unknown key in the JSON | `palace --dry-run` and read the message |
| out of memory | mesh too big for the request | 55 GB per million cells; use `--mem` accordingly or the `mem` partition |
| `Error` grep fires on a healthy run | matched the result-table header | grep for `Error:` / `Killed` / `OOM` instead |

---

Maintained in the chakram lab. Issues and improvements welcome; if you add a gotcha, add the date
and what it cost.
