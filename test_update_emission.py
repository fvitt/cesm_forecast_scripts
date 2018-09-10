#! /usr/bin/env python

from datetime import datetime
import prepare_cesm_inputs

print 'start test'
#date = datetime.now()
date = datetime(2017, 12, 12)

ok = prepare_cesm_inputs.update_emissions(date)

print 'success: ',ok

print 'end of test'

