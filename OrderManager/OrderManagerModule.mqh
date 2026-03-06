// [POLICY] PROIBIDO: EA nao pode compartilhar/passar inputs para indicador.
// [POLICY] Indicadores devem rodar com seus proprios inputs internos (iCustom sem parametros do EA).

#ifndef __CSM_ORDER_MANAGER_MODULE_MQH__
#define __CSM_ORDER_MANAGER_MODULE_MQH__

#include "..\\Contracts\\CoreTypes.mqh"
#include "..\\Contracts\\Snapshot.mqh"
#include "..\\Contracts\\Interfaces.mqh"
#include "..\\Strategies\\TradePolicies\\TradePolicyRegistry.mqh"
#include "Hedge\\HedgeBasketEngine.mqh"

class COrderManagerModule
{
private:
   ISlPolicyPlugin *m_sl;
   ITpPolicyPlugin *m_tp;
   ITsPolicyPlugin *m_ts;
   IBePolicyPlugin *m_be;
   IPendingPolicyPlugin *m_pending;
   IRiskPolicyPlugin *m_risk;
   bool m_policiesReady;
   CHedgeBasketEngine m_hedge;

   void ClearPolicies()
   {
      if(m_sl != NULL)
      {
         delete m_sl;
         m_sl = NULL;
      }
      if(m_tp != NULL)
      {
         delete m_tp;
         m_tp = NULL;
      }
      if(m_ts != NULL)
      {
         delete m_ts;
         m_ts = NULL;
      }
      if(m_be != NULL)
      {
         delete m_be;
         m_be = NULL;
      }
      if(m_pending != NULL)
      {
         delete m_pending;
         m_pending = NULL;
      }
      if(m_risk != NULL)
      {
         delete m_risk;
         m_risk = NULL;
      }
      m_policiesReady = false;
   }

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

   void PushRequest(SExecRequest &arr[], const SExecRequest &req) const
   {
      int n = ArraySize(arr);
      ArrayResize(arr, n + 1);
      arr[n] = req;
   }

   bool IsSlImprovement(const int signal,
                        const double currentSL,
                        const double candidateSL) const
   {
      if(!MathIsValidNumber(candidateSL) || candidateSL <= 0.0)
         return(false);

      if(signal == SIGNAL_BUY)
      {
         if(currentSL <= 0.0)
            return(true);
         return(candidateSL > currentSL + _Point);
      }

      if(signal == SIGNAL_SELL)
      {
         if(currentSL <= 0.0)
            return(true);
         return(candidateSL < currentSL - _Point);
      }

      return(false);
   }

public:
   COrderManagerModule()
   {
      m_sl = NULL;
      m_tp = NULL;
      m_ts = NULL;
      m_be = NULL;
      m_pending = NULL;
      m_risk = NULL;
      m_policiesReady = false;
   }

   void Deinit()
   {
      ClearPolicies();
      m_hedge.Reset();
   }

   int CountActiveBaskets(const SOrderManagerConfig &cfg) const
   {
      if(cfg.execMode != OM_EXEC_HEDGE_OCO_V1)
         return(0);
      return(m_hedge.CountActiveBaskets(cfg));
   }

   double SumActiveBasketNetPnl(const SOrderManagerConfig &cfg) const
   {
      if(cfg.execMode != OM_EXEC_HEDGE_OCO_V1)
         return(0.0);
      return(m_hedge.SumActiveBasketNetPnl(cfg));
   }

