#! /usr/bin/env python

from download_forecast_data import download_forecast_data
from scripts_info import met_root_dir as rootdir
from scripts_info import nfc_days, emis_root_dir
from subprocess import call
from os import path, system
from datetime import datetime, timedelta
from Process_GEOS5_Forecast import combine, regrid
from prepare_cesm_inputs import update_emissions

def dwnld_proc_fcst_met( date, n_forecast_days ):

    success = False
    print '  ... download_forecast_data(',date, n_forecast_days, rootdir,') ...'

    success = download_forecast_data( date, n_forecast_days, rootdir )

    if (success) :
        success = combine( date, rootdir, n_forecast_days )

    if (success) :
        success = regrid( date, rootdir, n_forecast_days )

    if (success) :
        yyyymmdd = date.strftime("%Y%m%d")
        filename = rootdir+'/.last_fcst_met_'+yyyymmdd
        cmd = ['touch',filename]
        print ' cmd: ',cmd
        stat = call(cmd)
        if stat == 0 : 
            success = True
        else :
            success = False

    return success

days_back=20
today = datetime.now()
oneday = timedelta(days=1)
success=True
found=False
x=0

print "***********************************************************"    
print " Start download and combine and regrid forecast data ... "
print "***********************************************************"    
while not found :
    
    date = today-x*oneday

    yyyymmdd = date.strftime("%Y%m%d")
    yyyy = date.strftime("%Y")
    reanalysis_filepath = '/glade/p/cesm/chwg_dev/met_data/GEOS5/0.9x1.25/'+yyyy+'/GEOS5_09x125_'+yyyymmdd+'.nc'
    print 'look for reanalysis : '+reanalysis_filepath 
    found = path.exists(reanalysis_filepath)
    x = x+1

yyyymmdd = date.strftime("%Y%m%d")
filepath = rootdir+'/.last_fcst_met_'+yyyymmdd
if (not path.exists(filepath)) :
    print "***********************************************"    
    print "download_forecast_data 1 date: "+yyyymmdd
    print "***********************************************"    
    success = download_forecast_data( date, 1, rootdir )
#    if (success) :
#        cmd = ['touch',filepath]
#        print ' cmd: ',cmd
#        stat = call(cmd)
#        if stat == 0 : 
#            success = True
#        else :
#            success = False

while date<today-oneday:
    date = date+oneday
    print ' forecast date = ',date
    yyyymmdd = date.strftime("%Y%m%d")
    #yyyy = date.strftime("%Y")
    filepath = rootdir+'/.last_fcst_met_'+yyyymmdd
    if (not path.exists(filepath)) :
        print '  ... dwnld_proc_fcst_met( date, 1 ): '+yyyymmdd
        print "***********************************************"    
        print " dwnld_proc_fcst_met( date, 1 ) : "+yyyymmdd
        print "***********************************************"    
        success = dwnld_proc_fcst_met( date, 1 )

yyyymmdd = today.strftime("%Y%m%d")
filepath = rootdir+'/.last_fcst_met_'+yyyymmdd
if (not path.exists(filepath)) :
    print "***********************************************"    
    print "dwnld_proc_fcst_met( date, ",nfc_days," ) : "+yyyymmdd
    print "***********************************************"    
    success = dwnld_proc_fcst_met( today, nfc_days )

# remove old forecast files :
for i in range(days_back,3,-1):
    yyyymmdd = (today-i*oneday).strftime("%Y%m%d")
    cmd = 'rm -fr '+rootdir+'/*'+yyyymmdd +'*'
    print ' cmd = '+cmd
    stat = system(cmd)
    cmd = 'rm '+rootdir+'/.last*'+yyyymmdd +'*'
    print ' cmd = '+cmd
    stat = system(cmd)


# update emissions
esuccess=False
for x in range(days_back,0,-1):
    date = today-x*oneday
    yyyymmdd = date.strftime("%Y%m%d")
    co_emis_file = emis_root_dir+'/FINNnrt/'+yyyymmdd+'/emissions_CO_0.9x1.25.nc'
    print "check for file : "+co_emis_file 
    if (not path.exists(co_emis_file)):
        esuccess=update_emissions(date)

print "Emissions success :",esuccess

print "Final success : ",success

