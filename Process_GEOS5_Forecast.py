#! /usr/bin/env python
from datetime import datetime, timedelta
from subprocess import call
from os import path, remove, system
from glob import glob
from combine_met_data_eff import combine_met_data
from check_met_data import check_met_data
from download_forecast_data import download_forecast_data
from download_forecast_data import download2
from scripts_info import scripts_dir

def combine( date, rootdir, n_forecast_days ):

    oneday = timedelta(days=1)
    yyyymmdd = date.strftime("%Y%m%d")
    dir1 = rootdir + "/" + date.strftime("%Y%m%d")

    for d in range(0,n_forecast_days):
        fcst_date = date+d*oneday
        fcst_yyyymmdd = fcst_date.strftime("%Y%m%d")
        ofilepath = dir1+'/GEOS5_orig_res_'+yyyymmdd+'+'+fcst_yyyymmdd+'.nc'
        print '================================================================'
        print '  Create : '+ofilepath
        print d, rootdir, date, fcst_date, ofilepath
        print '================================================================'
        done = False
        cnt = 0
        while not done:
            done = combine_met_data( rootdir, date, fcst_date, ofilepath )
            if not done :
                # in the event of a failure try re-downloading the forecasct data ...
                cnt += 1
                if (cnt>9) : return False

                year  = date.strftime("%Y")
                month = date.strftime("%m")
                day   = date.strftime("%d")
                local_dir = rootdir+'/'+year+month+day

                ret = download2( date, fcst_date, local_dir )
                if not ret: return False

                # might need previous day's forecast
                if d>0 :
                    ret = download2( date, fcst_date-oneday, local_dir )
                else :
                    year  = (date-oneday).strftime("%Y")
                    month = (date-oneday).strftime("%m")
                    day   = (date-oneday).strftime("%d")
                    local_dir = rootdir+'/'+year+month+day
                    ret = download2( date-oneday, fcst_date-oneday, local_dir )

                if not ret: return False

    return True

def regrid(date,rootdir,n_forecast_days):

    oneday = timedelta(days=1)
    yyyymmdd = date.strftime("%Y%m%d")
    dir1 = rootdir + "/" + date.strftime("%Y%m%d")

    newLats = 192
    newLons = 288

    for d in range(0,n_forecast_days):
        fcst_date = date+d*oneday
        fcst_yyyymmdd = fcst_date.strftime("%Y%m%d")
        in_filepath = dir1+'/GEOS5_orig_res_'+yyyymmdd+'+'+fcst_yyyymmdd+'.nc'
        out_filepath = rootdir+'/GEOS5fcst_0.9x1.25_'+yyyymmdd+'+'+fcst_yyyymmdd+'.nc'
        print '================================================================'
        print in_filepath + ' --> ' + out_filepath
        print '================================================================'
        cmd = scripts_dir+'/fortran/regrid_met -infile '+in_filepath+' -outfile '+out_filepath+' -nlons '+str(newLons)+' -nlats '+str(newLats)
        print ' regrid command: '+cmd
        stat = system(cmd)

        if not stat == 0 :
            print "ERROR in remapping " + in_filepath + ' --> ' + out_filepath
            return False
        if not check_met_data( out_filepath ) :
            print "ERROR in validating "+out_filepath
            return False

    return True

def cleanup(date,rootdir):
    dir1 = rootdir + "/" + date.strftime("%Y%m%d")
    cmd = 'rm -rf '+dir1
    print cmd
    os.system(cmd)

def _test():

    print "Begin Test"
    time0 = datetime.now()

    date = datetime(2017,9,27)
#    date = datetime.now()
    rootdir = '/glade/scratch/fvitt/GEOS5_frcst_data'

    d_success = download(date, rootdir)

    time1 = datetime.now()

    c_success = combine(date,rootdir)

    time2 = datetime.now()

    r_success = regrid(date,rootdir)

    time3 = datetime.now()

    print " "
    print 'download success : ', d_success
    print ' combine success : ', c_success
    print '  regrid success : ', r_success
    print " "
    print "...Download time : ", time1-time0
    print "....Combine time : ", time2-time1
    print ".....Regrid time : ", time3-time2
    print " "
    print "......Total Time : ", time3-time0
    print "Test Done"
