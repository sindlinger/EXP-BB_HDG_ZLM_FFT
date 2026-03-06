// [POLICY] PROIBIDO: EA nao pode compartilhar/passar inputs para indicador.
// [POLICY] Indicadores devem rodar com seus proprios inputs internos (iCustom sem parametros do EA).

#ifndef __CSM_STRATEGY_MODULE_MQH__
#define __CSM_STRATEGY_MODULE_MQH__

#include "..\\Contracts\\Interfaces.mqh"
#include "..\\Generated\\StrategyRegistry.generated.mqh"

class CStrategyModule
{
private:
   IStrategyPlugin* m_strategy;
   string m_id;
   CStrategyParamBag m_params;

   string OpText(const int op) const
   {
      if(op == COND_GT)
         return(">");
      if(op == COND_LT)
         return("<");
      if(op == COND_CROSS_UP)
         return("CRUZA_CIMA");
      if(op == COND_CROSS_DOWN)
         return("CRUZA_BAIXO");
      return("?");
   }

   string Fmt(const double v) const
   {
      if(!MathIsValidNumber(v))
         return("nan");
      return(DoubleToString(v, 5));
   }

   bool BufferNeedsPrev(const string key) const
   {
      return(key == "forecast.wave" ||
             key == "forecast.band_up" ||
             key == "forecast.band_dn");
   }

   void AppendPart(string &dst, const string part) const
   {
      if(part == "")
         return;
      if(dst != "")
         dst += " | ";
      dst += part;
   }

   void AddUniqueKey(const string key, string &keys[]) const
   {
      if(key == "")
         return;
      int n = ArraySize(keys);
      for(int i = 0; i < n; i++)
      {
         if(keys[i] == key)
            return;
      }
      ArrayResize(keys, n + 1);
      keys[n] = key;
   }

   void CollectRuleKeys(const CSignalRule &rule, string &keys[]) const
   {
      ArrayResize(keys, 0);
      string l = "", r = "";
      int op = COND_GT;
      for(int i = 0; i < rule.BuyCount(); i++)
      {
         if(rule.GetBuy(i, l, op, r))
         {
            AddUniqueKey(l, keys);
            AddUniqueKey(r, keys);
         }
      }
      for(int i = 0; i < rule.SellCount(); i++)
      {
         if(rule.GetSell(i, l, op, r))
         {
            AddUniqueKey(l, keys);
            AddUniqueKey(r, keys);
         }
      }
   }

   string BuildBufferTrace(const CIndicatorSnapshot &snap, const CSignalRule &rule) const
   {
      string keys[];
      CollectRuleKeys(rule, keys);
      if(ArraySize(keys) <= 0)
         return("sem buffers mapeados na regra");

      string out = "";
      for(int i = 0; i < ArraySize(keys); i++)
      {
         string k = keys[i];
         double c = 0.0, p = 0.0;
         if(snap.Get(k, c, p))
         {
            if(BufferNeedsPrev(k))
               AppendPart(out, StringFormat("%s=%s(p=%s)", k, Fmt(c), Fmt(p)));
            else
               AppendPart(out, StringFormat("%s=%s", k, Fmt(c)));
         }
         else
            AppendPart(out, StringFormat("%s=MISSING", k));
      }
      return(out);
   }

   bool EvalCondition(const CIndicatorSnapshot &snap,
                      const string left,
                      const int op,
                      const string right,
                      bool &ok,
                      string &why,
                      double &lc,
                      double &lp,
                      double &rc,
                      double &rp) const
   {
      ok = false;
      why = "";
      lc = 0.0;
      lp = 0.0;
      rc = 0.0;
      rp = 0.0;
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
                string &failReason,
                string &traceOut) const
   {
      failReason = "";
      traceOut = "";
      int n = (buySide ? rule.BuyCount() : rule.SellCount());
      if(n <= 0)
      {
         failReason = "rule-set vazio";
         traceOut = "rule-set vazio";
         return(false);
      }

      bool anyFail = false;
      string firstFail = "";
      for(int i = 0; i < n; i++)
      {
         string left = "", right = "";
         int op = COND_GT;
         bool got = (buySide ? rule.GetBuy(i, left, op, right) : rule.GetSell(i, left, op, right));
         if(!got)
         {
            failReason = "falha leitura da regra";
            AppendPart(traceOut, "falha leitura da regra");
            return(false);
         }

         bool condOk = false;
         string why = "";
         double lc = 0.0, lp = 0.0, rc = 0.0, rp = 0.0;
         if(!EvalCondition(snap, left, op, right, condOk, why, lc, lp, rc, rp))
         {
            string descErr = StringFormat("ERRO: %s %s %s (%s)", left, OpText(op), right, why);
            AppendPart(traceOut, descErr);
            failReason = descErr;
            return(false);
         }

         string desc = StringFormat("%s: %s %s %s",
                                    (condOk ? "OK" : "FAIL"),
                                    left,
                                    OpText(op),
                                    right);
         AppendPart(traceOut, desc);
         if(!condOk)
         {
            anyFail = true;
            if(firstFail == "")
               firstFail = StringFormat("%s %s %s (l=%s/%s r=%s/%s)",
                                        left, OpText(op), right,
                                        Fmt(lc), Fmt(lp), Fmt(rc), Fmt(rp));
         }
      }
      if(anyFail)
      {
         failReason = firstFail;
         return(false);
      }
      return(true);
   }

public:
   CStrategyModule()
   {
      m_strategy = NULL;
      m_id = "";
      m_params.Clear();
   }

