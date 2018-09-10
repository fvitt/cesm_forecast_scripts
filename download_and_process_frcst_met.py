#! /usr/bin/env python

from download_forecast_data import download_forecast_data
from scripts_info import met_root_dir as rootdir, emis_root_dir
from subprocess import call
from os import path, remove, system
from datetime import datetime, timedelta
from Process_GEOS5_Forecast import combine, regrid
from prepare_cesm_inputs import update_emissions, prepare_inputs

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
success=False
found=False
x=0

while not found :
    
    date = today-x*oneday

    yyyymmdd = date.strftime("%Y%m%d")
    yyyy = date.strftime("%Y")
    reanalysis_filepath = '/glade/p/cesm/chwg_dev/met_data/GEOS5/0.9x1.25/'+yyyy+'/GEOS5_09x125_'+yyyymmdd+'.nc'

    found = path.exists(reanalysis_filepath)
    x = x+1

first_fcst_date = date
print 'first_fcst_date = ',first_fcst_date.strftime("%Y-%m-%d")
print '          today = ', today.strftime("%Y-%m-%d")

yyyymmdd = date.strftime("%Y%m%d")
filepath = rootdir+'/.last_fcst_met_'+yyyymmdd
if (not path.exists(filepath)) :
    print "download_forecast_data 1 date: "+yyyymmdd
    success = download_forecast_data( date, 1, rootdir )
    if (success) :
        cmd = ['touch',filepath]
        print ' cmd: ',cmd
        stat = call(cmd)
        if stat == 0 : 
            success = True
        else :
            success = False

while date<today-oneday:
    date = date+oneday
    print ' forecast date = ',date
    yyyymmdd = date.strftime("%Y%m%d")
    yyyy = date.strftime("%Y")
    filepath = rootdir+'/.last_fcst_met_'+yyyymmdd
    if (not path.exists(filepath)) :
        print '  ... dwnld_proc_fcst_met( date, 1 ): '+yyyymmdd
        success = dwnld_proc_fcst_met( date, 1 )

yyyymmdd = today.strftime("%Y%m%d")
filepath = rootdir+'/.last_fcst_met_'+yyyymmdd
if (not path.exists(filepath)) :
    print "  ... dwnld_proc_fcst_met( date, 10 ) : "+yyyymmdd
    success = dwnld_proc_fcst_met( today, 10 )
    
inputlist_file = 'GEOS5fcst_met_list_'+yyyymmdd
if (path.exists(rootdir+'/'+inputlist_file)) : remove(rootdir+'/'+inputlist_file)

for x in range(days_back,0,-1):
    date = today-x*oneday
    yyyymmdd = date.strftime("%Y%m%d")
    yyyy = date.strftime("%Y")
#
#    filepath = rootdir+'/.last_fcst_met_'+yyyymmdd
    reanalysis_filepath = '/glade/p/cesm/chwg_dev/met_data/GEOS5/0.9x1.25/'+yyyy+'/GEOS5_09x125_'+yyyymmdd+'.nc'
    #print ' ... reanalysis_filepath: '+reanalysis_filepath
    #print '     ---------------- exits :', path.exists(reanalysis_filepath)
    if (path.exists(reanalysis_filepath)) :
        cmd = 'echo '+reanalysis_filepath+' >> '+rootdir+'/'+inputlist_file
        print 'cmd = '+cmd
        stat=system(cmd)
        if stat == 0 :
            success = True
        else:
            success = False

#        if (success) :
#            filename = rootdir+'/.last_reanalysis_date_'+yyyymmdd
#            cmd = ['touch',filename]
#            stat = call(cmd)
#            if stat == 0 : 
#                success = True
#            else :
#                success = False
       

date = first_fcst_date + oneday
print " ************* first_fcst_date : ",first_fcst_date 
print " ************************ date : ",           date 
print " *********************** today : ",          today

while date<today:
    frcst_filepath = rootdir+'/GEOS5fcst_0.9x1.25_'+yyyymmdd+'+'+yyyymmdd+'.nc'
    print " ***** check frcst_filepath : "+frcst_filepath 
    if (path.exists(frcst_filepath)) :
        cmd = 'echo '+frcst_filepath+' >> '+rootdir+'/'+inputlist_file
        print 'cmd = '+cmd
        stat=system(cmd)
        if stat == 0 :
            success = True
        else:
            success = False
        

date = today
curr_yyyymmdd = today.strftime("%Y%m%d")

for x in range(0,10):
    fcst_yyyymmdd = date.strftime("%Y%m%d")
    frcst_filepath = rootdir+'/GEOS5fcst_0.9x1.25_'+curr_yyyymmdd+'+'+fcst_yyyymmdd+'.nc'
    print " ***** check frcst_filepath : "+frcst_filepath 
    if (path.exists(frcst_filepath)) :
        cmd = 'echo '+frcst_filepath+' >> '+rootdir+'/'+inputlist_file
        print 'cmd = '+cmd
        stat=system(cmd)
        if stat == 0 :
            success = True
        else:
            success = False
    
    date=date+oneday


# update emissions
for x in range(days_back,0,-1):
    date = today-x*oneday
    yyyymmdd = date.strftime("%Y%m%d")
    co_emis_file = emis_root_dir+'/FINNnrt/'+yyyymmdd+'/emissions_CO_0.9x1.25.nc'
    if (not path.exists(co_emis_file)):
        success=update_emissions(date)

# determine start date of next run
#  look for the latest inputlist_file --> lastdate

found = False
x = 1
while not found :
    lastdate = today-x*oneday
    inputlist_filepath = rootdir+'/'+'GEOS5fcst_met_list_'+lastdate.strftime("%Y%m%d")
    x = x+1
    if (path.exists(inputlist_filepath)):
        found=True

#  look in lastdate's inputlist_file for last reanalysis met file ...
f = open(inputlist_filepath, 'r') 
for line in f:
    if (line.find('chwg_dev/met_data/GEOS5/0.9x1.25/') >= 0):
        last_reanalysis_path = line,
f.close()

# from the last reanalysis file name extract the corresponding date
mystring = last_reanalysis_path[0]
start = mystring.find('GEOS5_09x125_')
end = mystring.find('.nc',start)
yyyymmdd_string = mystring[start+13:end]

# the start date of the next run should be that reanalysis date + 1day

year=int(yyyymmdd_string[0:4])
mon =int(yyyymmdd_string[4:6])
dom =int(yyyymmdd_string[6:8])
sim_start_date = datetime(year,mon,dom) + oneday
print 'sim_start_date : ',sim_start_date

ddays = (today - sim_start_date).days
print ' ddays:',ddays

stop_n = ddays+9
print ' number of sim days : ',stop_n


##success = prepare_inputs(lastdate,today,sim_start_date)

print "Final success : ",success
