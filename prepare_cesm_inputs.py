#! /usr/bin/env python
from subprocess import call
from datetime import datetime, timedelta
from scripts_info import scripts_dir, met_root_dir, emis_root_dir, cesm_case_dir, scratch_dir, cesm_case
import os

def replace_namelist_strvar(nl_filefpath, nl_var, nl_val):

    cmd = 'perl -pi -e \'s/'+nl_var+'.*=.*\'\"\'\"\'.*\'\"\'\"\'/'+nl_var+' = \'\"\'\"\''+nl_val.replace('/','\/')+'\'\"\'\"\'/g\' '+nl_filefpath
    print cmd
    stat = os.system(cmd)
    if not stat == 0:
        return False
    return True

def update_emissions(date):

    yyyymmdd = date.strftime("%Y%m%d")
    cmd = scripts_dir+'/get_finn_web_emis --idlpath '+scripts_dir+'/emissions --date '+yyyymmdd+' --emispath '+emis_root_dir
    print 'cmd :'+cmd
    stat = os.system(cmd)
    if not stat == 0:
        return False
    return True

def prepare_inputs(prevdate,currdate,runstartdate, ndays):

    curryyyymmdd = currdate.strftime("%Y%m%d")
    prevyyyymmdd = prevdate.strftime("%Y%m%d")
    startyyyymmdd = runstartdate.strftime("%Y%m%d")
    startyyyy = runstartdate.strftime("%Y")

    data_dir = met_root_dir
    filelist = data_dir+'/GEOS5fcst_met_list_'+curryyyymmdd
    casedir = cesm_case_dir
    rundir = scratch_dir+cesm_case+'/run'

    cmd = 'cd '+rundir+'; ln -s '+ \
          data_dir+'/'+prevyyyymmdd+'/model_files/'+cesm_case+'*.r* . ; ln -s '+ \
          data_dir+'/'+prevyyyymmdd+'/model_files/'+cesm_case+'.cam.i.* . ; cp '+ \
          data_dir+'/'+prevyyyymmdd+'/model_files/rpointer.* .'

    print cmd
    stat = os.system(cmd)
    if not stat == 0:
        return False

    cmd = 'perl -p -i -e \'s/\.\d+-\d+-\d+-00000/\.'+runstartdate.strftime("%Y-%m-%d")+'-00000/g\' '+ rundir+'/rpointer.*'
    print cmd
    stat = os.system(cmd)
    if not stat == 0:
        return False

    atm_nl_filepath = casedir+'/user_nl_cam'

    # point to new met data list of files
    ok = replace_namelist_strvar(atm_nl_filepath,'met_filenames_list', filelist)
    print "ok = ",ok
    if not ok:
        return False

    # point to new met data file
    first_file = '/glade/p/cesm/chwg_dev/met_data/GEOS5/0.9x1.25/'+startyyyy+'/GEOS5_09x125_'+startyyyymmdd+'.nc'
    if (not os.path.exists(first_file)) :
        first_file = '/glade/scratch/fvitt/GEOS5_frcst_data/GEOS5fcst_0.9x1.25_'+startyyyymmdd+'+'+startyyyymmdd+'.nc'
    if (not os.path.exists(first_file)) :
        return False

    print "*************************************************************************************"
    print " first_file = "+first_file
    print "*************************************************************************************"
    ok = replace_namelist_strvar(atm_nl_filepath,'met_data_file', first_file)
    if not ok:
        return False

    ok = replace_namelist_strvar(atm_nl_filepath,'met_data_path', '')
    if not ok:
        return False

    datestamp = runstartdate.strftime("%Y-%m-%d")

    # change model start date and model run length (ndays)

    cmd = 'cd '+casedir+' ; ./xmlchange STOP_N='+str(ndays)+',RUN_STARTDATE='+datestamp+',RUN_REFDATE='+datestamp
    print cmd
    stat = os.system(cmd)
    if not stat == 0:
        return False

    return True

def test():
    
    print 'Begin TEST'
    runstartdate = datetime(2017,12,27)
    prevdate = datetime(2017,12,27)
    currdate = datetime(2017,12,28)

    case_name = 'forecast_test001'

    success = prepare_inputs(prevdate,currdate,runstartdate, 2 )
    print 'success : ',success

    print 'End TEST'
