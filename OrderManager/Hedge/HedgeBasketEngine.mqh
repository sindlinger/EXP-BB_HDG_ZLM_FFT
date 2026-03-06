// [POLICY] PROIBIDO: EA nao pode compartilhar/passar inputs para indicador.
// [POLICY] Indicadores devem rodar com seus proprios inputs internos (iCustom sem parametros do EA).

#ifndef __CSM_HEDGE_BASKET_ENGINE_MQH__
#define __CSM_HEDGE_BASKET_ENGINE_MQH__

#include "..\\..\\Config\\ConfigEnums.mqh"
#include "..\\..\\Contracts\\CoreTypes.mqh"
#include "..\\..\\Contracts\\Snapshot.mqh"
#include "HedgeCommentCodec.mqh"

class CHedgeBasketEngine
{
private:
   long m_nextBasketId;

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

   void AddUniqueLong(long &arr[], const long value) const
   {
      if(value <= 0)
         return;
      int n = ArraySize(arr);
      for(int i = 0; i < n; i++)
      {
         if(arr[i] == value)
            return;
      }
      ArrayResize(arr, n + 1);
      arr[n] = value;
   }

   void PushRequest(SExecRequest &arr[], const SExecRequest &req) const
   {
      int n = ArraySize(arr);
      ArrayResize(arr, n + 1);
      arr[n] = req;
   }

   bool ReadAnchorPrices(const CIndicatorSnapshot &snapshot,
                         double &zeroPrice,
                         double &up1Price,
                         double &dn1Price,
                         string &err) const
   {
      err = "";
      zeroPrice = 0.0;
      up1Price = 0.0;
      dn1Price = 0.0;

      double c = 0.0;
      double p = 0.0;
      if(!snapshot.Get("anchor.zero_price", c, p))
      {
         err = "missing key: anchor.zero_price";
         return(false);
      }
      zeroPrice = c;

      if(!snapshot.Get("anchor.up_1_price", c, p))
      {
         err = "missing key: anchor.up_1_price";
         return(false);
      }
      up1Price = c;

      if(!snapshot.Get("anchor.dn_1_price", c, p))
      {
         err = "missing key: anchor.dn_1_price";
         return(false);
      }
      dn1Price = c;

      if(!MathIsValidNumber(zeroPrice) || !MathIsValidNumber(up1Price) || !MathIsValidNumber(dn1Price) ||
         zeroPrice <= 0.0 || up1Price <= 0.0 || dn1Price <= 0.0)
      {
         err = "anchor prices invalidos";
         return(false);
      }
      if(!(up1Price > zeroPrice && zeroPrice > dn1Price))
      {
         err = "anchor ordering invalido (up > zero > dn)";
         return(false);
      }

      return(true);
   }

