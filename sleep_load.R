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
DB = scidbconnect(username='scidbadmin', password=readLines('/home/scidb_bio/.scidbadmin_pass'), port=8083, protocol="https")

#Load assist: read a .mat file from the dataset, dump it as text to /tmp/subject_[id]
#See usage below
unpack_matlab_file = function(filename, id, path)
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
                file=sprintf("%s/subject_%i", path, id), 
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
  tryCatch({ iquery(DB, "remove(IHI_DATA)") }, error=invisible) 

  iquery(DB, "create array IHI_DATA
         <acc_x:double null,
          acc_y:double null,
          acc_z:double null,
          light:double null,
          sleep:double null
         >
         [subject = 0:*,1,0, 
          day=0:*,1,0,
          mil=0:86399999,3600000,0
         ]", return=FALSE)
}

remove_versions = function(array)
{
  mv = max(iquery(DB, sprintf("versions(%s)", array), return=TRUE)$version_id)
  iquery(DB, sprintf("remove_versions(%s, %i)", array, mv))
}

load_file = function(path, id)
{
  #Lets suck the file into SciDB
  load_query = sprintf("
   project(
    apply(
     aio_input('%s','num_attributes=7'),  
     original_day, dcast(a0, int64(null)),
     mil,          dcast(a1, int64(null)),
     light,        dcast(a2, double(null)),
     acc_x,        dcast(a3, double(null)),
     acc_y,        dcast(a4, double(null)),
     acc_z,        dcast(a5, double(null)),
     sleep,        dcast(a6, double(null)),
     subject, %i
    ),
    original_day,mil,light,acc_x,acc_y,acc_z,sleep,subject
   )", path,id)
  loaded_temp = store(DB, scidb(DB,load_query), temp=TRUE)
  
  #There are at least two different date formats in the data. 
  #Some are in the 4100s (looks like day 0 = 1/1/2000) and
  #Others are in the 75000+s (looks like day 0 = 1/1/0)
  #We pretend that the exact date isn't too relevant and so 
  #re-number every subject relative to their first day
  
  #Find the zeroth day.
  day_zero = as.R(DB$aggregate(loaded_temp, "min(original_day) as min"))$min #min(loaded_temp$original_day)
  print(paste("Day zero:", day_zero))

  #Insert accelerometer and sleep data into IHI_ACCELEROMETER
  iquery(DB, sprintf(
    "insert(
      redimension(
       apply(
        %s,
        day, original_day - %i
       ),
       IHI_DATA,
       false
      ),
      IHI_DATA
     )",
     loaded_temp@name, day_zero)
  )
  remove_versions("IHI_DATA")
}

#Load the whole thing
run_load = function()
{
  path = '/home/scidb_bio/ihi_sleep'
  unpack_matlab_file(paste0(path,'/u01.mat'),0, path)
  unpack_matlab_file(paste0(path,'/u02.mat'),1, path)
  unpack_matlab_file(paste0(path,'/u03.mat'),2, path)
  unpack_matlab_file(paste0(path,'/u04.mat'),3, path)
  unpack_matlab_file(paste0(path,'/u05.mat'),4, path)
  unpack_matlab_file(paste0(path,'/u06.mat'),5, path)
  unpack_matlab_file(paste0(path,'/u07.mat'),6, path)
  unpack_matlab_file(paste0(path,'/u08.mat'),7, path)
  recreate_schema()
  load_file(paste0(path,'/subject_0'), 0)
  load_file(paste0(path,'/subject_1'), 1)
  load_file(paste0(path,'/subject_2'), 2)
  load_file(paste0(path,'/subject_3'), 3)
  load_file(paste0(path,'/subject_4'), 4)
  load_file(paste0(path,'/subject_5'), 5)
  load_file(paste0(path,'/subject_6'), 6)
  load_file(paste0(path,'/subject_7'), 7)
}

run_load()
