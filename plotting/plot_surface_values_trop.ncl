;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
;load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

begin
 print("Begin NCL plotting script")

; update to the right date
; get from script
; dir_output = "/glade/scratch/fvitt/GEOS5_frcst_data/20180302/model_files/"
; case_name = "f.e20.FWSD.f09_f09_mg17.forecast.008.ch"
; dir_plot =  "/glade/scratch/tilmes/GEOS5_frcst_data/20180302/plots/"
; dir_plot =  "/glade/scratch/tilmes/GEOS5_frcst_data/20171203/plots/"
; dir_plot =  "/glade/scratch/mmills/GEOS5_frcst_data/20171203/"
;;;;;;;;;;;;;;;;

;print("dir_output: "+dir_output)
;print("case_name: "+case_name)
;print("dir_plot: "+dir_plot)

; Constants
;
; NOTE: These are from CAM, shr_const_mod.F90.
 G = 9.80616 ; acceleration of gravity ~ m/s^2
 MWDAIR  = 28.966 ; molecular weight dry air ~ kg/kmole
 AVOGAD  = 6.02214e26 ; Avogadro's number ~ molecules/kmole
 Mair = MWDAIR/AVOGAD ; kg/molecule

 datesec4 = (/"00Z","03Z","06Z","09Z","12Z","15Z","18Z","21Z"/)

 srf_press = (/1000.,750.,500.,100.,85.,50.,10.,0.,0.,0./)
; srf_alt   = (/   0., 2.5, 5.5, 16.,20.,31.,0.,0.,0./)
 nSurfaces=dimsizes(srf_press)
 srf_n = srf_press+" hPa"
 srf_m = srf_press+"hPa"
 srf_n(ind(srf_press.eq.1000.))="Surface"
 srf_m(ind(srf_press.eq.1000.))="Surface"
 srf_n(nSurfaces-3:nSurfaces-1) = (/"Total Column","Trop. Column", "Strat. Column"/)
 srf_m(nSurfaces-3:nSurfaces-1) = (/"TotalColumn","TropColumn", "StratColumn"/)

 spec            = (/      "O3","CO",      "NOX", "EXTINCTdn","SO2",            "CLOX",      "SO4","BC","DUST",  "SSALT","CO01","CO02","CO03","CO04","CO05","CO06","CO07","CO08","CO09"/)
 spec_n          = (/"O~B~3~N~","CO","NO~B~x~N~","Extinction","SO~B~2~N~","ClO~B~x~N~","SO~B~4~N~","BC","Dust","Seasalt","CO_biomass","CO_NAm","CO_EU","CO_NAf","CO_WAs","CO_EAs","CO_SAm","CO_SAf","CO_Aus"/)
 spec_col        = (/        "",  "",         "",  "AODVISdn","",                   "",         "",  "",    "",       "","","","","","","","","",""/)
 spec_stratcol   = (/        "",  "",         "","AODVISstdn","",                   "",         "",  "",    "",       "","","","","","","","","",""/)
 spec_n_col      = (/"O~B~3~N~","CO","NO~B~x~N~",       "AOD","",                   "",         "",  "",    "",       "","","","","","","","","",""/)
 specLogContours = (/False, False, False, True, False, False, True, True, True, True,False, False, False,False, False, False,False, False, False/)
 spec_comb = (/False, False, True, False, False, False, True, True, True, True,False, False, False,False, False, False,False, False, False/)
 nSpec=dimsizes(spec)

 infile = systemfunc("ls -1 "+dir_output+case_name+".cam.h0.*nc")
 ny=dimsizes(infile)
 ff1 = addfile(infile(0),"r")
 lon=ff1->lon
 lat=ff1->lat
 lev=ff1->lev
 nlat = dimsizes(lat)
 nlon = dimsizes(lon)
 nlev = dimsizes(lev)
 hyam = ff1->hyam
 hybm = ff1->hybm
 hyai = ff1->hyai
 hybi = ff1->hybi
 interp = 2 ; log interpolation
 p0 = 1.e+05

 do n=0,ny-1