   bool InitPolicies(ISlPolicyPlugin *slPolicy,
                     ITpPolicyPlugin *tpPolicy,
                     ITsPolicyPlugin *tsPolicy,
                     IBePolicyPlugin *bePolicy,
                     IPendingPolicyPlugin *pendingPolicy,
                     IRiskPolicyPlugin *riskPolicy,
                     const SOrderPolicyConfig &policyCfg,
                     string &err)
   {
      err = "";
      ClearPolicies();

      m_sl = slPolicy;
      if(m_sl == NULL)
      {
         if(tpPolicy != NULL) delete tpPolicy;
         if(tsPolicy != NULL) delete tsPolicy;
         if(bePolicy != NULL) delete bePolicy;
         if(pendingPolicy != NULL) delete pendingPolicy;
         if(riskPolicy != NULL) delete riskPolicy;
         err = "SL policy invalida";
         return(false);
      }

      m_tp = tpPolicy;
      if(m_tp == NULL)
      {
         ClearPolicies();
         if(tsPolicy != NULL) delete tsPolicy;
         if(bePolicy != NULL) delete bePolicy;
         if(pendingPolicy != NULL) delete pendingPolicy;
         if(riskPolicy != NULL) delete riskPolicy;
         err = "TP policy invalida";
         return(false);
      }

      m_ts = tsPolicy;
      if(m_ts == NULL)
      {
         ClearPolicies();
         if(bePolicy != NULL) delete bePolicy;
         if(pendingPolicy != NULL) delete pendingPolicy;
         if(riskPolicy != NULL) delete riskPolicy;
         err = "TS policy invalida";
         return(false);
      }

      m_be = bePolicy;
      if(m_be == NULL)
      {
         ClearPolicies();
         if(pendingPolicy != NULL) delete pendingPolicy;
         if(riskPolicy != NULL) delete riskPolicy;
         err = "BE policy invalida";
         return(false);
      }

      m_pending = pendingPolicy;
      if(m_pending == NULL)
      {
         ClearPolicies();
         if(riskPolicy != NULL) delete riskPolicy;
         err = "Pending policy invalida";
         return(false);
      }

      m_risk = riskPolicy;
      if(m_risk == NULL)
      {
         ClearPolicies();
         err = "Risk policy invalida";
         return(false);
      }

      string oneErr = "";
      if(!m_sl.Configure(policyCfg, oneErr))
      {
         err = StringFormat("falha Configure SL policy (%s): %s", m_sl.Id(), oneErr);
         ClearPolicies();
         return(false);
      }
      if(!m_tp.Configure(policyCfg, oneErr))
      {
         err = StringFormat("falha Configure TP policy (%s): %s", m_tp.Id(), oneErr);
         ClearPolicies();
         return(false);
      }
      if(!m_ts.Configure(policyCfg, oneErr))
      {
         err = StringFormat("falha Configure TS policy (%s): %s", m_ts.Id(), oneErr);
         ClearPolicies();
         return(false);
      }
      if(!m_be.Configure(policyCfg, oneErr))
      {
         err = StringFormat("falha Configure BE policy (%s): %s", m_be.Id(), oneErr);
         ClearPolicies();
         return(false);
      }
      if(!m_pending.Configure(policyCfg, oneErr))
      {
         err = StringFormat("falha Configure Pending policy (%s): %s", m_pending.Id(), oneErr);
         ClearPolicies();
         return(false);
      }
      if(!m_risk.Configure(policyCfg, oneErr))
      {
         err = StringFormat("falha Configure Risk policy (%s): %s", m_risk.Id(), oneErr);
         ClearPolicies();
         return(false);
      }

      m_policiesReady = true;
      return(true);
   }

   bool InitPoliciesByConfig(const SOrderManagerConfig &cfg, string &err)
   {
      err = "";
      ISlPolicyPlugin *slPolicy = SlPolicyRegistry_CreateById(cfg.slPolicyId);
      if(slPolicy == NULL)
      {
         err = StringFormat("SL policy nao encontrada: %s", cfg.slPolicyId);
         return(false);
      }

      ITpPolicyPlugin *tpPolicy = TpPolicyRegistry_CreateById(cfg.tpPolicyId);
      if(tpPolicy == NULL)
      {
         delete slPolicy;
         err = StringFormat("TP policy nao encontrada: %s", cfg.tpPolicyId);
         return(false);
      }

      ITsPolicyPlugin *tsPolicy = TsPolicyRegistry_CreateById(cfg.tsPolicyId);
      if(tsPolicy == NULL)
      {
         delete slPolicy;
         delete tpPolicy;
         err = StringFormat("TS policy nao encontrada: %s", cfg.tsPolicyId);
         return(false);
      }

      IBePolicyPlugin *bePolicy = BePolicyRegistry_CreateById(cfg.bePolicyId);
      if(bePolicy == NULL)
      {
         delete slPolicy;
         delete tpPolicy;
         delete tsPolicy;
         err = StringFormat("BE policy nao encontrada: %s", cfg.bePolicyId);
         return(false);
      }

      IPendingPolicyPlugin *pendingPolicy = PendingPolicyRegistry_CreateById(cfg.pendingPolicyId);
      if(pendingPolicy == NULL)
      {
         delete slPolicy;
         delete tpPolicy;
         delete tsPolicy;
         delete bePolicy;
         err = StringFormat("Pending policy nao encontrada: %s", cfg.pendingPolicyId);
         return(false);
      }

      IRiskPolicyPlugin *riskPolicy = RiskPolicyRegistry_CreateById(cfg.riskPolicyId);
      if(riskPolicy == NULL)
      {
         delete slPolicy;
         delete tpPolicy;
         delete tsPolicy;
         delete bePolicy;
         delete pendingPolicy;
         err = StringFormat("Risk policy nao encontrada: %s", cfg.riskPolicyId);
         return(false);
      }

      if(!InitPolicies(slPolicy, tpPolicy, tsPolicy, bePolicy, pendingPolicy, riskPolicy, cfg.policyCfg, err))
         return(false);

      return(true);
   }

