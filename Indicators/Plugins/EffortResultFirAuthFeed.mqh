#ifndef __CSM_INDICATOR_EFFORT_RESULT_FIR_AUTH_FEED_MQH__
#define __CSM_INDICATOR_EFFORT_RESULT_FIR_AUTH_FEED_MQH__

#include "..\\..\\Contracts\\Interfaces.mqh"
#include "PluginDefaults.mqh"

class CIndicatorPlugin_EffortResultFirAuthFeed : public IIndicatorPlugin
{
private:
   int m_handle;

   bool ReadPair(const int bufferIdx, double &curr, double &prev, string &err)
   {
      err = "";
      curr = 0.0;
      prev = 0.0;

      double v0[1], v1[1];
      int c0 = CopyBuffer(m_handle, bufferIdx, 0, 1, v0);
      int c1 = CopyBuffer(m_handle, bufferIdx, 1, 1, v1);
      if(c0 < 1 || c1 < 1)
      {
         err = StringFormat("CopyBuffer insuficiente no buffer=%d", bufferIdx);
         return(false);
      }

      curr = v0[0];
      prev = v1[0];
      if(!MathIsValidNumber(curr) || !MathIsValidNumber(prev))
      {
         err = StringFormat("valor invalido no buffer=%d", bufferIdx);
         return(false);
      }
      return(true);
   }

public:
   CIndicatorPlugin_EffortResultFirAuthFeed()
   {
      m_handle = INVALID_HANDLE;
   }

   virtual string Id()
   {
      return("EffortResultFirAuthFeed");
   }

   virtual int PrimaryHandle() const
   {
      return(m_handle);
   }

   virtual void ChartAttachHints(string &hints[]) const
   {
      ArrayResize(hints, 2);
      hints[0] = "EffortFIRBridge";
      hints[1] = "Effort_Result_FIR_Bridge";
   }

   virtual bool Init(string &err)
   {
      err = "";

      // Sem parametros extras: usa defaults do indicador standalone.
      m_handle = iCustom(_Symbol, _Period, CSM_BRIDGE_EFFORT_PATH);
      if(m_handle == INVALID_HANDLE)
      {
         err = "falha ao criar iCustom para Effort_Result_FIR_Bridge";
         return(false);
      }

      // Indicador NAO e anexado ao chart por este modulo.
      // Exibicao no chart/terminal e responsabilidade do modulo View.

      return(true);
   }

   virtual void Deinit()
   {
      if(m_handle != INVALID_HANDLE)
         IndicatorRelease(m_handle);

      m_handle = INVALID_HANDLE;
   }

   virtual bool Update(CIndicatorSnapshot &snapshot, string &err)
   {
      err = "";
      if(m_handle == INVALID_HANDLE)
      {
         err = "plugin EffortResultFirAuthFeed nao inicializado";
         return(false);
      }

      // Buffer 0 = histograma do effort, Buffer 1 = media.
      double histCurr = 0.0, histPrev = 0.0;
      double maCurr = 0.0, maPrev = 0.0;

      if(!ReadPair(0, histCurr, histPrev, err))
         return(false);
      if(!ReadPair(1, maCurr, maPrev, err))
         return(false);

      bool aboveMean = (histCurr > maCurr);

      double barOpen = iOpen(_Symbol, _Period, 0);
      double barClose = iClose(_Symbol, _Period, 0);
      bool bullish = (MathIsValidNumber(barOpen) && MathIsValidNumber(barClose) && barClose > barOpen);
      bool bearish = (MathIsValidNumber(barOpen) && MathIsValidNumber(barClose) && barClose < barOpen);

      double buyAuth = ((aboveMean && bullish) ? 1.0 : 0.0);
      double sellAuth = ((aboveMean && bearish) ? 1.0 : 0.0);

      snapshot.Upsert("const.zero", 0.0, 0.0, true);
      snapshot.Upsert("effort.hist", histCurr, histPrev, true);
      snapshot.Upsert("effort.ma", maCurr, maPrev, true);
      snapshot.Upsert("ind2_buf0", histCurr, histPrev, true);
      snapshot.Upsert("ind2_buf1", maCurr, maPrev, true);
      snapshot.Upsert("effort.above_ma", (aboveMean ? 1.0 : 0.0), (aboveMean ? 1.0 : 0.0), true);
      snapshot.Upsert("effort.buy_auth", buyAuth, buyAuth, true);
      snapshot.Upsert("effort.sell_auth", sellAuth, sellAuth, true);

      return(true);
   }
};

IIndicatorPlugin* CreateIndicatorPlugin_EffortResultFirAuthFeed()
{
   return(new CIndicatorPlugin_EffortResultFirAuthFeed());
}

#endif
