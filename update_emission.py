#! /usr/bin/env python

from prepare_cesm_inputs import update_emissions
from datetime import datetime, timedelta
from scripts_info import emis_root_dir
from os import path

days_back=20
today = datetime.now()
oneday = timedelta(days=1)

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
