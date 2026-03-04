#ifndef __CSM_STRATEGY_SIMPLE_CROSS_MQH__
#define __CSM_STRATEGY_SIMPLE_CROSS_MQH__

#include "..\\..\\Contracts\\Interfaces.mqh"

class CStrategyPlugin_SimpleCross : public IStrategyPlugin
{
public:
   virtual string Id()
   {
      return("SimpleCross");
   }

   virtual bool BuildEntryRule(CSignalRule &rule, string &err)
   {
      err = "";
      rule.Clear();
      rule.ruleId = Id();

      rule.AddBuy("feed.fast", COND_GT, "feed.slow");
      rule.AddBuy("feed.fast", COND_CROSS_UP, "feed.slow");

      rule.AddSell("feed.fast", COND_LT, "feed.slow");
      rule.AddSell("feed.fast", COND_CROSS_DOWN, "feed.slow");

      return(true);
   }
};

IStrategyPlugin* CreateStrategyPlugin_SimpleCross()
{
   return(new CStrategyPlugin_SimpleCross());
}

#endif
