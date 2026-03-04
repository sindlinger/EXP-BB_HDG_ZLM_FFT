#property strict
#property version   "1.001"
#property description "CloseScale Modular EA: contratos agnosticos + plugins de indicador/estrategia"

#include "Config/ConfigInputs.mqh"
#include "Contracts/CoreTypes.mqh"
#include "Contracts/Interfaces.mqh"
#include "Config/ConfigModule.mqh"
#include "Indicators/IndicatorModule.mqh"
#include "Strategies/StrategyModule.mqh"
#include "EntrySignal/EntrySignalModule.mqh"
#include "OrderManager/OrderManagerModule.mqh"
#include "Exec/ExecModule.mqh"
#include "View/ViewModule.mqh"

CConfigModule      g_cfg;
CIndicatorModule   g_indicators;
CStrategyModule    g_strategy;
CEntrySignalModule g_entrySignal;
COrderManagerModule g_orderMgr;
CExecModule        g_exec;
CViewModule        g_view;

CIndicatorSnapshot g_snapshot;
CSignalRule        g_rule;

SRuntimeViewState  g_viewState;

bool g_lastBuyArmed = false;
bool g_lastSellArmed = false;
datetime g_signalBarTime = 0;
int g_buySignals = 0;
int g_sellSignals = 0;

bool g_modulesReady = false;
bool g_moduleCheckScheduled = false;
datetime g_moduleCheckDue = 0;
string g_moduleCheckMsg = "not-run";
datetime g_lastModuleCheckLog = 0;

void ResetSignalCountersOnNewBar()
{
   datetime b0 = iTime(_Symbol, _Period, 0);
   if(b0 > 0 && b0 != g_signalBarTime)
   {
      g_signalBarTime = b0;
      g_lastBuyArmed = false;
      g_lastSellArmed = false;
   }
}

void UpdateSignalCounters(const SSignalDecision &d)
{
   ResetSignalCountersOnNewBar();

   if(d.buyArmed && !g_lastBuyArmed)
      g_buySignals++;
   if(d.sellArmed && !g_lastSellArmed)
      g_sellSignals++;

   g_lastBuyArmed = d.buyArmed;
   g_lastSellArmed = d.sellArmed;
}

bool RunModuleCheckOnce(string &err, string &detail)
{
   err = "";
   detail = "";

   CIndicatorSnapshot warmSnap;
   warmSnap.Clear();

   string updErr = "";
   if(!g_indicators.Update(warmSnap, updErr))
   {
      err = StringFormat("indicadores sem leitura valida: %s", updErr);
      return(false);
   }

   SSignalDecision warmDecision;
   warmDecision.signal = SIGNAL_NONE;
   warmDecision.buyArmed = false;
   warmDecision.sellArmed = false;
   warmDecision.reason = "";
   g_entrySignal.Evaluate(warmSnap, g_rule, warmDecision);

   if(StringFind(warmDecision.reason, "missing key:") >= 0)
   {
      err = StringFormat("regra/indicadores inconsistentes: %s", warmDecision.reason);
      return(false);
   }

   detail = StringFormat("keys=%d decision=%s",
                         warmSnap.Count(),
                         warmDecision.reason);
   return(true);
}

int OnInit()
{
   string err = "";
   g_snapshot.Clear();
   g_rule.Clear();

   if(!g_cfg.LoadFromInputs(err))
   {
      PrintFormat("[MOD-EA] Config invalido: %s", err);
      return(INIT_PARAMETERS_INCORRECT);
   }

   if(!g_strategy.Init(g_cfg.strategyId, err))
   {
      PrintFormat("[MOD-EA] Falha Strategy.Init: %s", err);
      return(INIT_FAILED);
   }

   if(!g_strategy.BuildRule(g_rule, err))
   {
      PrintFormat("[MOD-EA] Falha BuildRule: %s", err);
      return(INIT_FAILED);
   }

   if(!g_indicators.Init(g_cfg.indicatorIds, err))
   {
      PrintFormat("[MOD-EA] Falha Indicators.Init: %s", err);
      return(INIT_FAILED);
   }

   g_exec.Init(g_cfg.magic, g_cfg.deviationPoints);
   g_view.Configure(g_cfg.viewChart, g_cfg.viewTerminal, g_cfg.viewRefreshMs);

   g_modulesReady = true;
   g_moduleCheckScheduled = false;
   g_moduleCheckDue = 0;
   g_lastModuleCheckLog = 0;

   if(g_cfg.moduleCheckMode == MODULE_CHECK_ON_INIT)
   {
      string checkErr = "";
      string checkDetail = "";
      if(!RunModuleCheckOnce(checkErr, checkDetail))
      {
         g_moduleCheckMsg = StringFormat("init-fail: %s", checkErr);
         PrintFormat("[MOD-EA] ModuleCheck falhou no OnInit: %s", checkErr);
         if(g_cfg.moduleCheckHardFail)
            return(INIT_FAILED);

         g_modulesReady = false;
         g_moduleCheckScheduled = true;
         g_moduleCheckDue = TimeCurrent();
         EventSetTimer(1);
      }
      else
      {
         g_moduleCheckMsg = StringFormat("ok(init): %s", checkDetail);
         PrintFormat("[MOD-EA] ModuleCheck ok no OnInit: %s", checkDetail);
      }
   }
   else if(g_cfg.moduleCheckMode == MODULE_CHECK_ON_TIMER_ONCE)
   {
      g_modulesReady = false;
      g_moduleCheckScheduled = true;
      g_moduleCheckDue = TimeCurrent() + (datetime)g_cfg.moduleCheckDelaySec;
      g_moduleCheckMsg = StringFormat("agendado +%d sec", g_cfg.moduleCheckDelaySec);
      EventSetTimer(1);
      PrintFormat("[MOD-EA] ModuleCheck agendado para timer (+%d sec)", g_cfg.moduleCheckDelaySec);
   }
   else
   {
      g_moduleCheckMsg = "disabled";
   }

   g_viewState.strategyId = g_strategy.CurrentId();
   g_viewState.signalText = "INIT";
   g_viewState.signalReason = g_moduleCheckMsg;
   g_viewState.execText = "idle";
   g_viewState.positions = 0;
   g_viewState.buySignals = 0;
   g_viewState.sellSignals = 0;
   g_viewState.ts = TimeCurrent();

   PrintFormat("[MOD-EA] Inicializado. strategy=%s indicators=%s rule=%s",
               g_strategy.CurrentId(),
               g_indicators.LoadedIdsText(),
               g_rule.ruleId);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   g_indicators.Deinit();
   g_strategy.Deinit();
   g_view.ClearChart();
   PrintFormat("[MOD-EA] Deinit reason=%d", reason);
}

