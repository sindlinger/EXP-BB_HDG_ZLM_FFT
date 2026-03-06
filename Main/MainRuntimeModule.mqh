#ifndef __CSM_MAIN_RUNTIME_MODULE_MQH__
#define __CSM_MAIN_RUNTIME_MODULE_MQH__

#include "..\\Config\\ConfigModule.mqh"
#include "..\\Contracts\\CoreTypes.mqh"
#include "..\\Contracts\\Interfaces.mqh"
#include "..\\Indicators\\IndicatorModule.mqh"
#include "..\\Strategies\\StrategyModule.mqh"
#include "..\\OrderManager\\OrderManagerModule.mqh"
#include "..\\Policies\\BlockAuthorityModule.mqh"
#include "..\\Exec\\ExecModule.mqh"
#include "..\\View\\ViewModule.mqh"
#include "..\\Verification\\VerificationModule.mqh"

class CMainRuntimeModule
{
private:
   CConfigModule *m_cfg;
   CIndicatorModule *m_indicators;
   CStrategyModule *m_strategy;
   COrderManagerModule *m_orderMgr;
   CBlockAuthorityModule m_block;
   CExecModule *m_exec;
   CViewModule *m_view;
   CVerificationModule *m_verify;
   CIndicatorSnapshot *m_snapshot;
   CSignalRule *m_rule;
   SOrderManagerConfig m_omCfg;
   SRuntimeViewState m_viewState;

   bool IsBound() const
   {
      return(m_cfg != NULL &&
             m_indicators != NULL &&
             m_strategy != NULL &&
             m_orderMgr != NULL &&
             m_exec != NULL &&
             m_view != NULL &&
             m_verify != NULL &&
             m_snapshot != NULL &&
             m_rule != NULL);
   }

   void LogSystem(const string msg)
   {
      if(m_view != NULL)
         m_view.PublishSystem(msg);
   }

   void ResetSignalVisuals()
   {
      m_viewState.buyArmed = false;
      m_viewState.sellArmed = false;
      m_viewState.useEffortAuth = m_cfg.authUseEffort;
      m_viewState.useMfiAuth = m_cfg.authUseMfi;
      m_viewState.csBuyTrigger = 0.0;
      m_viewState.csSellTrigger = 0.0;
      m_viewState.csBuyZero = 0.0;
      m_viewState.csSellZero = 0.0;
      m_viewState.effortBuyAuth = 0.0;
      m_viewState.effortSellAuth = 0.0;
      m_viewState.mfiBuyAuth = 0.0;
      m_viewState.mfiSellAuth = 0.0;
      m_viewState.activeBaskets = 0;
      m_viewState.basketNetPnl = 0.0;
      m_viewState.buyCondTrace = "-";
      m_viewState.sellCondTrace = "-";
      m_viewState.signalBuffersTrace = "-";
      m_viewState.indicatorBuffersLine1 = "-";
      m_viewState.indicatorBuffersLine2 = "-";
   }

public:
   CMainRuntimeModule()
   {
      m_cfg = NULL;
      m_indicators = NULL;
      m_strategy = NULL;
      m_orderMgr = NULL;
      m_exec = NULL;
      m_view = NULL;
      m_verify = NULL;
      m_snapshot = NULL;
      m_rule = NULL;
      ZeroMemory(m_omCfg);
      ZeroMemory(m_viewState);
   }

   void Bind(CConfigModule &cfg,
             CIndicatorModule &indicators,
             CStrategyModule &strategy,
             COrderManagerModule &orderMgr,
             CExecModule &exec,
             CViewModule &view,
             CVerificationModule &verify,
             CIndicatorSnapshot &snapshot,
             CSignalRule &rule,
             SOrderManagerConfig &omCfg,
             SRuntimeViewState &viewState)
   {
      m_cfg = &cfg;
      m_indicators = &indicators;
      m_strategy = &strategy;
      m_orderMgr = &orderMgr;
      m_exec = &exec;
      m_view = &view;
      m_verify = &verify;
      m_snapshot = &snapshot;
      m_rule = &rule;
      m_omCfg = omCfg;
      m_viewState = viewState;
      m_block.Bind(m_omCfg, m_cfg.verifyDailyDdPct, m_cfg.verifyMinFreeMarginPct);
   }

