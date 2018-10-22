#! /usr/bin/env python
from subprocess import call, check_output
from datetime import datetime, timedelta
import os
from scripts_info import date, cesm_case, met_root_dir, scratch_dir, scripts_dir

def make_plots():
    yyyymmdd = date.strftime("%Y%m%d")
    output_dir = met_root_dir+'/'+yyyymmdd+'/model_files/'
    plots_dir = met_root_dir+'/'+yyyymmdd+'/plots/'

    cmd = ['mkdir','-p',plots_dir]

    print cmd
    stat = call(cmd)
    print ' stat = ',stat
    if not stat == 0 : return False

    arg1 = 'dir_output=\"'+output_dir+'\"'
    arg2 = 'dir_plot=\"'+plots_dir+'\"'
    arg3 = 'case_name=\"'+cesm_case+'\"'

    cmd = 'ncl \'' +arg1+'\' \''+arg2+'\' \''+arg3+'\' '+scripts_dir+'/plotting/plot_surface_values_trop.ncl > /glade/scratch/fvitt/GEOS5_frcst_data/plotting.log.'+yyyymmdd
    print 'cmd = ',cmd
    output = check_output(cmd, shell=True)
    print output

    cmd = 'touch '+ plots_dir+'/.ready_for_xfer'
    print cmd
    stat = os.system(cmd)
    if not stat == 0 : return False

    return True

def submit_export_job():
    cmd = 'sbatch '+scripts_dir+'/export_data_batch'
    print 'cmd='+cmd
    stat = os.system(cmd)
    if not stat == 0 : return False
    return True

def export_plots():
    
    yyyymmdd = date.strftime("%Y%m%d")
    plots_dir = met_root_dir+'/'+yyyymmdd+'/plots'

    species = ['BC','CLOX','CO','DUST','EXTINCTdn','NOX','O3','SO2','SO4','SSALT']
    basedir = 'modeling2.acom.ucar.edu:/net/nitrogen.acom.ucar.edu/ur/fvitt/waccm_forecast_output/'
    for sp in species:
        cmd = 'scp '+plots_dir+'/'+cesm_case+'*_'+sp+'_*' +' '+basedir+sp+'_plots'
        print 'cmd='+cmd
        stat = os.system(cmd)
        if not stat == 0 : return False

    return True

def export_history():

    yyyymmdd = date.strftime("%Y%m%d")
    hist_dir = met_root_dir+'/'+yyyymmdd+'/model_files'

#  cp to modeling2:/amadeus-data/emmons/web/mz4_output/waccm

    dist_loc = 'modeling2.acom.ucar.edu:/amadeus-data/emmons/web/mz4_output/waccm/'
    cmd = 'scp '+ hist_dir +'/*cam.h3*nc '+ dist_loc

    print 'cmd='+cmd
    stat = os.system(cmd)
    if not stat == 0 : return False

    return True

def save_output(restart_yyyymmdd):

    yyyymmdd = date.strftime("%Y%m%d")

    data_dir = met_root_dir
    run_dir = scratch_dir+cesm_case+'/run'

    output_arc = data_dir+'/'+yyyymmdd+'/model_files'

    cmd = ['mkdir','-p',output_arc]

    print cmd

    stat = call(cmd)
    if not stat == 0 : return False

  # copy namelists and model output to safe place

    cmd = 'mv ' + run_dir+'/*cam.h*.nc ' + output_arc 
    print cmd
    stat = os.system(cmd)
    if not stat == 0 : return False

    cmd = 'mv ' + run_dir+'/'+cesm_case+'*cam.i.'+ restart_yyyymmdd+'*  '+ output_arc 
    print cmd
    stat = os.system(cmd)
    if not stat == 0 : return False

    cmd = 'mv ' + run_dir+'/'+cesm_case+'*.r*.'+ restart_yyyymmdd+'*  '+ output_arc 
    print cmd
    stat = os.system(cmd)
    if not stat == 0 : return False

    cmd = 'cp ' + run_dir+'/*_in ' + output_arc 
    print cmd
    stat = os.system(cmd)
    if not stat == 0 : return False

    cmd = 'cp ' + run_dir+'/rpointer.* ' + output_arc 
    print cmd
    stat = os.system(cmd)
    if not stat == 0 : return False

    cmd = 'touch '+ output_arc+'/.ready_for_xfer'
    print cmd
    stat = os.system(cmd)
    if not stat == 0 : return False

  # do some cleanup ...

    cmd = 'rm ' + run_dir+'/*' 
    print cmd
    stat = os.system(cmd)

    #if not stat == 0 : return False

    return True

print "Begin post-processing ..."
success = True

days_back=60
today = datetime.now()
oneday = timedelta(days=1)
found=False
x=0

while not found :
    
    xdate = today-x*oneday

    yyyymmdd = xdate.strftime("%Y%m%d")
    yyyy = xdate.strftime("%Y")
    reanalysis_filepath = '/glade/p/cesm/chwg_dev/met_data/GEOS5/0.9x1.25/'+yyyy+'/GEOS5_09x125_'+yyyymmdd+'.nc'
    print "check for : ",reanalysis_filepath
    found = os.path.exists(reanalysis_filepath)
    x = x+1

first_fcst_date = xdate+oneday
restart_yyyymmdd = first_fcst_date.strftime("%Y-%m-%d")
print 'restart_yyyymmdd = '+restart_yyyymmdd 

success = True
success = save_output(restart_yyyymmdd)
print '  save_output success : ',success

if (success): 
    success = make_plots()
print '   make_plots success : ',success

print ' post-process success : ',success
print ' '
print '********************************************************************'
print 'Clean out old files : '

# remove old forecast files :
if (success):
    for i in range(days_back,3,-1):
        yyyymmdd = (today-i*oneday).strftime("%Y%m%d")
        output_arc = met_root_dir+'/'+yyyymmdd+'/model_files'
        if (os.path.exists(output_arc+'/.ready_for_xfer')):
            cmd = 'rm -fr '+met_root_dir+'/*'+yyyymmdd +'*'
            print ' cmd = '+cmd
            stat = os.system(cmd)
            cmd = 'rm '+met_root_dir+'/.last*'+yyyymmdd +'*'
            print ' cmd = '+cmd
            stat = os.system(cmd)

print 'post-processing done'

