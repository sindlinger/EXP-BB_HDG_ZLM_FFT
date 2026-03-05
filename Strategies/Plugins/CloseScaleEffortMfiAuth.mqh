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

      // Regra base solicitada:
      // BUY: Feed1 atravessa o pacote BB completo de baixo para cima (3 linhas).
      // SELL: Feed1 atravessa o pacote BB completo de cima para baixo (3 linhas).
      rule.AddBuy("closescale.cross_pack_up", COND_GT, "const.zero");
      rule.AddSell("closescale.cross_pack_dn", COND_GT, "const.zero");

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

      SnapshotPair(snapshot, "forecast.wave", st.waveCurr, st.wavePrev);
      SnapshotPair(snapshot, "forecast.band_up", st.bandUpCurr, st.bandUpPrev);
      SnapshotPair(snapshot, "forecast.band_mid", st.bandMidCurr, st.bandMidPrev);
      SnapshotPair(snapshot, "forecast.band_dn", st.bandDnCurr, st.bandDnPrev);
      SnapshotPair(snapshot, "forecast.feed2", st.feed2Curr, st.feed2Prev);
      SnapshotPair(snapshot, "const.zero", st.zeroCurr, st.zeroPrev);

      const bool okWavePrev = IsUsableBufferValue(st.wavePrev);
      const bool okUpCurr = IsUsableBufferValue(st.bandUpCurr);
      const bool okUpPrev = IsUsableBufferValue(st.bandUpPrev);
      const bool okDnCurr = IsUsableBufferValue(st.bandDnCurr);
      const bool okDnPrev = IsUsableBufferValue(st.bandDnPrev);
      const bool okBandPackCurr = (okUpCurr && okDnCurr && IsUsableBufferValue(st.bandMidCurr));
      const bool okBandPackPrev = (okUpPrev && okDnPrev && IsUsableBufferValue(st.bandMidPrev));

      st.bandTopCurr = (okBandPackCurr ? MathMax(st.bandUpCurr, MathMax(st.bandMidCurr, st.bandDnCurr)) : 0.0);
      st.bandTopPrev = (okBandPackPrev ? MathMax(st.bandUpPrev, MathMax(st.bandMidPrev, st.bandDnPrev)) : 0.0);
      st.bandBotCurr = (okBandPackCurr ? MathMin(st.bandUpCurr, MathMin(st.bandMidCurr, st.bandDnCurr)) : 0.0);
      st.bandBotPrev = (okBandPackPrev ? MathMin(st.bandUpPrev, MathMin(st.bandMidPrev, st.bandDnPrev)) : 0.0);

      double cross3BuyCurr = 0.0, cross3BuyPrev = 0.0;
      double cross3SellCurr = 0.0, cross3SellPrev = 0.0;
      bool cross3BuyOk = snapshot.Get("closescale.cross_pack_up", cross3BuyCurr, cross3BuyPrev);
      bool cross3SellOk = snapshot.Get("closescale.cross_pack_dn", cross3SellCurr, cross3SellPrev);

      st.condBuyCross = (cross3BuyOk && cross3BuyCurr > 0.5);
      st.condSellCross = (cross3SellOk && cross3SellCurr > 0.5);

      st.condBuyZero = (okWavePrev && okBandPackPrev && st.wavePrev <= st.bandBotPrev);   // BUY start abaixo do pacote
      st.condSellZero = (okWavePrev && okBandPackPrev && st.wavePrev >= st.bandTopPrev);  // SELL start acima do pacote
      st.condBuyEffort = (st.effortBuyAuth > 0.5);
      st.condSellEffort = (st.effortSellAuth > 0.5);
      st.condBuyMfi = (st.mfiBuyAuth > 0.5);
      st.condSellMfi = (st.mfiSellAuth > 0.5);

      st.buyExpr = "buy : (ind1_buf0_prev <= band_bot_prev) && (ind1_buf0 > band_top)";
      st.sellExpr = "sell: (ind1_buf0_prev >= band_top_prev) && (ind1_buf0 < band_bot)";
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
                                              SnapshotPairOrEmpty(snapshot, "forecast.wave"),
                                              SnapshotPairOrEmpty(snapshot, "forecast.band_up"),
                                              SnapshotPairOrEmpty(snapshot, "forecast.band_mid"),
                                              SnapshotPairOrEmpty(snapshot, "forecast.band_dn"));
      st.indicatorBuffersLine2 = StringFormat("cross3 B=%s S=%s | start B(prev<=bot)=%s S(prev>=top)=%s",
                                              SnapshotPairOrEmpty(snapshot, "closescale.cross_pack_up", 0),
                                              SnapshotPairOrEmpty(snapshot, "closescale.cross_pack_dn", 0),
                                              (st.condBuyZero ? "true" : "false"),
                                              (st.condSellZero ? "true" : "false"));
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