; read different cam history files
  print("infile: "+infile(n))
  f1 = addfile(infile(n),"r")
  ps = f1->PS
  z3 = f1->Z3
  z3 = z3/1000.

  press = pres_hybrid_ccm(ps,p0,hyam,hybm) ; units=Pa=kg m-1 s-2
  press = press/100. ; hPa

  pp1 = pres_hybrid_ccm(ps,p0,hyai,hybi) ; units=Pa=kg m-1 s-2
  
  date4 = f1->date
  ndate = dimsizes(date4)

  do sp = 0,nSpec-1
    if spec(sp).eq."O3" then
     factor_sp = (/1.e+09,1.e+09,1.e+09,1.e6,1.e6,1.e6,1.e6,1.,1.,1./)
     units_sp =  (/"ppbv","ppbv","ppbv","ppmv","ppmv","ppmv","ppmv","DU","DU","DU"/)
     fact_sp =   (/5.,10.,10.,0.2,0.2,0.25,1.,20.,5.,20./)
     offset_sp = (/10.,10.,10.,0.5,0.5,0.5,1.,100.,20.,100./)
    end if
    if spec(sp).eq."CO" .or. sp.GT.9 then
     factor_sp = (/1.e+09,1.e+09,1.e+09,1.e+09,1.e+09,1.e+09,1.e+09,1.e-17,1.e-17,1.e-17/)
     units_sp = (/"ppbv","ppbv","ppbv","ppbv","ppbv","ppbv","ppbv","10~S~17~N~ cm~S~-2~N~","10~S~17~N~ cm~S~-2~N~","10~S~17~N~ cm~S~-2~N~"/)
     fact_sp = (/20.,20.,20.,20.,20.,20.,20.,2.,2.,2./)
     offset_sp = (/50.,50.,50.,50.,50.,50.,50.,5.,5.,5./)
    end if
    if spec(sp).eq."NOX" then
     factor_sp = (/1.e+12,1.e+12,1.e+12,1.e+12,1.e+12,1.e+12,1.e+12,1.e-15,1.e-15,1.e-15/)
     units_sp = (/"pptv","pptv","pptv","pptv","pptv","pptv","pptv","10~S~15~N~ cm~S~-2~N~","10~S~15~N~ cm~S~-2~N~","10~S~15~N~ cm~S~-2~N~"/)
     fact_sp = (/400.,400.,400.,400.,400.,400.,400.,1.,1.,1./)
     offset_sp = (/0.,0.,0.,0.,0.,0.,0.,0.,0.,0./)
    end if
    if spec(sp).eq."CLOX" then
     factor_sp = (/1.e+12,1.e+12,1.e+12,1.e+12,1.e+12,1.e+12,1.e+12,1.e-13,1.e-13,1.e-13/)
     units_sp = (/"pptv","pptv","pptv","pptv","pptv","pptv","pptv","10~S~13~N~ cm~S~-2~N~","10~S~13~N~ cm~S~-2~N~","10~S~13~N~ cm~S~-2~N~"/)
     fact_sp = (/40.,40.,40.,40.,40.,40.,40.,3.,0.5,3./)
     offset_sp = (/0.,0.,0.,0.,0.,0.,0.,0.,0.,0./)
    end if
    if spec(sp).eq."EXTINCTdn" then
     factor_sp = (/1.e+3,1.e+3,1.e+3,1.e+3,1.e+3,1.e+3,1.e+3,1.,1.,1./)
     units_sp = (/"km~S~-1~N~","km~S~-1~N~","km~S~-1~N~","km~S~-1~N~","km~S~-1~N~","km~S~-1~N~","km~S~-1~N~","","",""/)
     fact_sp   = (/0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25/)
     offset_sp = (/0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001/)
    end if
    if spec(sp).eq."SO2" then
     factor_sp = (/1.e+09,1.e+09,1.e+09,1.e9,1.e9,1.e9,1.e9,1.e-15,1.e-15,1.e-15/)
     units_sp  = (/"ppbv","ppbv","ppbv","ppbv","ppbv","ppbv","ppbv","10~S~15~N~ cm~S~-2~N~","10~S~15~N~ cm~S~-2~N~","10~S~15~N~ cm~S~-2~N~"/)
     fact_sp   = (/5.,2.,1.,0.5,0.1,0.1,0.1,0.5,0.5,0.1/)
     offset_sp = (/5.,2.,1.,0.5,0.1,0.1,0.1,0.5,0.5,0.1/)
    end if
    if spec(sp).eq."SO4" then
     fact_so4 = 32.065/115.108999; to adjust mol wt NH4HSO4 to S
     factor_sp = (/fact_so4*1.e+09,fact_so4*1.e+09,fact_so4*1.e+09,fact_so4*1.e+09,fact_so4*1.e+09,fact_so4*1.e+09,fact_so4*1.e+09,fact_so4*1.e+09,fact_so4*1.e+09,fact_so4*1.e+09/)
     units_sp = (/"ppbm","ppbm","ppbm","ppbm","ppbm","ppbm","pbbm","10~S~-9~N~ g/m~S~2~N~","10~S~-9~N~ g/m~S~2~N~","10~S~-9~N~ g/m~S~2~N~"/)
     fact_sp = (/0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5/)
     offset_sp = (/0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001/)
     ;offset_sp = (/0.,0.,0.,0.,0.,0.,0.,0.,0.,0./)
    end if
    if spec(sp).eq."BC" then
     factor_sp = (/1.e+09,1.e+09,1.e+09,1.e+09,1.e+09,1.e+09,1.e+09,1.e+09,1.e+09,1.e+09/)
     units_sp = (/"ppbm","ppbm","ppbm","ppbm","ppbm","ppbm","pbbm","10~S~-9~N~ g/m~S~2~N~","10~S~-9~N~ g/m~S~2~N~","10~S~-9~N~ g/m~S~2~N~"/)
     fact_sp   = (/0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5/)
     offset_sp = (/0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001/)
     ;fact_sp = (/0.2,0.2,0.2,0.2,0.2,0.2,0.2,0.05,0.05,0.05/)
     ;offset_sp = (/0.,0.,0.,0.,0.,0.,0.,0.,0.,0./)
    end if
    if spec(sp).eq."DUST" .or. spec(sp).eq."SSALT" then
     factor_sp = (/1.e+09,1.e+09,1.e+09,1.e+09,1.e+09,1.e+09,1.e+09,1.e+09,1.e+09,1.e+09/)
     units_sp = (/"ppbm","ppbm","ppbm","ppbm","ppbm","ppbm","pbbm","10~S~-9~N~ g/m~S~2~N~","10~S~-9~N~ g/m~S~2~N~","10~S~-9~N~ g/m~S~2~N~"/)
     fact_sp   = (/0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5/)
     offset_sp = (/0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001,0.001/)
    end if
    if spec_comb(sp) then
     if spec(sp).eq."BC" then
      sp1= f1->bc_a4
      sp2= f1->bc_a1
      sp1=sp1+sp2
      delete(sp2)
     end if
     if spec(sp).eq."NOX" then
      sp1= f1->NO
      sp2= f1->NO2
      sp1=sp1+sp2
      delete(sp2)
     end if
     if spec(sp).eq."SO4" then
      sp1= f1->so4_a1
      sp2= f1->so4_a2
      sp3= f1->so4_a3
      sp1=sp1+sp2+sp3
      delete(sp2)
      delete(sp3)
     end if
     if spec(sp).eq."DUST" then
      sp1= f1->dst_a1
      sp2= f1->dst_a2
      sp3= f1->dst_a3
      sp1=sp1+sp2+sp3
      delete(sp2)
      delete(sp3)
     end if
     if spec(sp).eq."SSALT" then
      sp1= f1->ncl_a1
      sp2= f1->ncl_a2
      sp3= f1->ncl_a3
      sp1=sp1+sp2+sp3
      delete(sp2)
      delete(sp3)
     end if
    else
     sp1 = f1->$spec(sp)$
    end if

   if sp.gt.9 then
      nSurfaces = 3
   end if 
    do srf = 0,nSurfaces-1
     ;print(spec(sp)+" "+srf_n(srf))
   ; interpolate to surface
     if (srf_press(srf).eq.1000) then 
       sp1_srf = sp1(:,nlev-1,:,:)
     end if
     if (srf_press(srf).gt.0 .and. srf_press(srf).lt.1000) then
       sp_int =  int2p_n_Wrap(press,sp1,srf_press(srf),2,1)
       sp1_srf = sp_int(:,0,:,:) 
       delete(sp_int)
