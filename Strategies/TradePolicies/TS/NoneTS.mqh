#ifndef __CSM_TS_NONE_MQH__
#define __CSM_TS_NONE_MQH__

#include "..\\..\\..\\Contracts\\Interfaces.mqh"

class CTsPolicy_None : public ITsPolicyPlugin
{
public:
   virtual string Id()
   {
      return("NoneTS");
   }

   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err)
   {
      err = "";
      return(true);
   }

   virtual bool ComputeTrailingSL(const int signal,
                                  const CIndicatorSnapshot &snapshot,
                                  const double openPrice,
                                  const double currentSL,
                                  const double currentTP,
                                  const double bid,
                                  const double ask,
                                  double &outSL,
                                  string &err)
   {
      err = "";
      outSL = 0.0;
      return(false);
   }
};

ITsPolicyPlugin* CreateTsPolicy_None()
{
   return(new CTsPolicy_None());
}

#endif
