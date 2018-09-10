#! /usr/bin/env python

# use threading to download the dates in parallel

from datetime import datetime, timedelta
from subprocess import call
import threading
import Queue

def download( date, f_date, local_dir, out_queue ):

    rc = download2( date, f_date, local_dir )
    out_queue.put(rc)

def download2( date, f_date, local_dir ):

    year  = date.strftime("%Y")
    month = date.strftime("%m")
    day   = date.strftime("%d")
    
    rc = True

    f_yyyymmdd = f_date.strftime("%Y%m%d")
    cmd = ['./download_data','-year',year,'-month',month,'-day',day, 
           '-hour','00','-remote_basedir','/fp/forecast','-local_dir',local_dir,
           '-base_filename','GEOS.fp.fcst','-forecast_date', f_yyyymmdd]
    print cmd

    stat = call(cmd)

    if not stat == 0 : rc = False
    return rc

def download_forecast_data( date, n_forecast_days, rootdir ):

    year  = date.strftime("%Y")
    month = date.strftime("%m")
    day   = date.strftime("%d")

    local_dir = rootdir+'/'+year+month+day

    cmd = ['mkdir','-p',local_dir]
    stat = call(cmd)
    if not stat == 0 : return False

    thread_list = []
    queue_list = []

    oneday = timedelta(days=1)

    for i in range(0,n_forecast_days):
        f_date = date+i*oneday
        q = Queue.Queue()
        t = threading.Thread(target=download, args=(date, f_date, local_dir,q))
        thread_list.append(t)
        queue_list.append(q)

    # Start the threads
    for thread in thread_list:
        thread.start()

    # block the calling thread until the thread whose join() method is called is terminated.
    for thread in thread_list:
        thread.join()

    rc = True

    # get the return values 
    for queue in queue_list:
        res = queue.get()
        rc = rc and res

    return rc

def test():

    print "Begin Test"
    time0 = datetime.now()

    date = datetime.now()
    #date = datetime( 2013, 12, 29)
#    date = datetime(2017,9,25)
    rootdir = '/glade/scratch/fvitt/GEOS5_frcst_data'

    success = download_forecast_data( date, rootdir )

    time1 = datetime.now()

    print ".........success : ",success
    print "...Download time : ", time1-time0

    print "End of Test"
