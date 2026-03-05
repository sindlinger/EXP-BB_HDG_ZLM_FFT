#ifndef __CSM_BLOCK_AUTHORITY_MODULE_MQH__
#define __CSM_BLOCK_AUTHORITY_MODULE_MQH__

#include "..\\Config\\ConfigEnums.mqh"
#include "..\\Contracts\\CoreTypes.mqh"
#include "..\\Contracts\\Snapshot.mqh"

class CBlockAuthorityModule
{
private:
   SOrderManagerConfig m_omCfg;
   double m_verifyDailyDdPct;
   double m_verifyMinFreeMarginPct;

   datetime m_lastOpenBarTime;
   datetime m_noMoneyBlockBarTime;
   bool m_buySignalConsumed;
   bool m_sellSignalConsumed;
   bool m_buySignalPending;
   bool m_sellSignalPending;
   bool m_lastBuyArmed;
   bool m_lastSellArmed;
   bool m_lastBuyTrigger;
   bool m_lastSellTrigger;
   bool m_signalTelemetryPrimed;
   datetime m_signalBarTime;
   int m_buySignals;
   int m_sellSignals;

   int m_dayKey;
   double m_dayStartEquity;

   void EnsureDayAnchor()
   {
      datetime now = TimeTradeServer();
      if(now <= 0)
         now = TimeCurrent();

      MqlDateTime dt;
      TimeToStruct(now, dt);
      int dayKey = dt.year * 10000 + dt.mon * 100 + dt.day;
      if(dayKey != m_dayKey)
      {
         m_dayKey = dayKey;
         double eq = AccountInfoDouble(ACCOUNT_EQUITY);
         m_dayStartEquity = (MathIsValidNumber(eq) && eq > 0.0 ? eq : 0.0);
      }
   }

   bool CheckGlobalRiskLimits(string &reason)
   {
      reason = "";
      EnsureDayAnchor();

      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

      if(MathIsValidNumber(equity) && equity > 0.0 && MathIsValidNumber(freeMargin))
      {
         double fmPct = (freeMargin / equity) * 100.0;
         if(fmPct < m_verifyMinFreeMarginPct)
         {
            reason = StringFormat("bloqueio risco: margem livre %.2f%% < %.2f%%", fmPct, m_verifyMinFreeMarginPct);
            return(false);
         }
      }

      if(m_dayStartEquity > 0.0 && MathIsValidNumber(equity) && equity > 0.0)
      {
         double ddPct = ((m_dayStartEquity - equity) / m_dayStartEquity) * 100.0;
         if(ddPct >= m_verifyDailyDdPct)
         {
            reason = StringFormat("bloqueio risco: DD diario %.2f%% >= %.2f%%", ddPct, m_verifyDailyDdPct);
            return(false);
         }
      }

      return(true);
   }

   void ResetSignalStateOnNewBar()
   {
      datetime b0 = iTime(_Symbol, _Period, 0);
      if(b0 > 0 && b0 != m_signalBarTime)
      {
         m_signalBarTime = b0;
         m_lastBuyArmed = false;
         m_lastSellArmed = false;
      }
   }

