// [POLICY] PROIBIDO: EA nao pode compartilhar/passar inputs para indicador.
// [POLICY] Indicadores devem rodar com seus proprios inputs internos (iCustom sem parametros do EA).

#ifndef __CSM_PENDING_CLOSESCALE_NEXTLEVEL_BREAKOUT_MQH__
#define __CSM_PENDING_CLOSESCALE_NEXTLEVEL_BREAKOUT_MQH__

#include "..\\..\\..\\Contracts\\Interfaces.mqh"
#include "..\\CloseScale\\CloseScaleSnapshotLevels.mqh"

enum ECloseScalePendingMode
{
   CSM_PENDING_MODE_STOP = 0,
   CSM_PENDING_MODE_LIMIT = 1,
   CSM_PENDING_MODE_STOP_LIMIT = 2
};

class CPendingPolicy_CloseScale_NextLevel : public IPendingPolicyPlugin
{
private:
   string m_id;
   int m_mode;

   double NormalizeVolume(const double requested) const
   {
      if(!MathIsValidNumber(requested) || requested <= 0.0)
         return(0.0);

      double vMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double vMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double vStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

      if(!MathIsValidNumber(vMin) || vMin <= 0.0)
         vMin = 0.01;
      if(!MathIsValidNumber(vMax) || vMax <= 0.0)
         vMax = requested;
      if(!MathIsValidNumber(vStep) || vStep <= 0.0)
         vStep = vMin;

      double v = MathMin(vMax, MathMax(0.0, requested));
      double steps = MathFloor((v + 1e-12) / vStep);
      v = steps * vStep;
      if(v < vMin)
         return(0.0);

      int digits = 0;
      double stepNorm = vStep;
      while(digits < 8 && MathAbs(stepNorm - MathRound(stepNorm)) > 1e-9)
      {
         stepNorm *= 10.0;
         digits++;
      }
      return(NormalizeDouble(v, digits));
   }

   double NormalizePrice(const double value) const
   {
      return(NormalizeDouble(value, _Digits));
   }

   double MinStopDistance() const
   {
      double d = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      if(!MathIsValidNumber(d) || d < 0.0)
         return(0.0);
      return(d);
   }

   bool ResolveVolume(const SOrderManagerConfig &cfg, double &outVolume, string &err) const
   {
      err = "";
      outVolume = 0.0;

      double frac = (cfg.openTwoLegs ? cfg.leg2Fraction : cfg.leg1Fraction);
      double fracSum = (cfg.openTwoLegs ? (cfg.leg1Fraction + cfg.leg2Fraction) : cfg.leg1Fraction);
      if(frac <= 0.0 || fracSum <= 0.0)
      {
         err = "pending: fracoes invalidas";
         return(false);
      }

      double vol = NormalizeVolume(cfg.lots * (frac / fracSum));
      if(vol <= 0.0)
      {
         err = "pending: volume invalido";
         return(false);
      }

      outVolume = vol;
      return(true);
   }

   bool BuildBuyStop(const double &levels[],
                     const double bid,
                     const double ask,
                     SExecRequest &req,
                     string &err) const
   {
      err = "";

      int entryIdx = CCloseScaleSnapshotLevels::IndexFirstAbove(levels, ask);
      if(entryIdx < 0)
      {
         err = "pending buy stop: sem nivel acima";
         return(false);
      }

      double entry = levels[entryIdx];
      double minDist = MinStopDistance();
      if(entry <= ask + minDist)
      {
         err = "pending buy stop: entrada muito perto do ask";
         return(false);
      }

      int slIdx = entryIdx - 1;
      if(slIdx < 0)
      {
         err = "pending buy stop: sem nivel para SL";
         return(false);
      }
      double sl = levels[slIdx];
      if(sl >= entry)
      {
         err = "pending buy stop: SL invalido";
         return(false);
      }

      int tpIdx = entryIdx + 1;
      double tp = 0.0;
      if(tpIdx < ArraySize(levels))
         tp = levels[tpIdx];
      else
      {
         double avg = CCloseScaleSnapshotLevels::AverageLevelSpacing(levels);
         if(avg <= 0.0)
            avg = MathMax(10.0 * _Point, entry * 0.0005);
         tp = entry + avg;
      }
      if(tp <= entry)
      {
         err = "pending buy stop: TP invalido";
         return(false);
      }

      req.action = EXEC_ACTION_OPEN_BUY_STOP;
      req.ticket = 0;
      req.price = NormalizePrice(entry);
      req.stopLimit = 0.0;
      req.sl = NormalizePrice(sl);
      req.tp = NormalizePrice(tp);
      req.comment = "CSM-PEND-BUY-STOP";
      return(true);
   }

