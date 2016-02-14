#!/bin/bash
#Quick restart script for dev use

DBNAME="mydb"
SCIDB_INSTALL=~/scidb
iquery -aq "unload_library('windowed_activity')" > /dev/null 2>&1
set -e
mydir=`dirname $0`
pushd $mydir
make clean
make SCIDB=$SCIDB_INSTALL SCIDB_THIRDPARTY_PREFIX=/opt/scidb/15.7
scidb.py stopall $DBNAME 
cp libwindowed_activity.so $SCIDB_INSTALL/lib/scidb/plugins/
scidb.py startall $DBNAME
#for multinode setups, dont forget to copy to every instance
iquery -aq "load_library('windowed_activity')"

