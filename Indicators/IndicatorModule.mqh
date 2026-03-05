#ifndef __CSM_INDICATOR_MODULE_MQH__
#define __CSM_INDICATOR_MODULE_MQH__

#include "..\\Contracts\\Interfaces.mqh"
#include "..\\Generated\\IndicatorRegistry.generated.mqh"

class CIndicatorModule
{
private:
   IIndicatorPlugin* m_plugins[];
   string m_ids[];

   bool HasId(const string id, const string &ids[])
   {
      int n = ArraySize(ids);
      for(int i = 0; i < n; i++)
      {
         if(ids[i] == id)
            return(true);
      }
      return(false);
   }

public:
   void Deinit()
   {
      int n = ArraySize(m_plugins);
      for(int i = 0; i < n; i++)
      {
         if(m_plugins[i] != NULL)
         {
            m_plugins[i].Deinit();
            delete m_plugins[i];
            m_plugins[i] = NULL;
         }
      }
      ArrayResize(m_plugins, 0);
      ArrayResize(m_ids, 0);
   }

   bool Init(const string &selectedIds[], string &err)
   {
      err = "";
      Deinit();

      string allIds[];
      int total = IndicatorRegistry_ListIds(allIds);
      if(total <= 0)
      {
         err = "nenhum plugin de indicador registrado";
         return(false);
      }

      bool autoAll = (ArraySize(selectedIds) == 1 && selectedIds[0] == "AUTO_ALL");
      for(int i = 0; i < total; i++)
      {
         string id = allIds[i];
         if(!autoAll && !HasId(id, selectedIds))
            continue;

         IIndicatorPlugin* p = IndicatorRegistry_CreateById(id);
         if(p == NULL)
         {
            err = StringFormat("falha na factory do indicador '%s'", id);
            Deinit();
            return(false);
         }

         string initErr = "";
         if(!p.Init(initErr))
         {
            err = StringFormat("falha Init indicador '%s': %s", id, initErr);
            delete p;
            Deinit();
            return(false);
         }

         int n = ArraySize(m_plugins);
         ArrayResize(m_plugins, n + 1);
         ArrayResize(m_ids, n + 1);
         m_plugins[n] = p;
         m_ids[n] = id;
      }

      if(ArraySize(m_plugins) <= 0)
      {
         err = "selecao de indicadores vazia";
         return(false);
      }

      return(true);
   }

   bool Update(CIndicatorSnapshot &snapshot, string &err)
   {
      err = "";
      bool anyOk = false;
      snapshot.tickTime = TimeCurrent();

      int n = ArraySize(m_plugins);
      for(int i = 0; i < n; i++)
      {
         if(m_plugins[i] == NULL)
            continue;

         string oneErr = "";
         bool ok = m_plugins[i].Update(snapshot, oneErr);
         if(ok)
            anyOk = true;
         else if(oneErr != "")
            err = StringFormat("%s%s[%s] %s",
                               err,
                               (err == "" ? "" : " | "),
                               m_ids[i],
                               oneErr);
      }

      if(!anyOk && err == "")
         err = "nenhum indicador retornou leitura valida";
      return(anyOk);
   }

   int Count() const
   {
      return(ArraySize(m_plugins));
   }

   bool GetChartAttachMeta(const int idx,
                           string &id,
                           int &primaryHandle,
                           string &hints[]) const
   {
      id = "";
      primaryHandle = INVALID_HANDLE;
      ArrayResize(hints, 0);

      int n = ArraySize(m_plugins);
      if(idx < 0 || idx >= n)
         return(false);
      if(m_plugins[idx] == NULL)
         return(false);

      id = (idx < ArraySize(m_ids) ? m_ids[idx] : "");
      primaryHandle = m_plugins[idx].PrimaryHandle();
      m_plugins[idx].ChartAttachHints(hints);
      return(true);
   }

   string LoadedIdsText() const
   {
      int n = ArraySize(m_ids);
      if(n <= 0)
         return("none");

      string out = "";
      for(int i = 0; i < n; i++)
      {
         if(i > 0)
            out += ",";
         out += m_ids[i];
      }
      return(out);
   }
};

#endif
