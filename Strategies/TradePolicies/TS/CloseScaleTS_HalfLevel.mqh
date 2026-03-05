#ifndef __CSM_TS_CLOSESCALE_HALFLEVEL_MQH__
#define __CSM_TS_CLOSESCALE_HALFLEVEL_MQH__

#include "..\\..\\..\\Contracts\\Interfaces.mqh"
#include "..\\CloseScale\\CloseScaleSnapshotLevels.mqh"

class CTsPolicy_CloseScale_HalfLevel : public ITsPolicyPlugin
{
public:
   virtual string Id()
   {
      return("CloseScaleTS_HalfLevel");
   }

   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err)
   {
      err = "";
      return(true);
   }

   virtual bool ComputeTrailingSL(const int signal,
                                  const CIndicatorSnapshot &snapshot,
                                  const double openPrice,
                                  const double currentSL,
                                  const double currentTP,
                                  const double bid,
                                  const double ask,
                                  double &outSL,
                                  string &err)
   {
      err = "";
      outSL = 0.0;

      if(signal != SIGNAL_BUY && signal != SIGNAL_SELL)
      {
         err = "signal invalido no trailing half level";
         return(false);
      }
      if(!MathIsValidNumber(bid) || !MathIsValidNumber(ask) || bid <= 0.0 || ask <= 0.0)
         return(false);

      double levelPrices[];
      if(!CCloseScaleSnapshotLevels::ReadLevelPrices(snapshot, levelPrices, err))
         return(false);

      int openIdx = CCloseScaleSnapshotLevels::IndexNearest(levelPrices, openPrice);
      if(openIdx < 0)
         return(false);

      double desiredSL = 0.0;
      int reachedIdx = -1;
      if(signal == SIGNAL_BUY)
      {
         reachedIdx = CCloseScaleSnapshotLevels::IndexLastBelow(levelPrices, bid + 1e-12);
         if(reachedIdx <= openIdx)
            return(false);
         if(reachedIdx <= 0)
            return(false);

         double step = MathAbs(levelPrices[reachedIdx] - levelPrices[reachedIdx - 1]);
         if(step <= 0.0)
            return(false);
         desiredSL = levelPrices[reachedIdx] - 0.5 * step;
      }
      else
      {
         reachedIdx = CCloseScaleSnapshotLevels::IndexFirstAbove(levelPrices, ask - 1e-12);
         if(reachedIdx < 0 || reachedIdx >= openIdx)
            return(false);
         if(reachedIdx + 1 >= ArraySize(levelPrices))
            return(false);

         double step = MathAbs(levelPrices[reachedIdx + 1] - levelPrices[reachedIdx]);
         if(step <= 0.0)
            return(false);
         desiredSL = levelPrices[reachedIdx] + 0.5 * step;
      }

      double minStopDistance = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      if(!MathIsValidNumber(minStopDistance) || minStopDistance < 0.0)
         minStopDistance = 0.0;

      if(signal == SIGNAL_BUY)
      {
         double maxAllowed = bid - minStopDistance;
         if(desiredSL >= maxAllowed)
            desiredSL = maxAllowed;
         if(currentSL > 0.0 && desiredSL <= currentSL + _Point)
            return(false);
      }
      else
      {
         double minAllowed = ask + minStopDistance;
         if(desiredSL <= minAllowed)
            desiredSL = minAllowed;
         if(currentSL > 0.0 && desiredSL >= currentSL - _Point)
            return(false);
      }

      desiredSL = NormalizeDouble(desiredSL, _Digits);
      if(!MathIsValidNumber(desiredSL) || desiredSL <= 0.0)
         return(false);

      outSL = desiredSL;
      return(true);
   }
};

ITsPolicyPlugin* CreateTsPolicy_CloseScale_HalfLevel()
{
   return(new CTsPolicy_CloseScale_HalfLevel());
}

#endif
