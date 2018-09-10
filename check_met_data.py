#! /usr/bin/env python
import Nio
import numpy

def check_var( fh, varname, minx, maxx ):
    minval = numpy.amin(fh.variables[varname].get_value())
    maxval = numpy.amax(fh.variables[varname].get_value())

    if  minval<minx or maxval>maxx :
        print varname + "... minval = " + str(minval) + "   maxval = " + str(maxval)
        return False

    return True

def check_met_data( filepath ):

    fh = Nio.open_file(filepath)
    ok = check_var ( fh,    "T",  1.e1, 1.e3 )
    if ok: ok = check_var ( fh,   "TS",  1.e1, 1.e3 )
    if ok: ok = check_var ( fh,    "U", -1.e3, 1.e3 )
    if ok: ok = check_var ( fh,    "V", -1.e3, 1.e3 )
    if ok: ok = check_var ( fh,   "PS",  1.e3, 1.e6 )
    if ok: ok = check_var ( fh,  "ORO",    0., 2.   )
    if ok: ok = check_var ( fh, "PHIS", -2.e3, 1.e6 )
    if ok: ok = check_var ( fh,    "Q",-1.e-3, 1.   )
    if ok: ok = check_var ( fh, "QFLX",-1.e-3, 1.   )
    if ok: ok = check_var ( fh, "SHFLX",-1.e3, 1.e5 )
    if ok: ok = check_var ( fh, "TAUX", -1.e2, 1.e2 )
    if ok: ok = check_var ( fh, "TAUX", -1.e2, 1.e2 )
    fh.close()
    if not ok:
        print " ***** UNREALISTIC VALUES FOUND IN: "+filepath
    return ok

def _test():
    print 'Begin Test ...'
    #filepath = '/glade/scratch/fvitt/GEOS/Y2013/M12/D04/GEOS5_19x2_20131204.nc'
    filepath = '/glade/scratch/fvitt/GEOS/Y2013/M12/D04/GEOS5_orig_res_20131204.nc'
    ok = check_met_data( filepath )

    print "file ok : ",ok

    print 'End Test ...'