   bool ValidatePoliciesForManage(const SOrderManagerConfig &cfg, string &reason) const
   {
      reason = "";
      if(!m_policiesReady)
      {
         reason = "manage: policies nao inicializadas";
         return(false);
      }

      if(cfg.execMode == OM_EXEC_HEDGE_OCO_V1)
         return(true);

      if(m_tp == NULL || m_ts == NULL || m_be == NULL)
      {
         reason = "manage: policies ausentes";
         return(false);
      }
      return(true);
   }

   bool ValidatePoliciesForOpen(const SSignalDecision &decision,
                                const SOrderManagerConfig &cfg,
                                string &reason) const
   {
      reason = "";
      if(!m_policiesReady)
      {
         reason = "open: policies nao inicializadas";
         return(false);
      }

      if(cfg.execMode == OM_EXEC_HEDGE_OCO_V1)
         return(true);

      if(m_sl == NULL || m_tp == NULL || m_pending == NULL || m_risk == NULL)
      {
         reason = "open: policies ausentes";
         return(false);
      }

      // Gate de policy nao bloqueia signal NONE.
      if(decision.signal == SIGNAL_NONE)
         return(true);

      return(true);
   }

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

   int BuildOpenRequests(const SSignalDecision &decision,
                         CIndicatorSnapshot &snapshot,
                         const SOrderManagerConfig &cfg,
                         SExecRequest &reqs[],
                         string &err)
   {
      err = "";
      ArrayResize(reqs, 0);

      if(!m_policiesReady || m_sl == NULL || m_tp == NULL || m_pending == NULL || m_risk == NULL)
      {
         err = "policies nao inicializadas";
         return(0);
      }

      double lotScale = 1.0;
      string riskReason = "";
      if(!m_risk.ComputeLotScale(decision.signal, snapshot, false, lotScale, riskReason))
      {
         snapshot.Report("risk", "compute_lot_scale", 2001, (riskReason == "" ? "falha sem detalhe" : riskReason));
         err = StringFormat("Risk policy (%s): falha ao calcular escala (%s)",
                            m_risk.Id(),
                            (riskReason == "" ? "sem detalhe" : riskReason));
         return(0);
      }
      if(!MathIsValidNumber(lotScale) || lotScale <= 0.0)
      {
         snapshot.Report("risk", "compute_lot_scale", 2002, StringFormat("escala invalida %.6f", lotScale));
         err = StringFormat("Risk policy (%s): escala invalida %.6f (%s)",
                            m_risk.Id(),
                            lotScale,
                            (riskReason == "" ? "sem detalhe" : riskReason));
         return(0);
      }
      snapshot.Upsert("risk.scale.applied", lotScale, lotScale, true);
      snapshot.Upsert("risk.scale.base_lots", cfg.lots, cfg.lots, true);
      snapshot.Upsert("risk.policy.id.Hedge70_30", (m_risk.Id() == "Hedge70_30" ? 1.0 : 0.0), (m_risk.Id() == "Hedge70_30" ? 1.0 : 0.0), true);
      snapshot.Report("risk", "compute_lot_scale", 0, (riskReason == "" ? "ok" : riskReason));

      if(cfg.execMode == OM_EXEC_HEDGE_OCO_V1)
      {
         SOrderManagerConfig scaledCfg = cfg;
         scaledCfg.lots = cfg.lots * lotScale;
         return(m_hedge.BuildOpenRequests(decision, snapshot, scaledCfg, reqs, err));
      }

      if(decision.signal == SIGNAL_NONE)
      {
         err = "signal none";
         return(0);
      }

      bool isBuy = (decision.signal == SIGNAL_BUY);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double entry = (isBuy ? ask : bid);
      double sl = 0.0;
      double tp1 = 0.0;
      string oneErr = "";

      if(!m_sl.ComputeInitialSL(decision.signal, snapshot, entry, sl, oneErr))
      {
         err = StringFormat("SL policy (%s): %s", m_sl.Id(), oneErr);
         return(0);
      }
      if(!m_tp.ComputeInitialTP1(decision.signal, snapshot, entry, sl, tp1, oneErr))
      {
         err = StringFormat("TP policy (%s): %s", m_tp.Id(), oneErr);
         return(0);
      }

      double leg1Frac = cfg.leg1Fraction;
      double leg2Frac = (cfg.openTwoLegs ? cfg.leg2Fraction : 0.0);
      double fracSum = leg1Frac + leg2Frac;
      if(fracSum <= 0.0)
      {
         err = "fracoes de lote invalidas";
         return(0);
      }

      // Primeiro aplica a escala de risco no lote TOTAL; depois reparte entre pernas.
      // Isso evita distorcao de 70/30 por arredondamento do step em cada perna separadamente.
      double scaledTotalLots = NormalizeVolume(cfg.lots * lotScale);
      if(scaledTotalLots <= 0.0)
      {
         err = StringFormat("volume total invalido apos risk policy (%s)", m_risk.Id());
         return(0);
      }

      double lot1 = 0.0;
      double lot2 = 0.0;
      if(cfg.openTwoLegs)
      {
         double leg1Target = scaledTotalLots * (leg1Frac / fracSum);
         lot1 = NormalizeVolume(leg1Target);
         lot2 = NormalizeVolume(scaledTotalLots - lot1);

         // Fallback: se step inviabilizar a perna 2, concentra tudo na perna 1.
         if(lot1 <= 0.0 && lot2 > 0.0)
         {
            lot1 = lot2;
            lot2 = 0.0;
         }
         if(lot2 <= 0.0)
            lot1 = NormalizeVolume(scaledTotalLots);
      }
      else
      {
         lot1 = NormalizeVolume(scaledTotalLots);
         lot2 = 0.0;
      }

      snapshot.Upsert("risk.scale.leg1_lot", lot1, lot1, (lot1 > 0.0));
      snapshot.Upsert("risk.scale.leg2_lot", lot2, lot2, (lot2 > 0.0));

      if(lot1 <= 0.0)
      {
         err = StringFormat("volume da perna 1 invalido apos risk policy (%s)", m_risk.Id());
         return(0);
      }

      SExecRequest r;
      r.action = (isBuy ? EXEC_ACTION_OPEN_BUY : EXEC_ACTION_OPEN_SELL);
      r.ticket = 0;
      r.volume = lot1;
      r.price = 0.0;
      r.stopLimit = 0.0;
      r.sl = sl;
      r.tp = tp1;
      r.comment = StringFormat("CSM-L1-%s", (isBuy ? "BUY" : "SELL"));
      PushRequest(reqs, r);

      if(cfg.openTwoLegs && lot2 > 0.0)
      {
         r.action = (isBuy ? EXEC_ACTION_OPEN_BUY : EXEC_ACTION_OPEN_SELL);
         r.ticket = 0;
         r.volume = lot2;
         r.price = 0.0;
         r.stopLimit = 0.0;
         r.sl = sl;
         r.tp = 0.0;
         r.comment = StringFormat("CSM-L2-%s", (isBuy ? "BUY" : "SELL"));
         PushRequest(reqs, r);
      }

      SExecRequest pendingReqs[];
      ArrayResize(pendingReqs, 0);
      string pendingErr = "";
      int pendingCount = m_pending.BuildPendingRequests(decision, snapshot, cfg, pendingReqs, pendingErr);
      if(pendingCount > 0)
      {
         for(int p = 0; p < pendingCount; p++)
            PushRequest(reqs, pendingReqs[p]);
      }

      return(ArraySize(reqs));
   }

