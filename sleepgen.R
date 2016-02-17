gather_stats=function()
{
  data = scidb("between(IHI_ACCELEROMETER, 7,1,null,7,1,null)")
  data = scidb(sprintf("apply(%s, t, mil)", data@name))
  data = scidb(sprintf("variable_window(%s,  
                       mil,
                       1,0,
                       first_value(sleep) as prev_sleep,
                       last_value(sleep) as cur_sleep,
                       first_value(acc_x) as prev_x,
                       last_value(acc_x)  as cur_x,
                       first_value(acc_y) as prev_y,
                       last_value(acc_y)  as cur_y,
                       first_value(acc_z) as prev_z,
                       last_value(acc_z)  as cur_z,
                       first_value(t) as prev_t,
                       last_value(t) as cur_t
  )", data@name))
  data = scidb(sprintf("apply(%s,
                       sleep_period,      iif(prev_sleep = 1 and cur_sleep=1, cur_t-prev_t, null),
                       sleep_delta_x,     iif(prev_sleep = 1 and cur_sleep=1, cur_x-prev_x, null),
                       sleep_delta_y,     iif(prev_sleep = 1 and cur_sleep=1, cur_y-prev_y, null),
                       sleep_delta_z,     iif(prev_sleep = 1 and cur_sleep=1, cur_z-prev_z, null),
                       awake_period,      iif(prev_sleep = 0 and cur_sleep=0, cur_t-prev_t, null),
                       awake_delta_x,     iif(prev_sleep = 0 and cur_sleep=0, cur_x-prev_x, null),
                       awake_delta_y,     iif(prev_sleep = 0 and cur_sleep=0, cur_y-prev_y, null),
                       awake_delta_z,     iif(prev_sleep = 0 and cur_sleep=0, cur_z-prev_z, null)
  )",data@name))
  data = scidb(sprintf("aggregate(%s,
                       avg(sleep_period)    as spm,
                       stdev(sleep_period)  as spsd,
                       stdev(sleep_delta_x) as sxsd,
                       stdev(sleep_delta_y) as sysd,
                       stdev(sleep_delta_z) as szsd,
                       avg(awake_period)    as apm,
                       stdev(awake_period)  as apsd,
                       stdev(awake_delta_x) as axsd,
                       stdev(awake_delta_y) as aysd,
                       stdev(awake_delta_z) as azsd
  )", data@name))
}

run_sleepgen = function(starting_subject = 0,
                                num_days         = 10,
                                num_subjects     = 10,
                                avg_sleep        = 439.3500,
                                sleep_stdev      = 28.41411,
                                spm              = 1078.688,
                                spsd             = 1024.826,
                                sxsd             = 1.283951,
                                sysd             = 0.9418459,
                                szsd             = 1.234103,
                                apm              = 181.3458,
                                apsd             = 478.8366,
                                axsd             = 6.72311,
                                aysd             = 4.67883, 
                                azsd             = 5.588951,
                                wiggle_pct       = 5,
                                sleepgen =  "~/workspace/sleepgen/Release/sleepgen")
{
  wiggle= function(val)
  {
    return(val + runif(1, -wiggle_pct, wiggle_pct) * val / 100.0)
  }
  for(subject in 0:(num_subjects-1))
  {
    my_subject     = subject + starting_subject;
    my_avg_sleep   = wiggle(avg_sleep)
    my_sleep_stdev = wiggle(sleep_stdev)
    my_spm         = wiggle(spm)
    my_spsd        = wiggle(spsd)
    my_sxsd        = wiggle(sxsd)
    my_sysd        = wiggle(sysd)
    my_szsd        = wiggle(szsd)
    my_apm         = wiggle(apm)
    my_apsd        = wiggle(apsd)
    my_axsd        = wiggle(axsd)
    my_aysd        = wiggle(aysd)
    my_azsd        = wiggle(azsd)
    command = sprintf("%s %i %i %f %f %f %f %f %f %f %f %f %f %f %f > /tmp/subject_%i", 
                  sleepgen,
                  my_subject,
                  num_days,
                  my_avg_sleep,
                  my_sleep_stdev,
                  my_spm,
                  my_spsd,
                  my_sxsd,
                  my_sysd,
                  my_szsd,
                  my_apm,
                  my_apsd,
                  my_axsd,
                  my_aysd,
                  my_azsd,
                  my_subject)
    print(command)
    system(command)
  }
}

recreate_sleepgen_schema = function()
{
  #We're going to create one array for the accelerometer data and one array for the light data
  scidbremove("IHI_SLEEPGEN_ACCELEROMETER", force=TRUE, error=invisible)
  iquery("create array IHI_SLEEPGEN_ACCELEROMETER
         <acc_x:uint8 null,
         acc_y:uint8 null,
         acc_z:uint8 null,
         sleep:uint8 null
         >
         [subject = 0:*,1,0, 
         day=0:*,1,0,
         mil=0:86399999,86400000,600000
         ]", return=FALSE)
}

load_sleepgen_file = function(path)
{
  #Lets suck the file into SciDB
  load_query = scidb(sprintf("
                             insert(
                             redimension(
                             apply(
                             parse(split('%s'),'num_attributes=7'),    --For enterprise edition, use aio_input() instead of parse(split())
                             subject, dcast(a0, int64(null)),
                             day,     dcast(a1, int64(null)),
                             mil,     dcast(a2, int64(null)),
                             acc_x,        dcast(a3, uint8(null)),
                             acc_y,        dcast(a4, uint8(null)),
                             acc_z,        dcast(a5, uint8(null)),
                             sleep,        dcast(a6, uint8(null))
                             ),
                             IHI_SLEEPGEN_ACCELEROMETER    
                             ),
                             IHI_SLEEPGEN_ACCELEROMETER
                             )", path))
  iquery(load_query, return=FALSE)
}

#To run this, build and load the attached libwindowed_activity.so example UDO
#This is also possible with SciDB built-in window aggregates but not nearly as fast.
compute_sleepgen_activity_score = function(window_preceding = 300000, window_following= 300000)
{
  scidbremove("IHI_SLEEPGEN_ACTIVITY", force=TRUE, error=invisible)
  result = sprintf("compute_windowed_activity(project(IHI_SLEEPGEN_ACCELEROMETER, acc_x, acc_y, acc_z), %i, %i)", window_preceding, window_following)
  result = sprintf("store(%s, IHI_SLEEPGEN_ACTIVITY)", result)
  t1=proc.time();
  iquery(result, return=FALSE)
  proc.time()-t1
}

make_sleepgen_summary_plot = function()
{
  daily = scidbeval(scidb("
                          filter(
                          aggregate(
                          apply(
                          regrid(
                          join( 
                          IHI_SLEEPGEN_ACCELEROMETER,
                          IHI_SLEEPGEN_ACTIVITY
                          ),
                          1,1,60000,
                          avg(activity) as activity,
                          max(sleep) as sleep
                          ),
                          sleep_minute,    iif(sleep=1, 1,null),
                          sleep_activity,  iif(sleep=1, activity, null),
                          awake_activity,  iif(sleep=0, activity, null)
                          ),
                          sum(sleep_minute) as total_sleep,
                          avg(sleep_activity) as sleep_activity,
                          avg(awake_activity) as awake_activity,
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
      stdev(total_sleep)  as Sleep_Daily_Stdev,
      avg(sleep_activity) as Avg_Sleep_Activity,
      avg(awake_activity) as Avg_Awake_Activity,
      count(*) as Total_Days", 
      by=list("subject")), n=Inf)
  
  mat = data.matrix(summary[c(3,5,7)])
  mc = sweep(mat, 2, apply(mat, 2, mean))
  clust = kmeans(mc,2)$cluster
  library('threejs')
  colors = c("red","green")
  colors = colors[clust]
  scatterplot3js(x=summary$Nightly_Sleep_Minutes,
                 y=summary$Sleep_Daily_Stdev,
                 z=summary$Avg_Awake_Activity, 
                 renderer="canvas",
                 color=colors)
  
  #sleep_plot     = ggplot(summary, aes(x=subject, y=Nightly_Sleep_Minutes)) + geom_bar(stat="identity",  fill="turquoise4")+ theme(axis.ticks.x=element_blank(), axis.text.x=element_blank(), axis.title.x=element_blank(), text = element_text(size=16))
  #sleep_var_plot = ggplot(summary, aes(x=subject, y=Sleep_Daily_Stdev))  + geom_bar(stat="identity",  fill="blue4") + theme(text = element_text(size=16))
  #sleep_act_plot = ggplot(summary, aes(x=subject, y=Avg_Sleep_Activity)) + geom_bar(stat="identity",  fill="orange3")+ theme(axis.ticks.x=element_blank(), axis.text.x=element_blank(), axis.title.x=element_blank(), text = element_text(size=16)) 
  #wake_act_plot  = ggplot(summary, aes(x=subject, y=Avg_Awake_Activity)) + geom_bar(stat="identity",  fill="orange1") + theme(text = element_text(size=16))
  #multiplot(sleep_plot,sleep_var_plot,sleep_act_plot, wake_act_plot, cols=2)
}

do_it_daddy = function()
{
  num_a_subjects=8
  num_b_subjects=2
  num_days = 20
  run_sleepgen( 0,             num_days, num_a_subjects, 449.3500, 15.41411, 1078.688, 1024.826, 1.283951, 0.9418459, 1.234103, 181.3458, 478.8366, 6.72311, 4.67883, 5.588951, 3.5)
  run_sleepgen(num_a_subjects, num_days, num_b_subjects, 509.1500, 34.41411, 1078.688, 1024.826, 0.983951, 0.7418459, 0.834103, 181.3458, 478.8366, 5.72311, 3.67883, 4.588951, 3.5)
  recreate_sleepgen_schema()
  for(subject in 0:(num_a_subjects+num_b_subjects-1))
  {
    print(sprintf("Loading subject %i", subject))
    load_sleepgen_file(sprintf("/tmp/subject_%i", subject)) 
  }
  compute_sleepgen_activity_score()
  make_sleepgen_summary_plot()
}

