# BEGIN_COPYRIGHT
# 
# Copyright © 2014 Paradigm4, Inc.
# Theis script is used in conjunction with the Community Edition of SciDB.
# SciDB is free software: you can redistribute it and/or modify it under the terms of the Affero General Public License, version 3, as published by the Free Software Foundation.
#
# END_COPYRIGHT

#Inspired by the dataset at:
#http://www.ess.tu-darmstadt.de/datasets/ihi_2012
#Example data loading scripts are here

library("R.matlab")
library('scidb')
scidbconnect()

#Load assist: read a .mat file from the dataset, dump it as text to /tmp/subject_[id]
#See usage below
unpack_matlab_file = function(filename, id)
{
  print(sprintf(">Running %s", filename))
  sub = readMat(filename)
  size = length(sub)
  if(size %% 2 != 0)
  {
    stop("Not an even number of elements")
  }
  for(i in 0:(size/2 - 1))
  {
    print(sprintf(">>Dumping day %i", i))
    timestamps = sub[[i * 2 + 1]]
    #split the floating point timestamp into day (since some date 0, dataset has different starting points)
    day = floor(timestamps)
    millis = round((timestamps - day)*86400000)
    data = sub[[i*2 +2]]
    light = data[,1]
    acc_x = data[,2]
    acc_y = data[,3]
    acc_z = data[,4]
    sleep = data[,5]
    res = data.frame(day, millis,light,acc_x,acc_y,acc_z,sleep)
    write.table(res, 
                file=sprintf("/tmp/subject_%i", id), 
                quote=FALSE,
                sep="\t",
                na="",
                row.names = FALSE,
                col.names=FALSE,
                append=TRUE
    )
  }
}

recreate_schema = function()
{
  #We're going to create one array for the accelerometer data and one array for the light data
  scidbremove("IHI_ACCELEROMETER", force=TRUE, error=invisible)
  iquery("create array IHI_ACCELEROMETER
         <acc_x:uint8 null,
          acc_y:uint8 null,
          acc_z:uint8 null,
          sleep:uint8 null
         >
         [subject = 0:*,1,0, 
          day=0:*,1,0,
          mil=0:86399999,86400000,600000
         ]", return=FALSE)
  
  #We're storing accelerometer data on millisecond granularity, and the light data aggregated
  #By second. We're only doing this to show-off regridding - as if the light were generated 
  #by another device
  scidbremove("IHI_LIGHT", force=TRUE, error=invisible)
  iquery("create array IHI_LIGHT
         <light:double null>
         [subject = 0:*,1,0, 
          day=0:*,1,0,
          sec=0:86399,86400,0
         ]", return=FALSE)
}

load_file = function(path, id)
{
  #Lets suck the file into SciDB
  load_query = scidb(sprintf("
   project(
    apply(
     parse(split('%s'),'num_attributes=7'),    --For enterprise edition, use aio_input() instead of parse(split())
     original_day, dcast(a0, int64(null)),
     mil,          dcast(a1, int64(null)),
     light,        dcast(a2, double(null)),
     acc_x,        dcast(a3, uint8(null)),
     acc_y,        dcast(a4, uint8(null)),
     acc_z,        dcast(a5, uint8(null)),
     sleep,        iif(a6='1', uint8(0), iif(a6='2', uint8(1), uint8(null))),
     subject, %i
    ),
    original_day,mil,light,acc_x,acc_y,acc_z,sleep,subject
   )", path,id))
  loaded_temp = scidbeval(load_query, temp=TRUE)
  
  #There are at least two different date formats in the data. 
  #Some are in the 4100s (looks like day 0 = 1/1/2000) and
  #Others are in the 75000+s (looks like day 0 = 1/1/0)
  #We pretend that the exact date isn't too relevant and so 
  #re-number every subject relative to their first day
  
  #Find the zeroth day.
  day_zero = aggregate(loaded_temp$original_day, FUN="min(original_day) as min")[]$min #min(loaded_temp$original_day)
  
  #Insert accelerometer and sleep data into IHI_ACCELEROMETER
  iquery(sprintf(
    "insert(
      redimension(
       apply(
        %s,
        day, original_day - %i
       ),
       IHI_ACCELEROMETER,
       false
      ),
      IHI_ACCELEROMETER
     )",
     loaded_temp@name, day_zero),
     return=FALSE
  )
  
  iquery(sprintf(
    "insert(
      redimension(
       apply(
        %s,
        day, original_day - %i,
        sec, mil / 1000
       ),
       IHI_LIGHT,
       sum(light) as light
      ),
      IHI_LIGHT
     )",
    loaded_temp@name, day_zero),
    return=FALSE
  )
}

#Load the whole thing
run_load = function()
{
  #Mind the path:
  unpack_matlab_file('~/sleep_IHI_2012/u01.mat',1)
  unpack_matlab_file('~/sleep_IHI_2012/u02.mat',2)
  unpack_matlab_file('~/sleep_IHI_2012/u03.mat',3)
  unpack_matlab_file('~/sleep_IHI_2012/u04.mat',4)
  unpack_matlab_file('~/sleep_IHI_2012/u05.mat',5)
  unpack_matlab_file('~/sleep_IHI_2012/u06.mat',6)
  unpack_matlab_file('~/sleep_IHI_2012/u07.mat',7)
  unpack_matlab_file('~/sleep_IHI_2012/u08.mat',8)
  recreate_schema()
  load_file('/tmp/subject_1', 1)
  load_file('/tmp/subject_2', 2)
  load_file('/tmp/subject_3', 3)
  load_file('/tmp/subject_4', 4)
  load_file('/tmp/subject_5', 5)
  load_file('/tmp/subject_6', 6)
  load_file('/tmp/subject_7', 7)
  load_file('/tmp/subject_8', 8)
}
