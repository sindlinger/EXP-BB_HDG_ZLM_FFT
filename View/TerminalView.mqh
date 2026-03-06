#ifndef __CSM_TERMINAL_VIEW_MQH__
#define __CSM_TERMINAL_VIEW_MQH__

#include "..\\Contracts\\CoreTypes.mqh"

class CTerminalView
{
private:
   string m_last;
   string m_lastDetail;
   string m_lastSystem;
   datetime m_lastLineTs;
   datetime m_lastDetailTs;
   string m_lastSignal;
   int m_lastPositions;

   string BoolText(const bool v) const
   {
      return(v ? "true" : "false");
   }

   string OptBoolText(const bool enabled, const bool v) const
   {
      if(!enabled)
         return("-");
      return(BoolText(v));
   }

public:
   CTerminalView()
   {
      m_last = "";
      m_lastDetail = "";
      m_lastSystem = "";
      m_lastLineTs = 0;
      m_lastDetailTs = 0;
      m_lastSignal = "";
      m_lastPositions = -1;
   }

   void Render(const SRuntimeViewState &st)
   {
      const datetime nowTs = (st.ts > 0 ? st.ts : TimeCurrent());
      const bool importantChange =
         (st.signalText != m_lastSignal) ||
         (st.positions != m_lastPositions);
      const bool dueLine = (m_lastLineTs == 0 || (nowTs - m_lastLineTs) >= 5);
      const bool dueDetail = (m_lastDetailTs == 0 || (nowTs - m_lastDetailTs) >= 10);

      string line = StringFormat("[MOD-EA] strat=%s signal=%s pos=%d buy/sell=%d/%d",
                                 st.strategyId,
                                 st.signalText,
                                 st.positions,
                                 st.buySignals,
                                 st.sellSignals);
      if(line != m_last && (importantChange || dueLine))
      {
         Print(line);
         m_last = line;
         m_lastLineTs = nowTs;
      }

      string detail = StringFormat("[MOD-EA] buy: %s | sell: %s",
                                   st.buyExpr,
                                   st.sellExpr);
      if(detail != m_lastDetail && (importantChange || dueDetail))
      {
         Print(detail);
         Print(StringFormat("[MOD-EA] ind1_buf0=%s/%s ind1_buf1=%s/%s ind1_buf2=%s/%s ind1_buf3=%s/%s ind1_buf4=%s/%s ind1_buf5=%s/%s",
                            DoubleToString(st.waveCurr, 6),
                            DoubleToString(st.wavePrev, 6),
                            DoubleToString(st.feed2Curr, 6),
                            DoubleToString(st.feed2Prev, 6),
                            DoubleToString(st.bandUpCurr, 6),
                            DoubleToString(st.bandUpPrev, 6),
                            DoubleToString(st.bandMidCurr, 6),
                            DoubleToString(st.bandMidPrev, 6),
                            DoubleToString(st.bandDnCurr, 6),
                            DoubleToString(st.bandDnPrev, 6),
                            DoubleToString(st.zeroCurr, 6),
                            DoubleToString(st.zeroPrev, 6)));
         Print(StringFormat("[MOD-EA] buy{bb_cross=%s zero_trend=%s zero_cross=%s effort(ind2_buf0 > ind2_buf1)=%s mfi(ind3_buf0 <= ind3_buf3)=%s} sell{bb_cross=%s zero_trend=%s zero_cross=%s effort(ind2_buf0 > ind2_buf1)=%s mfi(ind3_buf0 >= ind3_buf4)=%s}",
                            BoolText(st.condBuyCross),
                            BoolText(st.condBuyZero),
                            BoolText(st.condBuyZeroCross),
                            OptBoolText(st.useEffortAuth, st.condBuyEffort),
                            OptBoolText(st.useMfiAuth, st.condBuyMfi),
                            BoolText(st.condSellCross),
                            BoolText(st.condSellZero),
                            BoolText(st.condSellZeroCross),
                            OptBoolText(st.useEffortAuth, st.condSellEffort),
                            OptBoolText(st.useMfiAuth, st.condSellMfi)));
         Print(StringFormat("[MOD-EA] regime{bull_trend=%s bull_counter=%s bear_trend=%s bear_counter=%s}",
                            BoolText(st.regimeTrendBull),
                            BoolText(st.regimeCounterBull),
                            BoolText(st.regimeTrendBear),
                            BoolText(st.regimeCounterBear)));
         m_lastDetail = detail;
         m_lastDetailTs = nowTs;
      }

      m_lastSignal = st.signalText;
      m_lastPositions = st.positions;
   }

   void RenderSystem(const string msg)
   {
      string line = StringFormat("[MOD-EA] %s", msg);
      if(line != m_lastSystem)
      {
         Print(line);
         m_lastSystem = line;
      }
   }
};

#endif
