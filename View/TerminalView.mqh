#ifndef __CSM_TERMINAL_VIEW_MQH__
#define __CSM_TERMINAL_VIEW_MQH__

#include "..\\Contracts\\CoreTypes.mqh"

class CTerminalView
{
private:
   string m_last;

public:
   void Render(const SRuntimeViewState &st)
   {
      string line = StringFormat("[MOD-EA] strat=%s signal=%s pos=%d exec=%s reason=%s buy/sell=%d/%d",
                                 st.strategyId,
                                 st.signalText,
                                 st.positions,
                                 st.execText,
                                 st.signalReason,
                                 st.buySignals,
                                 st.sellSignals);
      if(line != m_last)
      {
         Print(line);
         m_last = line;
      }
   }
};

#endif