   void CollectBasketIdsFromPositions(const SOrderManagerConfig &cfg,
                                      long &ids[]) const
   {
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

         string comment = PositionGetString(POSITION_COMMENT);
         long bid = 0;
         string role = "";
         if(!CsmParseHedgeComment(comment, bid, role))
            continue;

         AddUniqueLong(ids, bid);
      }
   }

   void CollectBasketIdsFromOrders(const SOrderManagerConfig &cfg,
                                   long &ids[]) const
   {
      int total = OrdersTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0 || !OrderSelect(ticket))
            continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)
            continue;
         if((long)OrderGetInteger(ORDER_MAGIC) != cfg.magic)
            continue;

         string comment = OrderGetString(ORDER_COMMENT);
         long bid = 0;
         string role = "";
         if(!CsmParseHedgeComment(comment, bid, role))
            continue;

         AddUniqueLong(ids, bid);
      }
   }

   void CollectBasketIds(const SOrderManagerConfig &cfg,
                         long &ids[]) const
   {
      ArrayResize(ids, 0);
      CollectBasketIdsFromPositions(cfg, ids);
      CollectBasketIdsFromOrders(cfg, ids);
   }

   void CollectBasketItems(const SOrderManagerConfig &cfg,
                           const long basketId,
                           ulong &positionTickets[],
                           ulong &orderTickets[],
                           double &netPnl) const
   {
      ArrayResize(positionTickets, 0);
      ArrayResize(orderTickets, 0);
      netPnl = 0.0;

      int pTotal = PositionsTotal();
      for(int i = 0; i < pTotal; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != cfg.magic)
            continue;

         long id = 0;
         string role = "";
         string comment = PositionGetString(POSITION_COMMENT);
         if(!CsmParseHedgeComment(comment, id, role) || id != basketId)
            continue;

         int pn = ArraySize(positionTickets);
         ArrayResize(positionTickets, pn + 1);
         positionTickets[pn] = ticket;

         double posProfit = PositionGetDouble(POSITION_PROFIT);
         double posSwap = PositionGetDouble(POSITION_SWAP);
         if(MathIsValidNumber(posProfit))
            netPnl += posProfit;
         if(MathIsValidNumber(posSwap))
            netPnl += posSwap;
      }

      int oTotal = OrdersTotal();
      for(int i = 0; i < oTotal; i++)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0 || !OrderSelect(ticket))
            continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)
            continue;
         if((long)OrderGetInteger(ORDER_MAGIC) != cfg.magic)
            continue;

         long id = 0;
         string role = "";
         string comment = OrderGetString(ORDER_COMMENT);
         if(!CsmParseHedgeComment(comment, id, role) || id != basketId)
            continue;

         int on = ArraySize(orderTickets);
         ArrayResize(orderTickets, on + 1);
         orderTickets[on] = ticket;
      }
   }

