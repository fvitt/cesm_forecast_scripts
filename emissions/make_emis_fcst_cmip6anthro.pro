; use 2014 for all years

pro make_emis_fcst_cmip6anthro

today = bin_date(systime())
todaystr = String(today[0:2],format='(i4,"/",i2.2,"/",i2.2)')
sdate_today = String(today[0:2],format='(i4,i2.2,i2.2)')
creation_date = sdate_today
thisfile = Routine_filepath()

path_orig = '/glade/p/cesm/chwg_dev/emmons/CMIP6_emissions_1750_2015_v20170608/'
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

;surface files
surfvert='surface'
specs = ['NH3_anthro','SO2_anthro-ag-ship-res','SO2_anthro-ene', $
   'bc_a4_anthro','pom_a4_anthro', $
   'so4_a1_anthro-ag-ship','so4_a1_anthro-ene','so4_a2_anthro-res', $
   'NO_anthro','CO_anthro','C2H6_anthro','C3H8_anthro','BIGALK_anthro','C2H4_anthro', $
   'C3H6_anthro','C2H2_anthro','BIGENE_anthro', $
   'BENZENE_anthro','TOLUENE_anthro','XYLENES_anthro','CH2O_anthro','CH3CHO_anthro', $
   'CH3OH_anthro','C2H5OH_anthro', $
   'CH3COCH3_anthro','MEK_anthro','HCOOH_anthro','CH3COOH_anthro', $
   'IVOC_anthro','SVOC_anthro','num_bc_a4_anthro','num_pom_a4_anthro', $
   'num_so4_a1_anthro-ag-ship','num_so4_a1_anthro-ene','num_so4_a2_anthro-res',  $
   'CH3CN_anthro', 'HCN_anthro']

;vertical files
;**** comment these lines to make surface files ****
surfvert='vertical'
specs = ['NO2_aircraft', 'bc_a4_aircraft', 'num_bc_a4_aircraft', 'SO2_aircraft']
;;   'SO2_anthro-ene', 'so4_a1_anthro-ene', 'num_so4_a1_anthro-ene']
;****

for ispec = 0,n_elements(specs)-1 do begin
  spec = specs[ispec]

  ;read 1750-2015 file
  files = File_search(path_orig+'emissions-cmip6_'+spec+'_'+surfvert+'_*_0.9x1.25_c2017*.nc',count=nfiles)
  file1 = files[nfiles-1]
  print,file1

  source_file = file1
  ncid = ncdf_open(file1)
  ncdf_varget,ncid,'lon',lon
  ncdf_varget,ncid,'lat',lat
  if (surfvert eq 'vertical') then begin
     ncdf_varget,ncid,'altitude',altitude
     ncdf_varget,ncid,'altitude_int',altitude_int
     nalt = n_elements(altitude)
  endif
  ncdf_varget,ncid,'date',date_o
  ncdf_varget,ncid,'time',time_o
  nlon = n_elements(lon)
  nlat = n_elements(lat)
  ntimo = n_elements(date_o)
  finq = ncdf_inquire(ncid)
  varnames = strarr(finq.nvars)
  ivar=0
  if (surfvert eq 'vertical') then ndim=4 else ndim=3
  for i=0,finq.nvars-1 do begin
    vinq = ncdf_varinq(ncid,i)
    if (vinq.ndims eq ndim) then begin
      varnames[ivar] = vinq.name
      ivar = ivar+1
    endif
  endfor
  varnames = varnames[0:ivar-1]
  nvars = n_elements(varnames)
  if (surfvert eq 'vertical') then begin
   anthro_o = fltarr(nvars,nlon,nlat,nalt,ntimo)
   longname = strarr(nvars)
   for ivar = 0,nvars-1 do begin
    ncdf_varget,ncid,varnames[ivar],emis1
    anthro_o[ivar,*,*,*,*] = emis1
    ncdf_attget,ncid,varnames[ivar],'molecular_weight',mw
    ncdf_attget,ncid,varnames[ivar],'long_name',lname
    longname[ivar] = string(lname)
    print,varnames[ivar],' ',longname[ivar]
   endfor
  endif else begin
   ;;; surface files
   anthro_o = fltarr(nvars,nlon,nlat,ntimo)
   longname = strarr(nvars)
   for ivar = 0,nvars-1 do begin
    ncdf_varget,ncid,varnames[ivar],emis1
    anthro_o[ivar,*,*,*] = emis1
    ncdf_attget,ncid,varnames[ivar],'molecular_weight',mw
    ncdf_attget,ncid,varnames[ivar],'long_name',lname
    longname[ivar] = string(lname)
    print,varnames[ivar],' ',longname[ivar]
   endfor
  endelse
  ncdf_close,ncid

  ind1 = where(date_o ge 20140101L)
  print,'2014: ',date_o[ind1[0]]
  
  if (surfvert eq 'vertical') then begin
   anthro_new = fltarr(nvars,nlon,nlat,nalt,ntim)
   ; repeat 2014 for 2015-2017
   for iyr=0,nyrs-1 do begin 
    for imon=0,11 do begin
     jtim = ind1[0]+imon
     itim = iyr*12 + imon
     if (imon eq 0) then print,'using ', date_o[jtim],' for ', date[itim]
     for ivar=0,nvars-1 do anthro_new[ivar,*,*,*,itim] = anthro_o[ivar,*,*,*,jtim]
    endfor
   endfor
  endif else begin
   ;;; surface files
   anthro_new = fltarr(nvars,nlon,nlat,ntim)
   for iyr=0,nyrs-1 do begin 
    for imon=0,11 do begin
     jtim = ind1[0]+imon
     itim = iyr*12 + imon
     if (imon eq 0) then print,'using ', date_o[jtim],' for ', date[itim]
     for ivar=0,nvars-1 do anthro_new[ivar,*,*,itim] = anthro_o[ivar,*,*,jtim]
    endfor
   endfor
  endelse

