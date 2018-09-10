#! /usr/bin/env python
import os
import prepare_cesm_inputs 
import Process_GEOS5_Forecast
from datetime import datetime
import subprocess
import re
from scripts_info import met_root_dir, scripts_dir, cesm_case, cesm_case_dir, date

def submit_cesm():

    cmd = 'cd '+cesm_case_dir+' ; ./case.submit'
    print cmd

    output = subprocess.check_output(cmd, shell=True)
    print output

    line = re.findall('Submitted job case.run with id \d+\.chadmin1', output )[0]
    print ' line : '+line
    jobid = re.findall('\d+\.chadmin1',line)[0]

    submitcmd = 'qsub -W depend=afterok:'+jobid+' '+scripts_dir+'/postprocess_batch'
    print 'submitcmd = '+submitcmd
    output = subprocess.check_output(submitcmd, shell=True)
    print output

    return True

def prestage_cesm():

    success = prepare_cesm_inputs.update_emissions(date) # don't care if successful -- need to run model regardless...

    success = prepare_cesm_inputs.prepare_inputs(date,cesm_case)
    if not success:
        print 'GEOS forecast prestage CESM FAILED', 'GEOS forecast prestage CESM FAILED : '+date.strftime("%Y-%m-%d")
    return success

def prepare_geos_forecast():

    time0 = datetime.now()

    d_success = Process_GEOS5_Forecast.download(date,met_root_dir)
    d_success = Process_GEOS5_Forecast.download(date,met_root_dir)

    if not d_success:
        print 'GEOS forecast download FAILED', 'GEOS forecast download FAILED : '+date.strftime("%Y-%m-%d")
        return False

    time1 = datetime.now()

    c_success = Process_GEOS5_Forecast.combine(date,met_root_dir)

    if not c_success:
        # try re-downloading the data ...
        d_success = Process_GEOS5_Forecast.download(date,met_root_dir)
        c_success = Process_GEOS5_Forecast.combine(date,met_root_dir)

    if not c_success:
        print "GEOS combine data FAILED",'GEOS combine data FAILED : '+date.strftime("%Y-%m-%d")
        return False

    time2 = datetime.now()

    r_success = Process_GEOS5_Forecast.regrid(date,met_root_dir)
    if not r_success:
        print "GEOS regrid data FAILED",'GEOS regrid data FAILED : '+date.strftime("%Y-%m-%d")
        return False

    time3 = datetime.now()

    print " ++++++++++++++++++++++++++++++++++++++++++ "
    print "...Download time : ", time1-time0
    print "....Combine time : ", time2-time1
    print ".....Regrid time : ", time3-time2
    print "......Total Time : ", time3-time0
    print " ++++++++++++++++++++++++++++++++++++++++++ "
    return True

print "Get the forecast data ..."

ok = prepare_geos_forecast()

if ok :
    print "Prestage CESM ..."
    ok = prestage_cesm()

if ok :
    print "Submit CESM ..."
    ok = submit_cesm()

nowdate = datetime.now()

if ok :
    msg = 'model forecast submitted at : '+nowdate.strftime("%d %b %Y %H:%M:%S")
    print msg
else :
    pass    

print "DONE"
