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
   CViewModule()
   {
      m_chartOn = false;
      m_terminalOn = true;
      m_refreshMs = 250;
      m_lastMs = 0;
   }

   void Configure(const bool chartOn,
                  const bool terminalOn,
                  const int refreshMs)
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

   void PublishSystem(const string msg)
   {
      if(m_terminalOn)
         m_terminal.RenderSystem(msg);
   }

   bool AttachIndicators(const long chartId,
                         const CIndicatorModule &indicators,
                         const bool &attachSlots[],
                         string &err)
   {
      err = "";
      if(!m_chartOn)
         return(true);
      return(m_chart.AttachIndicators(chartId, indicators, attachSlots, err));
   }

   int DetachIndicators(const long chartId,
                        const CIndicatorModule &indicators)
   {
      if(!m_chartOn)
         return(0);
      return(m_chart.DetachIndicators(chartId, indicators));
   }

   void ClearChart()
   {
      m_chart.Clear();
      Comment("");
   }
};

#endif
