#ifndef __CSM_RISK_DEFAULT_MQH__
#define __CSM_RISK_DEFAULT_MQH__

#include "..\\..\\..\\Contracts\\Interfaces.mqh"

class CRiskPolicy_Default : public IRiskPolicyPlugin
{
public:
   virtual string Id()
   {
      return("DefaultRisk");
   }

   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err)
   {
      err = "";
      return(true);
   }

   virtual bool ComputeLotScale(const int signal,
                                const CIndicatorSnapshot &snapshot,
                                const bool isSecondLeg,
                                double &outScale,
                                string &reason)
   {
      outScale = 1.0;
      reason = "risk default: scale=1.00";
      return(true);
   }
};

IRiskPolicyPlugin* CreateRiskPolicy_Default()
{
   return(new CRiskPolicy_Default());
}

#endif
