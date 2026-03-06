#ifndef __CSM_CONFIG_MODULE_MQH__
#define __CSM_CONFIG_MODULE_MQH__

#include "ConfigEnums.mqh"
#include "..\\Contracts\\CoreTypes.mqh"

class CConfigModule
{
public:
   string strategyId;
   string indicatorIds[];

   bool allowBuy;
   bool allowSell;
   double lots;
   long magic;
   int deviationPoints;
   int moduleCheckMode;
   int moduleCheckDelaySec;
   bool moduleCheckHardFail;
   bool onePairLock;
   bool omOpenTwoLegs;
   double omLeg1Fraction;
   double omLeg2Fraction;
   string omSlPolicyId;
   string omTpPolicyId;
   string omTsPolicyId;
   string omBePolicyId;
   string omPendingPolicyId;
   string omRiskPolicyId;
   int omTrailAtrPeriod;
   double omTrailAtrMult;
   double riskCountertrendScale;
   int omExecMode;
   int omHedgeOcoOrderFamily;
   int omHedgeMaxBaskets;
   double omHedgeTargetMoney;
   double omHedgeStopMoney;
   double omHedgeBiasStrongWeight;
   double omHedgeStopLimitPullbackFrac;
   double verifyDailyDdPct;
   double verifyMinFreeMarginPct;
   bool authUseEffort;
   bool authUseMfi;
   string busSession;

   bool viewChart;
   bool viewTerminal;
   int viewRefreshMs;
   bool viewAttachIndicators;
   bool viewAttachSubwindow1;
   bool viewAttachSubwindow2;
   bool viewAttachSubwindow3;
   bool viewAttachSubwindow4;
   bool viewAttachSubwindow5;
   bool viewAttachSubwindow6;
   bool viewAttachSubwindow7;
   bool viewAttachSubwindow8;

   void Clear()
   {
      strategyId = "AUTO_FIRST";
      ArrayResize(indicatorIds, 0);
      allowBuy = true;
      allowSell = true;
      lots = 0.10;
      magic = 5490001;
      deviationPoints = 20;
      moduleCheckMode = MODULE_CHECK_ON_INIT;
      moduleCheckDelaySec = 2;
      moduleCheckHardFail = true;
      onePairLock = false;
      omOpenTwoLegs = true;
      omLeg1Fraction = 0.5;
      omLeg2Fraction = 0.5;
      omSlPolicyId = "CloseScaleSL_Back1Level";
      omTpPolicyId = "CloseScaleTP_NextLevelAndFinal";
      omTsPolicyId = "CloseScaleTS_HalfLevel";
      omBePolicyId = "NoneBE";
      omPendingPolicyId = "NonePending";
      omRiskPolicyId = "DefaultRisk";
      omTrailAtrPeriod = 14;
      omTrailAtrMult = 1.0;
      riskCountertrendScale = 0.35;
      omExecMode = OM_EXEC_LEGACY;
      omHedgeOcoOrderFamily = HEDGE_OCO_FAMILY_STOP_LIMIT;
      omHedgeMaxBaskets = 2;
      omHedgeTargetMoney = 30.0;
      omHedgeStopMoney = 45.0;
      omHedgeBiasStrongWeight = 0.70;
      omHedgeStopLimitPullbackFrac = 0.35;
      verifyDailyDdPct = 2.0;
      verifyMinFreeMarginPct = 35.0;
      authUseEffort = false;
      authUseMfi = false;
      busSession = "CSM_DEFAULT";

      viewChart = true;
      viewTerminal = true;
      viewRefreshMs = 250;
      viewAttachIndicators = true;
      viewAttachSubwindow1 = true;
      viewAttachSubwindow2 = true;
      viewAttachSubwindow3 = true;
      viewAttachSubwindow4 = true;
      viewAttachSubwindow5 = true;
      viewAttachSubwindow6 = true;
      viewAttachSubwindow7 = true;
      viewAttachSubwindow8 = true;
   }

   void ParseCsv(const string csv, string &out[])
   {
      ArrayResize(out, 0);
      string src = csv;
      StringTrimLeft(src);
      StringTrimRight(src);
      if(src == "" || src == "AUTO_ALL")
      {
         ArrayResize(out, 1);
         out[0] = "AUTO_ALL";
         return;
      }

      string parts[];
      int n = StringSplit(src, ',', parts);
      if(n <= 0)
         return;

      for(int i = 0; i < n; i++)
      {
         string item = parts[i];
         StringTrimLeft(item);
         StringTrimRight(item);
         if(item == "")
            continue;

         bool exists = false;
         int sz = ArraySize(out);
         for(int j = 0; j < sz; j++)
         {
            if(out[j] == item)
            {
               exists = true;
               break;
            }
         }
         if(!exists)
         {
            ArrayResize(out, sz + 1);
            out[sz] = item;
         }
      }
   }

