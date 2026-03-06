#ifndef __CSM_STRATEGY_SIMPLE_CROSS_MQH__
#define __CSM_STRATEGY_SIMPLE_CROSS_MQH__

#include "..\\..\\Contracts\\Interfaces.mqh"

class CStrategyPlugin_SimpleCross : public IStrategyPlugin
{
private:
   bool SnapshotPair(const CIndicatorSnapshot &snap,
                     const string key,
                     double &curr,
                     double &prev) const
   {
      curr = 0.0;
      prev = 0.0;
      if(!snap.Get(key, curr, prev))
         return(false);
      return(true);
   }

   string SnapshotPairOrEmpty(const CIndicatorSnapshot &snap,
                              const string key,
                              const int digits = 5) const
   {
      double curr = 0.0, prev = 0.0;
      if(!snap.Get(key, curr, prev))
         return("EMPTY");
      return(StringFormat("%s/%s",
                          DoubleToString(curr, digits),
                          DoubleToString(prev, digits)));
   }

public:
   virtual string Id()
   {
      return("SimpleCross");
   }

   virtual void Configure(const CStrategyParamBag &params)
   {
      // Estrategia sem parametros dinamicos.
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

   virtual void ApplyDecisionSnapshot(CIndicatorSnapshot &snapshot,
                                      const SSignalDecision &decision)
   {
      snapshot.Upsert("signal.bias_side", (double)decision.signal, (double)decision.signal, true);
      snapshot.Upsert("signal.bias_strength", 1.0, 1.0, true);
      snapshot.Upsert("signal.buy_trigger", (decision.buyArmed ? 1.0 : 0.0), (decision.buyArmed ? 1.0 : 0.0), true);
      snapshot.Upsert("signal.sell_trigger", (decision.sellArmed ? 1.0 : 0.0), (decision.sellArmed ? 1.0 : 0.0), true);
   }

   virtual void FillViewState(const CIndicatorSnapshot &snapshot,
                              const SSignalDecision &decision,
                              const bool useEffortAuth,
                              const bool useMfiAuth,
                              const int activeBaskets,
                              const double basketNetPnl,
                              SRuntimeViewState &st)
   {
      st.buyArmed = decision.buyArmed;
      st.sellArmed = decision.sellArmed;
      st.useEffortAuth = useEffortAuth;
      st.useMfiAuth = useMfiAuth;
      st.activeBaskets = activeBaskets;
      st.basketNetPnl = basketNetPnl;

      SnapshotPair(snapshot, "feed.fast", st.waveCurr, st.wavePrev);
      SnapshotPair(snapshot, "feed.slow", st.feed2Curr, st.feed2Prev);
      st.bandUpCurr = st.feed2Curr;
      st.bandUpPrev = st.feed2Prev;
      st.bandMidCurr = st.feed2Curr;
      st.bandMidPrev = st.feed2Prev;
      st.bandDnCurr = st.feed2Curr;
      st.bandDnPrev = st.feed2Prev;
      st.bandTopCurr = st.feed2Curr;
      st.bandTopPrev = st.feed2Prev;
      st.bandBotCurr = st.feed2Curr;
      st.bandBotPrev = st.feed2Prev;
      st.zeroCurr = 0.0;
      st.zeroPrev = 0.0;

      st.condBuyCross = (st.wavePrev <= st.feed2Prev && st.waveCurr > st.feed2Curr);
      st.condSellCross = (st.wavePrev >= st.feed2Prev && st.waveCurr < st.feed2Curr);
      st.condBuyZero = (st.waveCurr > st.feed2Curr);
      st.condSellZero = (st.waveCurr < st.feed2Curr);
      st.condBuyZeroCross = false;
      st.condSellZeroCross = false;
      st.regimeTrendBull = false;
      st.regimeCounterBull = false;
      st.regimeTrendBear = false;
      st.regimeCounterBear = false;
      st.condBuyEffort = false;
      st.condSellEffort = false;
      st.condBuyMfi = false;
      st.condSellMfi = false;

      st.buyExpr = "buy : feed.fast > feed.slow && feed.fast XUP feed.slow";
      st.sellExpr = "sell: feed.fast < feed.slow && feed.fast XDN feed.slow";
      st.buyCondTrace = decision.buyTrace;
      st.sellCondTrace = decision.sellTrace;
      st.signalBuffersTrace = decision.buffersTrace;
      st.indicatorBuffersLine1 = StringFormat("feed.fast=%s | feed.slow=%s",
                                              SnapshotPairOrEmpty(snapshot, "feed.fast"),
                                              SnapshotPairOrEmpty(snapshot, "feed.slow"));
      st.indicatorBuffersLine2 = StringFormat("cross B=%s S=%s",
                                              (st.condBuyCross ? "true" : "false"),
                                              (st.condSellCross ? "true" : "false"));
   }
};

IStrategyPlugin* CreateStrategyPlugin_SimpleCross()
{
   return(new CStrategyPlugin_SimpleCross());
}

#endif
