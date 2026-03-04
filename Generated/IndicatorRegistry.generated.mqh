#ifndef __CSM_INDICATOR_REGISTRY_GENERATED_MQH__
#define __CSM_INDICATOR_REGISTRY_GENERATED_MQH__

#include "..\Contracts\Interfaces.mqh"
#include "..\Indicators\Plugins\ExampleFeedPair.mqh"

int IndicatorRegistry_ListIds(string &out[])
{
   ArrayResize(out, 1);
   out[0] = "ExampleFeedPair";
   return(1);
}

IIndicatorPlugin* IndicatorRegistry_CreateById(const string id)
{
   if(id == "ExampleFeedPair")
      return(CreateIndicatorPlugin_ExampleFeedPair());
   return(NULL);
}

#endif
