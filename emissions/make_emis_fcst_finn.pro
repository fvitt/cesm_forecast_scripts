
pro make_emis_fcst_finn

today = bin_date(systime())
todaystr = String(today[0:2],format='(i4,"/",i2.2,"/",i2.2)')
sdate_today = String(today[0:2],format='(i4,i2.2,i2.2)')
creation_date = sdate_today
thisfile = Routine_filepath()

path_orig = '/glade/p/work/emmons/emis/finn1.5/2002_2017_1deg/'
path_out = '/glade/p/work/emmons/emis/fcst_2017/'

;make new time array - daily - gregorian calendar, days since 1750
day1 = Julday(1,1,2017)
day2 = Julday(1,1,2019)
yrstr = '2018-2020'
ntim = day2-day1+1
time = fltarr(ntim)
date = lonarr(ntim)
for itim=0,ntim-1 do begin
  jday = day1 + itim
  caldat,jday,mon,day,yr
  date[itim] = yr*10000L + mon*100L + day
  time[itim] = jday - julday(1,1,1750)
endfor

specs = ['NO','NO2','NH3','SO2','CO','C2H2','C2H4','C2H6','C3H6','C3H8', $
        'BIGALK','BIGENE','TOLUENE', 'BENZENE', 'XYLENES','CH3OH','C2H5OH', $
        'CH2O','CH3CHO','CH3COCH3','MEK', 'HCN','CH3CN', 'HCOOH', 'CH3COOH', $
        'ISOP','TERPENES', 'BIGALD','CH3COCHO','CRESOL','GLYALD', 'HYAC','MACR','MVK', $
        'SVOC','IVOC', 'bc_a4','pom_a4','num_bc_a4','num_pom_a4']

for ispec = 0,n_elements(specs)-1 do begin
  spec = specs[ispec]

  ;read 2002-17 file
  files = File_search(path_orig+'emissions-finn1.5_'+spec+'_bb_surface_2002-2017_0.9x1.25.nc',count=nfiles)
  file1 = files[nfiles-1]
  print,file1

  source_file = file1
  ncido = ncdf_open(file1)
  ncdf_varget,ncido,'lon',lon
  ncdf_varget,ncido,'lat',lat
  ncdf_varget,ncido,'date',date_o
  ncdf_varget,ncido,'time',time_o
  nlon = n_elements(lon)
  nlat = n_elements(lat)
  varname = 'fire'
  if (ncdf_varid(ncido,varname) lt 0) then varname = 'bb'
  ncdf_varget,ncido,varname,fire_o
  ncdf_attget,ncido,varname,'long_name',lname
  longname = string(lname)
  print,longname

  ind1 = where(date_o ge 20170101L,ntimo)
  print,'2017/01/01: ',date_o[ind1[0]]
  help,ntimo

  bb = fltarr(nlon,nlat,ntim)
  ;put existing emis in new file
  bb[*,*,0:ntimo-1] = fire_o[*,*,ind1]
  ;*** emissions are zero for all following times

; write new file
  newfile = path_out+'emissions-fcst_'+spec+'_bb_surface_'+yrstr+'_0.9x1.25.nc'
  print,newfile
  ncid = ncdf_create(newfile,/clobber)
  xid = ncdf_dimdef(ncid,'lon',nlon)
  yid = ncdf_dimdef(ncid,'lat',nlat)
  tid = ncdf_dimdef(ncid,'time',/unlimited)
  ; Define variables with attributes
  xvarid = ncdf_vardef(ncid,'lon',[xid],/float)
  ncdf_attput, ncid, xvarid,/char, 'units', 'degrees_east'
  ncdf_attput, ncid, xvarid,/char, 'long_name', 'Longitude'
  yvarid = ncdf_vardef(ncid,'lat',[yid],/float)
  ncdf_attput, ncid, yvarid,/char, 'units', 'degrees_north'
  ncdf_attput, ncid, yvarid,/char, 'long_name', 'Latitude'
  tvarid = ncdf_vardef(ncid,'time',[tid],/float)
  ncdf_attput, ncid, tvarid,/char, 'long_name', 'Time'
  ncdf_attput, ncid, tvarid,/char, 'units', 'days since 1750-01-01 00:00:00'
  ncdf_attput, ncid, tvarid,/char, 'calendar', 'Gregorian'
  tvarid = ncdf_vardef(ncid,'date',[tid],/long)
  ncdf_attput, ncid, tvarid,/char, 'units', 'YYYYMMDD'
  ncdf_attput, ncid, tvarid,/char, 'long_name', 'Date'

  varid = ncdf_vardef(ncid,'bb',[xid,yid,tid],/float)
  ncdf_attput,ncid,/char,varid,'units','molecules/cm2/s'
  ncdf_attput,ncid,/char,varid,'long_name',longname

  ;Copy global attributes
  ncdf_attput,ncid,/GLOBAL,/char,'data_title','FINN1.5 and FINNv1-NRT fire emissions for forecasting'
  ncdf_attput,ncid,/GLOBAL,/char,'data_creator','Louisa Emmons (emmons@ucar.edu)'
  ncdf_attput,ncid,/GLOBAL,/char,'creation_date',creation_date
  ncdf_attput,ncid,/GLOBAL,/char,'history','original file:'+source_file
  ncdf_attput,ncid,/GLOBAL,/char,'data_script',thisfile
  ncdf_control,ncid,/ENDEF

  ncdf_varput,ncid,'lon',lon
  ncdf_varput,ncid,'lat',lat
  ncdf_varput,ncid,'time',time
  ncdf_varput,ncid,'date',date
  ncdf_varput,ncid,'bb',bb
  ncdf_close,ncid
  ncdf_close,ncido

endfor 

end
