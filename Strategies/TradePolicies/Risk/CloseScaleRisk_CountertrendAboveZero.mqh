#ifndef __CSM_RISK_CLOSESCALE_COUNTERTREND_ABOVE_ZERO_MQH__
#define __CSM_RISK_CLOSESCALE_COUNTERTREND_ABOVE_ZERO_MQH__

#include "..\\..\\..\\Contracts\\Interfaces.mqh"

class CRiskPolicy_CloseScaleCountertrendAboveZero : public IRiskPolicyPlugin
{
private:
   double m_scaleCountertrend;

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
   CRiskPolicy_CloseScaleCountertrendAboveZero()
   {
      m_scaleCountertrend = 0.35;
   }

   virtual string Id()
   {
      return("CloseScaleRisk_CountertrendAboveZero");
   }

   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err)
   {
      err = "";
      if(cfg.riskCountertrendScale <= 0.0 || cfg.riskCountertrendScale > 1.0)
      {
         err = "riskCountertrendScale invalido (esperado >0 e <=1)";
         return(false);
      }

      m_scaleCountertrend = cfg.riskCountertrendScale;
      return(true);
   }

   virtual bool ComputeLotScale(const int signal,
                                const CIndicatorSnapshot &snapshot,
                                const bool isSecondLeg,
                                double &outScale,
                                string &reason)
   {
      outScale = 1.0;
      reason = "risk normal: scale=1.00";

      if(signal != SIGNAL_BUY && signal != SIGNAL_SELL)
         return(true);

      // Regra solicitada:
      // quando cruza para baixo a(s) banda(s), mas ainda acima de zero,
      // entrada de contratendencia deve usar lote menor.
      if(signal != SIGNAL_SELL)
         return(true);

      double waveCurr = 0.0, wavePrev = 0.0;
      double upCurr = 0.0, upPrev = 0.0;
      double midCurr = 0.0, midPrev = 0.0;
      double dnCurr = 0.0, dnPrev = 0.0;
      double zeroCurr = 0.0, zeroPrev = 0.0;

      if(!TryGet(snapshot, "forecast.wave", waveCurr, wavePrev) ||
         !TryGet(snapshot, "forecast.band_up", upCurr, upPrev) ||
         !TryGet(snapshot, "forecast.band_mid", midCurr, midPrev) ||
         !TryGet(snapshot, "forecast.band_dn", dnCurr, dnPrev) ||
         !TryGet(snapshot, "const.zero", zeroCurr, zeroPrev))
      {
         reason = "risk: contrato incompleto, mantendo scale=1.00";
         return(true);
      }

      bool crossDownAny = ((wavePrev >= upPrev && waveCurr < upCurr) ||
                           (wavePrev >= midPrev && waveCurr < midCurr) ||
                           (wavePrev >= dnPrev && waveCurr < dnCurr));

      bool aboveZero = (waveCurr > zeroCurr);
      if(crossDownAny && aboveZero)
      {
         outScale = m_scaleCountertrend;
         reason = StringFormat("risk contratendencia acima de zero: scale=%.2f%s",
                               outScale,
                               (isSecondLeg ? " (leg2)" : ""));
      }

      return(true);
   }
};

IRiskPolicyPlugin* CreateRiskPolicy_CloseScaleCountertrendAboveZero()
{
   return(new CRiskPolicy_CloseScaleCountertrendAboveZero());
}

#endif