   bool BuildSellStop(const double &levels[],
                      const double bid,
                      const double ask,
                      SExecRequest &req,
                      string &err) const
   {
      err = "";

      int entryIdx = CCloseScaleSnapshotLevels::IndexLastBelow(levels, bid);
      if(entryIdx < 0)
      {
         err = "pending sell stop: sem nivel abaixo";
         return(false);
      }

      double entry = levels[entryIdx];
      double minDist = MinStopDistance();
      if(entry >= bid - minDist)
      {
         err = "pending sell stop: entrada muito perto do bid";
         return(false);
      }

      int slIdx = entryIdx + 1;
      if(slIdx >= ArraySize(levels))
      {
         err = "pending sell stop: sem nivel para SL";
         return(false);
      }
      double sl = levels[slIdx];
      if(sl <= entry)
      {
         err = "pending sell stop: SL invalido";
         return(false);
      }

      int tpIdx = entryIdx - 1;
      double tp = 0.0;
      if(tpIdx >= 0)
         tp = levels[tpIdx];
      else
      {
         double avg = CCloseScaleSnapshotLevels::AverageLevelSpacing(levels);
         if(avg <= 0.0)
            avg = MathMax(10.0 * _Point, entry * 0.0005);
         tp = entry - avg;
      }
      if(tp >= entry || tp <= 0.0)
      {
         err = "pending sell stop: TP invalido";
         return(false);
      }

      req.action = EXEC_ACTION_OPEN_SELL_STOP;
      req.ticket = 0;
      req.price = NormalizePrice(entry);
      req.stopLimit = 0.0;
      req.sl = NormalizePrice(sl);
      req.tp = NormalizePrice(tp);
      req.comment = "CSM-PEND-SELL-STOP";
      return(true);
   }

   bool BuildBuyLimit(const double &levels[],
                      const double bid,
                      const double ask,
                      SExecRequest &req,
                      string &err) const
   {
      err = "";

      int entryIdx = CCloseScaleSnapshotLevels::IndexLastBelow(levels, ask);
      if(entryIdx < 0)
      {
         err = "pending buy limit: sem nivel abaixo";
         return(false);
      }

      double entry = levels[entryIdx];
      double minDist = MinStopDistance();
      if(entry >= ask - minDist)
      {
         err = "pending buy limit: entrada muito perto do ask";
         return(false);
      }

      int slIdx = entryIdx - 1;
      if(slIdx < 0)
      {
         err = "pending buy limit: sem nivel para SL";
         return(false);
      }
      double sl = levels[slIdx];
      if(sl >= entry)
      {
         err = "pending buy limit: SL invalido";
         return(false);
      }

      int tpIdx = entryIdx + 1;
      double tp = 0.0;
      if(tpIdx < ArraySize(levels))
         tp = levels[tpIdx];
      else
      {
         double avg = CCloseScaleSnapshotLevels::AverageLevelSpacing(levels);
         if(avg <= 0.0)
            avg = MathMax(10.0 * _Point, entry * 0.0005);
         tp = entry + avg;
      }
      if(tp <= entry)
      {
         err = "pending buy limit: TP invalido";
         return(false);
      }

      req.action = EXEC_ACTION_OPEN_BUY_LIMIT;
      req.ticket = 0;
      req.price = NormalizePrice(entry);
      req.stopLimit = 0.0;
      req.sl = NormalizePrice(sl);
      req.tp = NormalizePrice(tp);
      req.comment = "CSM-PEND-BUY-LIMIT";
      return(true);
   }

