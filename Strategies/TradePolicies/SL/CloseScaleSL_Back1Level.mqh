// [POLICY] PROIBIDO: EA nao pode compartilhar/passar inputs para indicador.
// [POLICY] Indicadores devem rodar com seus proprios inputs internos (iCustom sem parametros do EA).

#ifndef __CSM_SL_CLOSESCALE_BACK1LEVEL_MQH__
#define __CSM_SL_CLOSESCALE_BACK1LEVEL_MQH__

#include "..\\..\\..\\Contracts\\Interfaces.mqh"
#include "..\\CloseScale\\CloseScaleSnapshotLevels.mqh"

class CSlPolicy_CloseScale_Back1Level : public ISlPolicyPlugin
{
public:
   virtual string Id()
   {
      return("CloseScaleSL_Back1Level");
   }

   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err)
   {
      err = "";
      return(true);
   }

   virtual bool ComputeInitialSL(const int signal,
                                 const CIndicatorSnapshot &snapshot,
                                 const double entry,
                                 double &outSL,
                                 string &err)
   {
      err = "";
      outSL = 0.0;
      if(signal != SIGNAL_BUY && signal != SIGNAL_SELL)
      {
         err = "signal invalido para SL";
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

      int backIdx = (signal == SIGNAL_BUY)
                    ? CCloseScaleSnapshotLevels::IndexLastBelow(levelPrices, entry)
                    : CCloseScaleSnapshotLevels::IndexFirstAbove(levelPrices, entry);
      if(backIdx < 0)
      {
         err = "sem nivel anterior para SL";
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

      double slDistance = MathAbs(entry - levelPrices[backIdx]);
      double minDistance = MathMax(avgSpacing, minStopDistance);
      if(slDistance < minDistance)
         slDistance = minDistance;

      outSL = (signal == SIGNAL_BUY)
              ? (entry - slDistance)
              : (entry + slDistance);
      outSL = NormalizeDouble(outSL, _Digits);

      if(!MathIsValidNumber(outSL) || outSL <= 0.0)
      {
         err = "SL calculado invalido";
         return(false);
      }

      return(true);
   }
};

ISlPolicyPlugin* CreateSlPolicy_CloseScale_Back1Level()
{
   return(new CSlPolicy_CloseScale_Back1Level());
}

#endif
