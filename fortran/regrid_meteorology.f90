program main
  implicit none

  character(len=512) :: infile='', outfile=''
  integer :: nlats=0, nlons=0
  integer :: i, m, rc
  character(len=512) :: arg

  m = iargc()

  i=0

  do while(i<m)
     i = i+1
     call getarg(i, arg)
     select case(trim(adjustl(arg)))
       case("-nlats")
          i = i+1
          call getarg(i, arg)
          read(arg,*) nlats
          write(*,*) "nlats: ",nlats
       case("-nlons")
          i = i+1
          call getarg(i, arg)
          read(arg,*) nlons
          write(*,*) "nlons: ",nlons
       case("-infile")
          i = i+1
          call getarg(i, arg)
          infile = trim(adjustl(arg))
          write(*,*) "infile: ",trim(infile)
       case("-outfile")
          i = i+1
          call getarg(i, arg)
          outfile = trim(adjustl(arg))
          write(*,*) "outfile: ",trim(outfile)
       case default
          write(*,*)"Option ",trim(adjustl(arg))," unknown"
          call print_help()
     end select
  end do
  if (len_trim(infile)==0 .or. len_trim(outfile)==0 .or. nlons==0 .or. nlats==0) then
     call print_help()
  endif

  call regrid_met_data( nlats, nlons, infile, outfile, rc )
  if (rc==0) then
    stop 0
  else
    stop -1
  endif

end program main

subroutine print_help()
  print '(a)', 'usage:'
  print '(a)', ''
  print '(a)', 'cmdline must include all options:'
  print '(a)', ''
  print '(a)', '  -infile     input file path'
  print '(a)', '  -outfile    output file path'
  print '(a)', '  -nlons      number of longitudes in output file'
  print '(a)', '  -nlats      number of latitudes in output file'
  print '(a)', ''
  stop 9
end subroutine print_help

