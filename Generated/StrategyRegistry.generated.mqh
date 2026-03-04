#ifndef __CSM_STRATEGY_REGISTRY_GENERATED_MQH__
#define __CSM_STRATEGY_REGISTRY_GENERATED_MQH__

#include "..\Contracts\Interfaces.mqh"
#include "..\Strategies\Plugins\SimpleCross.mqh"

int StrategyRegistry_ListIds(string &out[])
{
   ArrayResize(out, 1);
   out[0] = "SimpleCross";
   return(1);
}

IStrategyPlugin* StrategyRegistry_CreateById(const string id)
{
   if(id == "SimpleCross")
      return(CreateStrategyPlugin_SimpleCross());
   return(NULL);
}

#endif