; write new file
  newfile = path_out+'emissions-cmip6_'+spec+'_'+surfvert+'_'+yrstr+'_0.9x1.25_c'+creation_date+'.nc'
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

  if (surfvert eq 'vertical') then begin
   zid = ncdf_dimdef(ncid,'altitude',nalt)
   zvarid = ncdf_vardef(ncid,'altitude',[zid],/float)
   ncdf_attput, ncid, zvarid,/char, 'units', 'km'
   ncdf_attput, ncid, zvarid,/char, 'long_name', 'Altitude'
   z1id = ncdf_dimdef(ncid,'altitude_int',nalt+1)
   zvarid = ncdf_vardef(ncid,'altitude_int',[z1id],/float)
   ncdf_attput, ncid, zvarid,/char, 'units', 'km'
   ncdf_attput, ncid, zvarid,/char, 'long_name', 'Altitude interfaces'
   for ivar = 0,nvars-1 do begin
    varname = varnames[ivar]
    varid = ncdf_vardef(ncid,varname,[xid,yid,zid,tid],/float)
    ncdf_attput,ncid,/char,varid,'units','molecules/cm2/s'
    ncdf_attput,ncid,/char,varid,'long_name',longname[ivar]
    ncdf_attput,ncid,/float,varid,'molecular_weight',mw
   endfor
  endif else begin
   ;***surface files
   for ivar = 0,nvars-1 do begin
    varname = varnames[ivar]
    varid = ncdf_vardef(ncid,varname,[xid,yid,tid],/float)
    ncdf_attput,ncid,/char,varid,'units','molecules/cm2/s'
    ncdf_attput,ncid,/char,varid,'long_name',longname[ivar]
    ncdf_attput,ncid,/float,varid,'molecular_weight',mw
   endfor
  endelse 

  ;Define global attributes
  ncdf_attput,ncid,/GLOBAL,/char,'data_title','Anthropogenic emissions of '+spec+' for CMIP6'
  ncdf_attput,ncid,/GLOBAL,/float,'molecular_weight',mw
  ncdf_attput,ncid,/GLOBAL,/char,'data_creator','Jean-Francois Lamarque (lamar@ucar.edu) and Louisa Emmons (emmons@ucar.edu)'
  ncdf_attput,ncid,/GLOBAL,/char,'data_summary','Emissions from the Community Emission Data System (CEDS) have been manipulated for use in CESM2 for CMIP6. 2014 repeated for 2015-2017. '+source_file
  ncdf_attput,ncid,/GLOBAL,/char,'cesm_contact','Louisa Emmons or Simone Tilmes'
  ncdf_attput,ncid,/GLOBAL,/char,'creation_date',creation_date
  ncdf_attput,ncid,/GLOBAL,/char,'update_date',sdate_today
  ncdf_attput,ncid,/GLOBAL,/char,'history','original files have been regridded, units changed, concatenated, some species combined or renamed.'
  ncdf_attput,ncid,/GLOBAL,/char,'data_script',thisfile
  ncdf_attput,ncid,/GLOBAL,/char,'data_source_url','http://www.globalchange.umd.edu/ceds/ceds-cmip6-data/'
  ncdf_attput,ncid,/GLOBAL,/char,'data_reference','Hoesly et al., GMD, 2017 (http://www.geosci-model-dev-discuss.net/gmd-2017-43/)'

  ncdf_control,ncid,/ENDEF

  ncdf_varput,ncid,'lon',lon
  ncdf_varput,ncid,'lat',lat
  ncdf_varput,ncid,'time',time
  ncdf_varput,ncid,'date',date
  if (surfvert eq 'vertical') then begin
   ncdf_varput,ncid,'altitude',altitude
   ncdf_varput,ncid,'altitude_int',altitude_int
   for ivar = 0,nvars-1 do begin
    varname = varnames[ivar]
    emis1 = reform(anthro_new[ivar,*,*,*,*])
    ncdf_varput,ncid,varname,emis1
   endfor
  endif else begin
   ;surface
   for ivar = 0,nvars-1 do begin
    varname = varnames[ivar]
    emis1 = reform(anthro_new[ivar,*,*,*])
    ncdf_varput,ncid,varname,emis1
   endfor
  endelse
  ncdf_close,ncid

endfor

end
