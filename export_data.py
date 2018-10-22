#! /usr/bin/env python

import os
from scripts_info import date, cesm_case, met_root_dir, scripts_dir

def export_plots():
    
    yyyymmdd = date.strftime("%Y%m%d")
    plots_dir = met_root_dir+'/'+yyyymmdd+'/plots'

    species = ['BC','CLOX','CO','CO01','CO02','CO03','CO04','CO05','CO06','CO07','CO08','CO09','DUST','EXTINCTdn','NOX','O3','SO2','SO4','SSALT','PM25_SRF']
    basedir = '128.117.136.211:/ur/waccm_forecast_output/'
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

#    dist_loc = 'modeling2.acom.ucar.edu:/waccm-output/'
    dist_loc = '128.117.136.211:/net/modeling2.acom.ucar.edu/waccm-output/'
    cmd = 'scp '+ hist_dir +'/*cam.h[03]*nc '+ dist_loc

    print 'cmd='+cmd
    stat = os.system(cmd)
    if not stat == 0 : return False

    return True

success = export_plots()
print ' export_plots success : ',success
#success = export_history()
#print ' export_history success : ',success

