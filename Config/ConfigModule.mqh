#ifndef __CSM_CONFIG_MODULE_MQH__
#define __CSM_CONFIG_MODULE_MQH__

#include "ConfigEnums.mqh"

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

   int slSlot1;
   int slSlot2;
   int slSlot3;
   int slFixedPoints;
   int slAtrPeriod;
   double slAtrMult;

   int tpSlot1;
   int tpSlot2;
   int tpSlot3;
   int tpFixedPoints;
   double tpRR;

   int tsSlot1;
   int tsSlot2;
   int tsSlot3;
   int tsStartPoints;
   int tsDistancePoints;

   int beSlot1;
   int beSlot2;
   int beSlot3;
   int beTriggerPoints;
   int beOffsetPoints;

   int pendingSlot1;
   int pendingSlot2;
   int pendingSlot3;

   bool viewChart;
   bool viewTerminal;
   int viewRefreshMs;

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

      slSlot1 = SL_SLOT_NONE;
      slSlot2 = SL_SLOT_NONE;
      slSlot3 = SL_SLOT_NONE;
      slFixedPoints = 200;
      slAtrPeriod = 14;
      slAtrMult = 1.2;

      tpSlot1 = TP_SLOT_NONE;
      tpSlot2 = TP_SLOT_NONE;
      tpSlot3 = TP_SLOT_NONE;
      tpFixedPoints = 300;
      tpRR = 2.0;

      tsSlot1 = TS_SLOT_NONE;
      tsSlot2 = TS_SLOT_NONE;
      tsSlot3 = TS_SLOT_NONE;
      tsStartPoints = 150;
      tsDistancePoints = 120;

      beSlot1 = BE_SLOT_NONE;
      beSlot2 = BE_SLOT_NONE;
      beSlot3 = BE_SLOT_NONE;
      beTriggerPoints = 120;
      beOffsetPoints = 10;

      pendingSlot1 = PENDING_SLOT_NONE;
      pendingSlot2 = PENDING_SLOT_NONE;
      pendingSlot3 = PENDING_SLOT_NONE;

      viewChart = true;
      viewTerminal = true;
      viewRefreshMs = 250;
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

      slSlot1 = (int)InpSLSlot1;
      slSlot2 = (int)InpSLSlot2;
      slSlot3 = (int)InpSLSlot3;
      slFixedPoints = InpSLFixedPoints;
      slAtrPeriod = InpSLAtrPeriod;
      slAtrMult = InpSLAtrMult;

      tpSlot1 = (int)InpTPSlot1;
      tpSlot2 = (int)InpTPSlot2;
      tpSlot3 = (int)InpTPSlot3;
      tpFixedPoints = InpTPFixedPoints;
      tpRR = InpTPRR;

      tsSlot1 = (int)InpTSSlot1;
      tsSlot2 = (int)InpTSSlot2;
      tsSlot3 = (int)InpTSSlot3;
      tsStartPoints = InpTSStartPoints;
      tsDistancePoints = InpTSDistancePoints;

      beSlot1 = (int)InpBESlot1;
      beSlot2 = (int)InpBESlot2;
      beSlot3 = (int)InpBESlot3;
      beTriggerPoints = InpBETriggerPoints;
      beOffsetPoints = InpBEOffsetPoints;

      pendingSlot1 = (int)InpPendingSlot1;
      pendingSlot2 = (int)InpPendingSlot2;
      pendingSlot3 = (int)InpPendingSlot3;

      viewChart = InpViewChart;
      viewTerminal = InpViewTerminal;
      viewRefreshMs = InpViewRefreshMs;

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
      return(true);
   }
};

#endif
