# Storing and analyzing wearable timeseries.
This was inspired by the cool dataset and paper from here: http://www.ess.tu-darmstadt.de/datasets/ihi_2012
This is very much an "archive" repo. The schemas are close to what we use now but most of the query and analysis techniques we use for wearables nowadays are far ahead of this. 

### Load and see
`sleep_load.R` and `sleep.R` have some rough scripts for loading this data and visualizing it. We intentionally load the light data at a lower frequency and then demonstrate how regrid can be used to combine datasets sampled at different rates. 

To make this more realistic, overlap and a contiguous time axis can be used to avoid problems with chunk edges.

### Activity Window
`compute_windowed_activity` is a special-case SciDB UDO to compute a window-aggregate activity score. It accepts an input array, number of preceding milliseconds and the number of following milliseconds. For example,
```
compute_windowed_activity(input, 300000, 300000)
```
will compute a 10-minute moving window (5 minutes preceding and following). The input array must have the shape:
```
<x:uint8 null, y:uint8 null, z:uint8 null>
[subject = 0:*,1,0, day=0:*,1,0, millis=0:86399999,86400000,0]
```
For the 10-minute window surrounding each cell, it computes the sum of 3D euclidean distances between each pair of successive points `{t(i+1),t(i)}`, divided by the total time elapsed. Thus it outputs roughly the "total amount of motion" performed. 

This predated SciDB Streaming. These days, using Streaming with a fourier transform and power spectrum would be far superior!

### Generate fake data

`sleepgen` is a little program built to quickly spit out data similar to these timeseries - based on some statistical measures. At the moment, it uses the normal distributions, seeded with some means and standard deviations to compute how long to "sleep" for and then how often to move the accelerometer and by how much. This doesn't quite capture the "look" of the natural waveforms, but somewhat close.

The IHI dataset is between 1 and 3 GB (depending on who's counting) and covers only 8 subjects over ~8-20 days. The objective of `sleepgen` is to quickly generate hundreds of gigs of data that looks like it - so that queries and aggregates can be benchmarked on higher volumes. See `sleepgen.R` for an example driver script.
