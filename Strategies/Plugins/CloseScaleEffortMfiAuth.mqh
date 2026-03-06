#ifndef __CSM_STRATEGY_CLOSESCALE_EFFORT_MFI_AUTH_MQH__
#define __CSM_STRATEGY_CLOSESCALE_EFFORT_MFI_AUTH_MQH__

#include "..\\..\\Contracts\\Interfaces.mqh"

class CStrategyPlugin_CloseScaleEffortMfiAuth : public IStrategyPlugin
{
private:
   bool m_useEffortAuth;
   bool m_useMfiAuth;

   bool IsUsableBufferValue(const double v) const
   {
      if(!MathIsValidNumber(v))
         return(false);
      if(v == EMPTY_VALUE)
         return(false);
      if(MathAbs(v) > 1.0e100)
         return(false);
      return(true);
   }

   double SnapshotCurrOrZero(const CIndicatorSnapshot &snap, const string key) const
   {
      double curr = 0.0, prev = 0.0;
      if(!snap.Get(key, curr, prev))
         return(0.0);
      if(!MathIsValidNumber(curr))
         return(0.0);
      return(curr);
   }

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
   CStrategyPlugin_CloseScaleEffortMfiAuth()
   {
      m_useEffortAuth = false;
      m_useMfiAuth = false;
   }

   virtual string Id()
   {
      return("CloseScaleEffortMfiAuth");
   }

   virtual void Configure(const CStrategyParamBag &params)
   {
      int v = 0;
      m_useEffortAuth = (params.GetInt("auth.effort.enabled", v) && v != 0);
      m_useMfiAuth = (params.GetInt("auth.mfi.enabled", v) && v != 0);
   }

