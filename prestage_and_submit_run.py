#! /usr/bin/env python

from scripts_info import met_root_dir as rootdir, emis_root_dir
from scripts_info import scripts_dir, cesm_case_dir, date, nfc_days, cesm_case
from subprocess import call
from os import path, remove, system
from datetime import datetime, timedelta
from prepare_cesm_inputs import update_emissions, prepare_inputs
import subprocess
import re

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

print " "
print " ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
print " "

days_back=20
today = datetime.now()
oneday = timedelta(days=1)
success=True
found=False
x=0

while not found :
    
    date = today-x*oneday

    yyyymmdd = date.strftime("%Y%m%d")
    yyyy = date.strftime("%Y")
    reanalysis_filepath = '/glade/p/cesm/chwg_dev/met_data/GEOS5/0.9x1.25/'+yyyy+'/GEOS5_09x125_'+yyyymmdd+'.nc'
    print "check for : ",reanalysis_filepath
    found = path.exists(reanalysis_filepath)
    x = x+1

first_fcst_date = date+oneday

print 'last realn date = ',date.strftime("%Y-%m-%d")
print 'first_fcst_date = ',first_fcst_date.strftime("%Y-%m-%d")
print '          today = ', today.strftime("%Y-%m-%d")


print '           date = ', date.strftime("%Y-%m-%d")

yyyymmdd = today.strftime("%Y%m%d")
inputlist_file = 'GEOS5fcst_met_list_'+yyyymmdd
if (path.exists(rootdir+'/'+inputlist_file)) : remove(rootdir+'/'+inputlist_file)

for x in range(days_back,0,-1):
    date = today-x*oneday
    yyyymmdd = date.strftime("%Y%m%d")
    yyyy = date.strftime("%Y")
    reanalysis_filepath = '/glade/p/cesm/chwg_dev/met_data/GEOS5/0.9x1.25/'+yyyy+'/GEOS5_09x125_'+yyyymmdd+'.nc'
    print " 0***** check reanalysis_filepath : "+reanalysis_filepath
    if (path.exists(reanalysis_filepath)) :
        cmd = 'echo '+reanalysis_filepath+' >> '+rootdir+'/'+inputlist_file
        print 'cmd = '+cmd
        stat=system(cmd)
        if stat == 0 :
            success = True
        else:
            success = False
    else :
        frcst_filepath = rootdir+'/GEOS5fcst_0.9x1.25_'+yyyymmdd+'+'+yyyymmdd+'.nc'
        if (path.exists(frcst_filepath)) :
            cmd = 'echo '+frcst_filepath+' >> '+rootdir+'/'+inputlist_file
            print 'cmd = '+cmd
            stat=system(cmd)
            if stat == 0 :
                success = True
            else:
                success = False
        else:
            success = False

#date = first_fcst_date + oneday
#
#print " ************* first_fcst_date : ",first_fcst_date 
#print " ************************ date : ",           date 
#print " *********************** today : ",          today
#
#while date<today:
#    yyyymmdd = date.strftime("%Y%m%d")
#    frcst_filepath = rootdir+'/GEOS5fcst_0.9x1.25_'+yyyymmdd+'+'+yyyymmdd+'.nc'
#    print " 1***** check frcst_filepath : "+frcst_filepath 
#    if (path.exists(frcst_filepath)) :
#        cmd = 'echo '+frcst_filepath+' >> '+rootdir+'/'+inputlist_file
#        print 'cmd = '+cmd
#        stat=system(cmd)
#        if stat == 0 :
#            success = True
#        else:
#            success = False
#    else :
#        frcst_filepath = rootdir+'/GEOS5fcst_0.9x1.25_'+curr_yyyymmdd+'+'+fcst_yyyymmdd+'.nc'
#    date = date + oneday

date = today
curr_yyyymmdd = today.strftime("%Y%m%d")

for x in range(0,nfc_days):
    fcst_yyyymmdd = date.strftime("%Y%m%d")
    frcst_filepath = rootdir+'/GEOS5fcst_0.9x1.25_'+curr_yyyymmdd+'+'+fcst_yyyymmdd+'.nc'
    print " 2***** check frcst_filepath : "+frcst_filepath 
    if (path.exists(frcst_filepath)) :
        cmd = 'echo '+frcst_filepath+' >> '+rootdir+'/'+inputlist_file
        print 'cmd = '+cmd
        stat=system(cmd)
        if stat == 0 :
            success = True
        else:
            success = False
    
    date=date+oneday

## update emissions
#for x in range(days_back,0,-1):
#    date = today-x*oneday
#    yyyymmdd = date.strftime("%Y%m%d")
#    co_emis_file = emis_root_dir+'/FINNnrt/'+yyyymmdd+'/emissions_CO_0.9x1.25.nc'
#    print "check for file : "+co_emis_file 
#    if (not path.exists(co_emis_file)):
#        xsuccess=update_emissions(date)

# determine start date of next run
# -- look for the last model_files directory
#   --> *cam.i.* file date gives the start date of the next run

model_files_dir = 'none'
found = False
give_up = False
x = 1

while (not found and not give_up):
    lastdate = today-x*oneday
    yyyymmdd = lastdate.strftime("%Y%m%d")
    model_files_dir = rootdir+'/'+yyyymmdd+'/model_files'
    x = x+1
    print "LOOK for directory : "+model_files_dir
    if (path.exists(model_files_dir)):
        found=True
    if (x == days_back):
        give_up = True

if (path.exists(model_files_dir)):
    print " "
    # determine start date from *cam.i.* file in model_files_dir 
    found = False
    give_up = False
    x = 1
    while (not found and not give_up):
        startdate = today-x*oneday
        datestr = startdate.strftime("%Y-%m-%d")
        ic_file = model_files_dir+'/'+cesm_case+'.cam.i.'+datestr+'-00000.nc'
        x = x+1
        print "LOOK for IC file : "+ic_file
        if (path.exists(ic_file)):
            found=True
        if (x == days_back):
            give_up = True


    if (found) :
        sim_start_date = startdate
        print 'sim_start_date : ',sim_start_date

        ddays = (today - sim_start_date).days
        print ' ddays:',ddays

        stop_n = ddays+nfc_days-1

        print ' number of sim days : ',stop_n
        print " save restart files : ",first_fcst_date.strftime("%Y-%m-%d"), " to ",today.strftime("%Y%m%d")+'/model_files/'

        success = prepare_inputs(lastdate,today,sim_start_date, stop_n)

        #print "success : ",success
        #print "STOP HERE"
        print " "
        print " +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        print "      found : ",found
        print "    give_up : ",give_up
        print "    IC file : ",ic_file
        print " start date : ",startdate.strftime("%Y-%m-%d")
        print " --------------------------------------------------------------------------- "
        print " "
#        exit()
        #print " "
        #print "success : ",success
        #print "EXIT NOW"
        #exit(0)

        # submit the model run ...
        print "submit the the model run"
        success = submit_cesm()
else:
    print " "
    print "*************************************************"
    print "Could not find model_files from the last run..."
    print "*************************************************"
    print " "
    success = False


print "Final success : ",success
print " "
