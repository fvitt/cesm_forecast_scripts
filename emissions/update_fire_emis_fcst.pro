; read daily NRT FINN emissions and write to emissions files for forecasts
; copy current day emissions to next Nday (10) days

pro update_fire_emis_fcst, date, path_fires, path_emis

sdate = strtrim(date,2)

Nday = 11  ;# of days to repeat emissions

resol='0.9x1.25'

specs = ['CO','NO','NO2','HCN','CH3CN','C2H2', 'C2H6','C2H4','C3H8', $
 'C3H6','BIGALK','BIGENE','BENZENE','TOLUENE','XYLENES','ISOP','TERPENES','HCOOH', 'CH3COOH', $ 
 'CH2O','CH3OH','C2H5OH','CH3CHO','CH3COCH3','MEK','BIGALD','CH3COCHO', $
 'CRESOL','GLYALD','HYAC','MACR','MVK','SO2','NH3','bc_a4','pom_a4', 'SVOC','IVOC','num_bc_a4','num_pom_a4']

for ispec = 0,n_elements(specs)-1 do begin
    spec = specs[ispec]

    ;open existing emissions file and update bb emis with nrt
    emisfile = path_emis+'emissions-fcst_'+spec+'_bb_surface_2018-2020_'+resol+'.nc'
    print,emisfile
    ncide = ncdf_open(emisfile,/write)
    ncdf_varget,ncide,'date',date_emis
    ncdf_varget,ncide,'lon',lon
    ncdf_varget,ncide,'lat',lat
    ntim = n_elements(date_emis)
    nlon = n_elements(lon)
    nlat = n_elements(lat)

    ;read fire emissions file for this day
    itim = where(date_emis eq date)
    itim = itim[0]
    print,date,': ',date_emis[itim]

    spec_finn = spec
    sf = 1.0
    if (spec eq 'AROMATIC') then spec_finn = 'TOLUENE'
    if (spec eq 'AROMATICS') then spec_finn = 'TOLUENE'
    if (spec eq 'TERPENES') then spec_finn = 'C10H16'
    if (spec eq 'ISOPRENE') then spec_finn = 'ISOP'
    if (spec eq 'TOLUENE') then begin
      spec_finn = 'TOLUENE'
      sf = 0.3
    endif
    if (spec eq 'BENZENE') then begin
      spec_finn = 'TOLUENE'
      sf = 0.6
    endif
    if (spec eq 'XYLENES') then begin
      spec_finn = 'TOLUENE'
      sf = 0.1
    endif
    if (spec eq 'CObb') then spec_finn = 'CO'
    if (spec eq 'OC1' or spec eq 'OC2') then begin 
      spec_finn = 'OC'
      sf = 0.5
    endif 
    if (spec eq 'CB1' or spec eq 'BC1') then begin 
      spec_finn = 'BC'
      sf = 0.8
    endif 
        if (spec eq 'CB2' or spec eq 'BC2') then begin 
      spec_finn = 'BC'
      sf = 0.2
    endif 
     if (spec eq 'bc_a4') then spec_finn = 'BC'
     if (spec eq 'pom_a4') then begin
       spec_finn = 'OC'
       sf = 1.4
     endif
 
    if (spec eq 'SVOC') then begin
       spec_finn = 'OC'
       mw_svoc = 310.
       mw_pom = 12.
       pom_oc = 1.4
       sf = 0.6*mw_pom/mw_svoc *pom_oc
    endif

    if (spec eq 'IVOC') then begin
      specs_ivoc = ['C3H6', 'C3H8', 'C2H6', 'C2H4', 'BIGENE', 'BIGALK', $
              'CH3COCH3', 'MEK', 'CH3CHO', 'CH2O', 'TOLUENE']   ;, 'BENZENE', 'XYLENES']
      mws_ivoc = [42, 44, 30, 28, 56, 72, 58, 72, 44, 30, 92]   ;, 78, 126]
      mw_ivoc = 184.
      bb_ivoc = fltarr(nlon,nlat)
      for jsp = 0,n_elements(specs_ivoc)-1 do begin
        spec_hc = specs_ivoc[jsp]
        file_hc = path_fires+'emissions_'+spec_hc+'_'+resol+'.nc'
        ;print,file_hc
        ncid = ncdf_open(file_hc)
        ncdf_varget,ncid,'date',date_fire
        ;print,date_emis[itim],date_fire
        ncdf_varget,ncid,'fire',emis_hc1_bb
        ncdf_close,ncid
        mw_hc = mws_ivoc[jsp]
        bb_ivoc = bb_ivoc + 0.2*emis_hc1_bb*mw_hc/mw_ivoc
      endfor
      bb_itim = bb_ivoc
    endif else if (spec eq 'num_bc_a4') then begin
      spec_finn = 'BC'
      diam = 0.134e-6
      rho = 1700.
      mw_bc = 12.
      mass_particle = rho *(!PI/6.) *(diam)^3  ;mass per particle (kg/particle)
      firefile = path_fires+'emissions_'+spec_finn+'_'+resol+'.nc'
      ;print,firefile
      ncidf = ncdf_open(firefile)
      ncdf_varget,ncidf,'date',date_fire
      ;print,date_emis[itim],date_fire
      ncdf_varget,ncidf,'fire',fire1
      ncdf_close,ncidf
      bb_itim = fire1 *mw_bc  /mass_particle  ;(particles/cm2/s)(molecules/mole)(g/kg)

    endif else  if (spec eq 'num_pom_a4') then begin
      spec_finn = 'OC'
      sf = 1.4
      diam = 0.134e-6
      rho = 1000.
      mw_pom = 12.
      mass_particle = rho *(!PI/6.) *(diam)^3  ;mass per particle (kg/particle)
      firefile = path_fires+'emissions_'+spec_finn+'_'+resol+'.nc'
      ;print,firefile
      ncidf = ncdf_open(firefile)
      ncdf_varget,ncidf,'date',date_fire
      ;print,date_emis[itim],date_fire
      ncdf_varget,ncidf,'fire',fire1
      ncdf_close,ncidf
      bb_itim = fire1*sf *mw_pom  /mass_particle  ;(particles/cm2/s)(molecules/mole)(g/kg)

   endif else begin
      firefile = path_fires+'emissions_'+spec_finn+'_'+resol+'.nc'
      ;print,firefile
      ncidf = ncdf_open(firefile)
      ncdf_varget,ncidf,'date',date_fire
      ;print,date_emis[itim],date_fire
      ncdf_varget,ncidf,'fire',fire1
      ncdf_close,ncidf
      bb_itim = fire1*sf
   endelse

   if (date_emis[itim] ne date_fire) then stop,'wrong date'+date_fire

   ;put new emissions in current day and following 10 days
   ncdf_varget,ncide,'bb',bb
   ;help,bb, bb_itim
   bb[*,*,itim] = bb_itim
   itmax = (itim+Nday) < (ntim-1)
   for itim1 = itim,itmax do bb[*,*,itim1] = bb_itim
   ncdf_varput,ncide,'bb',bb

   ncdf_close,ncide

endfor
skipemis:
end
