#!/bin/bash
# Phase A -- run on a LOGIN node (needs internet, light CPU, ~10 min).
# Installs Spack under $PREFIX, registers the system compiler, pins the CPU target, concretizes
# the Palace spec and prefetches every source tarball so the compute-node build needs no network.
#
# Why it is split in two phases: login nodes have internet, cmake and dev headers; compute nodes
# have none of those (RHEL 9.6 compute image, checked 2026-09-09). So we download here and
# compile in a batch job, and we let Spack build cmake/openssl/python itself.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/env.sh"

cd "$PREFIX"
if [ ! -d spack ]; then
  echo "=== cloning spack ==="
  git clone --depth=1 https://github.com/spack/spack.git
fi
. spack/share/spack/setup-env.sh

echo "=== compilers ==="
spack compiler find                        # picks up the system gcc (11.5 on RHEL 9.6)

# Externals: ONLY what exists and is complete on the COMPUTE image. cmake is missing there and
# openssl/python lack dev headers, so Spack must build them (~20 min). Registering the login
# node's copies cost one failed build. --path /usr/bin keeps any conda copies out of the picture.
spack external find --not-buildable --path /usr/bin perl pkgconf || true

# The login node is a newer CPU than much of the `main` partition. Without a pinned target Spack
# tunes for the login CPU and the binary can die with "illegal instruction" on a compute node.
spack config add "packages:all:target:[$SPACK_TARGET]"

echo "=== concretize $PALACE_SPEC (first run also bootstraps clingo; a few minutes) ==="
spack spec -I $PALACE_SPEC > "$PREFIX/palace.spec.txt"
tail -5 "$PREFIX/palace.spec.txt"

echo "=== prefetch all sources ==="
spack fetch --dependencies $PALACE_SPEC

echo "=== bootstrap done. Next: sbatch $HERE/palace_build.sbatch ==="
