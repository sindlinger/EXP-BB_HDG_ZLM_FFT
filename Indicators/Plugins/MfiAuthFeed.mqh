#ifndef __CSM_INDICATOR_MFI_AUTH_FEED_MQH__
#define __CSM_INDICATOR_MFI_AUTH_FEED_MQH__

#include "..\\..\\Contracts\\Interfaces.mqh"
#include "PluginDefaults.mqh"

class CIndicatorPlugin_MfiAuthFeed : public IIndicatorPlugin
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
   CIndicatorPlugin_MfiAuthFeed()
   {
      m_handle = INVALID_HANDLE;
   }

   virtual string Id()
   {
      return("MfiAuthFeed");
   }

   virtual int PrimaryHandle() const
   {
      return(m_handle);
   }

   virtual void ChartAttachHints(string &hints[]) const
   {
      ArrayResize(hints, 2);
      hints[0] = "MFIBridge";
      hints[1] = "MFI_Bridge";
   }

   virtual bool Init(string &err)
   {
      err = "";

      // Sem parametros extras: carrega MFI com defaults do proprio indicador.
      m_handle = iCustom(_Symbol, _Period, CSM_BRIDGE_MFI_PATH);
      if(m_handle == INVALID_HANDLE)
      {
         err = "falha ao criar iCustom para MFI_Bridge";
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
         err = "plugin MfiAuthFeed nao inicializado";
         return(false);
      }

      double mfiCurr = 0.0, mfiPrev = 0.0;
      if(!ReadPair(0, mfiCurr, mfiPrev, err))
         return(false);

      double oversoldCurr = 0.0, oversoldPrev = 0.0;
      double overboughtCurr = 0.0, overboughtPrev = 0.0;
      if(!ReadPair(3, oversoldCurr, oversoldPrev, err))
      {
         err = StringFormat("oversold: %s", err);
         return(false);
      }
      if(!ReadPair(4, overboughtCurr, overboughtPrev, err))
      {
         err = StringFormat("overbought: %s", err);
         return(false);
      }

      double buyAuth = (mfiCurr <= oversoldCurr ? 1.0 : 0.0);
      double sellAuth = (mfiCurr >= overboughtCurr ? 1.0 : 0.0);

      snapshot.Upsert("const.zero", 0.0, 0.0, true);
      snapshot.Upsert("mfi.value", mfiCurr, mfiPrev, true);
      snapshot.Upsert("mfi.oversold", oversoldCurr, oversoldPrev, true);
      snapshot.Upsert("mfi.overbought", overboughtCurr, overboughtPrev, true);
      snapshot.Upsert("ind3_buf0", mfiCurr, mfiPrev, true);
      snapshot.Upsert("ind3_buf3", oversoldCurr, oversoldPrev, true);
      snapshot.Upsert("ind3_buf4", overboughtCurr, overboughtPrev, true);
      snapshot.Upsert("mfi.buy_auth", buyAuth, buyAuth, true);
      snapshot.Upsert("mfi.sell_auth", sellAuth, sellAuth, true);

      return(true);
   }
};

IIndicatorPlugin* CreateIndicatorPlugin_MfiAuthFeed()
{
   return(new CIndicatorPlugin_MfiAuthFeed());
}

#endif
