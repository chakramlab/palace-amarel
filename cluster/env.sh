# Paths and versions for Palace on Amarel. Sourced by every script in cluster/ and tests/.
# Everything lives under your scratch; nothing here is specific to one person.
set -u
: "${USER:?USER is not set}"
export SCRATCH="/scratch/$USER"
export PREFIX="$SCRATCH/quantum"                 # toolchain: spack, palace source, paraview
export LOGS="$SCRATCH/logs"                      # every job's stdout/stderr
export CONDA_ROOT="$SCRATCH/miniconda3"
export MESH_ENV="mesh"
export PALACE_VERSION="0.16.0"                   # bump here, then rerun phase A + B (README section 10)
export PALACE_SPEC="palace@$PALACE_VERSION ^openmpi schedulers=slurm +legacylaunchers"
export SPACK_TARGET="x86_64_v3"                  # AVX2: runs on every CPU generation in `main`
export PARAVIEW_VERSION="6.1.1"
export PARAVIEW_TARBALL="ParaView-6.1.1-MPI-Linux-Python3.12-x86_64.tar.gz"
export PARAVIEW_URL="https://www.paraview.org/paraview-downloads/download.php?submit=Download&version=v6.1&type=binary&os=Linux&downloadFile=$PARAVIEW_TARBALL"
export PV="$PREFIX/paraview/${PARAVIEW_TARBALL%.tar.gz}"
mkdir -p "$PREFIX" "$LOGS"
