#ifndef __CSM_EXEC_MODULE_MQH__
#define __CSM_EXEC_MODULE_MQH__

#include <Trade/Trade.mqh>
#include "..\\Contracts\\CoreTypes.mqh"

class CExecModule
{
private:
   CTrade m_trade;

public:
   void Init(const long magic, const int deviationPoints)
   {
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

      res.accepted = true;
      res.stage = "execute";

      bool ok = false;
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
         {
            string sym = PositionGetString(POSITION_SYMBOL);
            ok = m_trade.PositionModify(sym, req.sl, req.tp);
         }
      }

      res.retcode = (int)m_trade.ResultRetcode();
      res.ticket = (ulong)m_trade.ResultOrder();
      res.executed = ok;
      res.message = (ok ? "exec ok" : "exec fail");
      return(ok);
   }
};

#endif
