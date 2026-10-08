@echo off
rem Run the cylinder-cavity smoke test (submits a 1-minute job). Then 06_fetch_results.bat + check.
ssh amarel "cd /scratch/$USER/GitHub/palace-amarel && bash tests/smoke_cylinder.sh"
echo When the job has left the queue (04_status.bat), run 06_fetch_results.bat.
pause