subroutine regrid_met_data( newLats, newLons, inFileName, outFileName, rc )
  use netcdf

  implicit none 

 ! args
  integer,intent(in) :: newLats, newLons
  character(len=*), intent(in) :: inFileName, outFileName
  integer, intent(out) :: rc

 ! local vars
  integer :: i
  integer :: n

  integer :: irec, ilev
  integer :: psid, tsid, tid, qid,dateid,datesecid,latid,lonid,levid,hyamid,hybmid,hyaiid,hybiid,timeid
  integer :: phiid, landid, qflxid, hflxid, snowhid, fsdsid, soilwid, tauxid, tauyid, uid, vid
  integer :: newLatDimID,newLonDimID,newLevDimID,newiLevDimID,newRecordDimID
  integer :: newLatVarId,newLonVarId,newLevVarId,newiLevVarId,newRecordVarID,newDateVarId,newDatesecVarId
  integer :: newHyamVarId,newHybmVarId,newHyaiVarId,newHybiVarId, newPSvarID, newTSvarID
  integer :: newTvarId, newQvarId, newPHISvarId, newOROvarId, newQFLXvarid, newSHFLXvarid
  integer :: newALBEDOvarID, newSNOWHvarID, newFSDSvarID, newSOILWvarID
  integer :: newTAUXvarId, newTAUYvarId, newUvarId, newVvarid
  integer :: time_vals(8)
  integer :: out_ncid
  integer :: ncid, status, iLevDimID, LevDimID, LonDimID, LatDimID, RecordDimID, DateDimID
  integer :: niLevs, nLevs, nLats, nLons, nRecords,nDate
  character(len = nf90_max_name) :: RecordDimName
  integer, parameter :: nvars2d=9
  integer, parameter :: nvars3d=2
  integer, parameter :: nvars3d_wind=2

  real, allocatable :: oldLat(:), oldLon(:)

  real, allocatable :: lev(:)
  real, allocatable :: hyam(:)
  real, allocatable :: hybm(:)

  real, allocatable :: hyai(:)
  real, allocatable :: hybi(:)
  real, allocatable :: da(:,:,:)
  real, allocatable :: db(:,:,:)
  real, allocatable :: d3a(:,:,:,:)
  real, allocatable :: d3b(:,:,:,:)
  real, allocatable :: ua(:,:,:,:),va(:,:,:,:)
  real, allocatable :: ub(:,:,:,:),vb(:,:,:,:)

  integer, allocatable :: date(:),datesec(:)
  real, allocatable :: time(:)

  real :: newLat(newLats)
  real :: newLon(newLons)

  character(len=128) :: hist_str

  rc = -1

  call date_and_time( values=time_vals)
  write(*,fmt='(" time: ",I2.2,":",I2.2,":",I2.2)') time_vals(5:7)

  status = nf90_open(inFileName, nf90_nowrite, ncid)
  if (status /= nf90_noerr) call handle_err(status)

  ! Get ID of unlimited dimension
  status = nf90_inquire(ncid, unlimitedDimId = RecordDimID)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_inq_dimid(ncid, "ilev", iLevDimID)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_dimid(ncid, "lev", LevDimID)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_dimid(ncid, "lat", LatDimID)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_dimid(ncid, "lon", LonDimID)
  if (status /= nf90_noerr) call handle_err(status)


  ! How many values of "ilev" are there?
  status = nf90_inquire_dimension(ncid, iLevDimID, len = niLevs)
  if (status /= nf90_noerr) call handle_err(status)

  ! How many values of "lev" are there?
  status = nf90_inquire_dimension(ncid, LevDimID, len = nLevs)
  ! 3D scalar fields
  if (status /= nf90_noerr) call handle_err(status)

  ! How many values of "lat" are there?
  status = nf90_inquire_dimension(ncid, LatDimID, len = nLats)
  if (status /= nf90_noerr) call handle_err(status)

  ! How many values of "lon" are there?
  status = nf90_inquire_dimension(ncid, LonDimID, len = nLons)
  if (status /= nf90_noerr) call handle_err(status)

  ! What is the name of the unlimited dimension, how many records are there?
  status = nf90_inquire_dimension(ncid, RecordDimID, name = RecordDimName, len = nRecords)
  if (status /= nf90_noerr) call handle_err(status)
  
  allocate(date(nRecords),datesec(nRecords))
  allocate(lev(nLevs),hyam(nLevs),hybm(nLevs))
  allocate(time(nRecords))
  allocate(oldLon(nLons))
  allocate(oldLat(nLats))
  allocate(hyai(niLevs),hybi(niLevs))
  allocate( da(nLons,nLats,nRecords) )
  allocate( db(newLons,newLats,nRecords) )
  allocate( d3a(nLons,nLats,nLevs,nRecords) )
  allocate( d3b(newLons,newLats,nLevs,nRecords) )
  allocate( ua(nLons,nLats,nLevs,nRecords) )
  allocate( va(nLons,nLats,nLevs,nRecords) )
  allocate( ub(newLons,newLats,nLevs,nRecords) )
  allocate( vb(newLons,newLats,nLevs,nRecords) )

  status = nf90_inq_varid(ncid, 'time', timeid)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_get_var(ncid, timeid, time)
  if (status /= nf90_noerr) call handle_err(status)
  !print*,time

  status = nf90_inq_varid(ncid, 'date', dateid)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_get_var(ncid, dateid, date)
  if (status /= nf90_noerr) call handle_err(status)
  !print*,date

  status = nf90_inq_varid(ncid, 'datesec', datesecid)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_get_var(ncid, datesecid, datesec)
  if (status /= nf90_noerr) call handle_err(status)
  !print*,datesec


  status = nf90_inq_varid(ncid, 'lev', levid)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_get_var(ncid, levid, lev)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'lon', lonid)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_inq_varid(ncid, 'lat', latid)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_get_var(ncid, lonid, oldLon)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_get_var(ncid, latid, oldLat)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'hyam', hyamid)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_get_var(ncid, hyamid, hyam)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'hybm', hybmid)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_get_var(ncid, hybmid, hybm)
  if (status /= nf90_noerr) call handle_err(status)


  status = nf90_inq_varid(ncid, 'hyai', hyaiid)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_get_var(ncid, hyaiid, hyai)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'hybi', hybiid)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_get_var(ncid, hybiid, hybi)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'T', tid)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'Q', qid)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'PHIS', phiid)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'ORO', landid)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'QFLX', qflxid)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'SHFLX', hflxid)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'PS', psid)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'U', uid)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'V', vid)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'TAUX', tauxid)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'TAUY', tauyid)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'SNOWH', snowhid)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'FSDS', fsdsid)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'SOILW', soilwid)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_inq_varid(ncid, 'TS', tsid)
  if (status /= nf90_noerr) call handle_err(status)

  ! setup output file
  status = nf90_create( outFileName, nf90_clobber, out_ncid)
  if (status /= nf90_noerr) call handle_err(status)

  ! dimensions in out file
  status = nf90_def_dim(out_ncid, "lat", newLats, newLatDimID)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_def_dim(out_ncid, "lon", newLons, newLonDimID)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_def_dim(out_ncid, "lev", nLevs, newLevDimID)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_def_dim(out_ncid, "time", nf90_unlimited, newRecordDimID)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_def_dim(out_ncid, "ilev", niLevs, newiLevDimID)
  if (status /= nf90_noerr) call handle_err(status)
  
  ! Define the coordinate variables
  status = nf90_def_var(out_ncid, "lat",     nf90_float, (/ newLatDimID /),  newLatVarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, latid, "units", out_ncid, newLatVarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, latid, "long_name", out_ncid, newLatVarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "lon",     nf90_float, (/ newLonDimID /),  newLonVarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, lonid, "units", out_ncid, newLonVarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, lonid, "long_name", out_ncid, newLonVarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "lev",     nf90_float, (/ newLevDimID /),  newLevVarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, levid, "units", out_ncid, newLevVarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, levid, "long_name", out_ncid, newLevVarId )
  if (status /= nf90_noerr) call handle_err(status)

  !print*,'start time'
  status = nf90_def_var(out_ncid, "time",     nf90_float, (/ newRecordDimID /),  newRecordVarID)
  if(status /= nf90_NoErr) call handle_err(status)
  !print*,newRecordVarID
  status = nf90_copy_att(ncid, timeid, "units", out_ncid, newRecordVarID)
 ! status = nf90_put_att(out_ncid, newRecordVarID, "units", "days since "//trim(year)//"-01-01 00:00:00")
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, timeid, "long_name", out_ncid, newRecordVarID)
  if (status /= nf90_noerr) call handle_err(status)
 !status = nf90_copy_att(ncid, timeid, "calendar", out_ncid, newRecordVarID)
 !if (status /= nf90_noerr) call handle_err(status)
  !print*,'end time'

  status = nf90_def_var(out_ncid, "ilev",     nf90_float, (/ newiLevDimID /),  newiLevVarID)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, levid, "units", out_ncid, newLevVarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, levid, "long_name", out_ncid, newLevVarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "date",    nf90_int,   (/ newRecordDimID /), newDateVarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, dateid, "long_name", out_ncid, newDateVarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "datesec", nf90_int,   (/ newRecordDimID /), newDatesecVarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, datesecid, "long_name", out_ncid, newDatesecVarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "hyam",     nf90_float, (/ newLevDimID /),  newHyamVarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, hyamid, "long_name", out_ncid, newHyamVarId )
  if (status /= nf90_noerr) call handle_err(status)
 
  status = nf90_def_var(out_ncid, "hybm",     nf90_float, (/ newLevDimID /),  newHybmVarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, hybmid, "long_name", out_ncid, newHybmVarId )
  if (status /= nf90_noerr) call handle_err(status)
  
  status = nf90_def_var(out_ncid, "hyai",     nf90_float, (/ newiLevDimID /),  newHyaiVarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, hyaiid, "long_name", out_ncid, newHyaiVarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "hybi",     nf90_float, (/ newiLevDimID /),  newHybiVarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, hybiid, "long_name", out_ncid, newHybiVarId )
  if (status /= nf90_noerr) call handle_err(status)
  
  ! Define the data variables
  status = nf90_def_var(out_ncid, "PS", nf90_float, (/ newLonDimId, newLatDimID, newRecordDimID /), newPSvarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, psid, "units", out_ncid, newPSvarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, psid, "long_name", out_ncid, newPSvarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "U", nf90_float, (/ newLonDimId, newLatDimID, newLevDimID, newRecordDimID /), newUvarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, uid, "units", out_ncid, newUvarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, uid, "long_name", out_ncid, newUvarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "V", nf90_float, (/ newLonDimId, newLatDimID, newLevDimID, newRecordDimID /), newVvarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, vid, "units", out_ncid, newVvarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, vid, "long_name", out_ncid, newVvarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "TAUX", nf90_float, (/ newLonDimId, newLatDimID, newRecordDimID /), newTAUXvarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, tauxid, "units", out_ncid, newTAUXvarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, tauxid, "long_name", out_ncid, newTAUXvarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "TAUY", nf90_float, (/ newLonDimId, newLatDimID, newRecordDimID /), newTAUYvarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, tauyid, "units", out_ncid, newTAUYvarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, tauyid, "long_name", out_ncid, newTAUYvarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "SNOWH", nf90_float, (/ newLonDimId, newLatDimID, newRecordDimID /), newSNOWHvarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, snowhid, "units", out_ncid, newSNOWHvarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, snowhid, "long_name", out_ncid, newSNOWHvarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "FSDS", nf90_float, (/ newLonDimId, newLatDimID, newRecordDimID /), newFSDSvarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, fsdsid, "units", out_ncid, newFSDSvarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, fsdsid, "long_name", out_ncid, newFSDSvarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "SOILW", nf90_float, (/ newLonDimId, newLatDimID, newRecordDimID /), newSOILWvarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, soilwid, "units", out_ncid, newSOILWvarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, soilwid, "long_name", out_ncid, newSOILWvarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "TS", nf90_float, (/ newLonDimId, newLatDimID, newRecordDimID /), newTSvarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, tsid, "units", out_ncid, newTSvarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, tsid, "long_name", out_ncid, newTSvarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "T", nf90_float, (/ newLonDimId, newLatDimID, newLevDimID, newRecordDimID /), newTvarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, tid, "units", out_ncid, newTvarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, tid, "long_name", out_ncid, newTvarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "Q", nf90_float, (/ newLonDimId, newLatDimID, newLevDimID, newRecordDimID /), newQvarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, qid, "units", out_ncid, newQvarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, qid, "long_name", out_ncid, newQvarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "PHIS", nf90_float, (/ newLonDimId, newLatDimID, newRecordDimID /), newPHISvarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, phiid, "units", out_ncid, newPHISvarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, phiid, "long_name", out_ncid, newPHISvarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "ORO", nf90_float, (/ newLonDimId, newLatDimID, newRecordDimID /), newOROvarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, landid, "units", out_ncid, newOROvarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, landid, "long_name", out_ncid, newOROvarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "QFLX", nf90_float, (/ newLonDimId, newLatDimID, newRecordDimID /), newQFLXvarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, qflxid, "units", out_ncid, newQFLXvarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, qflxid, "long_name", out_ncid, newQFLXvarId )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_def_var(out_ncid, "SHFLX", nf90_float, (/ newLonDimId, newLatDimID, newRecordDimID /), newSHFLXvarId)
  if(status /= nf90_NoErr) call handle_err(status)
  status = nf90_copy_att(ncid, hflxid, "units", out_ncid, newSHFLXvarId )
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_copy_att(ncid, hflxid, "long_name", out_ncid, newSHFLXvarId )
  if (status /= nf90_noerr) call handle_err(status)
  
  call date_and_time( values=time_vals)
  write(hist_str,fmt='("created by regrid_met_data : ",I4.4,"-",I2.2,"-",I2.2," ",I2.2,":",I2.2,":",I2.2)')  time_vals(1:3), time_vals(5:7)
  status = nf90_put_att(out_ncid, NF90_GLOBAL, 'history', trim(hist_str) )
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_put_att(out_ncid, NF90_GLOBAL, 'input_file', trim(inFileName) )
  if (status /= nf90_noerr) call handle_err(status)

  ! end of define mode
  status = nf90_enddef(out_ncid)
  if (status /= nf90_noerr) call handle_err(status)

  do i=1,newlats
    newLat(i) = -90.d0+ (float(i)-1.d0)*180.d0/(float(newLats)-1.d0)
  enddo

  do i=1,newlons
    newLon(i) = (float(i)-1.)*360./float(newLons)
  enddo

  status = nf90_put_var(out_ncid, newLonVarId, newLon)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_put_var(out_ncid, newLatVarId, newLat)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_put_var(out_ncid, newRecordVarID, time)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_put_var(out_ncid, newDateVarId, date)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_put_var(out_ncid, newDatesecVarId, datesec)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_put_var(out_ncid, newLevVarId, lev)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_put_var(out_ncid, newHyamVarId, hyam)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_put_var(out_ncid, newHybmVarId, hybm)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_put_var(out_ncid, newHyaiVarId, hyai)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_put_var(out_ncid, newHybiVarId, hybi)
  if (status /= nf90_noerr) call handle_err(status)

  ! linear interpolate
