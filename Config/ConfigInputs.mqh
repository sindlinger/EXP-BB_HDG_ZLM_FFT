// [POLICY] PROIBIDO: EA nao pode compartilhar/passar inputs para indicador.
// [POLICY] Indicadores devem rodar com seus proprios inputs internos (iCustom sem parametros do EA).

#ifndef __CSM_CONFIG_INPUTS_MQH__
#define __CSM_CONFIG_INPUTS_MQH__

#include "ConfigEnums.mqh"

input group "Core"
input string InpModStrategyId = "CloseScaleEffortMfiAuth";
input string InpModIndicatorsCsv = "CloseScaleForecastFeed";
input bool   InpModAllowBuy = true;
input bool   InpModAllowSell = true;
input double InpModLots = 0.10;
input long   InpModMagic = 5490001;
input int    InpModDeviationPoints = 20;
input EModuleCheckMode InpModCheckMode = MODULE_CHECK_ON_INIT;
input int InpModCheckDelaySec = 2;
input bool InpModCheckHardFail = true;

input group "Order Manager"
input bool InpOMOnePairLock = false;
input bool InpOMOpenTwoLegs = true;
input double InpOMLeg1Fraction = 0.50;
input double InpOMLeg2Fraction = 0.50;
input string InpOMSlPolicyId = "CloseScaleSL_Back1Level";
input string InpOMTpPolicyId = "CloseScaleTP_NextLevelAndFinal";
input string InpOMTsPolicyId = "CloseScaleTS_HalfLevel";
input string InpOMBePolicyId = "NoneBE";
input string InpOMPendingPolicyId = "NonePending";
input ERiskSubmodule InpOMRiskSubmodule = RISK_SUBMODULE_HEDGE_70_30;
input int InpOMTrailAtrPeriod = 14;
input double InpOMTrailAtrMult = 1.0;
input EModuleToggle InpOMHedgeSubmodule = MODULE_DISABLED;

input group "Risk Manager"
input double InpRiskCountertrendScale = 0.30;

input group "Hedge OCO v1"
input int InpOMHedgeOcoOrderFamily = HEDGE_OCO_FAMILY_STOP_LIMIT;
input int InpOMHedgeMaxBaskets = 2;
input double InpOMHedgeTargetMoney = 30.0;
input double InpOMHedgeStopMoney = 45.0;
input double InpOMHedgeBiasStrongWeight = 0.70;
input double InpOMHedgeStopLimitPullbackFrac = 0.35;

input group "Risk Guards"
input double InpVerifyDailyDDPct = 2.0;
input double InpVerifyMinFreeMarginPct = 35.0;

input group "Strategy Auth (optional)"
input bool InpAuthUseEffort = false;
input bool InpAuthUseMfi = false;

input group "Bus DLL (obrigatorio)"
input string InpBusSession = "CSM_DEFAULT";

input group "View"
input bool InpViewChart = true;
input bool InpViewTerminal = true;
input int  InpViewRefreshMs = 250;
input bool InpViewShowStateHeader = false;
input bool InpViewShowSyncTelemetry = false;
input bool InpViewShowIndicatorValues = false;
input bool InpViewShowConditionRules = true;
input bool InpViewShowTradeTape = true;
input bool InpViewAttachIndicators = true;
input bool InpViewAttachSubwindow1 = true;
input bool InpViewAttachSubwindow2 = true;
input bool InpViewAttachSubwindow3 = true;
input bool InpViewAttachSubwindow4 = true;
input bool InpViewAttachSubwindow5 = true;
input bool InpViewAttachSubwindow6 = true;
input bool InpViewAttachSubwindow7 = true;
input bool InpViewAttachSubwindow8 = true;

#endif
