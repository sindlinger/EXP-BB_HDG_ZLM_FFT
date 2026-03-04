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
   EXEC_ACTION_CLOSE = 4
};

struct SExecRequest
{
   int action;
   ulong ticket;
   double volume;
   double price;
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
};

struct SRuntimeViewState
{
   datetime ts;
   string strategyId;
   string signalText;
   string signalReason;
   string execText;
   int positions;
   int buySignals;
   int sellSignals;
};

#endif
