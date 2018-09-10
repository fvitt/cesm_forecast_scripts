#! /usr/bin/env python
import Nio
import os
import numpy
import glob
from datetime import datetime, timedelta

def define_flds( vars, filepath, out_file ):
    print 'define_flds... filepath = ' + filepath[0]
    filep = Nio.open_file( filepath[0] )

    for ivar in vars.keys():
        
        try:
            ovar = vars[ivar]
            print 'define '+ovar+' from '+ivar

            type=filep.variables[ivar].typecode()
            vdims=filep.variables[ivar].dimensions
            out_file.create_variable(ovar,type,vdims)
            varatts = filep.variables[ivar].__dict__.keys()
            for att in varatts:
                val = getattr(filep.variables[ivar],att)
                setattr(out_file.variables[ovar],att,val)
        except:
            print 'EROOR in define_flds'
            cmd = '/bin/mv ' + filepath[0] + ' ' + filepath[0] + '.bad'
            print 'cmd = '+cmd
            os.system(cmd)
            return False

    filep.close()
    return True

def write_inst_flds( vars, files, nroll, out_file ):

    for ivar in vars.keys():
        ovar = vars[ivar]
        print ivar+' --> '+ovar
        cnt = 0
        for fin in files:
            print fin
            in_file = Nio.open_file(fin)

            try:
                v = in_file.variables[ivar].get_value()
                ndims = in_file.variables[ivar].rank
                v = numpy.roll(v,nroll,axis=ndims-1)
                if cnt > 0 :
                    val = numpy.append(val,v,axis=0)
                else :
                    val = v

                cnt = cnt+1

            except:

                print 'EROOR in write_inst_flds'
                cmd = '/bin/mv ' + fin + ' ' + fin + '.bad'
                print 'cmd = '+cmd
                os.system(cmd)
                return False

            in_file.close()

        out_file.variables[ovar].assign_value(val)

    return True

def write_tavg_flds( vars, filepaths, nroll, out_file ):

    for ivar in vars.keys():
        ovar = vars[ivar]
        print ivar+' --> '+ovar
        for n in range(1,24,3):
            print filepaths[n-1]
            print filepaths[n]

            filem = Nio.open_file(filepaths[n-1])
            filep = Nio.open_file(filepaths[n])

            try:

                valm = filem.variables[ivar].get_value()
                valp = filep.variables[ivar].get_value()
                if ovar=='SNOWH':
                    valm[valm.mask] = 0.0
                    valp[valp.mask] = 0.0
                ndims = filep.variables[ivar].rank
                vala = valm+valp
                vala = 0.5*vala
                if ovar=='TAUX' or ovar=='TAUY' :
                    vala = -vala
                if ovar=='ALB':
                    vala[valm.mask] = vala.fill_value
                    vala[valp.mask] = vala.fill_value
                vala = numpy.roll(vala,nroll,ndims-1)
                if n > 1 :
                    val = numpy.append(val,vala,axis=0)
                else :
                    val = vala

            except:

                print 'EROOR in write_tavg_flds'
                if (n>1):
                    cmd = '/bin/mv ' + filepaths[n-1] + ' ' + filepaths[n-1] + '.bad'
                    print 'cmd = '+cmd
                    os.system(cmd)
                cmd = '/bin/mv ' + filepaths[n] + ' ' + filepaths[n] + '.bad'
                print 'cmd = '+cmd
                os.system(cmd)
                return False

            filem.close()
            filep.close()

        out_file.variables[ovar].assign_value(val)

    return True

def combine_met_data( rootdir, date, fcst_date, ofilepath ) :

    #
    # Set the dirs based on date
    #
    day = timedelta(days=1)
    date0 = fcst_date-day

    dir0 = rootdir + "/" + date.strftime("%Y%m%d")
    dir1 = rootdir + "/" + date.strftime("%Y%m%d")

    #
    # Set the PreFill option to False to improve writing performance
    #
    opt = Nio.options()
    opt.PreFill = False

    fcst_yyyymmdd = fcst_date.strftime("%Y%m%d")
    yyyymmdd = date.strftime("%Y%m%d")

    if (yyyymmdd == fcst_yyyymmdd):
        dir0 = rootdir + "/" + date0.strftime("%Y%m%d")

    yyyymmdd0 = date0.strftime("%Y%m%d")
    #
    # Options for writing NetCDF4 "classic" file.
    #
    # If Nio wasn't built with netcdf 4 support, you will get a
    # warning here, and the code will use netcdf 3 instead.
    #
    opt.Format = "netcdf4classic"
    #opt.Format = "LargeFile"

    vrt_file = Nio.open_file('/glade/p/acom/acom-climate/fvitt/GEOS/GEOS5_orig_res_20180715.nc',mode='r')

    # define vertical coordinate

    os.system("/bin/rm -f "+ofilepath)
    now = datetime.now()
    hist_str = 'created by combine_met_data.py : '+now.strftime("%a %d %b %Y %H:%M:%S")
    out_file = Nio.open_file( ofilepath, mode='c', options=opt, history=hist_str )

    # vertical dimension ...

