#ifndef __CSM_TRADE_POLICY_REGISTRY_MQH__
#define __CSM_TRADE_POLICY_REGISTRY_MQH__

#include "..\\..\\Contracts\\Interfaces.mqh"
#include "SL\\CloseScaleSL_Back1Level.mqh"
#include "TP\\CloseScaleTP_NextLevelAndFinal.mqh"
#include "TS\\NoneTS.mqh"
#include "TS\\ATR_TS.mqh"
#include "TS\\CloseScaleTS_HalfLevel.mqh"
#include "BE\\NoneBE.mqh"
#include "BE\\CloseScaleBE_NextLevel.mqh"
#include "Pending\\NonePending.mqh"
#include "Pending\\CloseScalePending_NextLevelBreakout.mqh"
#include "Risk\\DefaultRisk.mqh"
#include "Risk\\CloseScaleRisk_CountertrendAboveZero.mqh"

int SlPolicyRegistry_ListIds(string &out[])
{
   ArrayResize(out, 1);
   out[0] = "CloseScaleSL_Back1Level";
   return(1);
}

ISlPolicyPlugin* SlPolicyRegistry_CreateById(const string id)
{
   if(id == "CloseScaleSL_Back1Level")
      return(CreateSlPolicy_CloseScale_Back1Level());
   return(NULL);
}

int TpPolicyRegistry_ListIds(string &out[])
{
   ArrayResize(out, 1);
   out[0] = "CloseScaleTP_NextLevelAndFinal";
   return(1);
}

ITpPolicyPlugin* TpPolicyRegistry_CreateById(const string id)
{
   if(id == "CloseScaleTP_NextLevelAndFinal")
      return(CreateTpPolicy_CloseScale_NextLevelAndFinal());
   return(NULL);
}

int TsPolicyRegistry_ListIds(string &out[])
{
   ArrayResize(out, 3);
   out[0] = "NoneTS";
   out[1] = "ATR_TS";
   out[2] = "CloseScaleTS_HalfLevel";
   return(3);
}

ITsPolicyPlugin* TsPolicyRegistry_CreateById(const string id)
{
   if(id == "NoneTS")
      return(CreateTsPolicy_None());
   if(id == "ATR_TS")
      return(CreateTsPolicy_ATR());
   if(id == "CloseScaleTS_HalfLevel")
      return(CreateTsPolicy_CloseScale_HalfLevel());
   return(NULL);
}

int BePolicyRegistry_ListIds(string &out[])
{
   ArrayResize(out, 2);
   out[0] = "NoneBE";
   out[1] = "CloseScaleBE_NextLevel";
   return(2);
}

IBePolicyPlugin* BePolicyRegistry_CreateById(const string id)
{
   if(id == "NoneBE")
      return(CreateBePolicy_None());
   if(id == "CloseScaleBE_NextLevel")
      return(CreateBePolicy_CloseScale_NextLevel());
   return(NULL);
}

int PendingPolicyRegistry_ListIds(string &out[])
{
   ArrayResize(out, 4);
   out[0] = "NonePending";
   out[1] = "CloseScalePending_NextLevelBreakout";
   out[2] = "CloseScalePending_NextLevelLimit";
   out[3] = "CloseScalePending_NextLevelStopLimit";
   return(4);
}

IPendingPolicyPlugin* PendingPolicyRegistry_CreateById(const string id)
{
   if(id == "NonePending")
      return(CreatePendingPolicy_None());
   if(id == "CloseScalePending_NextLevelBreakout")
      return(CreatePendingPolicy_CloseScale_NextLevelBreakout());
   if(id == "CloseScalePending_NextLevelLimit")
      return(CreatePendingPolicy_CloseScale_NextLevelLimit());
   if(id == "CloseScalePending_NextLevelStopLimit")
      return(CreatePendingPolicy_CloseScale_NextLevelStopLimit());
   return(NULL);
}

int RiskPolicyRegistry_ListIds(string &out[])
{
   ArrayResize(out, 2);
   out[0] = "DefaultRisk";
   out[1] = "CloseScaleRisk_CountertrendAboveZero";
   return(2);
}

IRiskPolicyPlugin* RiskPolicyRegistry_CreateById(const string id)
{
   if(id == "DefaultRisk")
      return(CreateRiskPolicy_Default());
   if(id == "CloseScaleRisk_CountertrendAboveZero")
      return(CreateRiskPolicy_CloseScaleCountertrendAboveZero());
   return(NULL);
}

#endif
