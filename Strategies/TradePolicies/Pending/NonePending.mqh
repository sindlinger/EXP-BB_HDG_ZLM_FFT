#ifndef __CSM_PENDING_NONE_MQH__
#define __CSM_PENDING_NONE_MQH__

#include "..\\..\\..\\Contracts\\Interfaces.mqh"

class CPendingPolicy_None : public IPendingPolicyPlugin
{
public:
   virtual string Id()
   {
      return("NonePending");
   }

   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err)
   {
      err = "";
      return(true);
   }

   virtual int BuildPendingRequests(const SSignalDecision &decision,
                                    const CIndicatorSnapshot &snapshot,
                                    const SOrderManagerConfig &cfg,
                                    SExecRequest &reqs[],
                                    string &err)
   {
      err = "";
      ArrayResize(reqs, 0);
      return(0);
   }
};

IPendingPolicyPlugin* CreatePendingPolicy_None()
{
   return(new CPendingPolicy_None());
}

#endif
