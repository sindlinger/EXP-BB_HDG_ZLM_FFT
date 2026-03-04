#ifndef __CSM_VIEW_MODULE_MQH__
#define __CSM_VIEW_MODULE_MQH__

#include "ChartView.mqh"
#include "TerminalView.mqh"

class CViewModule
{
private:
   bool m_chartOn;
   bool m_terminalOn;
   int  m_refreshMs;
   ulong m_lastMs;

   CChartView m_chart;
   CTerminalView m_terminal;

public:
   void Configure(const bool chartOn, const bool terminalOn, const int refreshMs)
   {
      m_chartOn = chartOn;
      m_terminalOn = terminalOn;
      m_refreshMs = refreshMs;
      m_lastMs = 0;
   }

   void Publish(const SRuntimeViewState &st)
   {
      ulong now = GetTickCount64();
      if(m_refreshMs > 0 && m_lastMs > 0 && (now - m_lastMs) < (ulong)m_refreshMs)
         return;
      m_lastMs = now;

      if(m_chartOn)
         m_chart.Render(st);
      if(m_terminalOn)
         m_terminal.Render(st);
   }

   void ClearChart()
   {
      Comment("");
   }
};

#endif