!  call MAP_A2A
!  variables for A2A Interpolation, 2-dim: PS, PHIS, ORO, QFLX, SHFLX, SNOWH, TAUX, TAUY, TS, ALBEDO
!  variables for A2A Interpolation 3-dim: Q, T
!  variables for D2D Interpolation 3-dim: U, V
!do i=1,nvar2d
!     Do are-weighted interpolation and write out
! linear interpolate

  status = nf90_get_var(ncid, psid, da)
  if (status /= nf90_noerr) call handle_err(status)
  call MAP_A2A(nLons,nLats,1,nRecords,da,newLons,newLats,db,0,0)
  status = nf90_put_var(out_ncid, newPSvarId, db)
  if (status /= nf90_noerr) call handle_err(status)

  print*, '2d grid A2A Interpolation'

  status = nf90_get_var(ncid, phiid, da)
  if (status /= nf90_noerr) call handle_err(status)
  call MAP_A2A(nLons,nLats,1,nRecords,da,newLons,newLats,db,0,0)
  status = nf90_put_var(out_ncid, newPHISvarId, db)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_get_var(ncid, landid, da)
  if (status /= nf90_noerr) call handle_err(status)
  call MAP_A2A(nLons,nLats,1,nRecords,da,newLons,newLats,db,0,0)
  status = nf90_put_var(out_ncid, newOROvarId, db)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_get_var(ncid, snowhid, da)
  if (status /= nf90_noerr) call handle_err(status)
  call MAP_A2A(nLons,nLats,1,nRecords,da,newLons,newLats,db,0,0)
! WHERE(db>500.) 
!    db = 0.
! elsewhere 
!  db=db
! end where
  status = nf90_put_var(out_ncid, newSNOWHvarId, db)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_get_var(ncid, fsdsid, da)
  if (status /= nf90_noerr) call handle_err(status)
  call MAP_A2A(nLons,nLats,1,nRecords,da,newLons,newLats,db,0,0)
  status = nf90_put_var(out_ncid, newFSDSvarId, db)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_get_var(ncid, soilwid, da)
  if (status /= nf90_noerr) call handle_err(status)
  call MAP_A2A(nLons,nLats,1,nRecords,da,newLons,newLats,db,0,0)
  status = nf90_put_var(out_ncid, newSOILWvarId, db)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_get_var(ncid, qflxid, da)
  if (status /= nf90_noerr) call handle_err(status)
  call MAP_A2A(nLons,nLats,1,nRecords,da,newLons,newLats,db,0,0)
  status = nf90_put_var(out_ncid, newQFLXvarId, db)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_get_var(ncid, hflxid, da)
  if (status /= nf90_noerr) call handle_err(status)
  call MAP_A2A(nLons,nLats,1,nRecords,da,newLons,newLats,db,0,0)
  status = nf90_put_var(out_ncid, newSHFLXvarId, db)
  if (status /= nf90_noerr) call handle_err(status)
  
  status = nf90_get_var(ncid, tauxid, da)
  if (status /= nf90_noerr) call handle_err(status)
  call MAP_A2A(nLons,nLats,1,nRecords,da,newLons,newLats,db,0,0)
  status = nf90_put_var(out_ncid, newTAUXvarId, db)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_get_var(ncid, tauyid, da)
  if (status /= nf90_noerr) call handle_err(status)
  call MAP_A2A(nLons,nLats,1,nRecords,da,newLons,newLats,db,0,0)
  status = nf90_put_var(out_ncid, newTAUYvarId, db)
  if (status /= nf90_noerr) call handle_err(status)
  
  status = nf90_get_var(ncid, tsid, da)
  if (status /= nf90_noerr) call handle_err(status)
  call MAP_A2A(nLons,nLats,1,nRecords,da,newLons,newLats,db,0,0)
  status = nf90_put_var(out_ncid, newTSvarId, db)
  if (status /= nf90_noerr) call handle_err(status)
  
  call date_and_time( values=time_vals)
  write(*,fmt='(" time: ",I2.2,":",I2.2,":",I2.2)') time_vals(5:7)

