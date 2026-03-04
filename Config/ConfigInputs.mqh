#ifndef __CSM_CONFIG_INPUTS_MQH__
#define __CSM_CONFIG_INPUTS_MQH__

#include "ConfigEnums.mqh"

input group "Core"
input string InpModStrategyId = "AUTO_FIRST";
input string InpModIndicatorsCsv = "AUTO_ALL";
input bool   InpModAllowBuy = true;
input bool   InpModAllowSell = true;
input double InpModLots = 0.10;
input long   InpModMagic = 5490001;
input int    InpModDeviationPoints = 20;
input EModuleCheckMode InpModCheckMode = MODULE_CHECK_ON_INIT;
input int InpModCheckDelaySec = 2;
input bool InpModCheckHardFail = true;

input group "SL Slots"
input ESlSlotChoice InpSLSlot1 = SL_SLOT_FIXED_POINTS;
input ESlSlotChoice InpSLSlot2 = SL_SLOT_NONE;
input ESlSlotChoice InpSLSlot3 = SL_SLOT_NONE;
input int InpSLFixedPoints = 200;
input int InpSLAtrPeriod = 14;
input double InpSLAtrMult = 1.2;

input group "TP Slots"
input ETpSlotChoice InpTPSlot1 = TP_SLOT_FIXED_POINTS;
input ETpSlotChoice InpTPSlot2 = TP_SLOT_NONE;
input ETpSlotChoice InpTPSlot3 = TP_SLOT_NONE;
input int InpTPFixedPoints = 300;
input double InpTPRR = 2.0;

input group "TS Slots"
input ETsSlotChoice InpTSSlot1 = TS_SLOT_NONE;
input ETsSlotChoice InpTSSlot2 = TS_SLOT_NONE;
input ETsSlotChoice InpTSSlot3 = TS_SLOT_NONE;
input int InpTSStartPoints = 150;
input int InpTSDistancePoints = 120;

input group "BE Slots"
input EBeSlotChoice InpBESlot1 = BE_SLOT_NONE;
input EBeSlotChoice InpBESlot2 = BE_SLOT_NONE;
input EBeSlotChoice InpBESlot3 = BE_SLOT_NONE;
input int InpBETriggerPoints = 120;
input int InpBEOffsetPoints = 10;

input group "Pending Slots"
input EPendingSlotChoice InpPendingSlot1 = PENDING_SLOT_NONE;
input EPendingSlotChoice InpPendingSlot2 = PENDING_SLOT_NONE;
input EPendingSlotChoice InpPendingSlot3 = PENDING_SLOT_NONE;

input group "View"
input bool InpViewChart = true;
input bool InpViewTerminal = true;
input int  InpViewRefreshMs = 250;

#endif
