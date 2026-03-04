#ifndef __CSM_ORDER_MANAGER_MODULE_MQH__
#define __CSM_ORDER_MANAGER_MODULE_MQH__

#include "..\\Contracts\\CoreTypes.mqh"
#include "..\\Config\\ConfigModule.mqh"

class COrderManagerModule
{
private:
   bool ReadAtrValue(const int period, double &out)
   {
      out = 0.0;
      if(period < 1)
         return(false);

      static int s_handle = INVALID_HANDLE;
      static int s_period = 0;
      if(s_handle == INVALID_HANDLE || s_period != period)
      {
         if(s_handle != INVALID_HANDLE)
            IndicatorRelease(s_handle);
         s_handle = iATR(_Symbol, _Period, period);
         s_period = period;
      }
      if(s_handle == INVALID_HANDLE)
         return(false);

      double v[1];
      int c = CopyBuffer(s_handle, 0, 1, 1, v);
      if(c < 1)
         return(false);
      out = v[0];
      return(MathIsValidNumber(out) && out > 0.0);
   }

   int FirstNonNoneSL(const CConfigModule &cfg) const
   {
      if(cfg.slSlot1 != SL_SLOT_NONE) return(cfg.slSlot1);
      if(cfg.slSlot2 != SL_SLOT_NONE) return(cfg.slSlot2);
      if(cfg.slSlot3 != SL_SLOT_NONE) return(cfg.slSlot3);
      return(SL_SLOT_NONE);
   }

   int FirstNonNoneTP(const CConfigModule &cfg) const
   {
      if(cfg.tpSlot1 != TP_SLOT_NONE) return(cfg.tpSlot1);
      if(cfg.tpSlot2 != TP_SLOT_NONE) return(cfg.tpSlot2);
      if(cfg.tpSlot3 != TP_SLOT_NONE) return(cfg.tpSlot3);
      return(TP_SLOT_NONE);
   }

   bool BuildStops(const bool isBuy,
                   const CConfigModule &cfg,
                   const double bid,
                   const double ask,
                   double &sl,
                   double &tp,
                   string &err)
   {
      err = "";
      sl = 0.0;
      tp = 0.0;

      double entry = (isBuy ? ask : bid);
      if(!MathIsValidNumber(entry) || entry <= 0.0)
      {
         err = "preco invalido";
         return(false);
      }

      int slChoice = FirstNonNoneSL(cfg);
      if(slChoice == SL_SLOT_FIXED_POINTS)
      {
         double d = MathMax(0, cfg.slFixedPoints) * _Point;
         sl = (isBuy ? entry - d : entry + d);
      }
      else if(slChoice == SL_SLOT_ATR_MULT)
      {
         double atr = 0.0;
         if(!ReadAtrValue(cfg.slAtrPeriod, atr))
         {
            err = "falha ATR para SL";
            return(false);
         }
         sl = (isBuy ? entry - cfg.slAtrMult * atr : entry + cfg.slAtrMult * atr);
      }

      int tpChoice = FirstNonNoneTP(cfg);
      if(tpChoice == TP_SLOT_FIXED_POINTS)
      {
         double d = MathMax(0, cfg.tpFixedPoints) * _Point;
         tp = (isBuy ? entry + d : entry - d);
      }
      else if(tpChoice == TP_SLOT_RR)
      {
         if(sl == 0.0)
         {
            err = "TP RR exige SL ativo";
            return(false);
         }
         double risk = MathAbs(entry - sl);
         if(risk <= 0.0)
         {
            err = "risk invalido para TP RR";
            return(false);
         }
         tp = (isBuy ? entry + risk * cfg.tpRR : entry - risk * cfg.tpRR);
      }

      if(sl > 0.0)
         sl = NormalizeDouble(sl, _Digits);
      if(tp > 0.0)
         tp = NormalizeDouble(tp, _Digits);
      return(true);
   }

public:
   int CountOurPositions(const long magic) const
   {
      int count = 0;
      int total = PositionsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         count++;
      }
      return(count);
   }

   bool BuildOpenRequest(const SSignalDecision &decision,
                         const CConfigModule &cfg,
                         SExecRequest &req,
                         string &err)
   {
      err = "";
      req.action = EXEC_ACTION_NONE;
      req.ticket = 0;
      req.volume = 0.0;
      req.price = 0.0;
      req.sl = 0.0;
      req.tp = 0.0;
      req.comment = "";

      if(decision.signal == SIGNAL_NONE)
      {
         err = "signal none";
         return(false);
      }

      bool isBuy = (decision.signal == SIGNAL_BUY);
      if(isBuy && !cfg.allowBuy)
      {
         err = "buy bloqueado no config";
         return(false);
      }
      if(!isBuy && !cfg.allowSell)
      {
         err = "sell bloqueado no config";
         return(false);
      }

      if(CountOurPositions(cfg.magic) > 0)
      {
         err = "ja existe posicao ativa (one-pair lock)";
         return(false);
      }

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(!MathIsValidNumber(bid) || !MathIsValidNumber(ask) || bid <= 0.0 || ask <= 0.0)
      {
         err = "bid/ask invalido";
         return(false);
      }

      double sl = 0.0, tp = 0.0;
      if(!BuildStops(isBuy, cfg, bid, ask, sl, tp, err))
         return(false);

      req.action = (isBuy ? EXEC_ACTION_OPEN_BUY : EXEC_ACTION_OPEN_SELL);
      req.volume = cfg.lots;
      req.sl = sl;
      req.tp = tp;
      req.comment = StringFormat("%s|%s", (isBuy ? "BUY" : "SELL"), decision.reason);
      return(true);
   }
};

#endif
