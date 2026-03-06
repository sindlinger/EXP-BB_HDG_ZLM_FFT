// [POLICY] PROIBIDO: EA nao pode compartilhar/passar inputs para indicador.
// [POLICY] Indicadores devem rodar com seus proprios inputs internos (iCustom sem parametros do EA).

#ifndef __CSM_RISK_HEDGE_70_30_MQH__
#define __CSM_RISK_HEDGE_70_30_MQH__

#include "..\\..\\..\\Contracts\\Interfaces.mqh"

class CRiskPolicy_Hedge70_30 : public IRiskPolicyPlugin
{
private:
   double m_scaleCountertrend;
   double m_scaleTrend;

   bool TryGet(const CIndicatorSnapshot &snapshot,
               const string key,
               double &curr,
               double &prev) const
   {
      curr = 0.0;
      prev = 0.0;
      return(snapshot.Get(key, curr, prev));
   }

public:
   CRiskPolicy_Hedge70_30()
   {
      m_scaleCountertrend = 0.30;
      m_scaleTrend = 0.70;
   }

   virtual string Id()
   {
      return("Hedge70_30");
   }

   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err)
   {
      err = "";
      if(cfg.riskCountertrendScale <= 0.0 || cfg.riskCountertrendScale >= 1.0)
      {
         err = "riskCountertrendScale invalido (esperado >0 e <1)";
         return(false);
      }

      m_scaleCountertrend = cfg.riskCountertrendScale;
      m_scaleTrend = (1.0 - m_scaleCountertrend);
      return(true);
   }

   virtual bool ComputeLotScale(const int signal,
                                const CIndicatorSnapshot &snapshot,
                                const bool isSecondLeg,
                                double &outScale,
                                string &reason)
   {
      outScale = 1.0;
      reason = "hedge70_30: scale=1.00 (neutro)";

      if(signal != SIGNAL_BUY && signal != SIGNAL_SELL)
         return(true);

      double buyTrend = 0.0, buyTrendPrev = 0.0;
      double buyCounter = 0.0, buyCounterPrev = 0.0;
      double sellTrend = 0.0, sellTrendPrev = 0.0;
      double sellCounter = 0.0, sellCounterPrev = 0.0;
      if(!TryGet(snapshot, "closescale.regime_buy_trend", buyTrend, buyTrendPrev) ||
         !TryGet(snapshot, "closescale.regime_buy_counter", buyCounter, buyCounterPrev) ||
         !TryGet(snapshot, "closescale.regime_sell_trend", sellTrend, sellTrendPrev) ||
         !TryGet(snapshot, "closescale.regime_sell_counter", sellCounter, sellCounterPrev))
      {
         reason = "hedge70_30: regimes canonicos indisponiveis, scale=1.00";
         return(true);
      }

      if(signal == SIGNAL_BUY)
      {
         if(buyTrend > 0.5)
         {
            outScale = m_scaleTrend;
            reason = StringFormat("hedge70_30 buy tendencia: scale=%.2f%s",
                                  outScale,
                                  (isSecondLeg ? " (leg2)" : ""));
            return(true);
         }
         if(buyCounter > 0.5)
         {
            outScale = m_scaleCountertrend;
            reason = StringFormat("hedge70_30 buy contratendencia: scale=%.2f%s",
                                  outScale,
                                  (isSecondLeg ? " (leg2)" : ""));
            return(true);
         }
      }
      else if(signal == SIGNAL_SELL)
      {
         if(sellTrend > 0.5)
         {
            outScale = m_scaleTrend;
            reason = StringFormat("hedge70_30 sell tendencia: scale=%.2f%s",
                                  outScale,
                                  (isSecondLeg ? " (leg2)" : ""));
            return(true);
         }
         if(sellCounter > 0.5)
         {
            outScale = m_scaleCountertrend;
            reason = StringFormat("hedge70_30 sell contratendencia: scale=%.2f%s",
                                  outScale,
                                  (isSecondLeg ? " (leg2)" : ""));
            return(true);
         }
      }

      return(true);
   }
};

IRiskPolicyPlugin* CreateRiskPolicy_Hedge70_30()
{
   return(new CRiskPolicy_Hedge70_30());
}

#endif
