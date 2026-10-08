@echo off
rem Phase B: submit the Palace compile as a batch job (about 25 minutes on 16 cores).
ssh amarel "tail -2 /scratch/$USER/logs/spack_bootstrap.log 2>/dev/null | grep -q 'bootstrap done' || { echo 'phase A has not finished (see spack_bootstrap.log)'; exit 1; }; cd /scratch/$USER/GitHub/palace-amarel && sbatch cluster/palace_build.sbatch"
echo Watch with 04_status.bat. Success ends with "=== palace at: ... ===" and a version line.
pause
