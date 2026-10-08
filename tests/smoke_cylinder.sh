#!/bin/bash
# Smoke test: Palace's shipped cylinder-cavity eigenmode example, submitted through our template.
# Run on a login node after the build. Then run check_cylinder.py on the postpro folder.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../cluster/env.sh"

# Palace source at the installed version (for the examples)
if [ ! -d "$PREFIX/palace-src" ]; then
  git clone --depth=1 --branch "v$PALACE_VERSION" https://github.com/awslabs/palace.git "$PREFIX/palace-src"
fi
EX="$PREFIX/palace-src/examples/cylinder"
[ -f "$EX/cavity_pec.json" ] || { echo "example not found at $EX (example names drift between versions: ls $PREFIX/palace-src/examples)"; exit 2; }

RUN="$SCRATCH/palace-tests/cylinder"
mkdir -p "$RUN"; cp -r "$EX"/. "$RUN"/
# mesh path in the config is relative to the example folder; it comes along with the copy
JOB=$(sbatch --job-name=smoke-cylinder --ntasks=8 --mem=16G --time=00:20:00 \
      --output="$LOGS/smoke-cylinder_%j.out" "$HERE/../cluster/palace_job.slurm" "$RUN/cavity_pec.json" | awk '{print $NF}')
echo "submitted job $JOB"
echo "when it finishes (squeue -j $JOB is empty):"
echo "  log:    $LOGS/smoke-cylinder_$JOB.out"
echo "  check:  python $HERE/check_cylinder.py $RUN/postpro/cavity_pec"