! 3d grid A2A Interpolation
  print*, '3d grid A2A Interpolation'
!  variables for A2A Interpolation 3-dim: Q, T
  status = nf90_get_var(ncid, qid, d3a)
  if (status /= nf90_noerr) call handle_err(status)
  call MAP_A2A(nLons,nLats,nLevs,nRecords,d3a,newLons,newLats,d3b,0,0)
  status = nf90_put_var(out_ncid, newQvarId, d3b)
  if (status /= nf90_noerr) call handle_err(status)
  status = nf90_get_var(ncid, tid, d3a)
  if (status /= nf90_noerr) call handle_err(status)
  call MAP_A2A(nLons,nLats,nLevs,nRecords,d3a,newLons,newLats,d3b,0,0)
  status = nf90_put_var(out_ncid, newTvarId, d3b)
  if (status /= nf90_noerr) call handle_err(status)

!  variables for D2D Interpolation 3-dim: U, V
 ! 3D scalar fields

  status = nf90_get_var(ncid, uid, ua)
  if (status /= nf90_noerr) call handle_err(status)
! call MAP_D2D_U(nLons,nLats,nLevs,nRecords,ua,newLons,newLats,ub,0,0)
  call MAP_A2A(nLons,nLats,nLevs,nRecords,ua,newLons,newLats,ub,0,1)
  status = nf90_put_var(out_ncid, newUvarId, ub)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_get_var(ncid, vid, va)
  if (status /= nf90_noerr) call handle_err(status)
! call MAP_D2D_V(nLons,nLats,nLevs,nRecords,va,newLons,newLats,vb,0,0)
  call MAP_A2A(nLons,nLats,nLevs,nRecords,va,newLons,newLats,vb,0,1)
  status = nf90_put_var(out_ncid, newVvarId, vb)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_close(ncid)
  if (status /= nf90_noerr) call handle_err(status)

  status = nf90_close(out_ncid)
  if (status /= nf90_noerr) call handle_err(status)

  call date_and_time( values=time_vals)
  write(*,fmt='(" time: ",I2.2,":",I2.2,":",I2.2)') time_vals(5:7)

  write(*,fmt='(a)') 'FINISHED file :'//trim(outfilename)

  deallocate(date,datesec)
  deallocate(lev,hyam,hybm)
  deallocate(time)
  deallocate(oldLon)
  deallocate(oldLat)
  deallocate(hyai,hybi)
  deallocate( da )
  deallocate( db )
  deallocate( d3a )
  deallocate( d3b )
  deallocate( ua )
  deallocate( va )
  deallocate( ub )
  deallocate( vb )

  rc = 0

end subroutine regrid_met_data

subroutine MAP_A2A( im, jm, km, tm, q1, in, jn, q2, ig, iv)
  ! Horizontal arbitrary grid to arbitrary grid conservative high-order mapping
! S.-J. Lin

      implicit none
      integer im, jm, km, tm, kt
      integer in, jn, jj
      integer ig                ! ig=0: pole to pole; ig=1 j=1 is half-dy
                                ! north of south pole
      integer iv                ! iv=0: scalar; iv=1: vector
      real pi

      real q1(im,jm,*)

      real lon1(im+1)
      real lon2(in+1)

      real sin1(jm+1)
      real sin2(jn+1)
      real dx1, dx2, dy1, dy2

! Output
      real q2(in,jn,*)
! local
      integer i,j,k,m
!fvitt      real qtmp(im,jm)
      real qtmp(in,jm)
!      km=1

      pi=4.*atan(1.)
 
      dx1 = 360./float(im)
      dx2 = 360./float(in)
      dy1 = pi/float(jm-1)
      dy2 = pi/float(jn-1)
 
      do i=1,im+1
         lon1(i) = dx1 * (-0.5 + (i-1) )
      enddo
      do i=1,in+1
         lon2(i) = dx2 * (-0.5 + (i-1) )
      enddo
 
      sin1(   1) = -1.
      sin1(jm+1) =  1.
      do j=2,jm
         sin1(j) = sin( -0.5*pi + dy1*(-0.5+float(j-1)) )
      enddo

      sin2(   1) = -1.
      sin2(jn+1) =  1.
      do j=2,jn
         sin2(j) = sin( -0.5*pi + dy2*(-0.5+float(j-1)) )
      enddo


      do m=1, tm
      do k=1, km
         kt = (m-1)*km + k
        if( im .eq. in ) then
            do j=1,jm-ig
               do i=1,im
                  qtmp(i,j+ig) = q1(i,j+ig,kt)
               enddo
            enddo
        else
! Mapping in the E-W direction
         call xmap(im, jm-ig, lon1, q1(1,1+ig,kt), in, lon2, qtmp(1,1+ig) )
        endif

        if( jm .eq. jn ) then
            do j=1,jm-ig
               do i=1,in
                  q2(i,j+ig,kt) = qtmp(i,j+ig)
               enddo
            enddo
        else
! Mapping in the N-S direction
         call ymap(in, jm, sin1, qtmp(1,1+ig), jn, sin2, q2(1,1+ig,kt), ig, iv)
        endif
      enddo
      enddo

      end subroutine MAP_A2A