;       print(press(0,:,30,30))
;       print(max(sp1_srf))
;       print(min(sp1_srf)) 
     end if
     
     if srf_press(srf).eq.0 then 
;       print("Column name:"+spec_col(sp))
       if spec_col(sp).eq."" then ; if no precalculated column species, calculate column here
         delp = sp1 
         do k=0,nlev-1
           delp(:,k,:,:)=pp1(:,k+1,:,:)-pp1(:,k,:,:) ; Pa=kg m-1 s-2
         end do
         o31 = f1->O3
         if srf_m(srf).eq."TropColumn" then
          delp = where(o31.le.150.*1.e-09,delp,0.)
         end if
         if srf_m(srf).eq."StratColumn" then
           delp = where(o31.ge.150.*1.e-09,delp,0.)
         end if
         if (units_sp(0).eq."ppbm") then
          partPress=delp*sp1/G  ; delp(Pa=kg m-1 s-2)/(kg/molec * m s-2) = molec m-2
         else
          partPress=delp*sp1/(Mair*G)  ; delp(Pa=kg m-1 s-2)/(kg/molec * m s-2) = molec m-2
         end if
         copy_VarMeta(sp1,partPress)
         sp1_srf = dim_sum_n_Wrap(partPress,1) ; molec m-2
         sp1_srf = sp1_srf *1.e-4 ; molec cm-2
         delete(partPress)
         delete(delp)
         if (units_sp(srf).eq."DU") then
           sp1_srf = sp1_srf/2.687e16 ; convert molec cm-2 to Dobson Units
         end if
       else
         if srf_m(srf).eq."TotalColumn" then
           ;print("Column:"+spec_col(sp))
           sp1_srf = f1->$spec_col(sp)$
         end if
         if srf_m(srf).eq."StratColumn" then
           ;print("Column:"+spec_stratcol(sp))
           sp1_srf = f1->$spec_stratcol(sp)$
         end if 
         if srf_m(srf).eq."TropColumn" then
           ;print("Column:"+spec_col(sp)+"-"+spec_stratcol(sp))
           sp1_srf = f1->$spec_col(sp)$
           sp1_srf = sp1_srf-f1->$spec_stratcol(sp)$
         end if
       end if
     end if
     sp1_srf = factor_sp(srf) * sp1_srf

