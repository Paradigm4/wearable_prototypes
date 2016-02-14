# BEGIN_COPYRIGHT
# 
# Copyright © 2014 Paradigm4, Inc.
# Theis script is used in conjunction with the Community Edition of SciDB.
# SciDB is free software: you can redistribute it and/or modify it under the terms of the Affero General Public License, version 3, as published by the Free Software Foundation.
#
# END_COPYRIGHT

#Some sample scripts and workflows, inspired by the dataset at:
#http://www.ess.tu-darmstadt.de/datasets/ihi_2012

#The objective is just to show off basic regridding, joining, slicing and various ways to interact with R
#The dataset itself is a bit too small for SciDB; SciDB would've made much more sense if we had
#100s of subjects instead of just 8, or more days or both.

library('scidb')
library('ggplot2')
library('gridExtra')

#To run this, build and load the attached libwindowed_activity.so example UDO
#This is also possible with SciDB built-in window aggregates but not nearly as fast.
compute_activity_score = function(window_preceding = 300000, window_following= 300000)
{
  scidbremove("IHI_ACTIVITY", force=TRUE, error=invisible)
  result = sprintf("compute_windowed_activity(project(IHI_ACCELEROMETER, acc_x, acc_y, acc_z), %i, %i)", window_preceding, window_following)
  result = sprintf("store(%s, IHI_ACTIVITY)", result)
  t1=proc.time();
  iquery(result, return=FALSE)
  proc.time()-t1
}

#Build a crude "sleeping/awake" prediction based on the thresholded 
#activity and light values. The above compute_activity_score() needs to be run first.
#The values are chosen arbitrarily. Cross-validation is also not performed here.
compute_threshold_prediction = function(activity_threshold = 0.007,
                                        light_threshold    = 7)
{
  activity = scidb("regrid(IHI_ACTIVITY, 1,1,1000, avg(activity) as activity)")
  light = dimension_rename(scidb("IHI_LIGHT"), old="sec", new="mil")
  prediction = merge(activity, light)
  prediction = scidb(sprintf("project(apply(%s, prediction, iif(activity<%f and light<%f, 1.0, 0.0)),prediction)", prediction@name, activity_threshold, light_threshold))
  scidbremove("IHI_SLEEP_PREDICTION", force=TRUE, error=invisible)
  prediction = scidbeval(prediction, name="IHI_SLEEP_PREDICTION", gc=0)
  iqdf("aggregate(apply(
       join(IHI_SLEEP_PREDICTION, regrid(IHI_ACCELEROMETER, 1,1,1000, max(sleep) as sleep)),
       true_neg,  iif(sleep=0 and prediction=0, 1, null),
       false_neg, iif(sleep=1 and prediction=0, 1, null),
       true_pos,  iif(sleep=1 and prediction=1, 1, null),
       false_pos, iif(sleep=0 and prediction=1, 1, null)
  ),
  sum(true_neg) as true_neg, 
  sum(false_neg) as false_neg,
  sum(true_pos) as true_pos,
  sum(false_pos) as false_pos
 )")
}

# Multiple plot function - put several plots on the same page
# Taken from http://www.cookbook-r.com/Graphs/Multiple_graphs_on_one_page_(ggplot2)/
multiplot <- function(..., plotlist=NULL, file, cols=1, layout=NULL) {
  library(grid)
  
  # Make a list from the ... arguments and plotlist
  plots <- c(list(...), plotlist)
  
  numPlots = length(plots)
  
  # If layout is NULL, then use 'cols' to determine layout
  if (is.null(layout)) {
    # Make the panel
    # ncol: Number of columns of plots
    # nrow: Number of rows needed, calculated from # of cols
    layout <- matrix(seq(1, cols * ceiling(numPlots/cols)),
                     ncol = cols, nrow = ceiling(numPlots/cols))
  }
  
  if (numPlots==1) {
    print(plots[[1]])
    
  } else {
    # Set up the page
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))
    
    # Make each plot, in the correct location
    for (i in 1:numPlots) {
      # Get the i,j matrix positions of the regions that contain this subplot
      matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))
      
      print(plots[[i]], vp = viewport(layout.pos.row = matchidx$row,
                                      layout.pos.col = matchidx$col))
    }
  }
}

