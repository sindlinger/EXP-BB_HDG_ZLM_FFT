#ifndef __CSM_STRATEGY_MODULE_MQH__
#define __CSM_STRATEGY_MODULE_MQH__

#include "..\\Contracts\\Interfaces.mqh"
#include "..\\Generated\\StrategyRegistry.generated.mqh"

class CStrategyModule
{
private:
   IStrategyPlugin* m_strategy;
   string m_id;

public:
   CStrategyModule()
   {
      m_strategy = NULL;
      m_id = "";
   }

   void Deinit()
   {
      if(m_strategy != NULL)
      {
         delete m_strategy;
         m_strategy = NULL;
      }
      m_id = "";
   }

   bool Init(const string desiredId, string &err)
   {
      err = "";
      Deinit();

      string allIds[];
      int n = StrategyRegistry_ListIds(allIds);
      if(n <= 0)
      {
         err = "nenhuma estrategia registrada";
         return(false);
      }

      string chosen = desiredId;
      if(chosen == "" || chosen == "AUTO_FIRST")
         chosen = allIds[0];

      m_strategy = StrategyRegistry_CreateById(chosen);
      if(m_strategy == NULL)
      {
         err = StringFormat("estrategia nao encontrada: %s", chosen);
         return(false);
      }

      m_id = chosen;
      return(true);
   }

   bool BuildRule(CSignalRule &rule, string &err)
   {
      err = "";
      if(m_strategy == NULL)
      {
         err = "strategy module nao inicializado";
         return(false);
      }
      return(m_strategy.BuildEntryRule(rule, err));
   }

   string CurrentId() const
   {
      return(m_id);
   }
};

#endif