   bool BuildSellLimit(const double &levels[],
                       const double bid,
                       const double ask,
                       SExecRequest &req,
                       string &err) const
   {
      err = "";

      int entryIdx = CCloseScaleSnapshotLevels::IndexFirstAbove(levels, bid);
      if(entryIdx < 0)
      {
         err = "pending sell limit: sem nivel acima";
         return(false);
      }

      double entry = levels[entryIdx];
      double minDist = MinStopDistance();
      if(entry <= ask + minDist)
      {
         err = "pending sell limit: entrada muito perto do ask";
         return(false);
      }

      int slIdx = entryIdx + 1;
      if(slIdx >= ArraySize(levels))
      {
         err = "pending sell limit: sem nivel para SL";
         return(false);
      }
      double sl = levels[slIdx];
      if(sl <= entry)
      {
         err = "pending sell limit: SL invalido";
         return(false);
      }

      int tpIdx = entryIdx - 1;
      double tp = 0.0;
      if(tpIdx >= 0)
         tp = levels[tpIdx];
      else
      {
         double avg = CCloseScaleSnapshotLevels::AverageLevelSpacing(levels);
         if(avg <= 0.0)
            avg = MathMax(10.0 * _Point, entry * 0.0005);
         tp = entry - avg;
      }
      if(tp >= entry || tp <= 0.0)
      {
         err = "pending sell limit: TP invalido";
         return(false);
      }

      req.action = EXEC_ACTION_OPEN_SELL_LIMIT;
      req.ticket = 0;
      req.price = NormalizePrice(entry);
      req.stopLimit = 0.0;
      req.sl = NormalizePrice(sl);
      req.tp = NormalizePrice(tp);
      req.comment = "CSM-PEND-SELL-LIMIT";
      return(true);
   }

   bool BuildBuyStopLimit(const double &levels[],
                          const double bid,
                          const double ask,
                          SExecRequest &req,
                          string &err) const
   {
      err = "";

      int triggerIdx = CCloseScaleSnapshotLevels::IndexFirstAbove(levels, ask);
      if(triggerIdx <= 0)
      {
         err = "pending buy stop-limit: sem niveis para trigger/limit";
         return(false);
      }

      double trigger = levels[triggerIdx];
      double minDist = MinStopDistance();
      if(trigger <= ask + minDist)
      {
         err = "pending buy stop-limit: trigger muito perto do ask";
         return(false);
      }

      int limitIdx = triggerIdx - 1;
      double stopLimit = levels[limitIdx];
      if(stopLimit > trigger || stopLimit <= 0.0)
      {
         err = "pending buy stop-limit: limit invalido";
         return(false);
      }

      int slIdx = limitIdx - 1;
      if(slIdx < 0)
      {
         err = "pending buy stop-limit: sem nivel para SL";
         return(false);
      }
      double sl = levels[slIdx];
      if(sl >= stopLimit)
      {
         err = "pending buy stop-limit: SL invalido";
         return(false);
      }

      int tpIdx = triggerIdx + 1;
      double tp = 0.0;
      if(tpIdx < ArraySize(levels))
         tp = levels[tpIdx];
      else
      {
         double avg = CCloseScaleSnapshotLevels::AverageLevelSpacing(levels);
         if(avg <= 0.0)
            avg = MathMax(10.0 * _Point, stopLimit * 0.0005);
         tp = stopLimit + avg;
      }
      if(tp <= stopLimit)
      {
         err = "pending buy stop-limit: TP invalido";
         return(false);
      }

      req.action = EXEC_ACTION_OPEN_BUY_STOP_LIMIT;
      req.ticket = 0;
      req.price = NormalizePrice(trigger);
      req.stopLimit = NormalizePrice(stopLimit);
      req.sl = NormalizePrice(sl);
      req.tp = NormalizePrice(tp);
      req.comment = "CSM-PEND-BUY-STOPLIMIT";
      return(true);
   }

   bool BuildSellStopLimit(const double &levels[],
                           const double bid,
                           const double ask,
                           SExecRequest &req,
                           string &err) const
   {
      err = "";

      int triggerIdx = CCloseScaleSnapshotLevels::IndexLastBelow(levels, bid);
      if(triggerIdx < 0 || triggerIdx >= ArraySize(levels) - 1)
      {
         err = "pending sell stop-limit: sem niveis para trigger/limit";
         return(false);
      }

      double trigger = levels[triggerIdx];
      double minDist = MinStopDistance();
      if(trigger >= bid - minDist)
      {
         err = "pending sell stop-limit: trigger muito perto do bid";
         return(false);
      }

      int limitIdx = triggerIdx + 1;
      double stopLimit = levels[limitIdx];
      if(stopLimit < trigger)
      {
         err = "pending sell stop-limit: limit invalido";
         return(false);
      }

      int slIdx = limitIdx + 1;
      if(slIdx >= ArraySize(levels))
      {
         err = "pending sell stop-limit: sem nivel para SL";
         return(false);
      }
      double sl = levels[slIdx];
      if(sl <= stopLimit)
      {
         err = "pending sell stop-limit: SL invalido";
         return(false);
      }

      int tpIdx = triggerIdx - 1;
      double tp = 0.0;
      if(tpIdx >= 0)
         tp = levels[tpIdx];
      else
      {
         double avg = CCloseScaleSnapshotLevels::AverageLevelSpacing(levels);
         if(avg <= 0.0)
            avg = MathMax(10.0 * _Point, stopLimit * 0.0005);
         tp = stopLimit - avg;
      }
      if(tp >= stopLimit || tp <= 0.0)
      {
         err = "pending sell stop-limit: TP invalido";
         return(false);
      }

      req.action = EXEC_ACTION_OPEN_SELL_STOP_LIMIT;
      req.ticket = 0;
      req.price = NormalizePrice(trigger);
      req.stopLimit = NormalizePrice(stopLimit);
      req.sl = NormalizePrice(sl);
      req.tp = NormalizePrice(tp);
      req.comment = "CSM-PEND-SELL-STOPLIMIT";
      return(true);
   }

public:
   CPendingPolicy_CloseScale_NextLevel(const string id, const int mode)
   {
      m_id = id;
      m_mode = mode;
   }

