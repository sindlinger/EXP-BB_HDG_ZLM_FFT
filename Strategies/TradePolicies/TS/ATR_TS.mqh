#ifndef __CSM_TS_ATR_MQH__
#define __CSM_TS_ATR_MQH__

#include "..\\..\\..\\Contracts\\Interfaces.mqh"

class CTsPolicy_ATR : public ITsPolicyPlugin
{
private:
   int m_atrHandle;
   int m_period;
   double m_mult;
   string m_symbol;
   ENUM_TIMEFRAMES m_tf;

   void ReleaseAtr()
   {
      if(m_atrHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_atrHandle);
         m_atrHandle = INVALID_HANDLE;
      }
   }

   bool ReadAtr(double &out, string &err)
   {
      err = "";
      out = 0.0;
      ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
      if(m_atrHandle == INVALID_HANDLE || m_symbol != _Symbol || m_tf != tf)
      {
         ReleaseAtr();
         m_atrHandle = iATR(_Symbol, tf, m_period);
         m_symbol = _Symbol;
         m_tf = tf;
      }
      if(m_atrHandle == INVALID_HANDLE)
      {
         err = "falha handle ATR";
         return(false);
      }

      double v[1];
      int c = CopyBuffer(m_atrHandle, 0, 1, 1, v);
      if(c < 1 || !MathIsValidNumber(v[0]) || v[0] <= 0.0)
      {
         err = "falha leitura ATR";
         return(false);
      }

      out = v[0];
      return(true);
   }

public:
   CTsPolicy_ATR()
   {
      m_atrHandle = INVALID_HANDLE;
      m_period = 14;
      m_mult = 1.0;
      m_symbol = "";
      m_tf = PERIOD_CURRENT;
   }

   virtual string Id()
   {
      return("ATR_TS");
   }

   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err)
   {
      err = "";
      if(cfg.trailAtrPeriod < 1 || cfg.trailAtrMult <= 0.0)
      {
         err = "parametros ATR invalidos";
         return(false);
      }
      m_period = cfg.trailAtrPeriod;
      m_mult = cfg.trailAtrMult;
      return(true);
   }

   virtual bool ComputeTrailingSL(const int signal,
                                  const CIndicatorSnapshot &snapshot,
                                  const double openPrice,
                                  const double currentSL,
                                  const double currentTP,
                                  const double bid,
                                  const double ask,
                                  double &outSL,
                                  string &err)
   {
      err = "";
      outSL = 0.0;

      if(signal != SIGNAL_BUY && signal != SIGNAL_SELL)
      {
         err = "signal invalido no trailing ATR";
         return(false);
      }
      if(!MathIsValidNumber(bid) || !MathIsValidNumber(ask) || bid <= 0.0 || ask <= 0.0)
         return(false);

      double atr = 0.0;
      if(!ReadAtr(atr, err))
         return(false);

      double desiredSL = (signal == SIGNAL_BUY)
                         ? (bid - m_mult * atr)
                         : (ask + m_mult * atr);

      double minStopDistance = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      if(!MathIsValidNumber(minStopDistance) || minStopDistance < 0.0)
         minStopDistance = 0.0;

      if(signal == SIGNAL_BUY)
      {
         double maxAllowed = bid - minStopDistance;
         if(desiredSL >= maxAllowed)
            desiredSL = maxAllowed;
         if(currentSL > 0.0 && desiredSL <= currentSL + _Point)
            return(false);
      }
      else
      {
         double minAllowed = ask + minStopDistance;
         if(desiredSL <= minAllowed)
            desiredSL = minAllowed;
         if(currentSL > 0.0 && desiredSL >= currentSL - _Point)
            return(false);
      }

      desiredSL = NormalizeDouble(desiredSL, _Digits);
      if(!MathIsValidNumber(desiredSL) || desiredSL <= 0.0)
         return(false);

      outSL = desiredSL;
      return(true);
   }
};

ITsPolicyPlugin* CreateTsPolicy_ATR()
{
   return(new CTsPolicy_ATR());
}

#endif
