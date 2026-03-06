// [POLICY] PROIBIDO: EA nao pode compartilhar/passar inputs para indicador.
// [POLICY] Indicadores devem rodar com seus proprios inputs internos (iCustom sem parametros do EA).

#ifndef __CSM_BE_CLOSESCALE_NEXTLEVEL_MQH__
#define __CSM_BE_CLOSESCALE_NEXTLEVEL_MQH__

#include "..\\..\\..\\Contracts\\Interfaces.mqh"
#include "..\\CloseScale\\CloseScaleSnapshotLevels.mqh"

class CBePolicy_CloseScale_NextLevel : public IBePolicyPlugin
{
public:
   virtual string Id()
   {
      return("CloseScaleBE_NextLevel");
   }

   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err)
   {
      err = "";
      return(true);
   }

   virtual bool ComputeBreakEvenSL(const int signal,
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
         err = "signal invalido no BE";
         return(false);
      }
      if(!MathIsValidNumber(openPrice) || openPrice <= 0.0)
      {
         err = "openPrice invalido";
         return(false);
      }
      if(!MathIsValidNumber(bid) || !MathIsValidNumber(ask) || bid <= 0.0 || ask <= 0.0)
      {
         err = "bid/ask invalido";
         return(false);
      }

      double levelPrices[];
      if(!CCloseScaleSnapshotLevels::ReadLevelPrices(snapshot, levelPrices, err))
         return(false);

      int triggerIdx = -1;
      if(signal == SIGNAL_BUY)
      {
         triggerIdx = CCloseScaleSnapshotLevels::IndexFirstAbove(levelPrices, openPrice);
         if(triggerIdx < 0)
         {
            err = "sem nivel de gatilho para BE buy";
            return(false);
         }
         if(bid < levelPrices[triggerIdx])
            return(false);
      }
      else
      {
         triggerIdx = CCloseScaleSnapshotLevels::IndexLastBelow(levelPrices, openPrice);
         if(triggerIdx < 0)
         {
            err = "sem nivel de gatilho para BE sell";
            return(false);
         }
         if(ask > levelPrices[triggerIdx])
            return(false);
      }

      double minStopDistance = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      if(!MathIsValidNumber(minStopDistance) || minStopDistance < 0.0)
         minStopDistance = 0.0;

      double candidate = openPrice;
      if(signal == SIGNAL_BUY)
      {
         double maxAllowed = bid - minStopDistance;
         if(candidate >= maxAllowed)
            candidate = maxAllowed;
      }
      else
      {
         double minAllowed = ask + minStopDistance;
         if(candidate <= minAllowed)
            candidate = minAllowed;
      }

      candidate = NormalizeDouble(candidate, _Digits);
      if(!MathIsValidNumber(candidate) || candidate <= 0.0)
         return(false);

      outSL = candidate;
      return(true);
   }
};

IBePolicyPlugin* CreateBePolicy_CloseScale_NextLevel()
{
   return(new CBePolicy_CloseScale_NextLevel());
}

#endif
