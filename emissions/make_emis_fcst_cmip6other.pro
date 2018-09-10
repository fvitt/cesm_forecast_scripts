; use 2014 for all years

pro make_emis_fcst_cmip6other

today = bin_date(systime())
todaystr = String(today[0:2],format='(i4,"/",i2.2,"/",i2.2)')
sdate_today = String(today[0:2],format='(i4,i2.2,i2.2)')
creation_date = sdate_today
thisfile = Routine_filepath()

path_orig = '/glade/p/cesm/chwg_dev/emmons/CMIP6_emissions_1750_2015_v20170322/'
path_out = '/glade/p/work/emmons/emis/fcst_2017/'

;make new time array - gregorian calendar, days since 1750
yr1 = 2017
yr2 = 2020
yrstr = string(yr1,yr2,format='(i4,"-",i4)')
nyrs = (yr2-yr1+1)
ntim = nyrs*12
time = fltarr(ntim)
date = lonarr(ntim)
for yr = yr1,yr2 do begin
  for mon = 1,12 do begin
    itim =  (mon-1) + (yr-yr1)*12
    day = 15
    date[itim] = yr*10000L + mon*100L + day
    time[itim] = julday(mon,day,yr) - julday(1,1,1750)
    if (yr eq yr1 or yr eq yr2) then print,itim,mon,yr,date[itim],time[itim]
  endfor
endfor

specs = ['NO','NH3','DMS','CO','C2H4','C2H6','C3H6','C3H8']

for ispec = 0,n_elements(specs)-1 do begin
  spec = specs[ispec]

  ;read 1750-2015 file
  files = File_search(path_orig+'emissions-cmip6_'+spec+'_other_surface_1750-2015_0.9x1.25_c20170322.nc',count=nfiles)
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
  ntimo = n_elements(date_o)
  finq = ncdf_inquire(ncido)
  varnames = strarr(finq.nvars)
  ivar=0
  for i=0,finq.nvars-1 do begin
    vinq = ncdf_varinq(ncido,i)
    if (vinq.ndims eq 3) then begin
      varnames[ivar] = vinq.name
      ivar = ivar+1
    endif
  endfor
  varnames = varnames[0:ivar-1]
  nvars = n_elements(varnames)
  anthro_o = fltarr(nvars,nlon,nlat,ntimo)
  longname = strarr(nvars)
  for ivar = 0,nvars-1 do begin
    ncdf_varget,ncido,varnames[ivar],emis1
    anthro_o[ivar,*,*,*] = emis1
    ncdf_attget,ncido,varnames[ivar],'molecular_weight',mw
    ncdf_attget,ncido,varnames[ivar],'long_name',lname
    longname[ivar] = string(lname)
    print,varnames[ivar],' ',longname[ivar]
  endfor

  ind1 = where(date_o ge 20140101L)
  print,'2014: ',date_o[ind1[0]]

   anthro_new = fltarr(nvars,nlon,nlat,ntim)
   ; repeat 2014 for 2015-2017
   for iyr=0,nyrs-1 do begin 
    for imon=0,11 do begin
     jtim = ind1[0]+imon
     itim = iyr*12 + imon
     if (imon eq 0) then print,'using ', date_o[jtim],' for ', date[itim]
     for ivar=0,nvars-1 do anthro_new[ivar,*,*,itim] = anthro_o[ivar,*,*,jtim]
    endfor
   endfor

; write new file
  newfile = path_out+'emissions-cmip6_'+spec+'_other_surface_'+yrstr+'_0.9x1.25_c'+creation_date+'.nc'
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

  for ivar = 0,nvars-1 do begin
    varname = varnames[ivar]
    varid = ncdf_vardef(ncid,varname,[xid,yid,tid],/float)
    ncdf_attput,ncid,/char,varid,'units','molecules/cm2/s'
    ncdf_attput,ncid,/char,varid,'long_name',longname[ivar]
    ncdf_attput,ncid,/float,varid,'molecular_weight',mw
  endfor

  ;Copy global attributes
  res = ncdf_attcopy(ncido,'data_title',ncid,/in_global,/out_global)
  res = ncdf_attcopy(ncido,'molecular_weight',ncid,/in_global,/out_global)
  ncdf_attput,ncid,/GLOBAL,/char,'data_creator','Louisa Emmons (emmons@ucar.edu)'
  ncdf_attput,ncid,/GLOBAL,/char,'creation_date',creation_date
  res = ncdf_attcopy(ncido,'data_summary',ncid,/in_global,/out_global)
  res = ncdf_attcopy(ncido,'cesm_contact',ncid,/in_global,/out_global)
  res = ncdf_attcopy(ncido,'data_source_url',ncid,/in_global,/out_global)
  res = ncdf_attcopy(ncido,'data_reference',ncid,/in_global,/out_global)
  ncdf_attput,ncid,/GLOBAL,/char,'history','original file:'+source_file
  ncdf_attput,ncid,/GLOBAL,/char,'data_script',thisfile
  ncdf_control,ncid,/ENDEF

  ncdf_varput,ncid,'lon',lon
  ncdf_varput,ncid,'lat',lat
  ncdf_varput,ncid,'time',time
  ncdf_varput,ncid,'date',date
  for ivar = 0,nvars-1 do begin
    varname = varnames[ivar]
    emis1 = reform(anthro_new[ivar,*,*,*])
    ncdf_varput,ncid,varname,emis1
  endfor

  ncdf_close,ncid
  ncdf_close,ncido

endfor

end