   virtual bool BuildEntryRule(CSignalRule &rule, string &err)
   {
      err = "";
      rule.Clear();
      rule.ruleId = Id();

      // Regra base direta nos buffers publicados do indicador (ind1_buf*):
      // BUY: ind1_buf0 cruza ind1_buf2 de baixo para cima.
      // SELL: ind1_buf0 cruza ind1_buf4 de cima para baixo.
      rule.AddBuy("ind1_buf0", COND_CROSS_UP, "ind1_buf2");
      rule.AddSell("ind1_buf0", COND_CROSS_DOWN, "ind1_buf4");

      // Blocos opcionais de autorizacao (fase incremental).
      if(m_useEffortAuth)
      {
         rule.AddBuy("effort.buy_auth", COND_GT, "const.zero");
         rule.AddSell("effort.sell_auth", COND_GT, "const.zero");
      }
      if(m_useMfiAuth)
      {
         rule.AddBuy("mfi.buy_auth", COND_GT, "const.zero");
         rule.AddSell("mfi.sell_auth", COND_GT, "const.zero");
      }

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

      st.csBuyTrigger = SnapshotCurrOrZero(snapshot, "signal.buy_trigger");
      st.csSellTrigger = SnapshotCurrOrZero(snapshot, "signal.sell_trigger");
      st.csBuyZero = SnapshotCurrOrZero(snapshot, "anchor.zero_price");
      st.csSellZero = SnapshotCurrOrZero(snapshot, "anchor.zero_price");
      st.effortBuyAuth = SnapshotCurrOrZero(snapshot, "effort.buy_auth");
      st.effortSellAuth = SnapshotCurrOrZero(snapshot, "effort.sell_auth");
      st.mfiBuyAuth = SnapshotCurrOrZero(snapshot, "mfi.buy_auth");
      st.mfiSellAuth = SnapshotCurrOrZero(snapshot, "mfi.sell_auth");
      st.activeBaskets = activeBaskets;
      st.basketNetPnl = basketNetPnl;

      SnapshotPair(snapshot, "ind1_buf0", st.waveCurr, st.wavePrev);
      SnapshotPair(snapshot, "ind1_buf2", st.bandUpCurr, st.bandUpPrev);
      SnapshotPair(snapshot, "ind1_buf3", st.bandMidCurr, st.bandMidPrev);
      SnapshotPair(snapshot, "ind1_buf4", st.bandDnCurr, st.bandDnPrev);
      SnapshotPair(snapshot, "ind1_buf1", st.feed2Curr, st.feed2Prev);
      SnapshotPair(snapshot, "ind1_buf5", st.zeroCurr, st.zeroPrev);

      const bool okWavePrev = IsUsableBufferValue(st.wavePrev);
      const bool okUpCurr = IsUsableBufferValue(st.bandUpCurr);
      const bool okUpPrev = IsUsableBufferValue(st.bandUpPrev);
      const bool okDnCurr = IsUsableBufferValue(st.bandDnCurr);
      const bool okDnPrev = IsUsableBufferValue(st.bandDnPrev);
      st.bandTopCurr = (okUpCurr ? st.bandUpCurr : 0.0);
      st.bandTopPrev = (okUpPrev ? st.bandUpPrev : 0.0);
      st.bandBotCurr = (okDnCurr ? st.bandDnCurr : 0.0);
      st.bandBotPrev = (okDnPrev ? st.bandDnPrev : 0.0);

      st.condBuyCross = (okWavePrev && okUpPrev && okUpCurr && st.wavePrev <= st.bandUpPrev && st.waveCurr > st.bandUpCurr);
      st.condSellCross = (okWavePrev && okDnPrev && okDnCurr && st.wavePrev >= st.bandDnPrev && st.waveCurr < st.bandDnCurr);

      st.condBuyZero = (okWavePrev && okUpPrev && st.wavePrev <= st.bandUpPrev);   // BUY start abaixo da UP
      st.condSellZero = (okWavePrev && okDnPrev && st.wavePrev >= st.bandDnPrev);  // SELL start acima da BOTTOM
      st.condBuyEffort = (st.effortBuyAuth > 0.5);
      st.condSellEffort = (st.effortSellAuth > 0.5);
      st.condBuyMfi = (st.mfiBuyAuth > 0.5);
      st.condSellMfi = (st.mfiSellAuth > 0.5);

      st.buyExpr = "buy : (ind1_buf0_prev <= ind1_buf2_prev) && (ind1_buf0 > ind1_buf2)";
      st.sellExpr = "sell: (ind1_buf0_prev >= ind1_buf4_prev) && (ind1_buf0 < ind1_buf4)";
      if(useEffortAuth)
      {
         st.buyExpr += " && ind2_buf0 > ind2_buf1";
         st.sellExpr += " && ind2_buf0 > ind2_buf1";
      }
      if(useMfiAuth)
      {
         st.buyExpr += " && ind3_buf0 <= ind3_buf3";
         st.sellExpr += " && ind3_buf0 >= ind3_buf4";
      }

      st.buyCondTrace = decision.buyTrace;
      st.sellCondTrace = decision.sellTrace;
      st.signalBuffersTrace = decision.buffersTrace;
      st.indicatorBuffersLine1 = StringFormat("ind1_buf0(wave)=%s | ind1_buf2(up)=%s | ind1_buf3(mid)=%s | ind1_buf4(dn)=%s",
                                              SnapshotPairOrEmpty(snapshot, "ind1_buf0"),
                                              SnapshotPairOrEmpty(snapshot, "ind1_buf2"),
                                              SnapshotPairOrEmpty(snapshot, "ind1_buf3"),
                                              SnapshotPairOrEmpty(snapshot, "ind1_buf4"));
      st.indicatorBuffersLine2 = StringFormat("trigger B(prev<=up && curr>up)=%s S(prev>=dn && curr<dn)=%s",
                                              (st.condBuyCross ? "true" : "false"),
                                              (st.condSellCross ? "true" : "false"));
      if(useEffortAuth || useMfiAuth)
      {
         st.indicatorBuffersLine2 += StringFormat(" | effort B=%s S=%s | mfi B=%s S=%s",
                                                   SnapshotPairOrEmpty(snapshot, "effort.buy_auth", 0),
                                                   SnapshotPairOrEmpty(snapshot, "effort.sell_auth", 0),
                                                   SnapshotPairOrEmpty(snapshot, "mfi.buy_auth", 0),
                                                   SnapshotPairOrEmpty(snapshot, "mfi.sell_auth", 0));
      }
   }
};

IStrategyPlugin* CreateStrategyPlugin_CloseScaleEffortMfiAuth()
{
   return(new CStrategyPlugin_CloseScaleEffortMfiAuth());
}

#endif