   int BuildManageRequests(const CIndicatorSnapshot &snapshot,
                           const SOrderManagerConfig &cfg,
                           SExecRequest &reqs[],
                           string &summary)
   {
      ArrayResize(reqs, 0);
      summary = "";

      if(!m_policiesReady)
      {
         summary = "manage: policies nao inicializadas";
         return(0);
      }

      if(cfg.execMode == OM_EXEC_HEDGE_OCO_V1)
         return(m_hedge.BuildManageRequests(snapshot, cfg, reqs, summary));

      if(m_tp == NULL || m_ts == NULL || m_be == NULL)
      {
         summary = "manage: policies nao inicializadas";
         return(0);
      }

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(!MathIsValidNumber(bid) || !MathIsValidNumber(ask) || bid <= 0.0 || ask <= 0.0)
      {
         summary = "manage: bid/ask invalido";
         return(0);
      }

      int closed = 0;
      int modified = 0;
      int total = PositionsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;

         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != cfg.magic)
            continue;

         int posType = (int)PositionGetInteger(POSITION_TYPE);
         int signal = (posType == POSITION_TYPE_BUY ? SIGNAL_BUY : (posType == POSITION_TYPE_SELL ? SIGNAL_SELL : SIGNAL_NONE));
         if(signal == SIGNAL_NONE)
            continue;

