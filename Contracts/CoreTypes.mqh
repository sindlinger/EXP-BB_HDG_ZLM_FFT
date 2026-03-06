#ifndef __CSM_CORE_TYPES_MQH__
#define __CSM_CORE_TYPES_MQH__

enum ESignalSide
{
   SIGNAL_NONE = 0,
   SIGNAL_BUY  = 1,
   SIGNAL_SELL = -1
};

enum EConditionOp
{
   COND_GT = 0,
   COND_LT = 1,
   COND_CROSS_UP = 2,
   COND_CROSS_DOWN = 3
};

enum EExecAction
{
   EXEC_ACTION_NONE = 0,
   EXEC_ACTION_OPEN_BUY = 1,
   EXEC_ACTION_OPEN_SELL = 2,
   EXEC_ACTION_MODIFY = 3,
   EXEC_ACTION_CLOSE = 4,
   EXEC_ACTION_OPEN_BUY_LIMIT = 5,
   EXEC_ACTION_OPEN_SELL_LIMIT = 6,
   EXEC_ACTION_OPEN_BUY_STOP = 7,
   EXEC_ACTION_OPEN_SELL_STOP = 8,
   EXEC_ACTION_DELETE_ORDER = 9,
   EXEC_ACTION_OPEN_BUY_STOP_LIMIT = 10,
   EXEC_ACTION_OPEN_SELL_STOP_LIMIT = 11
};

struct SExecRequest
{
   int action;
   ulong ticket;
   double volume;
   double price;
   double stopLimit;
   double sl;
   double tp;
   string comment;
};

struct SExecResult
{
   bool accepted;
   bool executed;
   int retcode;
   ulong ticket;
   string stage;
   string message;
};

struct SSignalDecision
{
   int signal;
   bool buyArmed;
   bool sellArmed;
   string reason;
   string buyTrace;
   string sellTrace;
   string buffersTrace;
};

struct SRuntimeViewState
{
   datetime ts;
   string strategyId;
   string signalText;
   string signalReason;
   string authorityStatus;
   string authorityReason;
   string blockReason;
   string execText;
   int positions;
   int buySignals;
   int sellSignals;
   bool buyArmed;
   bool sellArmed;
   bool useEffortAuth;
   bool useMfiAuth;
   double csBuyTrigger;
   double csSellTrigger;
   double csBuyZero;
   double csSellZero;
   double effortBuyAuth;
   double effortSellAuth;
   double mfiBuyAuth;
   double mfiSellAuth;
   int activeBaskets;
   double basketNetPnl;
   string buyExpr;
   string sellExpr;
   double waveCurr;
   double wavePrev;
   double feed2Curr;
   double feed2Prev;
   double bandUpCurr;
   double bandUpPrev;
   double bandMidCurr;
   double bandMidPrev;
   double bandDnCurr;
   double bandDnPrev;
   double bandTopCurr;
   double bandTopPrev;
   double bandBotCurr;
   double bandBotPrev;
   double zeroCurr;
   double zeroPrev;
   bool condBuyCross;
   bool condBuyZero;
   bool condSellCross;
   bool condSellZero;
   bool condBuyZeroCross;
   bool condSellZeroCross;
   bool regimeTrendBull;
   bool regimeCounterBull;
   bool regimeTrendBear;
   bool regimeCounterBear;
   bool condBuyEffort;
   bool condSellEffort;
   bool condBuyMfi;
   bool condSellMfi;
   string buyCondTrace;
   string sellCondTrace;
   string signalBuffersTrace;
   string indicatorBuffersLine1;
   string indicatorBuffersLine2;
};

struct SOrderPolicyConfig
{
   int trailAtrPeriod;
   double trailAtrMult;
   double riskCountertrendScale;
};

struct SHedgeOcoConfig
{
   int orderFamily;
   int maxBaskets;
   double targetMoney;
   double stopMoney;
   double biasStrongWeight;
   double stopLimitPullbackFrac;
};

struct SOrderManagerConfig
{
   bool allowBuy;
   bool allowSell;
   bool onePairLock;
   bool openTwoLegs;
   double lots;
   double leg1Fraction;
   double leg2Fraction;
   long magic;
   string slPolicyId;
   string tpPolicyId;
   string tsPolicyId;
   string bePolicyId;
   string pendingPolicyId;
   string riskPolicyId;
   int execMode;
   SHedgeOcoConfig hedgeCfg;
   SOrderPolicyConfig policyCfg;
};

#endif
