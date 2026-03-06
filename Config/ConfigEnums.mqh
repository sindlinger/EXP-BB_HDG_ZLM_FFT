// [POLICY] PROIBIDO: EA nao pode compartilhar/passar inputs para indicador.
// [POLICY] Indicadores devem rodar com seus proprios inputs internos (iCustom sem parametros do EA).

#ifndef __CSM_CONFIG_ENUMS_MQH__
#define __CSM_CONFIG_ENUMS_MQH__

enum EModuleCheckMode
{
   MODULE_CHECK_DISABLED = 0,
   MODULE_CHECK_ON_INIT = 1,
   MODULE_CHECK_ON_TIMER_ONCE = 2
};

enum EModuleToggle
{
   MODULE_DISABLED = 0,
   MODULE_ENABLED = 1
};

enum ERiskSubmodule
{
   RISK_SUBMODULE_DEFAULT = 0,
   RISK_SUBMODULE_CLOSESCALE_COUNTERTREND_ABOVE_ZERO = 1,
   RISK_SUBMODULE_HEDGE_70_30 = 2
};

enum EOmExecMode
{
   OM_EXEC_LEGACY = 0,
   OM_EXEC_HEDGE_OCO_V1 = 1
};

enum EHedgeOcoOrderFamily
{
   HEDGE_OCO_FAMILY_STOP = 0,
   HEDGE_OCO_FAMILY_STOP_LIMIT = 1
};

enum ECloseScaleBandFilter
{
   CS_BAND_FILTER_NONE = 0,
   CS_BAND_FILTER_ABOVE_UPPER = 1,
   CS_BAND_FILTER_BELOW_LOWER = 2
};

enum ECloseScaleZeroFilter
{
   CS_ZERO_FILTER_NONE = 0,
   CS_ZERO_FILTER_ABOVE_ZERO = 1,
   CS_ZERO_FILTER_BELOW_ZERO = 2
};

#endif
