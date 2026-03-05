#ifndef __CSM_TP_CLOSESCALE_NEXTLEVEL_FINAL_MQH__
#define __CSM_TP_CLOSESCALE_NEXTLEVEL_FINAL_MQH__

#include "..\\..\\..\\Contracts\\Interfaces.mqh"
#include "..\\CloseScale\\CloseScaleSnapshotLevels.mqh"

class CTpPolicy_CloseScale_NextLevelAndFinal : public ITpPolicyPlugin
{
public:
   virtual string Id()
   {
      return("CloseScaleTP_NextLevelAndFinal");
   }

   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err)
   {
      err = "";
      return(true);
   }

   virtual bool ComputeInitialTP1(const int signal,
                                  const CIndicatorSnapshot &snapshot,
                                  const double entry,
                                  const double initialSL,
                                  double &outTP1,
                                  string &err)
   {
      err = "";
      outTP1 = 0.0;
      if(signal != SIGNAL_BUY && signal != SIGNAL_SELL)
      {
         err = "signal invalido para TP";
         return(false);
      }
      if(!MathIsValidNumber(entry) || entry <= 0.0)
      {
         err = "entry invalido";
         return(false);
      }

      double levelPrices[];
      if(!CCloseScaleSnapshotLevels::ReadLevelPrices(snapshot, levelPrices, err))
         return(false);

      int nextIdx = (signal == SIGNAL_BUY)
                    ? CCloseScaleSnapshotLevels::IndexFirstAbove(levelPrices, entry)
                    : CCloseScaleSnapshotLevels::IndexLastBelow(levelPrices, entry);
      if(nextIdx < 0)
      {
         err = "sem proximo nivel para TP";
         return(false);
      }

      double avgSpacing = CCloseScaleSnapshotLevels::AverageLevelSpacing(levelPrices);
      if(avgSpacing <= 0.0)
      {
         err = "espacamento medio invalido";
         return(false);
      }

      double minStopDistance = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      if(!MathIsValidNumber(minStopDistance) || minStopDistance < 0.0)
         minStopDistance = 0.0;

      double tpDistance = MathAbs(levelPrices[nextIdx] - entry);
      double minDistance = MathMax(avgSpacing, minStopDistance);
      if(tpDistance < minDistance)
         tpDistance = minDistance;

      outTP1 = (signal == SIGNAL_BUY)
               ? (entry + tpDistance)
               : (entry - tpDistance);
      outTP1 = NormalizeDouble(outTP1, _Digits);

      if(!MathIsValidNumber(outTP1) || outTP1 <= 0.0)
      {
         err = "TP calculado invalido";
         return(false);
      }

      return(true);
   }

   virtual bool ShouldCloseFinal(const int signal,
                                 const CIndicatorSnapshot &snapshot,
                                 const double openPrice,
                                 const double bid,
                                 const double ask,
                                 bool &outClose,
                                 string &err)
   {
      err = "";
      outClose = false;

      if(signal != SIGNAL_BUY && signal != SIGNAL_SELL)
      {
         err = "signal invalido no TP final";
         return(false);
      }

      double levelPrices[];
      if(!CCloseScaleSnapshotLevels::ReadLevelPrices(snapshot, levelPrices, err))
         return(false);

      int targetIdx = (signal == SIGNAL_BUY)
                    ? CCloseScaleSnapshotLevels::IndexFirstAbove(levelPrices, openPrice)
                    : CCloseScaleSnapshotLevels::IndexLastBelow(levelPrices, openPrice);
      if(targetIdx < 0)
      {
         err = "sem proximo nivel para TP final";
         return(false);
      }

      double targetPrice = levelPrices[targetIdx];
      bool levelTouched = (signal == SIGNAL_BUY)
                        ? (bid >= targetPrice)
                        : (ask <= targetPrice);

      double upPrice = 0.0;
      double dnPrice = 0.0;
      if(!CCloseScaleSnapshotLevels::ReadBandPrices(snapshot, upPrice, dnPrice, err))
         return(false);

      double refPrice = (signal == SIGNAL_BUY ? bid : ask);
      bool betweenBands = ((refPrice >= MathMin(dnPrice, upPrice)) &&
                           (refPrice <= MathMax(dnPrice, upPrice)));

      outClose = (levelTouched && betweenBands);
      return(true);
   }
};

ITpPolicyPlugin* CreateTpPolicy_CloseScale_NextLevelAndFinal()
{
   return(new CTpPolicy_CloseScale_NextLevelAndFinal());
}

#endif
