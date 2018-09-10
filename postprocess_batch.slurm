#!/bin/tcsh
#
#SBATCH -J postproc_frcst
#SBATCH -n 8
#SBATCH -N 1
#SBATCH -t 08:00:00
#SBATCH -p dav
#SBATCH -o postproc_frcst.out.%J
#SBATCH -e postproc_frcst.out.%J
#SBATCH --account=P19010000
#SBATCH --mem 50G

#source /glade/u/apps/ch/opt/Lmod/7.3.14/lmod/7.3.14/init/tcsh 

module purge
module list
module load slurm
module load ncarenv
module load intel
module load python
module load ncl
module list

echo "Begin Post-Processing Job"

date

cd /glade/u/home/fvitt/cesm_forecast_scripts

# --- Determine time-stamp/file-ID string ---
setenv LID "`date +%Y%m%d-%H%M%S`"

./postprocess_cesm_outputs.py >&! /glade/scratch/fvitt/GEOS5_frcst_data/postprocess.log.$LID

echo "End Post-Processing Job"
date
exit 0