   bool LoadFromInputs(string &err)
   {
      err = "";
      Clear();

      strategyId = InpModStrategyId;
      allowBuy = InpModAllowBuy;
      allowSell = InpModAllowSell;
      lots = InpModLots;
      magic = InpModMagic;
      deviationPoints = InpModDeviationPoints;
      moduleCheckMode = (int)InpModCheckMode;
      moduleCheckDelaySec = InpModCheckDelaySec;
      moduleCheckHardFail = InpModCheckHardFail;
      onePairLock = InpOMOnePairLock;
      omOpenTwoLegs = InpOMOpenTwoLegs;
      omLeg1Fraction = InpOMLeg1Fraction;
      omLeg2Fraction = InpOMLeg2Fraction;
      omSlPolicyId = InpOMSlPolicyId;
      omTpPolicyId = InpOMTpPolicyId;
      omTsPolicyId = InpOMTsPolicyId;
      omBePolicyId = InpOMBePolicyId;
      omPendingPolicyId = InpOMPendingPolicyId;
      if(InpOMRiskSubmodule == RISK_SUBMODULE_DEFAULT)
         omRiskPolicyId = "DefaultRisk";
      else if(InpOMRiskSubmodule == RISK_SUBMODULE_CLOSESCALE_COUNTERTREND_ABOVE_ZERO)
         omRiskPolicyId = "CloseScaleRisk_CountertrendAboveZero";
      else
         omRiskPolicyId = "";
      omTrailAtrPeriod = InpOMTrailAtrPeriod;
      omTrailAtrMult = InpOMTrailAtrMult;
      riskCountertrendScale = InpRiskCountertrendScale;
      omExecMode = (InpOMHedgeSubmodule == MODULE_ENABLED ? OM_EXEC_HEDGE_OCO_V1 : OM_EXEC_LEGACY);
      omHedgeOcoOrderFamily = (int)InpOMHedgeOcoOrderFamily;
      omHedgeMaxBaskets = InpOMHedgeMaxBaskets;
      omHedgeTargetMoney = InpOMHedgeTargetMoney;
      omHedgeStopMoney = InpOMHedgeStopMoney;
      omHedgeBiasStrongWeight = InpOMHedgeBiasStrongWeight;
      omHedgeStopLimitPullbackFrac = InpOMHedgeStopLimitPullbackFrac;
      verifyDailyDdPct = InpVerifyDailyDDPct;
      verifyMinFreeMarginPct = InpVerifyMinFreeMarginPct;
      authUseEffort = InpAuthUseEffort;
      authUseMfi = InpAuthUseMfi;
      busSession = InpBusSession;

      viewChart = InpViewChart;
      viewTerminal = InpViewTerminal;
      viewRefreshMs = InpViewRefreshMs;
      viewAttachIndicators = InpViewAttachIndicators;
      viewAttachSubwindow1 = InpViewAttachSubwindow1;
      viewAttachSubwindow2 = InpViewAttachSubwindow2;
      viewAttachSubwindow3 = InpViewAttachSubwindow3;
      viewAttachSubwindow4 = InpViewAttachSubwindow4;
      viewAttachSubwindow5 = InpViewAttachSubwindow5;
      viewAttachSubwindow6 = InpViewAttachSubwindow6;
      viewAttachSubwindow7 = InpViewAttachSubwindow7;
      viewAttachSubwindow8 = InpViewAttachSubwindow8;

      ParseCsv(InpModIndicatorsCsv, indicatorIds);

      if(lots <= 0.0)
      {
         err = "InpModLots invalido";
         return(false);
      }
      if(!allowBuy && !allowSell)
      {
         err = "allowBuy/allowSell: ambos false";
         return(false);
      }
      if(moduleCheckMode < MODULE_CHECK_DISABLED || moduleCheckMode > MODULE_CHECK_ON_TIMER_ONCE)
      {
         err = "InpModCheckMode invalido";
         return(false);
      }
      if(moduleCheckDelaySec < 0)
      {
         err = "InpModCheckDelaySec invalido";
         return(false);
      }
      if(omLeg1Fraction < 0.0 || omLeg2Fraction < 0.0)
      {
         err = "InpOMLeg1Fraction/InpOMLeg2Fraction invalidos";
         return(false);
      }
      if(omOpenTwoLegs)
      {
         if((omLeg1Fraction + omLeg2Fraction) <= 0.0)
         {
            err = "soma de fracoes das pernas deve ser > 0";
            return(false);
         }
      }
      else if(omLeg1Fraction <= 0.0)
      {
         err = "InpOMLeg1Fraction deve ser > 0 quando modo 1 perna";
         return(false);
      }
      if(omSlPolicyId == "" || omTpPolicyId == "" || omTsPolicyId == "" || omBePolicyId == "" || omPendingPolicyId == "" || omRiskPolicyId == "")
      {
         err = "InpOMSlPolicyId/InpOMTpPolicyId/InpOMTsPolicyId/InpOMBePolicyId/InpOMPendingPolicyId/InpOMRiskSubmodule invalidos";
         return(false);
      }
      if(omTrailAtrPeriod < 1)
      {
         err = "InpOMTrailAtrPeriod invalido";
         return(false);
      }
      if(omTrailAtrMult <= 0.0)
      {
         err = "InpOMTrailAtrMult invalido";
         return(false);
      }
      if(riskCountertrendScale <= 0.0 || riskCountertrendScale > 1.0)
      {
         err = "InpRiskCountertrendScale invalido";
         return(false);
      }
      if(omHedgeOcoOrderFamily < HEDGE_OCO_FAMILY_STOP || omHedgeOcoOrderFamily > HEDGE_OCO_FAMILY_STOP_LIMIT)
      {
         err = "InpOMHedgeOcoOrderFamily invalido";
         return(false);
      }
      if(omHedgeMaxBaskets < 1)
      {
         err = "InpOMHedgeMaxBaskets invalido";
         return(false);
      }
      if(omHedgeTargetMoney <= 0.0 || omHedgeStopMoney <= 0.0)
      {
         err = "InpOMHedgeTargetMoney/InpOMHedgeStopMoney invalidos";
         return(false);
      }
      if(omHedgeBiasStrongWeight <= 0.5 || omHedgeBiasStrongWeight >= 1.0)
      {
         err = "InpOMHedgeBiasStrongWeight invalido";
         return(false);
      }
      if(omHedgeStopLimitPullbackFrac <= 0.0 || omHedgeStopLimitPullbackFrac >= 1.0)
      {
         err = "InpOMHedgeStopLimitPullbackFrac invalido";
         return(false);
      }
      if(verifyDailyDdPct <= 0.0 || verifyDailyDdPct > 100.0)
      {
         err = "InpVerifyDailyDDPct invalido";
         return(false);
      }
      if(verifyMinFreeMarginPct <= 0.0 || verifyMinFreeMarginPct > 100.0)
      {
         err = "InpVerifyMinFreeMarginPct invalido";
         return(false);
      }
      string s = busSession;
      StringTrimLeft(s);
      StringTrimRight(s);
      if(s == "")
      {
         err = "InpBusSession invalido";
         return(false);
      }
      busSession = s;
      return(true);
   }

