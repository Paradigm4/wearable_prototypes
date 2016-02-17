
#include <iostream>
#include <random>
#include <chrono>
#include <math.h>
#include <stdio.h>
using namespace std;


int main(int argc, char** argv)
{
	if(argc != 15)
	{
		cerr<<"Need exactly 14 args, sorry buddy!";
		return 1;
	}
	long subject;
	long num_days;
	double  avg_sleep_minutes,
		    sleep_stdev,
			spm,
			spsd,
			sxsd,
			sysd,
			szsd,
			apm,
			apsd,
			axsd,
			aysd,
			azsd;
	sscanf(argv[1], "%li", &subject);
	sscanf(argv[2], "%li", &num_days);
    sscanf(argv[3], "%lf", &avg_sleep_minutes);
    sscanf(argv[4], "%lf", &sleep_stdev);
    sscanf(argv[5], "%lf", &spm);
    sscanf(argv[6], "%lf", &spsd);
    sscanf(argv[7], "%lf", &sxsd);
    sscanf(argv[8], "%lf", &sysd);
    sscanf(argv[9], "%lf", &szsd);
    sscanf(argv[10], "%lf", &apm);
    sscanf(argv[11], "%lf", &apsd);
    sscanf(argv[12], "%lf", &axsd);
    sscanf(argv[13], "%lf", &aysd);
    sscanf(argv[14], "%lf", &azsd);

	unsigned seed1 = std::chrono::system_clock::now().time_since_epoch().count()+1;
	unsigned seed2 = std::chrono::system_clock::now().time_since_epoch().count()+2;
	unsigned seed3 = std::chrono::system_clock::now().time_since_epoch().count()+3;
	unsigned seed4 = std::chrono::system_clock::now().time_since_epoch().count()+4;
	std::default_random_engine rgen1(seed1);
	std::default_random_engine rgen2(seed2);
	std::default_random_engine rgen3(seed3);
	std::default_random_engine rgen4(seed4);
	std::normal_distribution<double> sleep_dist(avg_sleep_minutes,sleep_stdev);
	std::normal_distribution<double> dist_sp (spm,spsd);
	std::normal_distribution<double> dist_sx (0,sxsd);
	std::normal_distribution<double> dist_sy (0,sysd);
	std::normal_distribution<double> dist_sz (0,szsd);
	std::normal_distribution<double> dist_ap (apm,apsd);
	std::normal_distribution<double> dist_ax(0,axsd);
	std::normal_distribution<double> dist_ay(0,aysd);
	std::normal_distribution<double> dist_az(0,azsd);
	double x = 128, y=128, z=128;
	long day = 0;
	while(day < num_days)
	{
		double const sleep_minutes = sleep_dist(rgen1);
		unsigned long sleep_usec =  round(sleep_minutes * 60000);
		unsigned long t = 0;
		while(t < sleep_usec)
		{
			double tdelta = round(dist_sp(rgen1));
			if(tdelta<0)
			{
				tdelta = tdelta * -1;
			}
			else if (tdelta == 0)
			{
				tdelta = 1;
			}
			t += tdelta;
			double dx = dist_sx(rgen2);
			if(x + dx < 0 || x +dx > 255)
			{
				dx = dx*-1;
			}
			double dy = dist_sy(rgen3);
			if(y + dy < 0 || y +dy > 255)
			{
				dy = dy*-1;
			}
			double dz = dist_sz(rgen4);
			if(z + dz < 0 || z+dz > 255)
			{
				dz = dz*-1;
			}
			x+=dx;
			y+=dy;
			z+=dz;
			long xval = round(x);
			long yval = round(y);
			long zval = round(z);
			if(xval<0)   { xval = 0;   }
			if(xval>255) { xval = 255; }
			if(yval<0)   { yval = 0;   }
			if(yval>255) { yval = 255; }
			if(zval<0)   { zval = 0;   }
			if(zval>255) { zval = 255; }
			cout<<subject<<"\t"<<day<<"\t"<<t<<"\t"<<xval<<"\t"<<yval<<"\t"<<zval<<"\t"<<"1"<<endl;
		}
		while (t< 86400000)
		{
			double tdelta = round(dist_ap(rgen1));
			if(tdelta<0)
			{
				tdelta = tdelta * -1;
			}
			else if (tdelta == 0)
			{
				tdelta = 1;
			}
			t += tdelta;
			double dx = dist_ax(rgen2);
			if(x + dx < 0 || x +dx > 255)
			{
				dx = dx*-1;
			}
			double dy = dist_ay(rgen3);
			if(y + dy < 0 || y +dy > 255)
			{
				dy = dy*-1;
			}
			double dz = dist_az(rgen4);
			if(z + dz < 0 || z+dz > 255)
			{
				dz = dz*-1;
			}
			x+=dx;
			y+=dy;
			z+=dz;
			long xval = round(x);
			long yval = round(y);
			long zval = round(z);
			if(xval<0)   { xval = 0;   }
			if(xval>255) { xval = 255; }
			if(yval<0)   { yval = 0;   }
			if(yval>255) { yval = 255; }
			if(zval<0)   { zval = 0;   }
			if(zval>255) { zval = 255; }
			if(t<86399999)
			{
				cout<<subject<<"\t"<<day<<"\t"<<t<<"\t"<<xval<<"\t"<<yval<<"\t"<<zval<<"\t"<<"0"<<endl;
			}
		}
		day++;
	}
	return 0;
}
