@echo off
rem Queue state and the tail of the most recent logs.
ssh amarel "echo '--- your jobs:'; squeue -u $USER -o '%%.10i %%.20j %%.9T %%.10M %%.6D %%R'; echo; echo '--- spack bootstrap log (last 3 lines):'; tail -3 /scratch/$USER/logs/spack_bootstrap.log 2>/dev/null; echo; echo '--- newest palace-build log (last 5 lines):'; ls -t /scratch/$USER/logs/palace-build_*.out 2>/dev/null | head -1 | xargs -r tail -5; echo; echo '--- newest smoke-cylinder log (last 5 lines):'; ls -t /scratch/$USER/logs/smoke-cylinder_*.out 2>/dev/null | head -1 | xargs -r tail -5"
pause
