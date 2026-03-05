#ifndef __CSM_CLOSESCALE_SNAPSHOT_LEVELS_MQH__
#define __CSM_CLOSESCALE_SNAPSHOT_LEVELS_MQH__

#include "..\\..\\..\\Contracts\\Snapshot.mqh"

class CCloseScaleSnapshotLevels
{
public:
   static bool ReadLevelPrices(const CIndicatorSnapshot &snapshot, double &outLevels[], string &err)
   {
      err = "";
      ArrayResize(outLevels, 0);

      double countCurr = 0.0, countPrev = 0.0;
      if(!snapshot.Get("forecast.level.count", countCurr, countPrev))
      {
         err = "missing forecast.level.count";
         return(false);
      }

      int n = (int)MathRound(countCurr);
      if(n <= 0)
      {
         err = "forecast.level.count invalido";
         return(false);
      }

      ArrayResize(outLevels, n);
      for(int i = 0; i < n; i++)
      {
         string key = StringFormat("forecast.level.price.%d", i);
         double c = 0.0, p = 0.0;
         if(!snapshot.Get(key, c, p) || !MathIsValidNumber(c) || c <= 0.0)
         {
            err = StringFormat("missing %s", key);
            return(false);
         }
         outLevels[i] = c;
      }

      return(true);
   }

   static bool ReadBandPrices(const CIndicatorSnapshot &snapshot,
                              double &upPrice,
                              double &dnPrice,
                              string &err)
   {
      err = "";
      upPrice = 0.0;
      dnPrice = 0.0;

      double c = 0.0, p = 0.0;
      if(!snapshot.Get("forecast.band_up_price", c, p) || !MathIsValidNumber(c) || c <= 0.0)
      {
         err = "missing forecast.band_up_price";
         return(false);
      }
      upPrice = c;

      if(!snapshot.Get("forecast.band_dn_price", c, p) || !MathIsValidNumber(c) || c <= 0.0)
      {
         err = "missing forecast.band_dn_price";
         return(false);
      }
      dnPrice = c;

      return(true);
   }

   static int IndexFirstAbove(const double &arr[], const double value)
   {
      int n = ArraySize(arr);
      for(int i = 0; i < n; i++)
      {
         if(arr[i] > value)
            return(i);
      }
      return(-1);
   }

   static int IndexLastBelow(const double &arr[], const double value)
   {
      int n = ArraySize(arr);
      for(int i = n - 1; i >= 0; i--)
      {
         if(arr[i] < value)
            return(i);
      }
      return(-1);
   }

   static int IndexNearest(const double &arr[], const double value)
   {
      int n = ArraySize(arr);
      if(n <= 0)
         return(-1);

      int best = 0;
      double bestDist = MathAbs(arr[0] - value);
      for(int i = 1; i < n; i++)
      {
         double d = MathAbs(arr[i] - value);
         if(d < bestDist)
         {
            bestDist = d;
            best = i;
         }
      }
      return(best);
   }

   static double AverageLevelSpacing(const double &arr[])
   {
      int n = ArraySize(arr);
      if(n < 2)
         return(0.0);

      double acc = 0.0;
      int cnt = 0;
      for(int i = 1; i < n; i++)
      {
         double d = MathAbs(arr[i] - arr[i - 1]);
         if(MathIsValidNumber(d) && d > 0.0)
         {
            acc += d;
            cnt++;
         }
      }

      if(cnt <= 0)
         return(0.0);
      return(acc / (double)cnt);
   }
};

#endif