!#######################################################################
!!$  subroutine MAP_D2D_v( im, jm, km, tm, q1,in, jn, q2, ig, iv)
!!$
!!$! Horizontal D-grid VWND to D- grid conservative high-order mapping
!!$
!!$      implicit none
!!$      integer im, jm, km, tm, kt
!!$      integer in, jn, jj
!!$      integer ig                ! ig=0: pole to pole; ig=1 j=1 is half-dy
!!$                                ! north of south pole
!!$      integer iv                ! iv=0: scalar; iv=1: vector
!!$      real pi
!!$
!!$      real q1(im,jm,*)
!!$
!!$      real lon1(im+1)
!!$      real lon2(in+1)
!!$
!!$      real sin1(jm+1)
!!$      real sin2(jn+1)
!!$      real dx1, dx2, dy1, dy2
!!$
!!$! Output
!!$      real q2(in,jn,*)
!!$! local
!!$      integer i,j,k,m
!!$!fvitt      real qtmp(im,jm)
!!$      real qtmp(in,jm)
!!$!      km=1
!!$
!!$      pi=4.*atan(1.)
!!$!
!!$      dx1 = 360./float(im)
!!$      dx2 = 360./float(in)
!!$      dy1 = pi/float(jm-1)
!!$      dy2 = pi/float(jn-1)
!!$!
!!$      do i=1,im+1
!!$         lon1(i) = dx1 * (-1.0 + (i-1) )
!!$      enddo
!!$      do i=1,in+1
!!$         lon2(i) = dx2 * (-1.0 + (i-1) )
!!$      enddo
!!$!
!!$      sin1(   1) = -1.
!!$      sin1(jm+1) =  1.
!!$      do j=2,jm
!!$         sin1(j) = sin( -0.5*pi + dy1*(-0.5+float(j-1)) )
!!$      enddo
!!$
!!$      sin2(   1) = -1.
!!$      sin2(jn+1) =  1.
!!$      do j=2,jn
!!$         sin2(j) = sin( -0.5*pi + dy2*(-0.5+float(j-1)) )
!!$      enddo
!!$
!!$
!!$      do m=1, tm
!!$      do k=1, km
!!$         kt = (m-1)*km + k
!!$        if( im .eq. in ) then
!!$            do j=1,jm-ig
!!$               do i=1,im
!!$                  qtmp(i,j+ig) = q1(i,j+ig,kt)
!!$               enddo
!!$            enddo
!!$        else
!!$! Mapping in the E-W direction
!!$         call xmap(im, jm-ig, lon1, q1(1,1+ig,kt), in, lon2, qtmp(1,1+ig) )
!!$        endif
!!$
!!$        if( jm .eq. jn ) then
!!$            do j=1,jm-ig
!!$               do i=1,in
!!$                  q2(i,j+ig,kt) = qtmp(i,j+ig)
!!$               enddo
!!$            enddo
!!$        else
!!$! Mapping in the N-S direction
!!$         call ymap(in, jm, sin1, qtmp(1,1+ig), jn, sin2, q2(1,1+ig,kt), ig, iv)
!!$        endif
!!$      enddo
!!$      enddo
!!$
!!$      end subroutine MAP_D2D_v
!!$
!!$      subroutine MAP_D2D_u( im, jm, km, tm, q1, in, jn, q2, ig, iv)
!!$
!!$! Horizontal D-grid UWND to D-grid conservative high-order mapping
!!$
!!$      implicit none
!!$      integer im, jm, km, tm, kt
!!$      integer in, jn, jj
!!$      integer ig                ! ig=0: pole to pole; ig=1 j=1 is half-dy
!!$                                ! north of south pole
!!$      integer iv                ! iv=0: scalar; iv=1: vector
!!$      real ar
!!$
!!$      real q1(im,jm,*)
!!$
!!$      real lon1(im+1)
!!$      real lon2(in+1)
!!$      real lat1(jm+1)
!!$      real lat2(jn+1)
!!$
!!$      real sin1(jm+1)
!!$      real sin2(jn+1)
!!$      real dx1, dx2, dy1, dy2
!!$
!!$! Output
!!$      real q2(in,jn,*)
!!$! local
!!$      integer i,j,k,m
!!$!fvitt      real qtmp(im,jm)
!!$      real qtmp(in,jm)
!!$!      km=1
!!$
!!$      ar=atan(1.)/90.
!!$!
!!$      dx1 = 360./float(im)
!!$      dx2 = 360./float(in)
!!$      dy1 = 180./float(jm-1)
!!$      dy2 = 180./float(jn-1)
!!$!
!!$      do i=1,im+1
!!$         lon1(i) = dx1 * (-0.5 + (i-1) )
!!$      enddo
!!$      do i=1,in+1
!!$         lon2(i) = dx2 * (-0.5 + (i-1) )
!!$      enddo
!!$
!!$      lat1(1) = -90.0
!!$      lat1(2) = lat1(1) + 0.25 * dy1
!!$      lat1(3) = lat1(2) + 0.75 * dy1
!!$      do j=4,jm
!!$         lat1(j) = lat1(j-1) + dy1
!!$      enddo
!!$      lat1(jm+1) = lat1(jm) + 0.75 * dy1
!!$
!!$      sin1(:) = sin( ar * lat1(:))
!!$
!!$      lat2(1) = -90.0
!!$      lat2(2) = lat2(1) + 0.25 * dy2
!!$      lat2(3) = lat2(2) + 0.75 * dy2
!!$      do j=4,jn
!!$         lat2(j) = lat2(j-1) + dy2
!!$      enddo
!!$      lat2(jn+1) = lat2(jn) + 0.75 * dy2
!!$
!!$      sin2(:) = sin( ar * lat2(:))
!!$!
!!$
!!$      do m=1, tm
!!$      do k=1, km
!!$         kt = (m-1)*km + k
!!$        if( im .eq. in ) then
!!$            do j=1,jm-ig
!!$               do i=1,im
!!$                  qtmp(i,j+ig) = q1(i,j+ig,kt)
!!$               enddo
!!$            enddo
!!$        else
!!$! Mapping in the E-W direction
!!$         call xmap(im, jm-ig, lon1, q1(1,1+ig,kt), in, lon2, qtmp(1,1+ig) )
!!$        endif
!!$
!!$        if( jm .eq. jn ) then
!!$            do j=1,jm-ig
!!$               do i=1,in
!!$                  q2(i,j+ig,kt) = qtmp(i,j+ig)
!!$               enddo
!!$            enddo
!!$        else
!!$! Mapping in the N-S direction
!!$         call ymap(in, jm, sin1, qtmp(1,1+ig), jn, sin2, q2(1,1+ig,kt), ig, iv)
!!$        endif
!!$      enddo
!!$      enddo
!!$
!!$      end subroutine MAP_D2D_u
!!$
!!$!#######################################################################


      subroutine YMAP(im, jm, sin1, q1, jn, sin2, q2, ig, iv)

! Routine to perform aream preserving mapping in N-S from an arbitrary
! resolution to another.
!
! sin1 (1) = -1 must be south pole; sin1(jm+1)=1 must be N pole.
!
! sin1(1) < sin1(2) < sin1(3) < ... < sin1(jm) < sin1(jm+1)
! sin2(1) < sin2(2) < sin2(3) < ... < sin2(jn) < sin2(jn+1)
!
! Developer: S.-J. Lin
! First version: piece-wise constant mapping
! Apr 1, 2000
! Last modified:

      implicit none

! Input
      integer im              ! original E-W dimension
      integer jm              ! original N-S dimension
      integer jn              ! Target N-S dimension
      integer ig              ! ig=0: scalars from S.P. to N. P.
                              ! D-grid v-wind is also ig 0
                              ! ig=1: D-grid u-wind
      integer iv              ! iv=0 scalar; iv=1: vector
      real    sin1(jm+1-ig)   ! original southern edge of the cell
                              ! sin(lat1)
