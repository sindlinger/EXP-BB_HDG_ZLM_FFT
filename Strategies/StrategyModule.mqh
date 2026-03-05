#ifndef __CSM_STRATEGY_MODULE_MQH__
#define __CSM_STRATEGY_MODULE_MQH__

#include "..\\Contracts\\Interfaces.mqh"
#include "..\\Generated\\StrategyRegistry.generated.mqh"

class CStrategyModule
{
private:
   IStrategyPlugin* m_strategy;
   string m_id;
   CStrategyParamBag m_params;

public:
   CStrategyModule()
   {
      m_strategy = NULL;
      m_id = "";
      m_params.Clear();
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
      m_strategy.Configure(m_params);
      return(true);
   }

   void SetParams(const CStrategyParamBag &params)
   {
      m_params = params;
      if(m_strategy != NULL)
         m_strategy.Configure(m_params);
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

   void ApplyDecisionSnapshot(CIndicatorSnapshot &snapshot,
                              const SSignalDecision &decision)
   {
      if(m_strategy == NULL)
         return;
      m_strategy.ApplyDecisionSnapshot(snapshot, decision);
   }

   void FillStrategyViewState(const CIndicatorSnapshot &snapshot,
                              const SSignalDecision &decision,
                              const bool useEffortAuth,
                              const bool useMfiAuth,
                              const int activeBaskets,
                              const double basketNetPnl,
                              SRuntimeViewState &st)
   {
      if(m_strategy == NULL)
         return;
      m_strategy.FillViewState(snapshot,
                               decision,
                               useEffortAuth,
                               useMfiAuth,
                               activeBaskets,
                               basketNetPnl,
                               st);
   }

   string CurrentId() const
   {
      return(m_id);
   }
};

#endif
