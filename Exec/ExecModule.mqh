// [POLICY] PROIBIDO: EA nao pode compartilhar/passar inputs para indicador.
// [POLICY] Indicadores devem rodar com seus proprios inputs internos (iCustom sem parametros do EA).

#ifndef __CSM_EXEC_MODULE_MQH__
#define __CSM_EXEC_MODULE_MQH__

#include <Trade/Trade.mqh>
#include "..\\Contracts\\CoreTypes.mqh"

class CExecModule
{
private:
   CTrade m_trade;
   long m_magic;
   int m_deviationPoints;

   bool SendStopLimitOrder(const SExecRequest &req,
                           const ENUM_ORDER_TYPE orderType,
                           int &outRetcode,
                           ulong &outTicket)
   {
      outRetcode = 0;
      outTicket = 0;

      MqlTradeRequest tr;
      MqlTradeResult rs;
      ZeroMemory(tr);
      ZeroMemory(rs);

      tr.action = TRADE_ACTION_PENDING;
      tr.symbol = _Symbol;
      tr.magic = m_magic;
      tr.volume = req.volume;
      tr.type = orderType;
      tr.price = req.price;
      tr.stoplimit = req.stopLimit;
      tr.sl = req.sl;
      tr.tp = req.tp;
      tr.deviation = m_deviationPoints;
      tr.type_time = ORDER_TIME_GTC;
      tr.type_filling = ORDER_FILLING_RETURN;
      tr.comment = req.comment;

      bool sent = OrderSend(tr, rs);
      outRetcode = (int)rs.retcode;
      outTicket = (ulong)rs.order;
      return(sent && (rs.retcode == TRADE_RETCODE_DONE || rs.retcode == TRADE_RETCODE_PLACED));
   }

public:
   void Init(const long magic, const int deviationPoints)
   {
      m_magic = magic;
      m_deviationPoints = deviationPoints;
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(deviationPoints);
   }

   bool Execute(const SExecRequest &req, SExecResult &res)
   {
      res.accepted = false;
      res.executed = false;
      res.retcode = 0;
      res.ticket = 0;
      res.stage = "receive";
      res.message = "";

      if(req.action == EXEC_ACTION_NONE)
      {
         res.message = "acao NONE";
         return(false);
      }

      if((req.action == EXEC_ACTION_OPEN_BUY || req.action == EXEC_ACTION_OPEN_SELL) && req.volume <= 0.0)
      {
         res.message = "volume invalido";
         return(false);
      }
      if((req.action == EXEC_ACTION_OPEN_BUY_LIMIT ||
          req.action == EXEC_ACTION_OPEN_SELL_LIMIT ||
          req.action == EXEC_ACTION_OPEN_BUY_STOP ||
          req.action == EXEC_ACTION_OPEN_SELL_STOP ||
          req.action == EXEC_ACTION_OPEN_BUY_STOP_LIMIT ||
          req.action == EXEC_ACTION_OPEN_SELL_STOP_LIMIT) &&
         (req.volume <= 0.0 || req.price <= 0.0))
      {
         res.message = "volume/preco invalido para pending";
         return(false);
      }
      if((req.action == EXEC_ACTION_OPEN_BUY_STOP_LIMIT || req.action == EXEC_ACTION_OPEN_SELL_STOP_LIMIT) &&
         req.stopLimit <= 0.0)
      {
         res.message = "stopLimit invalido para stop-limit";
         return(false);
      }

      res.accepted = true;
      res.stage = "execute";

      bool ok = false;
      bool usedRawResult = false;
      int rawRetcode = 0;
      ulong rawTicket = 0;
      if(req.action == EXEC_ACTION_OPEN_BUY)
         ok = m_trade.Buy(req.volume, _Symbol, 0.0, req.sl, req.tp, req.comment);
      else if(req.action == EXEC_ACTION_OPEN_SELL)
         ok = m_trade.Sell(req.volume, _Symbol, 0.0, req.sl, req.tp, req.comment);
      else if(req.action == EXEC_ACTION_CLOSE)
         ok = m_trade.PositionClose(req.ticket);
      else if(req.action == EXEC_ACTION_MODIFY)
      {
         if(req.ticket == 0 || !PositionSelectByTicket(req.ticket))
            ok = false;
         else
            ok = m_trade.PositionModify(req.ticket, req.sl, req.tp);
      }
      else if(req.action == EXEC_ACTION_OPEN_BUY_LIMIT)
      {
         ok = m_trade.BuyLimit(req.volume, req.price, _Symbol, req.sl, req.tp, ORDER_TIME_GTC, 0, req.comment);
      }
      else if(req.action == EXEC_ACTION_OPEN_SELL_LIMIT)
      {
         ok = m_trade.SellLimit(req.volume, req.price, _Symbol, req.sl, req.tp, ORDER_TIME_GTC, 0, req.comment);
      }
      else if(req.action == EXEC_ACTION_OPEN_BUY_STOP)
      {
         ok = m_trade.BuyStop(req.volume, req.price, _Symbol, req.sl, req.tp, ORDER_TIME_GTC, 0, req.comment);
      }
      else if(req.action == EXEC_ACTION_OPEN_SELL_STOP)
      {
         ok = m_trade.SellStop(req.volume, req.price, _Symbol, req.sl, req.tp, ORDER_TIME_GTC, 0, req.comment);
      }
      else if(req.action == EXEC_ACTION_OPEN_BUY_STOP_LIMIT)
      {
         usedRawResult = true;
         ok = SendStopLimitOrder(req, ORDER_TYPE_BUY_STOP_LIMIT, rawRetcode, rawTicket);
      }
      else if(req.action == EXEC_ACTION_OPEN_SELL_STOP_LIMIT)
      {
         usedRawResult = true;
         ok = SendStopLimitOrder(req, ORDER_TYPE_SELL_STOP_LIMIT, rawRetcode, rawTicket);
      }
      else if(req.action == EXEC_ACTION_DELETE_ORDER)
      {
         ok = (req.ticket != 0 && m_trade.OrderDelete(req.ticket));
      }

      if(usedRawResult)
      {
         res.retcode = rawRetcode;
         res.ticket = rawTicket;
      }
      else
      {
         res.retcode = (int)m_trade.ResultRetcode();
         res.ticket = (ulong)m_trade.ResultOrder();
      }
      res.executed = ok;
      res.message = (ok ? "exec ok" : "exec fail");
      return(ok);
   }
};

#endif