!     real    q1(im,jm-ig)    ! original data at center of the cell
      real    q1(im,jm)       ! original data at center of the cell
      real    sin2(jn+1-ig)   ! Target cell's southern edge
                              ! sin(lat2)

! Output
!     real    q2(im,jn-ig)    ! Mapped data at the target resolution
      real    q2(im,jn)       ! Mapped data at the target resolution

! Local
      integer i, j0, m, mm
      integer j

! PPM related arrays
      real   al(im,jm)
      real   ar(im,jm)
      real   a6(im,jm)
      real  dy1(jm)

      real  r3, r23
      parameter ( r3 = 1./3., r23 = 2./3. )
      real pl, pr, qsum, esl
      real dy, sum

      do j=1,jm-ig
         dy1(j) = sin1(j+1) - sin1(j)
      enddo

! ***********************
! Area preserving mapping
! ***********************

! Construct subgrid PP distribution
      call ppm_lat(im, jm, ig, q1, al, ar, a6, 3, iv)

      do 1000 i=1,im
         j0 = 1
      do 555 j=1,jn-ig
      do 100 m=j0,jm-ig
!
! locate the southern edge: sin2(i)
!
      if(sin2(j) .ge. sin1(m) .and. sin2(j) .le. sin1(m+1)) then
         pl = (sin2(j)-sin1(m)) / dy1(m)
         if(sin2(j+1) .le. sin1(m+1)) then
! entire new cell is within the original cell 
            pr = (sin2(j+1)-sin1(m)) / dy1(m)
            q2(i,j) = al(i,m) + 0.5*(a6(i,m)+ar(i,m)-al(i,m)) *(pr+pl)-a6(i,m)*r3*(pr*(pr+pl)+pl**2)
               j0 = m
               goto 555
          else
! South most fractional aream 
            qsum = (sin1(m+1)-sin2(j))*(al(i,m)+0.5*(a6(i,m)+ ar(i,m)-al(i,m))*(1.+pl)-a6(i,m)*(r3*(1.+pl*(1.+pl))))
              do mm=m+1,jm-ig
! locate the eastern edge: sin2(j+1)
                 if(sin2(j+1) .gt. sin1(mm+1) ) then
! Whole layer
                     qsum = qsum + dy1(mm)*q1(i,mm)
                 else
! North most fractional aream
                     dy = sin2(j+1)-sin1(mm)
                    esl = dy / dy1(mm)
                   qsum = qsum + dy*(al(i,mm)+0.5*esl*(ar(i,mm)-al(i,mm)+a6(i,mm)*(1.-r23*esl)))
                     j0 = mm
                     goto 123
                 endif
              enddo
              goto 123
           endif
      endif
100   continue
123   q2(i,j) = qsum / ( sin2(j+1) - sin2(j) )
555   continue
1000  continue
! Final processing for poles

      if ( ig .eq. 0 .and. iv .eq. 0 ) then

! South pole
           sum = 0.
         do i=1,im
           sum = sum + q2(i,1)
         enddo

           sum = sum / float(im)
         do i=1,im
           q2(i,1) = sum
         enddo

! North pole:
           sum = 0.
         do i=1,im
           sum = sum + q2(i,jn)
         enddo

           sum = sum / float(im)
         do i=1,im
           q2(i,jn) = sum
         enddo

      endif

      end subroutine YMAP

!#########################################################################
      subroutine PPM_LAT(im, jm, ig, q, al, ar, a6, jord, iv)
      implicit none

!INPUT
! ig=0: scalar pole to pole
! ig=1: D-grid u-wind; not defined at poles because of staggering

      integer im, jm                      !  Dimensions
      integer ig
      real  q(im,jm-ig)
      real al(im,jm-ig)
      real ar(im,jm-ig)
      real a6(im,jm-ig)
      integer jord
      integer iv                             ! iv=0 scalar
                                             ! iv=1 vector
! Local
      real dm(im,jm-ig)
      real    r3
      parameter ( r3 = 1./3. )
      integer i, j, im2, iop, jm1
      real tmp, qmax, qmin
      real qop

! Compute dm: linear slope

      do j=2,jm-1-ig
         do i=1,im
            dm(i,j) = 0.25*(q(i,j+1) - q(i,j-1))
            qmax = max(q(i,j-1),q(i,j),q(i,j+1)) - q(i,j)
            qmin = q(i,j) - min(q(i,j-1),q(i,j),q(i,j+1))
            dm(i,j) = sign(min(abs(dm(i,j)),qmin,qmax),dm(i,j))
         enddo
      enddo

      im2 = im/2
      jm1 = jm - 1

!Poles:

      if (iv .eq. 1 ) then
!
!*********
! u-wind (ig=1)
! v-wind (ig=0)
!*********
!
! SP
          do i=1,im
              if( i .le. im2) then
                  qop = -q(i+im2,2-ig)
              else
                  qop = -q(i-im2,2-ig)
              endif
              tmp = 0.25*(q(i,2) - qop)
              qmax = max(q(i,2),q(i,1), qop) - q(i,1)
              qmin = q(i,1) - min(q(i,2),q(i,1), qop)
              dm(i,1) = sign(min(abs(tmp),qmax,qmin),tmp)
           enddo
! NP
           do i=1,im
              if( i .le. im2) then
                  qop = -q(i+im2,jm1)
              else
                  qop = -q(i-im2,jm1)
              endif
              tmp = 0.25*(qop - q(i,jm1-ig))
              qmax = max(qop,q(i,jm-ig), q(i,jm1-ig)) - q(i,jm-ig)
              qmin = q(i,jm-ig) - min(qop,q(i,jm-ig), q(i,jm1-ig))
              dm(i,jm-ig) = sign(min(abs(tmp),qmax,qmin),tmp)
           enddo
      else
!
!*********
! Scalar:
!*********
! This code segment currently works only if ig=0
! SP
          do i=1,im2
            tmp = 0.25*(q(i,2)-q(i+im2,2))
            qmax = max(q(i,2),q(i,1), q(i+im2,2)) - q(i,1)
            qmin = q(i,1) - min(q(i,2),q(i,1), q(i+im2,2))
            dm(i,1) = sign(min(abs(tmp),qmax,qmin),tmp)
          enddo

          do i=im2+1,im
            dm(i, 1) =  - dm(i-im2, 1)
          enddo
! NP
          do i=1,im2
            tmp = 0.25*(q(i+im2,jm1)-q(i,jm1))
            qmax = max(q(i+im2,jm1),q(i,jm), q(i,jm1)) - q(i,jm)
            qmin = q(i,jm) - min(q(i+im2,jm1),q(i,jm), q(i,jm1))
            dm(i,jm) = sign(min(abs(tmp),qmax,qmin),tmp)
          enddo

          do i=im2+1,im
            dm(i,jm) =  - dm(i-im2,jm)
          enddo
      endif

      do j=2,jm-ig
        do i=1,im
          al(i,j) = 0.5*(q(i,j-1)+q(i,j)) + r3*(dm(i,j-1) - dm(i,j))
        enddo
      enddo

      do j=1,jm-1-ig
        do i=1,im
          ar(i,j) = al(i,j+1)
        enddo
      enddo

      if ( iv .eq. 1 ) then