   void BuildOrderManagerConfig(SOrderManagerConfig &outCfg) const
   {
      outCfg.allowBuy = allowBuy;
      outCfg.allowSell = allowSell;
      outCfg.onePairLock = onePairLock;
      outCfg.openTwoLegs = omOpenTwoLegs;
      outCfg.lots = lots;
      outCfg.leg1Fraction = omLeg1Fraction;
      outCfg.leg2Fraction = omLeg2Fraction;
      outCfg.magic = magic;
      outCfg.slPolicyId = omSlPolicyId;
      outCfg.tpPolicyId = omTpPolicyId;
      outCfg.tsPolicyId = omTsPolicyId;
      outCfg.bePolicyId = omBePolicyId;
      outCfg.pendingPolicyId = omPendingPolicyId;
      outCfg.riskPolicyId = omRiskPolicyId;
      outCfg.execMode = omExecMode;
      outCfg.hedgeCfg.orderFamily = omHedgeOcoOrderFamily;
      outCfg.hedgeCfg.maxBaskets = omHedgeMaxBaskets;
      outCfg.hedgeCfg.targetMoney = omHedgeTargetMoney;
      outCfg.hedgeCfg.stopMoney = omHedgeStopMoney;
      outCfg.hedgeCfg.biasStrongWeight = omHedgeBiasStrongWeight;
      outCfg.hedgeCfg.stopLimitPullbackFrac = omHedgeStopLimitPullbackFrac;
      outCfg.policyCfg.trailAtrPeriod = omTrailAtrPeriod;
      outCfg.policyCfg.trailAtrMult = omTrailAtrMult;
      outCfg.policyCfg.riskCountertrendScale = riskCountertrendScale;
   }
};

#endif
