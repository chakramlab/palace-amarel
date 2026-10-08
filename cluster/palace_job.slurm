#!/bin/bash
#SBATCH --partition=main
#SBATCH --nodes=1
#SBATCH --ntasks=16
#SBATCH --cpus-per-task=1
#SBATCH --mem=64G
#SBATCH --time=04:00:00
#SBATCH --requeue
#SBATCH --exclude=halk0001,halk0002,halk0003,halk0004,halk0005,halk0006,halk0007,halk0008,halk0009,halk0010,halk0011,halk0012,halk0013,halk0014,halk0015,halk0016,halk0017,halk0018,halk0019,halk0020,halk0021,halk0022,halk0023,halk0024,halk0025,halk0026,halk0027,halk0028,halk0029,halk0030,halk0031,halk0032,halk0033,halk0034,halk0035,halk0036,halk0037,halk0038,halk0039,halk0040,halk0041,halk0042,halk0043,halk0044,halk0045,halk0046,halk0047,halk0048,halk0049,halk0050,halk0051,halk0052,halk0053,halk0054,halk0055,halk0056,halk0057,halk0058,halk0059,halk0060,halk0061,halk0062,halk0063,halk0064,halk0065,halk0066,halk0067,halk0068,halk0069,halk0070,halk0071,halk0072,halk0073,halk0074,halk0075,halk0076,halk0077,halk0078,halk0079,halk0080,halk0081,halk0082,halk0083,halk0084,halk0085,halk0086,halk0087,halk0088,halk0089,halk0090,halk0091,halk0092,halk0093,halk0094,halk0095,halk0096,halk0097,halk0098,halk0099,halk0100,halk0101,halk0102,halk0103,halk0104,halk0105,halk0106,halk0107,halk0108,halk0109,halk0110,halk0111,halk0112,halk0113,halk0114,halk0115,halk0116,halk0117,halk0118,halk0119,halk0120,halk0121,halk0122,halk0123,halk0124,halk0125,halk0126,halk0127,halk0128,halk0129,halk0130,halk0131,halk0132,halk0133,halk0134,halk0135,halk0136,halk0137,halk0138,halk0139,halk0140,halk0141,halk0142,halk0143,halk0144,halk0145,halk0146,halk0147,halk0148,halk0149,halk0150,halk0151,halk0152,halk0153,halk0154,halk0155,halk0156,halk0157,halk0158,halk0159,memk001,memk002,memk003,memk004
#SBATCH --job-name=palace
#SBATCH --output=/scratch/%u/logs/palace_%j.out

# Palace job template. Usage:
#   sbatch [--job-name=X --ntasks=N --mem=M --time=T --partition=P --output=/scratch/$USER/logs/X_%j.out] \
#          palace_job.slurm /absolute/path/to/config.json
# Sizing: ~55 GB RAM per million second-order tets; 50-100k cells per rank. CPU only (Palace is MPI code).
#
# The --exclude list is the halk*/memk* node family, which mounts /scratch through a delayed
# write-back layer (/scache): jobs there finish but their output reaches the login nodes ~2 h late
# (observed 2026-09-09/10; OARC ticket filed). The guard below catches any new offender.

HERE="$(cd "$(dirname "$(scontrol show job "$SLURM_JOB_ID" | grep -o 'Command=[^ ]*' | cut -d= -f2)")" && pwd)"
. "$HERE/env.sh"

# ---- scratch guard: if this node's /scratch is the delayed /scache view, record it and resubmit
BAD_NODES="$LOGS/bad_scratch_nodes.txt"
if df -P /scratch | tail -1 | grep -q "/scache$"; then
  me=$(hostname -s)
  echo "SCRATCH GUARD: /scratch is /scache on $me -- recording it and resubmitting this job" >&2
  touch "$BAD_NODES"; grep -qx "$me" "$BAD_NODES" || echo "$me" >> "$BAD_NODES"
  EXC=$( (grep -o "exclude=.*" "$0" | head -1 | cut -d= -f2 | tr "," "\n"; cat "$BAD_NODES") | sort -u | paste -sd, -)
  INFO=$(scontrol show job "$SLURM_JOB_ID")
  TL=$(echo "$INFO" | grep -o 'TimeLimit=[^ ]*' | head -1 | cut -d= -f2)
  MEM=$(echo "$INFO" | grep -o 'MinMemoryNode=[^ ]*' | head -1 | cut -d= -f2)
  sbatch --partition="$SLURM_JOB_PARTITION" --job-name="$SLURM_JOB_NAME" --ntasks="$SLURM_NTASKS" --nodes=1 \
         --mem="${MEM:-64G}" --time="${TL:-04:00:00}" --exclude="$EXC" \
         --output="$LOGS/${SLURM_JOB_NAME}_%j.out" "$0" "$@" >&2
  exit 0
fi

set -uo pipefail
CONFIG="${1:?usage: sbatch palace_job.slurm /abs/path/config.json}"
[ -f "$CONFIG" ] || { echo "config not found: $CONFIG" >&2; exit 2; }

. "$PREFIX/spack/share/spack/setup-env.sh"
spack load palace@"$PALACE_VERSION" openmpi

echo "palace: $(which palace)  version: $(palace --version 2>/dev/null | head -1)"
echo "config: $CONFIG  ranks: $SLURM_NTASKS  node: $(hostname -s)  start: $(date)"
cd "$(dirname "$CONFIG")"

# Call the binary under mpirun directly: the `palace` launcher writes a hostfile `mpi_nodes` into
# the working directory, so two jobs started from one folder clobber each other. Slurm-aware
# OpenMPI takes the allocation from the environment; no hostfile needed.
PALACE_BIN="$(dirname "$(which palace)")/palace-x86_64.bin"
mpirun -n "$SLURM_NTASKS" "$PALACE_BIN" "$(basename "$CONFIG")"
R=$?
echo "end: $(date)  exit: $R"
exit $R