! Vector:
! ig=0
        if ( ig .eq. 0 ) then
          do i=1,im2
            al(i,    1) = -al(i+im2,2)
            al(i+im2,1) = -al(i,    2)
          enddo

          do i=1,im2
            ar(i,    jm) = -ar(i+im2,jm1)
            ar(i+im2,jm) = -ar(i,    jm1)
          enddo
        else
! ig=1
! SP
          do i=1,im
             if( i .le. im2) then
                 iop = i+im2
             else
                 iop = i-im2
             endif
             al(i,1) = 0.5*(q(i,1)-q(iop,1)) - r3*(dm(iop,1) + dm(i,1))
          enddo
! NP
          do i=1,im
             if( i .le. im2) then
                 iop = i+im2
             else
                 iop = i-im2
             endif
             ar(i,jm1) = 0.5*(q(i,jm1)-q(iop,jm1)) - r3*(dm(iop,jm1) + dm(i,jm1))
          enddo
        endif
      else
! Scalar (works for ig=0 only):
          do i=1,im2
            al(i,    1) = al(i+im2,2)
            al(i+im2,1) = al(i,    2)
          enddo

          do i=1,im2
            ar(i,    jm) = ar(i+im2,jm1)
            ar(i+im2,jm) = ar(i,    jm1)
           enddo
      endif

      do j=1,jm-ig
        do i=1,im
          a6(i,j) = 3.*(q(i,j)+q(i,j) - (al(i,j)+ar(i,j)))
        enddo
        call LMPPM(dm(1,j), a6(1,j), ar(1,j),al(1,j),  q(1,j), im, jord-3)
      enddo

      end subroutine PPM_LAT
!#######################################################################

      subroutine XMAP(im, jm, lon1, q1, in, lon2, q2)

! Routine to perform area preserving mapping in E-W from an arbitrary
! resolution to another.
! Periodic domain will be assumed, i.e., the eastern wall bounding cell
! im is lon1(im+1) = lon1(1); Note the equal sign is true geographysically.
!
! lon1(1) < lon1(2) < lon1(3) < ... < lon1(im) < lon1(im+1)
! lon2(1) < lon2(2) < lon2(3) < ... < lon2(in) < lon2(in+1)
!
! Developer: S.-J. Lin
! First version: piece-wise constant mapping
! Apr 1, 2000
! Last modified:

      implicit none

! Input
      integer im              ! original E-W dimension
      integer in              ! Target E-W dimension
      integer jm              ! original N-S dimension
      real    lon1(im+1)      ! original western edge of the cell
      real    q1(im,jm)       ! original data at center of the cell
      real    lon2(in+1)      ! Target cell's western edge

! Output
      real    q2(in,jm)       ! Mapped data at the target resolution

! Local
      integer i1, i2
      integer i, i0, m, mm
      integer j

! PPM related arrays
      real qtmp(-im:im+im)
      real   al(-im:im+im)
      real   ar(-im:im+im)
      real   a6(-im:im+im)
      real   x1(-im:im+im+1)
      real  dx1(-im:im+im)
      real  r3, r23
      parameter ( r3 = 1./3., r23 = 2./3. )
      real pl, pr, qsum, esl
      real dx
      integer iord
      data iord /3/
      logical found

      do i=1,im+1
         x1(i) = lon1(i)
      enddo

      do i=1,im
         dx1(i) = x1(i+1) - x1(i)
      enddo

! check to see if ghosting is necessary

!**************
! Western edge:
!**************
          found = .false.
          i1 = 1
      do while ( .not. found )
         if( lon2(1) .ge. x1(i1) ) then
             found = .true.
         else
                  i1 = i1 - 1
             if (i1 .lt. -im) then
                 write(6,*) 'failed in xmap'
                 stop
             else
                 x1(i1) = x1(i1+1) - dx1(im+i1)
                dx1(i1) = dx1(im+i1)
             endif
         endif
      enddo

!**************
! Eastern edge:
!**************
          found = .false.
          i2 = im+1
      do while ( .not. found )
         if( lon2(in+1) .le. x1(i2) ) then
             found = .true.
         else
                  i2 = i2 + 1
             if (i2 .gt. 2*im) then
                 write(6,*) 'failed in xmap'
                 stop
             else
                dx1(i2-1) = dx1(i2-1-im)
                 x1(i2) = x1(i2-1) + dx1(i2-1)
             endif
         endif
      enddo

!     write(6,*) 'i1,i2=',i1,i2

      do 1000 j=1,jm

! ***********************
! Area preserving mapping
! ***********************
! Construct subgrid PP distribution
      call PPM_CYCLE(im, q1(1,j), al(1), ar(1), a6(1), qtmp(0), iord)

! check to see if ghosting is necessary

! Western edge
          if ( i1 .le. 0 ) then
               do i=i1,0
                  qtmp(i) = qtmp(im+i)
                    al(i) = al(im+i)
                    ar(i) = ar(im+i)
                    a6(i) = a6(im+i)
               enddo
          endif

! Eastern edge:
          if ( i2 .gt. im+1 ) then
             do i=im+1,i2-1
                qtmp(i) = qtmp(i-im)
                  al(i) =   al(i-im)
                  ar(i) =   ar(i-im)
                  a6(i) =   a6(i-im)
             enddo
          endif

         i0 = i1

      do 555 i=1,in
      do 100 m=i0,i2-1
!
! locate the western edge: lon2(i)
!
      if(lon2(i) .ge. x1(m) .and. lon2(i) .le. x1(m+1)) then
         pl = (lon2(i)-x1(m)) / dx1(m)
         if(lon2(i+1) .le. x1(m+1)) then
! entire new grid is within the original grid
            pr = (lon2(i+1)-x1(m)) / dx1(m)
            q2(i,j) = al(m) + 0.5*(a6(m)+ar(m)-al(m))*(pr+pl)-a6(m)*r3*(pr*(pr+pl)+pl**2)
               i0 = m
               goto 555
          else
! Left most fractional area
            qsum = (x1(m+1)-lon2(i))*(al(m)+0.5*(a6(m)+ar(m)-al(m))*(1.+pl)-a6(m)*(r3*(1.+pl*(1.+pl))))
              do mm=m+1,i2-1
! locate the eastern edge: lon2(i+1)
                 if(lon2(i+1) .gt. x1(mm+1) ) then
! Whole layer
                     qsum = qsum + dx1(mm)*qtmp(mm)
                 else
