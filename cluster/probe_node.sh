#!/bin/bash
# Does a compute node mount /scratch normally, or through the delayed /scache layer?
# Usage: bash probe_node.sh <nodename>      (runs a 1-core, 1-minute job on that node)
set -euo pipefail
NODE="${1:?usage: probe_node.sh <node>}"
srun --partition=main --nodelist="$NODE" --ntasks=1 --time=00:02:00 --mem=1G \
  bash -c 'echo "$(hostname -s): $(df -P /scratch | tail -1 | awk "{print \$NF}")  ($(mount | grep -E " /scratch | /scache " | head -1))"'
echo "(/scratch = normal, /scache = delayed write-back: add the node to the exclude list / bad_scratch_nodes.txt)"