#Plot accelerometer, light, activity, actual sleep and/or sleep prediction
#Examples:
#plot_data(zoom=20, light=TRUE, stroke_size=4) #zoomed-in on a 20-second time period
#plot_data(zoom=20, light=TRUE, stroke_size=4, grid_interval=1000) #shows off what regrid does
#plot_data(zoom=86400, light=TRUE, activity=TRUE, sleep_actual=TRUE, prediction=TRUE) #plot a day's worth
plot_data = function(subject=2, day = 6, hour=07, min=34, 
                     zoom=36000, 
                     grid_interval,
                     accelerometer = TRUE,
                     activity      = FALSE,
                     light         = FALSE,
                     sleep_actual  = FALSE, 
                     prediction    = FALSE, 
                     text_size=16,
                     stroke_size=1
)
{
  if(!missing(grid_interval) && grid_interval!=1 && grid_interval<1000)
  {
    stop("grid_interval must be 1 or greater than 1000")
  }
  subject = as.numeric(subject)
  t0 = round(max(hour * 3600000 + min * 60000 - (zoom * 1000/2 - 1), 0))
  t1 = round(min(hour * 3600000 + min * 60000 + (zoom * 1000/2),     86399999))
  if(zoom==86400)
  {
    t0=0;
    t1=86399999;
  }
  plot_fun = geom_line
  if(t1-t0 <= 120000)
  {
    plot_fun = geom_point
  }
  if(missing(grid_interval))
  {
    if(t1-t0 <= 3600000)
    {
      grid_interval = 1
    }
    else if(t1-t0 <= 3600000 * 4)
    {
      grid_interval = 1000
    }
    else
    {
      grid_interval = 10000
    }
  }
  plots=list()
  acc_plot=NULL
  act_plot=NULL
  light_plot = NULL
  n = 1
  if(accelerometer)
  {
    query = sprintf("between(IHI_ACCELEROMETER, %i, %i, %i, %i, %i, %i)",subject, day, t0, subject, day, t1)
    if(grid_interval!=1)
    {
      query = sprintf("regrid(%s, 1,1,%i, avg(acc_x) as acc_x, avg(acc_y) as acc_y, avg(acc_z) as acc_z)", query, grid_interval)
    }
    query = sprintf("project(%s, acc_x, acc_y, acc_z)", query)
    start_time=proc.time()
    #download = iqdf(query, n=Inf)
    download = iquery(query, return=TRUE)
    print(proc.time()-start_time)
    download$seconds = download$mil * grid_interval / 1000
    acc_plot = ggplot(download, aes(x=seconds)) + 
      plot_fun(aes(y=acc_x, colour="acc_x"), size = stroke_size) + 
      plot_fun(aes(y=acc_y, colour="acc_y"), size = stroke_size) + 
      plot_fun(aes(y=acc_z, colour="acc_z"), size = stroke_size) +
      guides(colour=FALSE) + 
      ylab("accelerometer") + 
      theme(text = element_text(size=text_size))
    plots[[n]] = acc_plot
    n=n+1
  }
  if(activity)
  {
    query = sprintf("between(IHI_ACTIVITY, %i, %i, %i, %i, %i, %i)",subject, day, t0, subject, day, t1)
    if(grid_interval!=1)
    {
      query = sprintf("regrid(%s, 1,1,%i, avg(activity) as activity)", query, grid_interval)
    }
    query = sprintf("project(%s, activity)", query)
    download = iqdf(query, n=Inf)
    download$seconds = download$mil * grid_interval / 1000
    act_plot = ggplot(download, aes(x=seconds, y=activity)) + plot_fun(size = stroke_size) + theme(text = element_text(size=text_size))
    plots[[n]] = act_plot
    n=n+1
  }
  if(light)
  {
    query = sprintf("between(IHI_LIGHT, %i, %i, %i, %i, %i, %i)",subject, day, round(t0/1000), subject, day, round(t1/1000))
    light_grid_interval = 1
    if(grid_interval>1000)
    {
      light_grid_interval = round(grid_interval / 1000)
      query = sprintf("regrid(%s, 1,1,%i, avg(light) as light)", query, light_grid_interval)
    }
    query = sprintf("project(%s, light)", query)
    download = iqdf(query, n=Inf)
    download$seconds = download$sec * light_grid_interval
    light_plot = ggplot(download, aes(x=seconds, y=light)) + plot_fun(size = stroke_size) + theme(text = element_text(size=text_size))
    plots[[n]] = light_plot
    n=n+1
  }
  if(sleep_actual)
  {
    query = sprintf("between(IHI_ACCELEROMETER, %i, %i, %i, %i, %i, %i)",subject, day, t0, subject, day, t1)
    if(grid_interval!=1)
    {
      query = sprintf("regrid(%s, 1,1,%i, max(sleep) as sleep)", query, grid_interval)
    }
    query = sprintf("project(%s, sleep)", query)
    download = iqdf(query, n=Inf)
    download$seconds = download$mil * grid_interval / 1000
    sleep_plot = ggplot(download, aes(x=seconds, y=sleep)) + plot_fun(size = stroke_size) + theme(text = element_text(size=text_size))
    plots[[n]] = sleep_plot
    n=n+1
  }
  if(prediction)
  {
    query = sprintf("between(IHI_SLEEP_PREDICTION, %i, %i, %i, %i, %i, %i)", subject, day, round(t0/1000), subject, day, round(t1/1000))
    light_grid_interval = 1
    if(grid_interval>1000)
    {
      light_grid_interval = round(grid_interval / 1000)
      query = sprintf("regrid(%s, 1,1,%i, max(prediction) as prediction)", query, light_grid_interval)
    }
    query = sprintf("project(%s, prediction)", query)
    download = iqdf(query, n=Inf)
    download$seconds = download$mil * light_grid_interval
    prediction_plot = ggplot(download, aes(x=seconds, y=prediction)) + plot_fun(size = stroke_size) + theme(text = element_text(size=text_size))
    plots[[n]] = prediction_plot
    n=n+1
  }
  multiplot(plotlist=plots, cols=1)  
}