public:
   CHedgeBasketEngine()
   {
      m_nextBasketId = 1;
   }

   void Reset()
   {
      m_nextBasketId = 1;
   }

   int CountActiveBaskets(const SOrderManagerConfig &cfg) const
   {
      long ids[];
      CollectBasketIds(cfg, ids);
      return(ArraySize(ids));
   }

   double SumActiveBasketNetPnl(const SOrderManagerConfig &cfg) const
   {
      double sum = 0.0;
      long ids[];
      CollectBasketIds(cfg, ids);
      int n = ArraySize(ids);
      for(int i = 0; i < n; i++)
      {
         ulong pos[];
         ulong ord[];
         double pnl = 0.0;
         CollectBasketItems(cfg, ids[i], pos, ord, pnl);
         sum += pnl;
      }
      return(sum);
   }

   int BuildOpenRequests(const SSignalDecision &decision,
                         const CIndicatorSnapshot &snapshot,
                         const SOrderManagerConfig &cfg,
                         SExecRequest &reqs[],
                         string &err)
   {
      err = "";
      ArrayResize(reqs, 0);

      if(decision.signal != SIGNAL_BUY && decision.signal != SIGNAL_SELL)
      {
         err = "hedge: signal none";
         return(0);
      }

      double zeroPrice = 0.0;
      double up1Price = 0.0;
      double dn1Price = 0.0;
      if(!ReadAnchorPrices(snapshot, zeroPrice, up1Price, dn1Price, err))
         return(0);

      double strongW = cfg.hedgeCfg.biasStrongWeight;
      if(!MathIsValidNumber(strongW) || strongW <= 0.5 || strongW >= 1.0)
         strongW = 0.70;
      double weakW = 1.0 - strongW;

      double buyW = (decision.signal == SIGNAL_BUY ? strongW : weakW);
      double sellW = (decision.signal == SIGNAL_SELL ? strongW : weakW);

      double buyVol = NormalizeVolume(cfg.lots * buyW);
      double sellVol = NormalizeVolume(cfg.lots * sellW);
      if(buyVol <= 0.0 || sellVol <= 0.0)
      {
         err = "hedge: volume invalido";
         return(0);
      }

      long basketId = m_nextBasketId;
      if(basketId <= 0)
         basketId = 1;
      m_nextBasketId = basketId + 1;

      string buyComment = "";
      string sellComment = "";
      if(!CsmBuildHedgeComment(basketId, CSM_HEDGE_ROLE_PENDING_BUY, buyComment) ||
         !CsmBuildHedgeComment(basketId, CSM_HEDGE_ROLE_PENDING_SELL, sellComment))
      {
         err = "hedge: falha ao montar comentario de cesta";
         return(0);
      }

      SExecRequest buyReq;
      buyReq.action = EXEC_ACTION_NONE;
      buyReq.ticket = 0;
      buyReq.volume = buyVol;
      buyReq.price = NormalizeDouble(up1Price, _Digits);
      buyReq.stopLimit = 0.0;
      buyReq.sl = 0.0;
      buyReq.tp = 0.0;
      buyReq.comment = buyComment;

      SExecRequest sellReq;
      sellReq.action = EXEC_ACTION_NONE;
      sellReq.ticket = 0;
      sellReq.volume = sellVol;
      sellReq.price = NormalizeDouble(dn1Price, _Digits);
      sellReq.stopLimit = 0.0;
      sellReq.sl = 0.0;
      sellReq.tp = 0.0;
      sellReq.comment = sellComment;

      if(cfg.hedgeCfg.orderFamily == HEDGE_OCO_FAMILY_STOP_LIMIT || cfg.hedgeCfg.orderFamily == HEDGE_OCO_FAMILY_STOP)
      {
         double frac = cfg.hedgeCfg.stopLimitPullbackFrac;
         if(!MathIsValidNumber(frac) || frac <= 0.0 || frac >= 1.0)
            frac = 0.35;

         double buyStopLimit = zeroPrice + (up1Price - zeroPrice) * frac;
         double sellStopLimit = zeroPrice - (zeroPrice - dn1Price) * frac;
         if(!(buyStopLimit > zeroPrice && buyStopLimit < up1Price))
         {
            err = "hedge: buy stop-limit invalido";
            return(0);
         }
         if(!(sellStopLimit < zeroPrice && sellStopLimit > dn1Price))
         {
            err = "hedge: sell stop-limit invalido";
            return(0);
         }

         buyReq.action = EXEC_ACTION_OPEN_BUY_STOP_LIMIT;
         sellReq.action = EXEC_ACTION_OPEN_SELL_STOP_LIMIT;
         buyReq.stopLimit = NormalizeDouble(buyStopLimit, _Digits);
         sellReq.stopLimit = NormalizeDouble(sellStopLimit, _Digits);
      }

      PushRequest(reqs, buyReq);
      PushRequest(reqs, sellReq);
      return(ArraySize(reqs));
   }

   int BuildManageRequests(const CIndicatorSnapshot &snapshot,
                           const SOrderManagerConfig &cfg,
                           SExecRequest &reqs[],
                           string &summary)
   {
      ArrayResize(reqs, 0);
      summary = "";

      long ids[];
      CollectBasketIds(cfg, ids);
      int n = ArraySize(ids);
      if(n <= 0)
      {
         summary = "hedge-manage: sem cestas";
         return(0);
      }

      int closeReqs = 0;
      int delReqs = 0;
      for(int i = 0; i < n; i++)
      {
         ulong posTickets[];
         ulong ordTickets[];
         double netPnl = 0.0;
         CollectBasketItems(cfg, ids[i], posTickets, ordTickets, netPnl);

         int posCount = ArraySize(posTickets);
         int ordCount = ArraySize(ordTickets);
         bool closeBasket = (posCount > 0 && (netPnl >= cfg.hedgeCfg.targetMoney || netPnl <= -cfg.hedgeCfg.stopMoney));

         if(closeBasket)
         {
            for(int p = 0; p < posCount; p++)
            {
               SExecRequest r;
               r.action = EXEC_ACTION_CLOSE;
               r.ticket = posTickets[p];
               r.volume = 0.0;
               r.price = 0.0;
               r.stopLimit = 0.0;
               r.sl = 0.0;
               r.tp = 0.0;
               r.comment = StringFormat("HEDGE-CLOSE|%I64d", ids[i]);
               PushRequest(reqs, r);
               closeReqs++;
            }
            for(int o = 0; o < ordCount; o++)
            {
               SExecRequest r;
               r.action = EXEC_ACTION_DELETE_ORDER;
               r.ticket = ordTickets[o];
               r.volume = 0.0;
               r.price = 0.0;
               r.stopLimit = 0.0;
               r.sl = 0.0;
               r.tp = 0.0;
               r.comment = StringFormat("HEDGE-CLR-PEND|%I64d", ids[i]);
               PushRequest(reqs, r);
               delReqs++;
            }
            continue;
         }

         // Fallback de consistencia OCO: se ja existe posicao na cesta, remove pendentes remanescentes.
         if(posCount > 0 && ordCount > 0)
         {
            for(int o = 0; o < ordCount; o++)
            {
               SExecRequest r;
               r.action = EXEC_ACTION_DELETE_ORDER;
               r.ticket = ordTickets[o];
               r.volume = 0.0;
               r.price = 0.0;
               r.stopLimit = 0.0;
               r.sl = 0.0;
               r.tp = 0.0;
               r.comment = StringFormat("HEDGE-OCO-FALLBACK|%I64d", ids[i]);
               PushRequest(reqs, r);
               delReqs++;
            }
         }
      }

      summary = StringFormat("hedge-manage: closeReq=%d deleteReq=%d", closeReqs, delReqs);
      return(ArraySize(reqs));
   }

   int OnTradeTransaction(const MqlTradeTransaction &trans,
                          const SOrderManagerConfig &cfg,
                          SExecRequest &reqs[],
                          string &summary)
   {
      ArrayResize(reqs, 0);
      summary = "";

      if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
         return(0);
      if(trans.deal == 0)
         return(0);
      if(trans.symbol != _Symbol)
         return(0);

      if(!HistoryDealSelect(trans.deal))
         return(0);

      long dealMagic = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
      if(dealMagic != cfg.magic)
         return(0);

      string dealComment = HistoryDealGetString(trans.deal, DEAL_COMMENT);
      long basketId = 0;
      string role = "";
      if(!CsmParseHedgeComment(dealComment, basketId, role))
         return(0);

      string siblingRole = "";
      if(role == CSM_HEDGE_ROLE_PENDING_BUY)
         siblingRole = CSM_HEDGE_ROLE_PENDING_SELL;
      else if(role == CSM_HEDGE_ROLE_PENDING_SELL)
         siblingRole = CSM_HEDGE_ROLE_PENDING_BUY;
      else
         return(0);

      int deleted = 0;
      int total = OrdersTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0 || !OrderSelect(ticket))
            continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)
            continue;
         if((long)OrderGetInteger(ORDER_MAGIC) != cfg.magic)
            continue;

         long id = 0;
         string rl = "";
         string comment = OrderGetString(ORDER_COMMENT);
         if(!CsmParseHedgeComment(comment, id, rl))
            continue;
         if(id != basketId)
            continue;
         if(rl != siblingRole)
            continue;

         SExecRequest r;
         r.action = EXEC_ACTION_DELETE_ORDER;
         r.ticket = ticket;
         r.volume = 0.0;
         r.price = 0.0;
         r.stopLimit = 0.0;
         r.sl = 0.0;
         r.tp = 0.0;
         r.comment = StringFormat("HEDGE-OCO|%I64d", basketId);
         PushRequest(reqs, r);
         deleted++;
      }

      if(deleted > 0)
         summary = StringFormat("hedge-oco: basket=%I64d sibling_cancel=%d", basketId, deleted);
      return(ArraySize(reqs));
   }
};

#endif
