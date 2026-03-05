#ifndef __CSM_INTERFACES_MQH__
#define __CSM_INTERFACES_MQH__

#include "CoreTypes.mqh"
#include "Snapshot.mqh"
#include "StrategyParams.mqh"

class CSignalRule
{
private:
   string m_buyLeft[];
   int    m_buyOp[];
   string m_buyRight[];

   string m_sellLeft[];
   int    m_sellOp[];
   string m_sellRight[];

public:
   string ruleId;

   void Clear()
   {
      ruleId = "";
      ArrayResize(m_buyLeft, 0);
      ArrayResize(m_buyOp, 0);
      ArrayResize(m_buyRight, 0);
      ArrayResize(m_sellLeft, 0);
      ArrayResize(m_sellOp, 0);
      ArrayResize(m_sellRight, 0);
   }

   void AddBuy(const string left, const int op, const string right)
   {
      int i = ArraySize(m_buyLeft);
      ArrayResize(m_buyLeft, i + 1);
      ArrayResize(m_buyOp, i + 1);
      ArrayResize(m_buyRight, i + 1);
      m_buyLeft[i] = left;
      m_buyOp[i] = op;
      m_buyRight[i] = right;
   }

   void AddSell(const string left, const int op, const string right)
   {
      int i = ArraySize(m_sellLeft);
      ArrayResize(m_sellLeft, i + 1);
      ArrayResize(m_sellOp, i + 1);
      ArrayResize(m_sellRight, i + 1);
      m_sellLeft[i] = left;
      m_sellOp[i] = op;
      m_sellRight[i] = right;
   }

   int BuyCount() const
   {
      return(ArraySize(m_buyLeft));
   }

   int SellCount() const
   {
      return(ArraySize(m_sellLeft));
   }

   bool GetBuy(const int idx, string &left, int &op, string &right) const
   {
      if(idx < 0 || idx >= ArraySize(m_buyLeft))
         return(false);
      left = m_buyLeft[idx];
      op = m_buyOp[idx];
      right = m_buyRight[idx];
      return(true);
   }

   bool GetSell(const int idx, string &left, int &op, string &right) const
   {
      if(idx < 0 || idx >= ArraySize(m_sellLeft))
         return(false);
      left = m_sellLeft[idx];
      op = m_sellOp[idx];
      right = m_sellRight[idx];
      return(true);
   }
};

class IIndicatorPlugin
{
public:
   virtual string Id() = 0;
   virtual bool Init(string &err) = 0;
   virtual void Deinit() = 0;
   virtual bool Update(CIndicatorSnapshot &snapshot, string &err) = 0;
   virtual int PrimaryHandle() const
   {
      return(INVALID_HANDLE);
   }
   virtual void ChartAttachHints(string &hints[]) const
   {
      ArrayResize(hints, 0);
   }
};

class IStrategyPlugin
{
public:
   virtual string Id() = 0;
   virtual void Configure(const CStrategyParamBag &params) = 0;
   virtual bool BuildEntryRule(CSignalRule &rule, string &err) = 0;
   virtual void ApplyDecisionSnapshot(CIndicatorSnapshot &snapshot,
                                      const SSignalDecision &decision) = 0;
   virtual void FillViewState(const CIndicatorSnapshot &snapshot,
                              const SSignalDecision &decision,
                              const bool useEffortAuth,
                              const bool useMfiAuth,
                              const int activeBaskets,
                              const double basketNetPnl,
                              SRuntimeViewState &st) = 0;
};

class ISlPolicyPlugin
{
public:
   virtual string Id() = 0;
   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err) = 0;
   virtual bool ComputeInitialSL(const int signal,
                                 const CIndicatorSnapshot &snapshot,
                                 const double entry,
                                 double &outSL,
                                 string &err) = 0;
};

class ITpPolicyPlugin
{
public:
   virtual string Id() = 0;
   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err) = 0;
   virtual bool ComputeInitialTP1(const int signal,
                                  const CIndicatorSnapshot &snapshot,
                                  const double entry,
                                  const double initialSL,
                                  double &outTP1,
                                  string &err) = 0;
   virtual bool ShouldCloseFinal(const int signal,
                                 const CIndicatorSnapshot &snapshot,
                                 const double openPrice,
                                 const double bid,
                                 const double ask,
                                 bool &outClose,
                                 string &err) = 0;
};

class ITsPolicyPlugin
{
public:
   virtual string Id() = 0;
   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err) = 0;
   virtual bool ComputeTrailingSL(const int signal,
                                  const CIndicatorSnapshot &snapshot,
                                  const double openPrice,
                                  const double currentSL,
                                  const double currentTP,
                                  const double bid,
                                  const double ask,
                                  double &outSL,
                                  string &err) = 0;
};

class IBePolicyPlugin
{
public:
   virtual string Id() = 0;
   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err) = 0;
   virtual bool ComputeBreakEvenSL(const int signal,
                                   const CIndicatorSnapshot &snapshot,
                                   const double openPrice,
                                   const double currentSL,
                                   const double currentTP,
                                   const double bid,
                                   const double ask,
                                   double &outSL,
                                   string &err) = 0;
};

class IPendingPolicyPlugin
{
public:
   virtual string Id() = 0;
   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err) = 0;
   virtual int BuildPendingRequests(const SSignalDecision &decision,
                                    const CIndicatorSnapshot &snapshot,
                                    const SOrderManagerConfig &cfg,
                                    SExecRequest &reqs[],
                                    string &err) = 0;
};

class IRiskPolicyPlugin
{
public:
   virtual string Id() = 0;
   virtual bool Configure(const SOrderPolicyConfig &cfg, string &err) = 0;
   virtual bool ComputeLotScale(const int signal,
                                const CIndicatorSnapshot &snapshot,
                                const bool isSecondLeg,
                                double &outScale,
                                string &reason) = 0;
};

#endif