void OnTimer()
{
   if(!g_moduleCheckScheduled || g_modulesReady)
      return;

   datetime now = TimeCurrent();
   if(now < g_moduleCheckDue)
      return;

   string checkErr = "";
   string checkDetail = "";
   if(RunModuleCheckOnce(checkErr, checkDetail))
   {
      g_modulesReady = true;
      g_moduleCheckScheduled = false;
      g_moduleCheckMsg = StringFormat("ok(timer): %s", checkDetail);
      EventKillTimer();
      PrintFormat("[MOD-EA] ModuleCheck ok no timer: %s", checkDetail);
      return;
   }

   g_moduleCheckMsg = StringFormat("pending: %s", checkErr);
   if((now - g_lastModuleCheckLog) >= 5)
   {
      g_lastModuleCheckLog = now;
      PrintFormat("[MOD-EA] ModuleCheck pendente: %s", checkErr);
   }
}

void OnTick()
{
   string err = "";
   g_snapshot.Clear();

   if(!g_modulesReady)
   {
      g_viewState.ts = TimeCurrent();
      g_viewState.strategyId = g_strategy.CurrentId();
      g_viewState.signalText = "WAIT";
      g_viewState.signalReason = StringFormat("module-check: %s", g_moduleCheckMsg);
      g_viewState.execText = "blocked";
      g_viewState.positions = g_orderMgr.CountOurPositions(g_cfg.magic);
      g_viewState.buySignals = g_buySignals;
      g_viewState.sellSignals = g_sellSignals;
      g_view.Publish(g_viewState);
      return;
   }

   SSignalDecision decision;
   decision.signal = SIGNAL_NONE;
   decision.buyArmed = false;
   decision.sellArmed = false;
   decision.reason = "";

   if(!g_indicators.Update(g_snapshot, err))
   {
      g_viewState.ts = TimeCurrent();
      g_viewState.signalText = "NONE";
      g_viewState.signalReason = StringFormat("indicators: %s", err);
      g_viewState.execText = "skip";
      g_viewState.positions = g_orderMgr.CountOurPositions(g_cfg.magic);
      g_viewState.buySignals = g_buySignals;
      g_viewState.sellSignals = g_sellSignals;
      g_view.Publish(g_viewState);
      return;
   }

   g_entrySignal.Evaluate(g_snapshot, g_rule, decision);
   UpdateSignalCounters(decision);

   SExecRequest req;
   SExecResult res;
   string omErr = "";
   bool hasReq = g_orderMgr.BuildOpenRequest(decision, g_cfg, req, omErr);

   string execText = "idle";
   if(hasReq)
   {
      bool ok = g_exec.Execute(req, res);
      execText = StringFormat("%s|accepted=%s|executed=%s|ret=%d",
                              (ok ? "ok" : "fail"),
                              (res.accepted ? "true" : "false"),
                              (res.executed ? "true" : "false"),
                              res.retcode);
   }
   else
   {
      execText = (omErr == "" ? "no-order" : omErr);
   }

   g_viewState.ts = TimeCurrent();
   g_viewState.strategyId = g_strategy.CurrentId();
   g_viewState.signalText = (decision.signal == SIGNAL_BUY ? "BUY" : (decision.signal == SIGNAL_SELL ? "SELL" : "NONE"));
   g_viewState.signalReason = decision.reason;
   g_viewState.execText = execText;
   g_viewState.positions = g_orderMgr.CountOurPositions(g_cfg.magic);
   g_viewState.buySignals = g_buySignals;
   g_viewState.sellSignals = g_sellSignals;

   g_view.Publish(g_viewState);
}