   void UpdateSignalTelemetry(const SSignalDecision &decision,
                              const CIndicatorSnapshot &snapshot)
   {
      ResetSignalStateOnNewBar();

      double c = 0.0, p = 0.0;
      bool hasBuyTrigger = snapshot.Get("signal.buy_trigger", c, p);
      bool buyTrigger = (hasBuyTrigger && c > 0.5);
      bool hasSellTrigger = snapshot.Get("signal.sell_trigger", c, p);
      bool sellTrigger = (hasSellTrigger && c > 0.5);

      if(!m_signalTelemetryPrimed)
      {
         m_lastBuyArmed = decision.buyArmed;
         m_lastSellArmed = decision.sellArmed;
         m_lastBuyTrigger = buyTrigger;
         m_lastSellTrigger = sellTrigger;
         m_signalTelemetryPrimed = true;
         m_buySignalPending = false;
         m_sellSignalPending = false;
         return;
      }

      bool buyEdge = false;
      bool sellEdge = false;
      if(hasBuyTrigger || hasSellTrigger)
      {
         buyEdge = (buyTrigger && !m_lastBuyTrigger);
         sellEdge = (sellTrigger && !m_lastSellTrigger);
      }
      else
      {
         buyEdge = (decision.buyArmed && !m_lastBuyArmed);
         sellEdge = (decision.sellArmed && !m_lastSellArmed);
      }

      if(buyEdge)
      {
         m_buySignals++;
         m_buySignalPending = true;
         m_sellSignalPending = false;
      }
      if(sellEdge)
      {
         m_sellSignals++;
         m_sellSignalPending = true;
         m_buySignalPending = false;
      }
      if(decision.signal == SIGNAL_NONE)
      {
         m_buySignalPending = false;
         m_sellSignalPending = false;
      }

      if(buyEdge)
         m_sellSignalConsumed = false;
      if(sellEdge)
         m_buySignalConsumed = false;

      m_lastBuyArmed = decision.buyArmed;
      m_lastSellArmed = decision.sellArmed;
      m_lastBuyTrigger = buyTrigger;
      m_lastSellTrigger = sellTrigger;
   }

public:
   CBlockAuthorityModule()
   {
      ZeroMemory(m_omCfg);
      m_verifyDailyDdPct = 0.0;
      m_verifyMinFreeMarginPct = 0.0;
      m_lastOpenBarTime = 0;
      m_noMoneyBlockBarTime = 0;
      m_buySignalConsumed = false;
      m_sellSignalConsumed = false;
      m_buySignalPending = false;
      m_sellSignalPending = false;
      m_lastBuyArmed = false;
      m_lastSellArmed = false;
      m_lastBuyTrigger = false;
      m_lastSellTrigger = false;
      m_signalTelemetryPrimed = false;
      m_signalBarTime = 0;
      m_buySignals = 0;
      m_sellSignals = 0;
      m_dayKey = 0;
      m_dayStartEquity = 0.0;
   }

   void Bind(const SOrderManagerConfig &omCfg,
             const double verifyDailyDdPct,
             const double verifyMinFreeMarginPct)
   {
      m_omCfg = omCfg;
      m_verifyDailyDdPct = verifyDailyDdPct;
      m_verifyMinFreeMarginPct = verifyMinFreeMarginPct;
      m_dayKey = 0;
      m_dayStartEquity = 0.0;
      m_buySignalPending = false;
      m_sellSignalPending = false;
      m_lastBuyArmed = false;
      m_lastSellArmed = false;
      m_lastBuyTrigger = false;
      m_lastSellTrigger = false;
      m_buySignalConsumed = false;
      m_sellSignalConsumed = false;
      m_lastOpenBarTime = 0;
      m_noMoneyBlockBarTime = 0;
      m_signalTelemetryPrimed = false;
   }

   void SyncConfig(const SOrderManagerConfig &omCfg,
                   const double verifyDailyDdPct,
                   const double verifyMinFreeMarginPct)
   {
      m_omCfg = omCfg;
      m_verifyDailyDdPct = verifyDailyDdPct;
      m_verifyMinFreeMarginPct = verifyMinFreeMarginPct;
   }

   bool CanRunTick(const bool modulesReady,
                   const string moduleCheckMessage,
                   string &reason) const
   {
      reason = "";
      // Nao bloqueia tick por estado de module-check.
      // O runtime segue e trata degradacao por sinal/policies.
      return(true);
   }

   bool CanManage(const bool policiesReady,
                  const string policyReason,
                  const double bid,
                  const double ask,
                  string &reason)
   {
      reason = "";
      if(!CheckGlobalRiskLimits(reason))
         return(false);

      if(!policiesReady)
      {
         reason = policyReason;
         return(false);
      }

      if(!MathIsValidNumber(bid) || !MathIsValidNumber(ask) || bid <= 0.0 || ask <= 0.0)
      {
         reason = "manage: bid/ask invalido";
         return(false);
      }

      return(true);
   }

