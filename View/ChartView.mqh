#ifndef __CSM_CHART_VIEW_MQH__
#define __CSM_CHART_VIEW_MQH__

#include "..\\Contracts\\CoreTypes.mqh"

class CChartView
{
public:
   void Render(const SRuntimeViewState &st)
   {
      string txt = "";
      txt += StringFormat("CloseScale_ModularEA v1.0.0 | %s\n", st.strategyId);
      txt += StringFormat("Signal=%s | Pos=%d\n", st.signalText, st.positions);
      txt += StringFormat("Reason=%s\n", st.signalReason);
      txt += StringFormat("Exec=%s\n", st.execText);
      txt += StringFormat("Signals BUY/SELL=%d/%d", st.buySignals, st.sellSignals);
      Comment(txt);
   }
};

#endif
