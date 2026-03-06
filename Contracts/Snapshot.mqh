// [POLICY] PROIBIDO: EA nao pode compartilhar/passar inputs para indicador.
// [POLICY] Indicadores devem rodar com seus proprios inputs internos (iCustom sem parametros do EA).

#ifndef __CSM_SNAPSHOT_MQH__
#define __CSM_SNAPSHOT_MQH__

// Bus API direto na DLL (sem wrapper .mqh extra).
// A DLL deve estar em MQL5/Libraries/CSM_Bus.dll.
#import "CSM_Bus.dll"
int CsmBus_Init(string session);
int CsmBus_Shutdown();
int CsmBus_BeginTick(long tickSeq, long barTime, string symbol, int timeframe);
int CsmBus_EndTick(long tickSeq);
int CsmBus_Publish(string moduleId, string key, double curr, double prev, int valid);
int CsmBus_Read(string key, double &curr, double &prev, int &valid, long &tickSeq);
int CsmBus_Report(string moduleId, string stepId, int code, string detail);
#import

class CIndicatorSnapshot
{
private:
   string m_keys[];
   double m_curr[];
   double m_prev[];
   bool   m_valid[];

   bool   m_busOnline;
   int    m_lastBusRc;
   long   m_tickSeq;
   string m_busSession;
   string m_writerModule;

   int FindIndex(const string key) const
   {
      int n = ArraySize(m_keys);
      for(int i = 0; i < n; i++)
      {
         if(m_keys[i] == key)
            return(i);
      }
      return(-1);
   }

   string SafeWriter() const
   {
      if(m_writerModule == "")
         return("unknown");
      return(m_writerModule);
   }

public:
   datetime tickTime;

   CIndicatorSnapshot()
   {
      m_busOnline = false;
      m_lastBusRc = 0;
      m_tickSeq = 0;
      m_busSession = "";
      m_writerModule = "main";
      tickTime = 0;
      ArrayResize(m_keys, 0);
      ArrayResize(m_curr, 0);
      ArrayResize(m_prev, 0);
      ArrayResize(m_valid, 0);
   }

   bool ConfigureBus(const string session, string &err)
   {
      err = "";

      if(m_busOnline)
      {
         CsmBus_Shutdown();
         m_busOnline = false;
      }

      m_busSession = session;
      m_lastBusRc = 0;
      string s = m_busSession;
      StringTrimLeft(s);
      StringTrimRight(s);
      if(s == "")
      {
         err = "Bus DLL: session vazia";
         return(false);
      }
      m_busSession = s;

      ResetLastError();
      int rc = CsmBus_Init(m_busSession);
      m_lastBusRc = rc;
      if(rc != 0)
      {
         m_busOnline = false;
         err = StringFormat("Bus DLL init falhou rc=%d (err=%d)", rc, (int)GetLastError());
         return(false);
      }

      m_busOnline = true;
      return(true);
   }

   void ShutdownBus()
   {
      if(m_busOnline)
      {
         CsmBus_Shutdown();
         m_busOnline = false;
      }
      m_lastBusRc = 0;
   }

   void BeginCycle(const datetime barTime, const string symbol, const int timeframe)
   {
      m_tickSeq++;
      tickTime = TimeCurrent();
      if(!m_busOnline)
         return;

      int rc = CsmBus_BeginTick(m_tickSeq, (long)barTime, symbol, timeframe);
      if(rc != 0)
      {
         m_lastBusRc = rc;
         // Erro transitório de lock não deve derrubar a sessão inteira do bus.
         // Mantemos online e tentamos novamente no próximo ciclo.
      }
   }

   void EndCycle()
   {
      if(!m_busOnline)
         return;
      int rc = CsmBus_EndTick(m_tickSeq);
      if(rc != 0)
         m_lastBusRc = rc;
   }

   void SetWriterModule(const string moduleId)
   {
      m_writerModule = moduleId;
   }

   bool Report(const string moduleId, const string stepId, const int code, const string detail)
   {
      if(!m_busOnline)
         return(false);
      int rc = CsmBus_Report(moduleId, stepId, code, detail);
      if(rc != 0)
      {
         m_lastBusRc = rc;
         return(false);
      }
      return(true);
   }

   bool BusOnline() const
   {
      return(m_busOnline);
   }

   int LastBusRc() const
   {
      return(m_lastBusRc);
   }

   long CurrentTickSeq() const
   {
      return(m_tickSeq);
   }

   void Clear()
   {
      ArrayResize(m_keys, 0);
      ArrayResize(m_curr, 0);
      ArrayResize(m_prev, 0);
      ArrayResize(m_valid, 0);
      tickTime = 0;
   }

   void Upsert(const string key, const double curr, const double prev, const bool valid)
   {
      int idx = FindIndex(key);
      if(idx < 0)
      {
         idx = ArraySize(m_keys);
         ArrayResize(m_keys, idx + 1);
         ArrayResize(m_curr, idx + 1);
         ArrayResize(m_prev, idx + 1);
         ArrayResize(m_valid, idx + 1);
         m_keys[idx] = key;
      }
      m_curr[idx] = curr;
      m_prev[idx] = prev;
      m_valid[idx] = valid;

      if(m_busOnline)
      {
         int rc = CsmBus_Publish(SafeWriter(), key, curr, prev, (valid ? 1 : 0));
         if(rc != 0)
            m_lastBusRc = rc;
      }
   }

   bool Get(const string key, double &curr, double &prev) const
   {
      // Arquitetura strict-bus: leitura sempre pela DLL (sem fallback local).
      if(!m_busOnline)
         return(false);

      double bc = 0.0;
      double bp = 0.0;
      int bValid = 0;
      long bt = 0;
      int rc = CsmBus_Read(key, bc, bp, bValid, bt);
      if(rc != 0 || bValid == 0)
         return(false);
      if(bt != m_tickSeq)
         return(false); // evita consumir snapshot antigo/desincronizado

      curr = bc;
      prev = bp;
      return(MathIsValidNumber(curr) && MathIsValidNumber(prev));
   }

   bool ProbeBusKey(const string key, long &tickSeq, int &valid, int &readRc) const
   {
      tickSeq = 0;
      valid = 0;
      readRc = -1;
      if(!m_busOnline)
      {
         readRc = -1000;
         return(false);
      }

      double bc = 0.0;
      double bp = 0.0;
      long bt = 0;
      int bValid = 0;
      int rc = CsmBus_Read(key, bc, bp, bValid, bt);
      readRc = rc;
      valid = bValid;
      tickSeq = bt;
      return(rc == 0);
   }

   int Count() const
   {
      return(ArraySize(m_keys));
   }
};

#endif
