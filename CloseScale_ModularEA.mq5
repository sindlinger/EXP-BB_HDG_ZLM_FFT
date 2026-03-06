// [POLICY] PROIBIDO: EA nao pode compartilhar/passar inputs para indicador.
// [POLICY] Indicadores devem rodar com seus proprios inputs internos (iCustom sem parametros do EA).

#property strict
#property version   "1.001"
#property description "CloseScale Modular EA: contratos agnosticos + plugins de indicador/estrategia"

#include "Config/ConfigInputs.mqh"
#include "Contracts/CoreTypes.mqh"
#include "Contracts/Interfaces.mqh"
#include "Config/ConfigModule.mqh"
#include "Indicators/IndicatorModule.mqh"
#include "Strategies/StrategyModule.mqh"
#include "OrderManager/OrderManagerModule.mqh"
#include "Exec/ExecModule.mqh"
#include "View/ViewModule.mqh"
#include "Verification/VerificationModule.mqh"
#include "Main/MainRuntimeModule.mqh"

CConfigModule      g_cfg;
CIndicatorModule   g_indicators;
CStrategyModule    g_strategy;
COrderManagerModule g_orderMgr;
CExecModule        g_exec;
CViewModule        g_view;
CVerificationModule g_verify;
CMainRuntimeModule g_runtime;

CIndicatorSnapshot g_snapshot;
CSignalRule        g_rule;
SOrderManagerConfig g_omCfg;

SRuntimeViewState  g_viewState;

void LogSystem(const string msg)
{
   g_view.PublishSystem(msg);
}

bool RunModuleCheckOnce(string &err, string &detail)
{
   err = "";
   detail = "";

   CIndicatorSnapshot warmSnap;
   warmSnap.Clear();
   string busErr = "";
   string checkSession = g_cfg.busSession + "_MODCHK";
   if(!warmSnap.ConfigureBus(checkSession, busErr))
   {
      err = StringFormat("module-check bus init falhou: %s", busErr);
      return(false);
   }
   datetime bar0 = iTime(_Symbol, _Period, 0);
   if(bar0 <= 0)
      bar0 = TimeCurrent();
   warmSnap.BeginCycle(bar0, _Symbol, (int)_Period);
   warmSnap.SetWriterModule("indicators");

   string updErr = "";
   if(!g_indicators.Update(warmSnap, updErr))
   {
      err = StringFormat("indicadores sem leitura valida: %s", updErr);
      warmSnap.EndCycle();
      return(false);
   }

   warmSnap.SetWriterModule("strategy");
   SSignalDecision warmDecision;
   warmDecision.signal = SIGNAL_NONE;
   warmDecision.buyArmed = false;
   warmDecision.sellArmed = false;
   warmDecision.reason = "";
   warmDecision.buyTrace = "";
   warmDecision.sellTrace = "";
   warmDecision.buffersTrace = "";
   g_strategy.EvaluateSignal(warmSnap, g_rule, warmDecision);

   if(StringFind(warmDecision.reason, "missing key:") >= 0)
   {
      err = StringFormat("regra/indicadores inconsistentes: %s", warmDecision.reason);
      warmSnap.EndCycle();
      return(false);
   }

   detail = StringFormat("keys=%d decision=%s", warmSnap.Count(), warmDecision.reason);
   warmSnap.EndCycle();
   return(true);
}

bool ProcessPendingModuleCheck(const string stage, string &fatalErr)
{
   fatalErr = "";
   if(!g_verify.NeedCheckNow())
      return(true);

   string checkErr = "";
   string checkDetail = "";
   bool ok = RunModuleCheckOnce(checkErr, checkDetail);

   string applyLog = "";
   bool fatal = false;
   g_verify.ApplyCheckResult(ok, (ok ? checkDetail : checkErr), applyLog, fatal);
   if(applyLog != "")
      LogSystem(StringFormat("%s: %s", stage, applyLog));

   return(true);
}