   void Deinit()
   {
      if(m_strategy != NULL)
      {
         delete m_strategy;
         m_strategy = NULL;
      }
      m_id = "";
   }

   bool Init(const string desiredId, string &err)
   {
      err = "";
      Deinit();

      string allIds[];
      int n = StrategyRegistry_ListIds(allIds);
      if(n <= 0)
      {
         err = "nenhuma estrategia registrada";
         return(false);
      }

      string chosen = desiredId;
      if(chosen == "" || chosen == "AUTO_FIRST")
         chosen = allIds[0];

      m_strategy = StrategyRegistry_CreateById(chosen);
      if(m_strategy == NULL)
      {
         err = StringFormat("estrategia nao encontrada: %s", chosen);
         return(false);
      }

      m_id = chosen;
      m_strategy.Configure(m_params);
      return(true);
   }

   void SetParams(const CStrategyParamBag &params)
   {
      m_params = params;
      if(m_strategy != NULL)
         m_strategy.Configure(m_params);
   }

   bool BuildRule(CSignalRule &rule, string &err)
   {
      err = "";
      if(m_strategy == NULL)
      {
         err = "strategy module nao inicializado";
         return(false);
      }
      return(m_strategy.BuildEntryRule(rule, err));
   }

   bool EvaluateSignal(const CIndicatorSnapshot &snapshot,
                       const CSignalRule &rule,
                       SSignalDecision &out) const
   {
      out.signal = SIGNAL_NONE;
      out.buyArmed = false;
      out.sellArmed = false;
      out.reason = "";
      out.buyTrace = "";
      out.sellTrace = "";
      out.buffersTrace = "";

      string buyFail = "";
      string sellFail = "";
      string buyTrace = "";
      string sellTrace = "";

      out.buyArmed = EvalSet(snapshot, rule, true, buyFail, buyTrace);
      out.sellArmed = EvalSet(snapshot, rule, false, sellFail, sellTrace);
      out.buyTrace = buyTrace;
      out.sellTrace = sellTrace;
      out.buffersTrace = BuildBufferTrace(snapshot, rule);

      if(out.buyArmed && !out.sellArmed)
      {
         out.signal = SIGNAL_BUY;
         out.reason = "gatilho BUY confirmado";
         return(true);
      }
      if(out.sellArmed && !out.buyArmed)
      {
         out.signal = SIGNAL_SELL;
         out.reason = "gatilho SELL confirmado";
         return(true);
      }
      if(out.buyArmed && out.sellArmed)
      {
         out.signal = SIGNAL_NONE;
         out.reason = "conflito: BUY e SELL simultaneos";
         return(true);
      }

      out.signal = SIGNAL_NONE;
      out.reason = StringFormat("sem sinal | BUY falhou: %s | SELL falhou: %s", buyFail, sellFail);
      return(true);
   }

   void ApplyDecisionSnapshot(CIndicatorSnapshot &snapshot,
                              const SSignalDecision &decision)
   {
      if(m_strategy == NULL)
         return;
      m_strategy.ApplyDecisionSnapshot(snapshot, decision);
   }

   void FillStrategyViewState(const CIndicatorSnapshot &snapshot,
                              const SSignalDecision &decision,
                              const bool useEffortAuth,
                              const bool useMfiAuth,
                              const int activeBaskets,
                              const double basketNetPnl,
                              SRuntimeViewState &st)
   {
      if(m_strategy == NULL)
         return;
      m_strategy.FillViewState(snapshot,
                               decision,
                               useEffortAuth,
                               useMfiAuth,
                               activeBaskets,
                               basketNetPnl,
                               st);
   }

   string CurrentId() const
   {
      return(m_id);
   }
};

#endif