   virtual string Id()
   {
      return(m_id);
   }

   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err)
   {
      err = "";
      return(true);
   }

   virtual int BuildPendingRequests(const SSignalDecision &decision,
                                    const CIndicatorSnapshot &snapshot,
                                    const SOrderManagerConfig &cfg,
                                    SExecRequest &reqs[],
                                    string &err)
   {
      err = "";
      ArrayResize(reqs, 0);

      if(decision.signal != SIGNAL_BUY && decision.signal != SIGNAL_SELL)
      {
         err = "pending: signal none";
         return(0);
      }

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(!MathIsValidNumber(bid) || !MathIsValidNumber(ask) || bid <= 0.0 || ask <= 0.0)
      {
         err = "pending: bid/ask invalido";
         return(0);
      }

      double levels[];
      if(!CCloseScaleSnapshotLevels::ReadLevelPrices(snapshot, levels, err))
         return(0);

      SExecRequest req;
      req.action = EXEC_ACTION_NONE;
      req.ticket = 0;
      req.volume = 0.0;
      req.price = 0.0;
      req.stopLimit = 0.0;
      req.sl = 0.0;
      req.tp = 0.0;
      req.comment = "";

      bool ok = false;
      if(m_mode == CSM_PENDING_MODE_STOP)
      {
         // STOP simples desativado: converte para stop-limit.
         if(decision.signal == SIGNAL_BUY)
            ok = BuildBuyStopLimit(levels, bid, ask, req, err);
         else
            ok = BuildSellStopLimit(levels, bid, ask, req, err);
      }
      else if(m_mode == CSM_PENDING_MODE_LIMIT)
      {
         if(decision.signal == SIGNAL_BUY)
            ok = BuildBuyLimit(levels, bid, ask, req, err);
         else
            ok = BuildSellLimit(levels, bid, ask, req, err);
      }
      else if(m_mode == CSM_PENDING_MODE_STOP_LIMIT)
      {
         if(decision.signal == SIGNAL_BUY)
            ok = BuildBuyStopLimit(levels, bid, ask, req, err);
         else
            ok = BuildSellStopLimit(levels, bid, ask, req, err);
      }
      else
      {
         err = "pending: modo invalido";
         return(0);
      }

      if(!ok)
         return(0);

      if(!ResolveVolume(cfg, req.volume, err))
         return(0);

      ArrayResize(reqs, 1);
      reqs[0] = req;
      return(1);
   }
};

IPendingPolicyPlugin* CreatePendingPolicy_CloseScale_NextLevelBreakout()
{
   return(new CPendingPolicy_CloseScale_NextLevel("CloseScalePending_NextLevelBreakout", CSM_PENDING_MODE_STOP_LIMIT));
}

IPendingPolicyPlugin* CreatePendingPolicy_CloseScale_NextLevelLimit()
{
   return(new CPendingPolicy_CloseScale_NextLevel("CloseScalePending_NextLevelLimit", CSM_PENDING_MODE_LIMIT));
}

IPendingPolicyPlugin* CreatePendingPolicy_CloseScale_NextLevelStopLimit()
{
   return(new CPendingPolicy_CloseScale_NextLevel("CloseScalePending_NextLevelStopLimit", CSM_PENDING_MODE_STOP_LIMIT));
}

#endif
