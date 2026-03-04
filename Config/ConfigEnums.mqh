#ifndef __CSM_CONFIG_ENUMS_MQH__
#define __CSM_CONFIG_ENUMS_MQH__

enum ESlSlotChoice
{
   SL_SLOT_NONE = 0,
   SL_SLOT_FIXED_POINTS = 1,
   SL_SLOT_ATR_MULT = 2
};

enum ETpSlotChoice
{
   TP_SLOT_NONE = 0,
   TP_SLOT_FIXED_POINTS = 1,
   TP_SLOT_RR = 2
};

enum ETsSlotChoice
{
   TS_SLOT_NONE = 0,
   TS_SLOT_FIXED_POINTS = 1,
   TS_SLOT_ATR = 2
};

enum EBeSlotChoice
{
   BE_SLOT_NONE = 0,
   BE_SLOT_FIXED = 1,
   BE_SLOT_TRAIL = 2
};

enum EPendingSlotChoice
{
   PENDING_SLOT_NONE = 0,
   PENDING_SLOT_LIMIT = 1,
   PENDING_SLOT_STOP = 2
};

enum EModuleCheckMode
{
   MODULE_CHECK_DISABLED = 0,
   MODULE_CHECK_ON_INIT = 1,
   MODULE_CHECK_ON_TIMER_ONCE = 2
};

#endif