   bool CanOpen(const SSignalDecision &decision,
                const CIndicatorSnapshot &snapshot,
                const int activeBaskets,
                const int ourPositions,
                const bool policiesReady,
                const string policyReason,
                const double bid,
                const double ask,
                string &reason)
   {
      reason = "";
      UpdateSignalTelemetry(decision, snapshot);

      if(decision.signal == SIGNAL_NONE)
      {
         reason = (decision.reason == "" ? "sem sinal" : decision.reason);
         return(false);
      }

      if(!CheckGlobalRiskLimits(reason))
         return(false);

      if(decision.signal == SIGNAL_BUY && !m_omCfg.allowBuy)
      {
         reason = "buy bloqueado no config";
         return(false);
      }
      if(decision.signal == SIGNAL_SELL && !m_omCfg.allowSell)
      {
         reason = "sell bloqueado no config";
         return(false);
      }

      if(m_omCfg.execMode != OM_EXEC_HEDGE_OCO_V1 && m_omCfg.onePairLock && ourPositions > 0)
      {
         reason = StringFormat("bloqueio one-pair: ja existe posicao ativa (%d)", ourPositions);
         return(false);
      }

      if(!MathIsValidNumber(bid) || !MathIsValidNumber(ask) || bid <= 0.0 || ask <= 0.0)
      {
         reason = "open: bid/ask invalido";
         return(false);
      }

      if(decision.signal == SIGNAL_BUY && !m_buySignalPending)
      {
         double bc = 0.0, bp = 0.0;
         if(snapshot.Get("signal.buy_trigger", bc, bp))
            reason = StringFormat("aguardando novo cruzamento BUY (trigger curr=%.0f prev=%.0f)", bc, bp);
         else
            reason = "aguardando novo cruzamento BUY (trigger sem telemetria)";
         return(false);
      }
      if(decision.signal == SIGNAL_BUY && m_buySignalConsumed)
      {
         reason = "BUY deste cruzamento ja foi executado; aguarde cruzamento SELL para rearmar";
         return(false);
      }
      if(decision.signal == SIGNAL_SELL && !m_sellSignalPending)
      {
         double sc = 0.0, sp = 0.0;
         if(snapshot.Get("signal.sell_trigger", sc, sp))
            reason = StringFormat("aguardando novo cruzamento SELL (trigger curr=%.0f prev=%.0f)", sc, sp);
         else
            reason = "aguardando novo cruzamento SELL (trigger sem telemetria)";
         return(false);
      }
      if(decision.signal == SIGNAL_SELL && m_sellSignalConsumed)
      {
         reason = "SELL deste cruzamento ja foi executado; aguarde cruzamento BUY para rearmar";
         return(false);
      }

      datetime b0 = iTime(_Symbol, _Period, 0);
      if(b0 > 0 && m_lastOpenBarTime == b0)
      {
         reason = "bloqueio: 1 ordem por barra";
         return(false);
      }
      if(b0 > 0 && m_noMoneyBlockBarTime == b0)
      {
         reason = "bloqueio: sem margem nesta barra";
         return(false);
      }

      if(m_omCfg.execMode == OM_EXEC_HEDGE_OCO_V1)
      {
         if((int)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
         {
            reason = "bloqueio hedge: conta nao e HEDGING";
            return(false);
         }
         if(activeBaskets >= m_omCfg.hedgeCfg.maxBaskets)
         {
            reason = StringFormat("bloqueio hedge: max cestas (%d)", m_omCfg.hedgeCfg.maxBaskets);
            return(false);
         }

         double c = 0.0;
         double p = 0.0;
         if(!snapshot.Get("anchor.zero_price", c, p) ||
            !snapshot.Get("anchor.up_1_price", c, p) ||
            !snapshot.Get("anchor.dn_1_price", c, p))
         {
            reason = "bloqueio hedge: contrato anchor incompleto";
            return(false);
         }
      }

      if(!policiesReady)
      {
         reason = policyReason;
         return(false);
      }

      return(true);
   }

   void NotifyNoMoney()
   {
      datetime b0 = iTime(_Symbol, _Period, 0);
      if(b0 > 0)
         m_noMoneyBlockBarTime = b0;
   }

   void NotifyOpenSuccess(const int signal)
   {
      datetime b0 = iTime(_Symbol, _Period, 0);
      if(b0 > 0)
         m_lastOpenBarTime = b0;

      if(signal == SIGNAL_BUY)
      {
         m_buySignalPending = false;
         m_buySignalConsumed = true;
         m_sellSignalConsumed = false;
      }
      else if(signal == SIGNAL_SELL)
      {
         m_sellSignalPending = false;
         m_sellSignalConsumed = true;
         m_buySignalConsumed = false;
      }
   }

   int BuySignals() const
   {
      return(m_buySignals);
   }

   int SellSignals() const
   {
      return(m_sellSignals);
   }
};

#endif
