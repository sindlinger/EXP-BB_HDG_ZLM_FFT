#ifndef __CSM_ENTRY_SIGNAL_MODULE_MQH__
#define __CSM_ENTRY_SIGNAL_MODULE_MQH__

#include "..\\Contracts\\Interfaces.mqh"

class CEntrySignalModule
{
private:
   bool EvalCondition(const CIndicatorSnapshot &snap,
                      const string left,
                      const int op,
                      const string right,
                      bool &ok,
                      string &why) const
   {
      ok = false;
      why = "";

      double lc = 0.0, lp = 0.0;
      double rc = 0.0, rp = 0.0;
      if(!snap.Get(left, lc, lp))
      {
         why = StringFormat("missing key: %s", left);
         return(false);
      }
      if(!snap.Get(right, rc, rp))
      {
         why = StringFormat("missing key: %s", right);
         return(false);
      }

      if(op == COND_GT)
         ok = (lc > rc);
      else if(op == COND_LT)
         ok = (lc < rc);
      else if(op == COND_CROSS_UP)
         ok = (lp <= rp && lc > rc);
      else if(op == COND_CROSS_DOWN)
         ok = (lp >= rp && lc < rc);
      else
      {
         why = "op invalida";
         return(false);
      }

      return(true);
   }

   bool EvalSet(const CIndicatorSnapshot &snap,
                const CSignalRule &rule,
                const bool buySide,
                string &failReason) const
   {
      failReason = "";
      int n = (buySide ? rule.BuyCount() : rule.SellCount());
      if(n <= 0)
      {
         failReason = "rule-set vazio";
         return(false);
      }

      for(int i = 0; i < n; i++)
      {
         string left = "", right = "";
         int op = COND_GT;
         bool got = (buySide ? rule.GetBuy(i, left, op, right) : rule.GetSell(i, left, op, right));
         if(!got)
         {
            failReason = "falha leitura da regra";
            return(false);
         }

         bool condOk = false;
         string why = "";
         if(!EvalCondition(snap, left, op, right, condOk, why))
         {
            failReason = why;
            return(false);
         }
         if(!condOk)
         {
            failReason = StringFormat("condicao false: %s op=%d %s", left, op, right);
            return(false);
         }
      }
      return(true);
   }

public:
   bool Evaluate(const CIndicatorSnapshot &snap,
                 const CSignalRule &rule,
                 SSignalDecision &out) const
   {
      out.signal = SIGNAL_NONE;
      out.buyArmed = false;
      out.sellArmed = false;
      out.reason = "";

      string buyFail = "";
      string sellFail = "";

      out.buyArmed = EvalSet(snap, rule, true, buyFail);
      out.sellArmed = EvalSet(snap, rule, false, sellFail);

      if(out.buyArmed && !out.sellArmed)
      {
         out.signal = SIGNAL_BUY;
         out.reason = "buy armed";
         return(true);
      }
      if(out.sellArmed && !out.buyArmed)
      {
         out.signal = SIGNAL_SELL;
         out.reason = "sell armed";
         return(true);
      }
      if(out.buyArmed && out.sellArmed)
      {
         out.signal = SIGNAL_NONE;
         out.reason = "conflict: buy/sell armed";
         return(true);
      }

      out.signal = SIGNAL_NONE;
      out.reason = StringFormat("buy=%s | sell=%s", buyFail, sellFail);
      return(true);
   }
};

#endif