   void OnTickStep()
   {
      if(!IsBound())
         return;

      string err = "";
      datetime bar0 = iTime(_Symbol, _Period, 0);
      if(bar0 <= 0)
         bar0 = TimeCurrent();
      m_snapshot.BeginCycle(bar0, _Symbol, (int)_Period);
      m_snapshot.SetWriterModule("main");
      m_snapshot.Clear();
      m_snapshot.Report("main", "tick.begin", 0, "ok");

      string runGateErr = "";
      m_block.CanRunTick(m_verify.ModulesReady(), m_verify.ModuleCheckMessage(), runGateErr);

      SSignalDecision decision;
      decision.signal = SIGNAL_NONE;
      decision.buyArmed = false;
      decision.sellArmed = false;
      decision.reason = "";

      m_snapshot.SetWriterModule("indicators");
      bool indicatorsOk = m_indicators.Update(*m_snapshot, err);
      m_snapshot.Report("indicators", "update", (indicatorsOk ? 0 : 1001), (indicatorsOk ? "ok" : err));

      m_snapshot.SetWriterModule("strategy");
      m_strategy.EvaluateSignal(*m_snapshot, *m_rule, decision);
      m_snapshot.Report("strategy", "evaluate_rule", 0, decision.reason);
      if(!indicatorsOk && decision.reason == "")
         decision.reason = StringFormat("indicadores sem leitura valida: %s", err);

      m_snapshot.SetWriterModule("strategy");
      m_strategy.ApplyDecisionSnapshot(*m_snapshot, decision);
      m_snapshot.Report("strategy",
                        "apply_snapshot",
                        0,
                        (decision.signal == SIGNAL_BUY ? "BUY" : (decision.signal == SIGNAL_SELL ? "SELL" : "NONE")));
      m_snapshot.SetWriterModule("main");

      bool manageGateBlocked = false;
      string manageGateErr = "";
      string omErr = "";
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      SExecRequest manageReqs[];
      string manageSummary = "";
      int manageReqCount = 0;
      string managePolicyErr = "";
      bool managePoliciesOk = m_orderMgr.ValidatePoliciesForManage(m_omCfg, managePolicyErr);
      if(m_block.CanManage(managePoliciesOk, managePolicyErr, bid, ask, manageGateErr))
      {
         manageReqCount = m_orderMgr.BuildManageRequests(*m_snapshot, m_omCfg, manageReqs, manageSummary);
      }
      else
      {
         manageGateBlocked = true;
         manageSummary = manageGateErr;
      }
      int manageOk = 0;
      int manageFail = 0;
      string manageFailMsg = "";
      for(int i = 0; i < manageReqCount; i++)
      {
         SExecResult mres;
         bool mok = m_exec.Execute(manageReqs[i], mres);
         if(mok && mres.executed)
            manageOk++;
         else
         {
            manageFail++;
            if(manageFailMsg == "")
               manageFailMsg = StringFormat("%s ret=%d", mres.message, mres.retcode);
         }
      }

      bool openGateBlocked = false;
      string openGateErr = "";
      int activeBasketsBefore = m_orderMgr.CountActiveBaskets(m_omCfg);
      int ourPositions = m_orderMgr.CountOurPositions(m_omCfg.magic);
      string openPolicyErr = "";
      bool openPoliciesOk = m_orderMgr.ValidatePoliciesForOpen(decision, m_omCfg, openPolicyErr);
      if(!m_block.CanOpen(decision,
                          *m_snapshot,
                          activeBasketsBefore,
                          ourPositions,
                          openPoliciesOk,
                          openPolicyErr,
                          bid,
                          ask,
                          openGateErr))
      {
         openGateBlocked = true;
         omErr = openGateErr;
      }

      SExecRequest openReqs[];
      int openReqCount = 0;
      if(!openGateBlocked)
      {
         openReqCount = m_orderMgr.BuildOpenRequests(decision, *m_snapshot, m_omCfg, openReqs, omErr);
      }

      int openOk = 0;
      int openFail = 0;
      string openFailMsg = "";
      for(int i = 0; i < openReqCount; i++)
      {
         SExecResult res;
         bool ok = m_exec.Execute(openReqs[i], res);
         if(ok && res.executed)
         {
            openOk++;
         }
         else
         {
            openFail++;
            if(openFailMsg == "")
               openFailMsg = StringFormat("%s ret=%d", res.message, res.retcode);
         }

         if(res.retcode == 10019) // TRADE_RETCODE_NO_MONEY
         {
            m_block.NotifyNoMoney();
            if(openFailMsg == "")
               openFailMsg = "exec: no money (cooldown ate nova barra)";
         }
      }

      int activeBasketsAfter = m_orderMgr.CountActiveBaskets(m_omCfg);
      double basketNetPnl = m_orderMgr.SumActiveBasketNetPnl(m_omCfg);
      string execText = StringFormat("open %d/%d | manage %d/%d | baskets=%d pnl=%.2f",
                                     openOk, openReqCount, manageOk, manageReqCount, activeBasketsAfter, basketNetPnl);

      string localBlockReason = "";
      if(decision.signal != SIGNAL_NONE && !openGateBlocked && openReqCount <= 0)
      {
         localBlockReason = (omErr == "" ? "no-order" : omErr);
      }
      else if(openReqCount > 0 && openOk <= 0)
      {
         localBlockReason = (openFailMsg == "" ? "falha na execucao de abertura" : openFailMsg);
      }
      else if(manageFail > 0)
      {
         localBlockReason = StringFormat("manage fail: %s", (manageFailMsg == "" ? "n/a" : manageFailMsg));
      }
      else if(openGateBlocked && openGateErr != "")
      {
         localBlockReason = openGateErr;
      }
      else if(decision.signal == SIGNAL_NONE)
      {
         localBlockReason = "sem execucao: sem sinal armado";
      }
      else
      {
         localBlockReason = "sem bloqueio de execucao";
      }

      if(openOk > 0)
         m_block.NotifyOpenSuccess(decision.signal);

      string authorityStatus = "ALLOW";
      string authorityReason = "-";
      if(manageGateBlocked)
      {
         authorityStatus = "BLOCKED(manage)";
         authorityReason = manageGateErr;
      }
      if(openGateBlocked)
      {
         if(decision.signal == SIGNAL_NONE)
         {
            if(!manageGateBlocked)
            {
               authorityStatus = "IDLE(open)";
               authorityReason = openGateErr;
            }
         }
         else
         {
            authorityStatus = "BLOCKED(open)";
            authorityReason = openGateErr;
         }
      }

      m_viewState.ts = TimeCurrent();
      m_viewState.strategyId = m_strategy.CurrentId();
      m_viewState.signalText = (decision.signal == SIGNAL_BUY ? "BUY" : (decision.signal == SIGNAL_SELL ? "SELL" : "NONE"));
      m_viewState.signalReason = decision.reason;
      m_viewState.authorityStatus = authorityStatus;
      m_viewState.authorityReason = authorityReason;
      m_viewState.blockReason = localBlockReason;
      m_viewState.execText = execText;
      m_viewState.positions = m_orderMgr.CountOurPositions(m_omCfg.magic);
      m_viewState.buySignals = m_block.BuySignals();
      m_viewState.sellSignals = m_block.SellSignals();
      m_strategy.FillStrategyViewState(*m_snapshot,
                                       decision,
                                       m_cfg.authUseEffort,
                                       m_cfg.authUseMfi,
                                       activeBasketsAfter,
                                       basketNetPnl,
                                       m_viewState);

      m_view.Publish(m_viewState);
      m_snapshot.Report("main", "tick.end", 0, localBlockReason);
      m_snapshot.EndCycle();
   }

   void OnTradeTransactionStep(const MqlTradeTransaction &trans)
   {
      if(!IsBound())
         return;

      SExecRequest reqs[];
      string summary = "";
      int n = m_orderMgr.OnTradeTransaction(trans, m_omCfg, reqs, summary);
      if(summary != "")
         LogSystem(summary);

      for(int i = 0; i < n; i++)
      {
         SExecResult ex;
         bool ok = m_exec.Execute(reqs[i], ex);
         if(!ok || !ex.executed)
            LogSystem(StringFormat("OnTradeTransaction exec falhou: %s ret=%d", ex.message, ex.retcode));
      }
   }
};

#endif