int OnInit()
{
   string err = "";
   g_snapshot.Clear();
   g_rule.Clear();

   if(!g_cfg.LoadFromInputs(err))
   {
      LogSystem(StringFormat("Config invalido: %s", err));
      return(INIT_PARAMETERS_INCORRECT);
   }

   g_view.Configure(g_cfg.viewChart,
                    g_cfg.viewTerminal,
                    g_cfg.viewRefreshMs,
                    g_cfg.viewShowStateHeader,
                    g_cfg.viewShowSyncTelemetry,
                    g_cfg.viewShowIndicatorValues,
                    g_cfg.viewShowConditionRules,
                    g_cfg.viewShowTradeTape);

   string busErr = "";
   if(!g_snapshot.ConfigureBus(g_cfg.busSession, busErr))
   {
      LogSystem(StringFormat("Falha Bus DLL (obrigatorio): %s", busErr));
      return(INIT_FAILED);
   }
   LogSystem(StringFormat("Bus DLL ON: session=%s", g_cfg.busSession));

   // No tester visual, evita auto-attach implicito dos iCustom.
   // A exibicao fica sob autoridade exclusiva do modulo View.
   if((bool)MQLInfoInteger(MQL_TESTER))
      TesterHideIndicators(true);

   if(!g_strategy.Init(g_cfg.strategyId, err))
   {
      LogSystem(StringFormat("Falha Strategy.Init: %s", err));
      return(INIT_FAILED);
   }

   CStrategyParamBag stParams;
   stParams.Clear();
   stParams.SetInt("auth.effort.enabled", (g_cfg.authUseEffort ? 1 : 0));
   stParams.SetInt("auth.mfi.enabled", (g_cfg.authUseMfi ? 1 : 0));
   g_strategy.SetParams(stParams);

   if(!g_strategy.BuildRule(g_rule, err))
   {
      LogSystem(StringFormat("Falha BuildRule: %s", err));
      return(INIT_FAILED);
   }

   if(!g_indicators.Init(g_cfg.indicatorIds, err))
   {
      LogSystem(StringFormat("Falha Indicators.Init: %s", err));
      return(INIT_FAILED);
   }

   if(g_cfg.viewChart && g_cfg.viewAttachIndicators)
   {
      bool attachSlots[];
      ArrayResize(attachSlots, 8);
      attachSlots[0] = g_cfg.viewAttachSubwindow1;
      attachSlots[1] = g_cfg.viewAttachSubwindow2;
      attachSlots[2] = g_cfg.viewAttachSubwindow3;
      attachSlots[3] = g_cfg.viewAttachSubwindow4;
      attachSlots[4] = g_cfg.viewAttachSubwindow5;
      attachSlots[5] = g_cfg.viewAttachSubwindow6;
      attachSlots[6] = g_cfg.viewAttachSubwindow7;
      attachSlots[7] = g_cfg.viewAttachSubwindow8;

      string attachErr = "";
      if(!g_view.AttachIndicators(ChartID(), g_indicators, attachSlots, attachErr) && attachErr != "")
         LogSystem(StringFormat("Attach indicators no chart: %s", attachErr));
   }
   else if(g_cfg.viewChart && !g_cfg.viewAttachIndicators)
   {
      int removed = g_view.DetachIndicators(ChartID(), g_indicators);
      if(removed > 0)
         LogSystem(StringFormat("Indicators detach no chart: removidos=%d", removed));
   }

   g_cfg.BuildOrderManagerConfig(g_omCfg);

   if(!g_orderMgr.InitPoliciesByConfig(g_omCfg, err))
   {
      LogSystem(StringFormat("Falha OrderManager.InitPolicies: %s", err));
      return(INIT_FAILED);
   }

   g_exec.Init(g_omCfg.magic, g_cfg.deviationPoints);
   g_verify.Configure(g_cfg.moduleCheckMode,
                      g_cfg.moduleCheckDelaySec,
                      g_cfg.moduleCheckHardFail);
   g_verify.ResetRuntimeState();

   string verifyLog = "";
   string verifyFatal = "";
   g_verify.Begin(verifyLog, verifyFatal);
   if(verifyLog != "")
      LogSystem(verifyLog);

   string pendingFatal = "";
   ProcessPendingModuleCheck("init", pendingFatal);

   g_runtime.Bind(g_cfg,
                  g_indicators,
                  g_strategy,
                  g_orderMgr,
                  g_exec,
                  g_view,
                  g_verify,
                  g_snapshot,
                  g_rule,
                  g_omCfg,
                  g_viewState);

   if(g_verify.NeedTimer())
      EventSetTimer(1);
   else
      EventKillTimer();

   g_viewState.strategyId = g_strategy.CurrentId();
   g_viewState.signalText = "INIT";
   g_viewState.signalReason = g_verify.ModuleCheckMessage();
   g_viewState.authorityStatus = "INIT";
   g_viewState.authorityReason = "-";
   g_viewState.blockReason = "";
   g_viewState.execText = "idle";
   g_viewState.positions = 0;
   g_viewState.buySignals = 0;
   g_viewState.sellSignals = 0;
   g_viewState.buyArmed = false;
   g_viewState.sellArmed = false;
   g_viewState.useEffortAuth = g_cfg.authUseEffort;
   g_viewState.useMfiAuth = g_cfg.authUseMfi;
   g_viewState.csBuyTrigger = 0.0;
   g_viewState.csSellTrigger = 0.0;
   g_viewState.csBuyZero = 0.0;
   g_viewState.csSellZero = 0.0;
   g_viewState.effortBuyAuth = 0.0;
   g_viewState.effortSellAuth = 0.0;
   g_viewState.mfiBuyAuth = 0.0;
   g_viewState.mfiSellAuth = 0.0;
   g_viewState.condBuyCross = false;
   g_viewState.condBuyZero = false;
   g_viewState.condSellCross = false;
   g_viewState.condSellZero = false;
   g_viewState.condBuyZeroCross = false;
   g_viewState.condSellZeroCross = false;
   g_viewState.regimeTrendBull = false;
   g_viewState.regimeCounterBull = false;
   g_viewState.regimeTrendBear = false;
   g_viewState.regimeCounterBear = false;
   g_viewState.activeBaskets = 0;
   g_viewState.basketNetPnl = 0.0;
   g_viewState.buyCondTrace = "-";
   g_viewState.sellCondTrace = "-";
   g_viewState.signalBuffersTrace = "-";
   g_viewState.indicatorBuffersLine1 = "-";
   g_viewState.indicatorBuffersLine2 = "-";
   g_viewState.busOnline = false;
   g_viewState.busLastRc = 0;
   g_viewState.tickSeqLocal = 0;
   g_viewState.tickSeqReadBuf0 = 0;
   g_viewState.tickSeqReadBuf2 = 0;
   g_viewState.tickSeqReadBuf4 = 0;
   g_viewState.tickSeqReadBuf5 = 0;
   g_viewState.busReadRcBuf0 = 0;
   g_viewState.busReadRcBuf2 = 0;
   g_viewState.busReadRcBuf4 = 0;
   g_viewState.busReadRcBuf5 = 0;
   g_viewState.busReadValidBuf0 = 0;
   g_viewState.busReadValidBuf2 = 0;
   g_viewState.busReadValidBuf4 = 0;
   g_viewState.busReadValidBuf5 = 0;
   g_viewState.ts = TimeCurrent();

   LogSystem(StringFormat("Inicializado. strategy=%s indicators=%s rule=%s",
                          g_strategy.CurrentId(),
                          g_indicators.LoadedIdsText(),
                          g_rule.ruleId));

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   g_snapshot.ShutdownBus();
   g_view.DetachIndicators(ChartID(), g_indicators);
   g_indicators.Deinit();
   g_strategy.Deinit();
   g_orderMgr.Deinit();
   g_view.ClearChart();
   LogSystem(StringFormat("Deinit reason=%d", reason));
}

void OnTimer()
{
   string verifyLog = "";
   g_verify.OnTimerStep(verifyLog);
   if(verifyLog != "")
      LogSystem(verifyLog);

   string pendingFatal = "";
   ProcessPendingModuleCheck("timer", pendingFatal);

   if(!g_verify.NeedTimer())
      EventKillTimer();
}

void OnTick()
{
   string pendingFatal = "";
   ProcessPendingModuleCheck("tick", pendingFatal);

   g_runtime.OnTickStep();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // request/result remain available for future broker-side routing extensions.
   g_runtime.OnTradeTransactionStep(trans);
}