#Just some simple aggregate bar charts
#Appears to show some interesting clustering: 
#Subjects 7 and 8 have least activity, most sleep and most sleep variance
#One subtlety here is that a lot of the data-days have large pieces missing
#This function filters out days that aren't nearly full (>1420 out of 1440 minutes)
make_summary_plot = function()
{
  daily = scidbeval(scidb("
    filter(
      aggregate(
       apply(
        join(
         regrid(
          join( 
           IHI_ACCELEROMETER,
           IHI_ACTIVITY
          ),
          1,1,60000,
          avg(activity) as activity,
          max(sleep) as sleep
         ),
         regrid(
          IHI_LIGHT,
          1,1,60,
          avg(light) as light
         )
        ),
        sleep_minute,    iif(sleep=1, 1,null),
        sleep_activity,  iif(sleep=1, activity, null),
        sleep_light,     iif(sleep=1, light, null),
        awake_activity,  iif(sleep=0, activity, null),
        awake_light,     iif(sleep=0, light, null)
       ),
       sum(sleep_minute) as total_sleep,
       avg(sleep_activity) as sleep_activity,
       avg(sleep_light) as sleep_light,
       avg(awake_activity) as awake_activity,
       avg(awake_light) as awake_light,
       count(*) as total_minutes,
       subject, day
      ),
     total_minutes>1420
    )"), temp=TRUE)
  
  summary = iqdf(
    aggregate(
      daily, 
      FUN="avg(total_sleep)    as Nightly_Sleep_Minutes, 
           var(total_sleep)    as Sleep_Daily_Variance,
           avg(sleep_activity) as Avg_Sleep_Activity,
           avg(awake_activity) as Avg_Awake_Activity,
           avg(sleep_light) as Sleep_Light,
           avg(awake_light) as Awake_Light", 
      by=list("subject")), n=Inf)
  
  sleep_plot     = ggplot(summary, aes(x=subject, y=Nightly_Sleep_Minutes)) + geom_bar(stat="identity",  fill="turquoise4")+ scale_x_continuous(breaks = 1:8) + theme(axis.ticks.x=element_blank(), axis.text.x=element_blank(), axis.title.x=element_blank(), text = element_text(size=16))
  sleep_var_plot = ggplot(summary, aes(x=subject, y=Sleep_Daily_Variance))  + geom_bar(stat="identity",  fill="blue4") + scale_x_continuous(breaks = 1:8)+ theme(text = element_text(size=16))
  sleep_act_plot = ggplot(summary, aes(x=subject, y=Avg_Sleep_Activity)) + geom_bar(stat="identity",  fill="orange3") + scale_x_continuous(breaks = 1:8)+ theme(axis.ticks.x=element_blank(), axis.text.x=element_blank(), axis.title.x=element_blank(), text = element_text(size=16)) 
  wake_act_plot  = ggplot(summary, aes(x=subject, y=Avg_Awake_Activity)) + geom_bar(stat="identity",  fill="orange1") + scale_x_continuous(breaks = 1:8)+ theme(text = element_text(size=16))
  multiplot(sleep_plot,sleep_var_plot,sleep_act_plot, wake_act_plot, cols=2)
  #The light stuff is interesting too - but the plots get busy and harder to note any specific patterns
  #sleep_light_plot  = ggplot(summary, aes(x=subject, y=Sleep_Light)) + geom_bar(stat="identity", width=0.75, colour="orange", fill="orange") + scale_x_continuous(breaks = 1:8)+ theme(axis.ticks.x=element_blank(), axis.text.x=element_blank(), axis.title.x=element_blank()) 
  #wake_light_plot   = ggplot(summary, aes(x=subject, y=Awake_Light)) + geom_bar(stat="identity", width=0.75, colour="orange", fill="orange") + scale_x_continuous(breaks = 1:8)+ theme(axis.ticks.x=element_blank(), axis.text.x=element_blank(), axis.title.x=element_blank()) 
  #multiplot(sleep_plot,sleep_var_plot,sleep_act_plot, wake_act_plot, sleep_light_plot, wake_light_plot, cols=2)  
}
