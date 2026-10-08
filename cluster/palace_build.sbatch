#!/bin/bash
#SBATCH --partition=main
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=06:00:00
#SBATCH --requeue
#SBATCH --job-name=palace-build
#SBATCH --output=/scratch/%u/logs/palace-build_%j.out

# Phase B -- a batch job (no network needed after spack_bootstrap.sh).
# Compiles Palace + dependencies. About 25 min on 16 cores for 0.16.0; allow up to 3 h.
set -uo pipefail
HERE="$(cd "$(dirname "$(scontrol show job "$SLURM_JOB_ID" | grep -o 'Command=[^ ]*' | cut -d= -f2)")" && pwd)"
. "$HERE/env.sh"
. "$PREFIX/spack/share/spack/setup-env.sh"

echo "building $PALACE_SPEC on $(hostname -s) with $SLURM_CPUS_PER_TASK cores"
spack install --fail-fast -j "$SLURM_CPUS_PER_TASK" $PALACE_SPEC
R=$?
if [ $R -eq 0 ]; then
  spack load palace
  echo "=== palace at: $(which palace) ==="
  palace --version || true
else
  echo "=== build FAILED (exit $R); read the spack error above ===" >&2
fi
exit $R        # propagate: never let an echo be the last statement
