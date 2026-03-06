// [POLICY] PROIBIDO: EA nao pode compartilhar/passar inputs para indicador.
// [POLICY] Indicadores devem rodar com seus proprios inputs internos (iCustom sem parametros do EA).

#ifndef __CSM_STRATEGY_REGISTRY_GENERATED_MQH__
#define __CSM_STRATEGY_REGISTRY_GENERATED_MQH__

#include "..\Contracts\Interfaces.mqh"
#include "..\Strategies\Plugins\CloseScaleEffortMfiAuth.mqh"
#include "..\Strategies\Plugins\SimpleCross.mqh"

int StrategyRegistry_ListIds(string &out[])
{
   ArrayResize(out, 2);
   out[0] = "CloseScaleEffortMfiAuth";
   out[1] = "SimpleCross";
   return(2);
}

IStrategyPlugin* StrategyRegistry_CreateById(const string id)
{
   if(id == "CloseScaleEffortMfiAuth")
      return(CreateStrategyPlugin_CloseScaleEffortMfiAuth());
   if(id == "SimpleCross")
      return(CreateStrategyPlugin_SimpleCross());
   return(NULL);
}

#endif
