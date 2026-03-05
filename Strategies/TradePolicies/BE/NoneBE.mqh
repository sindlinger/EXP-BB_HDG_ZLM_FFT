#ifndef __CSM_BE_NONE_MQH__
#define __CSM_BE_NONE_MQH__

#include "..\\..\\..\\Contracts\\Interfaces.mqh"

class CBePolicy_None : public IBePolicyPlugin
{
public:
   virtual string Id()
   {
      return("NoneBE");
   }

   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err)
   {
      err = "";
      return(true);
   }

   virtual bool ComputeBreakEvenSL(const int signal,
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

IBePolicyPlugin* CreateBePolicy_None()
{
   return(new CBePolicy_None());
}

#endif