; plot each 4 dates
      do nd=0,ndate-1
      region = (/"","SH","NH","US"/)
      ;max_lat= (/90.,-30.,90.,56./)
      ;min_lat= (/-90.,-90.,30.,20./)
      max_lat= (/90.,-30.,90.,60./)
      min_lat= (/-90.,-90.,30.,10./)
      min_lon= (/-180.,-180.,-180.,-150./)
      max_lon= (/180.,180.,180.,-45./)

     if sp.gt.9 then
       nre = 0
     else
      nre = 3
     end if

      do re=0,nre

      ;;;;;;;;;;;;;;;;;;;;;;;;;
      ;
      ;    Make the Plot
      ;
      ;;;;;;;;;;;;;;;;;;;;;;;;;
        date = date4(nd)
        if re.eq.0 then
         plotname = dir_plot+case_name+"_"+date+"-"+datesec4(nd)+"_"+spec(sp)+"_"+srf_m(srf)
        else
         plotname = dir_plot+case_name+"_"+date+"-"+datesec4(nd)+"_"+spec(sp)+"_"+srf_m(srf)+"_"+region(re)
        end if


         wks = gsn_open_wks("png",plotname)
         gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
      ;  gsn_define_colormap(wks,"MPL_RdBu")        ; choose colormap
      ;  gsn_reverse_colormap(wks)                     ; reverse colormap

        res                      = True                  ; plot mods desired
        ;res@gsnAddCyclic         = True
        res@cnFillOn             = True                  ; turn on color fill
        res@cnLinesOn         = False                 ; no contour lines
        res@cnInfoLabelOn        = False
        res@cnLineLabelsOn    = False
        res@tmXTOn    = False
        res@tmXBOn = False
      ; res@gsnFrame          = False                 ; Do not draw plot
      ; res@gsnDraw           = False                 ; Do not advance frame
        res@tmYRMode          = "Automatic"          ; turn off special labels on right axis
      ; res@lbLabelBarOn      = False
        res@txFont = "helvetica-bold"
      ; res@gsnPaperOrientation = "landscape"
        res@cnLevelSelectionMode      = "ExplicitLevels"       ; manual levels
        res@cnMissingValFillColor = 0
      ; res@cnLevels       = sprintf("%7.2f",s1)
      ;  res@lbBoxLinesOn      = False
        res@lbOrientation     = "Vertical"
        res@lbTitleOn = True
        res@lbTitleString = units_sp(srf) 
        res@lbLabelFontHeightF = 0.018
        res@lbTitleFontHeightF = 0.02
        res@lbLabelStride  = 2
        res@cnInfoLabelOn        = False
        res@mpCenterLonF = 0
        res@cnFillMode        = "RasterFill"  ; Turn on raster fill
        res@gsnRightStringFontHeightF=0.022
        res@gsnLeftStringFontHeightF=0.022

        if specLogContours(sp) then
          con=offset_sp(srf) *10.0^( fact_sp(srf)*(/0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16/) )     
        else
          con=offset_sp(srf) + fact_sp(srf)*(/0,1,2,3,4,5,6,7,8,9,10,12.5,15,17.5,20/)
        end if
        res@cnLevels = con(:)

        res@gsnRightString     =  srf_n(srf) 
        ;print(max(sp1_srf(nd,:,:)))
        ;print(min(sp1_srf(nd,:,:)))
        
        res@gsnLeftString = spec_n(sp)+" "+date+"-"+datesec4(nd)
        if (srf_press(srf).eq.0) then
          res@gsnLeftString = spec_n_col(sp)+" "+date+"-"+datesec4(nd)         
        end if
        res@mpLimitMode         = "LatLon"     ; limit map via lat/lon
        res@mpMaxLatF           = max_lat(re)                 ; specify min lat
        res@mpMinLatF           = min_lat(re)                 ; specify min lat
        res@mpMaxLonF           = max_lon(re)                 ; specify min lat
        res@mpMinLonF           = min_lon(re)                 ; specify min lat

        if re.eq.3 then
          res@mpFillOn              = False           ; turn off map fill
          res@mpOutlineDrawOrder    = "PostDraw"      ; draw continental outline last
          res@mpOutlineBoundarySets = "GeophysicalAndUSStates" ; state boundaries
        end if

        if re.eq.0 .or. re.eq.3 then
          plot = gsn_csm_contour_map(wks,sp1_srf(nd,:,:),res)
        else
          res@gsnPolar = region(re)
          plot = gsn_csm_contour_map_polar(wks,sp1_srf(nd,:,:),res)
        end if
      
      ; frame(wks)
      ; draw(wks)
      ;-------------------------------------------------------------------------
       delete(plot)
       delete(con)
       delete(res)
      end do ; region
     end do ; ndate
     delete(sp1_srf)
    end do  ; srf
    delete(sp1)
   end do   ; spc
   delete(press)
   delete(pp1)
   delete(date4)
   delete(date)
   delete(ps)
   delete(z3)
   nSurfaces=dimsizes(srf_press)
 end do   ; nfile

 print("END NCL plotting script")


end