         string comment = PositionGetString(POSITION_COMMENT);
         bool isLeg2 = (StringFind(comment, "CSM-L2-") >= 0);

         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);

         if(isLeg2)
         {
            bool shouldClose = false;
            string tpErr = "";
            if(m_tp.ShouldCloseFinal(signal, snapshot, openPrice, bid, ask, shouldClose, tpErr) && shouldClose)
            {
               SExecRequest closeReq;
               closeReq.action = EXEC_ACTION_CLOSE;
               closeReq.ticket = ticket;
               closeReq.volume = 0.0;
               closeReq.price = 0.0;
               closeReq.stopLimit = 0.0;
               closeReq.sl = 0.0;
               closeReq.tp = 0.0;
               closeReq.comment = "CSM-L2-CLOSE";
               PushRequest(reqs, closeReq);
               closed++;
               continue;
            }
         }

         double bestSL = sl;
         bool hasNewSL = false;

         double beSL = 0.0;
         string beErr = "";
         if(m_be.ComputeBreakEvenSL(signal, snapshot, openPrice, sl, tp, bid, ask, beSL, beErr))
         {
            if(IsSlImprovement(signal, bestSL, beSL))
            {
               bestSL = beSL;
               hasNewSL = true;
            }
         }

         double newSL = 0.0;
         string tsErr = "";
         if(m_ts.ComputeTrailingSL(signal, snapshot, openPrice, sl, tp, bid, ask, newSL, tsErr))
         {
            if(IsSlImprovement(signal, bestSL, newSL))
            {
               bestSL = newSL;
               hasNewSL = true;
            }
         }

         if(hasNewSL)
         {
            SExecRequest modReq;
            modReq.action = EXEC_ACTION_MODIFY;
            modReq.ticket = ticket;
            modReq.volume = 0.0;
            modReq.price = 0.0;
            modReq.stopLimit = 0.0;
            modReq.sl = bestSL;
            modReq.tp = tp;
            modReq.comment = "CSM-MANAGE-SL";
            PushRequest(reqs, modReq);
            modified++;
         }
      }

      summary = StringFormat("manage: close=%d modify=%d", closed, modified);
      return(ArraySize(reqs));
   }

   int OnTradeTransaction(const MqlTradeTransaction &trans,
                          const SOrderManagerConfig &cfg,
                          SExecRequest &reqs[],
                          string &summary)
   {
      ArrayResize(reqs, 0);
      summary = "";
      if(cfg.execMode != OM_EXEC_HEDGE_OCO_V1)
         return(0);
      return(m_hedge.OnTradeTransaction(trans, cfg, reqs, summary));
   }
};

#endif
