#! /usr/bin/env python
from datetime import datetime

nfc_days=10
n_forecast_days=nfc_days-1
scripts_dir='/glade/u/home/fvitt/cesm_forecast_scripts'
met_root_dir='/glade/scratch/fvitt/GEOS5_frcst_data'
emis_root_dir='/glade/p/acom/acom-climate/fvitt/waccm_forecast_emis'
scratch_dir='/glade/scratch/fvitt/'
cesm_case = 'f.e21.FWSD.f09_f09_mg17.forecast.001'
cesm_case_dir = '/glade/work/fvitt/cesm/cases/'+cesm_case
date = datetime.now()