# define dimensions and ALL variables before writing the data ....

    length = vrt_file.dimensions["lev"]
    out_file.create_dimension("lev",length)

    length = vrt_file.dimensions["ilev"]
    out_file.create_dimension("ilev",length)

    # define horizontal coordinates

    hrz_file = Nio.open_file('/glade/p/acom/acom-climate/fvitt/GEOS/GEOS.fp.asm.const_2d_asm_Nx.00000000_0000.V01.nc4')

    length = hrz_file.dimensions["lat"]
    out_file.create_dimension("lat",length)

    length = hrz_file.dimensions["lon"]
    out_file.create_dimension("lon",length)

    # time dimension ...

    out_file.create_dimension("time",None)

    refdate = datetime( 1900, 01, 01 )

    dims = ('time',)
    out_file.create_variable("time",'d',dims)
    setattr(out_file.variables['time'],'units','days')
    setattr(out_file.variables['time'],'long_name','days since '+refdate.strftime("%d %b %Y %H:%M:%S"))

    out_file.create_variable("date",'i',dims)
    setattr(out_file.variables["date"],'units','current date (YYYYMMDD)')
    setattr(out_file.variables["date"],'long_name','current date (YYYYMMDD)')

    out_file.create_variable("datesec",'i',dims)
    setattr(out_file.variables["datesec"],'units','seconds')
    setattr(out_file.variables["datesec"],'long_name','current seconds of current date')

    vrt_vars = ["lev","ilev","hyam","hybm","hyai","hybi"]
    for var in vrt_vars:
        type=vrt_file.variables[var].typecode()
        vdims=vrt_file.variables[var].dimensions
        out_file.create_variable(var,type,vdims)
        varatts = vrt_file.variables[var].__dict__.keys()
        for att in varatts:
            val = getattr(vrt_file.variables[var],att)
            setattr(out_file.variables[var],att,val)

    hrz_vars = ["lon","lat","PHIS"]
    for var in hrz_vars:
        type=hrz_file.variables[var].typecode()
        vdims=hrz_file.variables[var].dimensions
        out_file.create_variable(var,type,vdims)
        varatts = hrz_file.variables[var].__dict__.keys()
        for att in varatts:
            val = getattr(hrz_file.variables[var],att)
            setattr(out_file.variables[var],att,val)

    type=hrz_file.variables["FRLAND"].typecode()
    vdims=hrz_file.variables["FRLAND"].dimensions
    out_file.create_variable("ORO",type,vdims)
    varatts = hrz_file.variables["FRLAND"].__dict__.keys()
    for att in varatts:
        val = getattr(hrz_file.variables["FRLAND"],att)
        setattr(out_file.variables["ORO"],att,val)

    tavg_flx_vars = {'HFLUX':'SHFLX', 'TAUX':'TAUX','TAUY':'TAUY', 'EVAP':'QFLX'} # flx 
    tavg_flx_filem = glob.glob(dir0+'/GEOS.fp.*.tavg1_2d_flx_Nx.*'+yyyymmdd0+'_2330.V01.nc4' )
    success = define_flds( tavg_flx_vars, tavg_flx_filem, out_file )
    if not success:
        return False

    tavg_rad_vars = {'ALBEDO':'ALB', 'TS':'TS', 'SWGDN':'FSDS'} # rad
    tavg_rad_filem = glob.glob(dir0+'/GEOS.fp.*.tavg1_2d_rad_Nx.*'+yyyymmdd0+'_2330.V01.nc4')
    success = define_flds( tavg_rad_vars, tavg_rad_filem, out_file )
    if not success:
        return False

    tavg_lnd_vars = {'GWETTOP':'SOILW', 'SNOMAS':'SNOWH'} # lnd
    tavg_lnd_filem = glob.glob(dir0+'/GEOS.fp.*.tavg1_2d_lnd_Nx.*'+yyyymmdd0+'_2330.V01.nc4' )
    success = define_flds( tavg_lnd_vars, tavg_lnd_filem, out_file )
    if not success:
        return False

    inst_vars = {'PS':'PS','T':'T','U':'U','V':'V','QV':'Q'}
    inst_files = glob.glob(dir1+'/GEOS.fp.*.inst3_3d_asm_Nv.'+yyyymmdd+'_*+'+fcst_yyyymmdd+'_*.V01.nc4')
    inst_files.sort()
    success = define_flds( inst_vars, inst_files, out_file )
    if not success:
        return False

