#ifndef __CSM_INDICATOR_EXAMPLE_FEED_PAIR_MQH__
#define __CSM_INDICATOR_EXAMPLE_FEED_PAIR_MQH__

#include "..\\..\\Contracts\\Interfaces.mqh"

class CIndicatorPlugin_ExampleFeedPair : public IIndicatorPlugin
{
private:
   int m_fastHandle;
   int m_slowHandle;

public:
   CIndicatorPlugin_ExampleFeedPair()
   {
      m_fastHandle = INVALID_HANDLE;
      m_slowHandle = INVALID_HANDLE;
   }

   virtual string Id()
   {
      return("ExampleFeedPair");
   }

   virtual bool Init(string &err)
   {
      err = "";
      m_fastHandle = iMA(_Symbol, _Period, 9, 0, MODE_EMA, PRICE_CLOSE);
      m_slowHandle = iMA(_Symbol, _Period, 21, 0, MODE_EMA, PRICE_CLOSE);
      if(m_fastHandle == INVALID_HANDLE || m_slowHandle == INVALID_HANDLE)
      {
         err = "falha ao criar handles MA do plugin ExampleFeedPair";
         return(false);
      }
      return(true);
   }

   virtual void Deinit()
   {
      if(m_fastHandle != INVALID_HANDLE)
         IndicatorRelease(m_fastHandle);
      if(m_slowHandle != INVALID_HANDLE)
         IndicatorRelease(m_slowHandle);
      m_fastHandle = INVALID_HANDLE;
      m_slowHandle = INVALID_HANDLE;
   }

   virtual bool Update(CIndicatorSnapshot &snapshot, string &err)
   {
      err = "";
      if(m_fastHandle == INVALID_HANDLE || m_slowHandle == INVALID_HANDLE)
      {
         err = "plugin ExampleFeedPair nao inicializado";
         return(false);
      }

      double fastCurr[1], fastPrev[1];
      double slowCurr[1], slowPrev[1];

      int cFast0 = CopyBuffer(m_fastHandle, 0, 0, 1, fastCurr);
      int cFast1 = CopyBuffer(m_fastHandle, 0, 1, 1, fastPrev);
      int cSlow0 = CopyBuffer(m_slowHandle, 0, 0, 1, slowCurr);
      int cSlow1 = CopyBuffer(m_slowHandle, 0, 1, 1, slowPrev);
      if(cFast0 < 1 || cFast1 < 1 || cSlow0 < 1 || cSlow1 < 1)
      {
         err = "CopyBuffer insuficiente no plugin ExampleFeedPair";
         return(false);
      }

      bool fastOk = (MathIsValidNumber(fastCurr[0]) && MathIsValidNumber(fastPrev[0]));
      bool slowOk = (MathIsValidNumber(slowCurr[0]) && MathIsValidNumber(slowPrev[0]));

      snapshot.Upsert("feed.fast", fastCurr[0], fastPrev[0], fastOk);
      snapshot.Upsert("feed.slow", slowCurr[0], slowPrev[0], slowOk);

      return(fastOk && slowOk);
   }
};

IIndicatorPlugin* CreateIndicatorPlugin_ExampleFeedPair()
{
   return(new CIndicatorPlugin_ExampleFeedPair());
}

#endif