! Right most fractional area
                     dx = lon2(i+1)-x1(mm)
                    esl = dx / dx1(mm)
                   qsum = qsum + dx*(al(mm)+0.5*esl*(ar(mm)-al(mm)+a6(mm)*(1.-r23*esl)))
                     i0 = mm
                     goto 123
                 endif
              enddo
              goto 123
           endif
      endif
100   continue
123   q2(i,j) = qsum / ( lon2(i+1) - lon2(i) )
555   continue
1000  continue

      end subroutine XMAP
!#######################################################################

      subroutine LMPPM(dm, a6, ar, al, p, im, lmt)
      implicit none
      real r12
      parameter ( r12 = 1./12. )

      integer im, lmt
      integer i
      real a6(im),ar(im),al(im),p(im),dm(im)
      real da1, da2, fmin, a6da

! LMT = 0: full monotonicity
! LMT = 1: semi-monotonic constraint (no undershoot)
! LMT = 2: positive-definite constraint

      if(lmt.eq.0) then

! Full constraint
      do 100 i=1,im
      if(dm(i) .eq. 0.) then
         ar(i) = p(i)
         al(i) = p(i)
         a6(i) = 0.
      else
         da1  = ar(i) - al(i)
         da2  = da1**2
         a6da = a6(i)*da1
         if(a6da .lt. -da2) then
            a6(i) = 3.*(al(i)-p(i))
            ar(i) = al(i) - a6(i)
         elseif(a6da .gt. da2) then
            a6(i) = 3.*(ar(i)-p(i))
            al(i) = ar(i) - a6(i)
         endif
      endif
100   continue

      elseif(lmt.eq.1) then
! Semi-monotonic constraint
      do 150 i=1,im
      if(abs(ar(i)-al(i)) .ge. -a6(i)) go to 150
      if(p(i).lt.ar(i) .and. p(i).lt.al(i)) then
            ar(i) = p(i)
            al(i) = p(i)
            a6(i) = 0.
      elseif(ar(i) .gt. al(i)) then
            a6(i) = 3.*(al(i)-p(i))
            ar(i) = al(i) - a6(i)
      else
            a6(i) = 3.*(ar(i)-p(i))
            al(i) = ar(i) - a6(i)
      endif
150   continue
      elseif(lmt.eq.2) then
! Positive definite constraint
      do 250 i=1,im
      if(abs(ar(i)-al(i)) .ge. -a6(i)) go to 250
      fmin = p(i) + 0.25*(ar(i)-al(i))**2/a6(i) + a6(i)*r12
      if(fmin.ge.0.) go to 250
      if(p(i).lt.ar(i) .and. p(i).lt.al(i)) then
            ar(i) = p(i)
            al(i) = p(i)
            a6(i) = 0.
      elseif(ar(i) .gt. al(i)) then
            a6(i) = 3.*(al(i)-p(i))
            ar(i) = al(i) - a6(i)
      else
            a6(i) = 3.*(ar(i)-p(i))
            al(i) = ar(i) - a6(i)
      endif
250   continue
      endif
      return
      end subroutine LMPPM

!#######################################################################

      subroutine PPM_CYCLE(im, q, al, ar, a6, p, iord)
      implicit none

      real r3
      parameter ( r3 = 1./3. )

! Input
      integer im, iord
      real  q(im)
! Output
      real al(im)
      real ar(im)
      real a6(im)
      real  p(0:im+1)

! local
      real  dm(0:im)
      integer i, lmt
      real tmp, qmax, qmin

         p(0) = q(im)
      do i=1,im
         p(i) = q(i)
      enddo
         p(im+1) = q(1)

! 2nd order slope
      do i=1,im

         tmp = 0.25*(p(i+1) - p(i-1))
         qmax = max(p(i-1), p(i), p(i+1)) - p(i)
         qmin = p(i) - min(p(i-1), p(i), p(i+1))
         dm(i) = sign(min(abs(tmp),qmax,qmin), tmp)
      enddo
         dm(0) = dm(im)

      do i=1,im
         al(i) = 0.5*(p(i-1)+p(i)) + (dm(i-1) - dm(i))*r3
      enddo

      do i=1,im-1
         ar(i) = al(i+1)
      enddo
         ar(im) = al(1)

      if(iord .le. 6) then
         do i=1,im
            a6(i) = 3.*(p(i)+p(i)  - (al(i)+ar(i)))
         enddo
         lmt = iord - 3
         if(lmt.le.2) call lmppm(dm(1),a6(1),ar(1),al(1),p(1),im,lmt)
      else
         call HUYNH(im, ar(1), al(1), p(1), a6(1), dm(1))
      endif

      return
 end subroutine PPM_CYCLE

!#######################################################################

      subroutine HUYNH(im, ar, al, p, d2, d1)

! Enforce Huynh's 2nd constraint in 1D periodic domain

      implicit none
      integer im, i
      real ar(im)
      real al(im)
      real  p(im)
      real d2(im)
      real d1(im)

! Local scalars:
      real pmp
      real lac
      real pmin
      real pmax

! Compute d1 and d2
         d1(1) = p(1) - p(im)
      do i=2,im
         d1(i) = p(i) - p(i-1)
      enddo

      do i=1,im-1
         d2(i) = d1(i+1) - d1(i)
      enddo
         d2(im) = d1(1) - d1(im)

! Constraint for AR
!            i = 1
         pmp   = p(1) + 2.0 * d1(1)
         lac   = p(1) + 0.5 * (d1(1)+d2(im)) + d2(im)
         pmin  = min(p(1), pmp, lac)
         pmax  = max(p(1), pmp, lac)
         ar(1) = min(pmax, max(ar(1), pmin))

      do i=2, im
         pmp   = p(i) + 2.0*d1(i)
         lac   = p(i) + 0.5*(d1(i)+d2(i-1)) + d2(i-1)
         pmin  = min(p(i), pmp, lac)
         pmax  = max(p(i), pmp, lac)
         ar(i) = min(pmax, max(ar(i), pmin))
      enddo

! Constraint for AL
      do i=1, im-1
         pmp   = p(i) - 2.0*d1(i+1)
         lac   = p(i) + 0.5*(d2(i+1)-d1(i+1)) + d2(i+1)
         pmin  = min(p(i), pmp, lac)
         pmax  = max(p(i), pmp, lac)
         al(i) = min(pmax, max(al(i), pmin))
      enddo

! i=im
         i = im
         pmp    = p(im) - 2.0*d1(1)
         lac    = p(im) + 0.5*(d2(1)-d1(1)) + d2(1)
         pmin   = min(p(im), pmp, lac)
         pmax   = max(p(im), pmp, lac)
         al(im) = min(pmax, max(al(im), pmin))

! compute A6 (d2)
      do i=1, im
         d2(i) = 3.*(p(i)+p(i)  - (al(i)+ar(i)))
      enddo
      return
      end subroutine HUYNH



subroutine handle_err( status )
  implicit none

  integer, intent(in) :: status

  print*,'***** handle_err status = ',status
  stop

endsubroutine handle_err