# definitions should be done at this point

    # Write coordinate dimension variables first

    for var in vrt_vars:
        if vrt_file.dimensions.keys().count(var) > 0:
            v = vrt_file.variables[var].get_value()
            out_file.variables[var].assign_value(v)

    for var in vrt_vars:
        if vrt_file.dimensions.keys().count(var) == 0:
            v = vrt_file.variables[var].get_value()
            out_file.variables[var].assign_value(v)
            
    vrt_file.close()


    # set time/date data ...

    times = [i * 3 for i in range(8)]  # hours
    days = list()
    datesecs = list()

    for hr in times :
        d = datetime( fcst_date.year, fcst_date.month, fcst_date.day, hr, 0, 0 )
        dd = d - refdate
        days.append( dd.days + (dd.seconds/86400.0) )
        datesecs.append( dd.seconds )

    out_file.variables['time'].assign_value(days)

    out_file.variables['date'].assign_value(int(fcst_yyyymmdd))

    out_file.variables['datesec'].assign_value(datesecs)

    var = "lat"
    v = hrz_file.variables[var].get_value()
    out_file.variables[var].assign_value(v)

    var = "lon"
    v = hrz_file.variables[var].get_value()

    # want logitudes from 0 to 360 ( rather than -180 to 180)
    neglons = numpy.where(v<0.0)
    nroll = neglons[0][-1]+1
    lons = numpy.roll(v, nroll )
    lons = numpy.where(lons<0., lons+360., lons)
    lons = numpy.where(lons<1.e-3, 0., lons) # GEOS data has a small value rather than zero
    out_file.variables[var].assign_value(lons)

    for var in hrz_vars:
        if hrz_file.dimensions.keys().count(var) == 0:
            v = hrz_file.variables[var].get_value()
            v = numpy.roll(v,nroll,axis=2)
            v = numpy.tile(v,(8,1,1))
            out_file.variables[var].assign_value(v)
            

    # instantaneous fields ....
    success =  write_inst_flds( inst_vars, inst_files, nroll, out_file )
    if not success:
        return False

    # time-averaged fields ....

    files = glob.glob(dir1+'/GEOS.fp.*.tavg1_2d_flx_Nx.'+yyyymmdd+'_*+'+fcst_yyyymmdd+'_*.V01.nc4')
    files.sort()
    filepaths = tavg_flx_filem + files

    success = write_tavg_flds( tavg_flx_vars, filepaths, nroll, out_file )
    if not success:
        return False

    # special code for ORO
    ivar = 'FRSEAICE'
    for n in range(1,24,3):
        filem = Nio.open_file(filepaths[n-1])
        filep = Nio.open_file(filepaths[n])

        valm = filem.variables[ivar].get_value()
        valp = filep.variables[ivar].get_value()
        ndims = filep.variables[ivar].rank
        vala = 0.5*(valm+valp)
        vala = numpy.roll(vala,nroll,ndims-1)
        if n > 1 :
            val = numpy.append(val,vala,axis=0)
        else :
            val = vala

    seaice = val

    v = hrz_file.variables["FRLAND"].get_value()
    v = numpy.roll(v,nroll,axis=2)
    v = numpy.tile(v,(8,1,1))
    v = numpy.where(v==2, 1, v)
    v = numpy.where(seaice>0.5,2,v)
    out_file.variables["ORO"].assign_value(v)

    hrz_file.close()

    files = glob.glob(dir1+'/GEOS.fp.*.tavg1_2d_rad_Nx.'+yyyymmdd+'_*+'+fcst_yyyymmdd+'_*.V01.nc4')
    files.sort()
    filepaths = tavg_rad_filem + files
    
    success = write_tavg_flds( tavg_rad_vars, filepaths, nroll, out_file )
    if not success:
        return False

    files = glob.glob(dir1+'/GEOS.fp.*.tavg1_2d_lnd_Nx.'+yyyymmdd+'_*+'+fcst_yyyymmdd+'_*.V01.nc4')
    files.sort()
    filepaths = tavg_lnd_filem + files

    success = write_tavg_flds( tavg_lnd_vars, filepaths, nroll, out_file )
    if not success:
        return False

    out_file.close( )
    return True

def _test() :

    print 'Begin TEST'

    time0 = datetime.now()

    day = timedelta(days=1)
    rootdir = '/data1/fvitt/GEOS5_frcst_data'
    #date = datetime(2013,12,10)
    date = datetime.now()
    yyyymmdd = date.strftime("%Y%m%d")
    dir1 = rootdir + "/" + date.strftime("%Y%m%d")

    for d in range(0,4):
        fcst_date = date+d*day
        fcst_yyyymmdd = fcst_date.strftime("%Y%m%d")
        ofilepath = dir1+'/GEOS5_orig_res_'+yyyymmdd+'+'+fcst_yyyymmdd+'.nc'
        print '****************************************** '
        print '*** Create : '+ofilepath
        print '****************************************** '
        success = combine_met_data( rootdir, date, fcst_date, ofilepath )
        print " sucessful : ", success
        if not success:
            break

    time1 = datetime.now()

    print " time elapsed : ", time1-time0

    print 'End TEST'
