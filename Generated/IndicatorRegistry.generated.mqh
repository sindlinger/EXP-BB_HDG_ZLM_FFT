#ifndef __CSM_INDICATOR_REGISTRY_GENERATED_MQH__
#define __CSM_INDICATOR_REGISTRY_GENERATED_MQH__

#include "..\Contracts\Interfaces.mqh"
#include "..\Indicators\Plugins\CloseScaleForecastFeed.mqh"
#include "..\Indicators\Plugins\EffortResultFirAuthFeed.mqh"
#include "..\Indicators\Plugins\MfiAuthFeed.mqh"

int IndicatorRegistry_ListIds(string &out[])
{
   ArrayResize(out, 3);
   out[0] = "CloseScaleForecastFeed";
   out[1] = "EffortResultFirAuthFeed";
   out[2] = "MfiAuthFeed";
   return(3);
}

IIndicatorPlugin* IndicatorRegistry_CreateById(const string id)
{
   if(id == "CloseScaleForecastFeed")
      return(CreateIndicatorPlugin_CloseScaleForecastFeed());
   if(id == "EffortResultFirAuthFeed")
      return(CreateIndicatorPlugin_EffortResultFirAuthFeed());
   if(id == "MfiAuthFeed")
      return(CreateIndicatorPlugin_MfiAuthFeed());
   return(NULL);
}

#endif
