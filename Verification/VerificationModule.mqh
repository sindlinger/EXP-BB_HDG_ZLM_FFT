// [POLICY] PROIBIDO: EA nao pode compartilhar/passar inputs para indicador.
// [POLICY] Indicadores devem rodar com seus proprios inputs internos (iCustom sem parametros do EA).

#ifndef __CSM_VERIFICATION_MODULE_MQH__
#define __CSM_VERIFICATION_MODULE_MQH__

#include "..\\Config\\ConfigEnums.mqh"

class CVerificationModule
{
private:
   bool m_modulesReady;
   bool m_moduleCheckScheduled;
   datetime m_moduleCheckDue;
   string m_moduleCheckMsg;
   datetime m_lastModuleCheckLog;

   int m_checkMode;
   int m_checkDelaySec;
   bool m_checkHardFail;

   bool IsTransientModuleCheckError(const string err) const
   {
      if(StringFind(err, "CopyBuffer insuficiente") >= 0)
         return(true);
      if(StringFind(err, "indicadores sem leitura valida") >= 0)
         return(true);
      return(false);
   }

public:
   CVerificationModule()
   {
      m_checkMode = MODULE_CHECK_ON_INIT;
      m_checkDelaySec = 2;
      m_checkHardFail = true;
      ResetRuntimeState();
   }

   void Configure(const int checkMode,
                  const int checkDelaySec,
                  const bool checkHardFail)
   {
      m_checkMode = checkMode;
      m_checkDelaySec = checkDelaySec;
      m_checkHardFail = checkHardFail;
   }

   void ResetRuntimeState()
   {
      m_modulesReady = false;
      m_moduleCheckScheduled = false;
      m_moduleCheckDue = 0;
      m_moduleCheckMsg = "not-run";
      m_lastModuleCheckLog = 0;
   }

   bool Begin(string &logMsg, string &fatalErr)
   {
      logMsg = "";
      fatalErr = "";

      m_modulesReady = false;
      m_moduleCheckScheduled = false;
      m_moduleCheckDue = 0;
      m_lastModuleCheckLog = 0;

      if(m_checkMode == MODULE_CHECK_DISABLED)
      {
         m_modulesReady = true;
         m_moduleCheckMsg = "disabled";
         logMsg = "ModuleCheck desabilitado";
         return(true);
      }

      m_moduleCheckScheduled = true;
      if(m_checkMode == MODULE_CHECK_ON_INIT)
      {
         m_moduleCheckDue = TimeCurrent();
         m_moduleCheckMsg = "agendado(init imediato)";
         logMsg = "ModuleCheck agendado para init imediato";
         return(true);
      }

      m_moduleCheckDue = TimeCurrent() + (datetime)MathMax(0, m_checkDelaySec);
      m_moduleCheckMsg = StringFormat("agendado +%d sec", m_checkDelaySec);
      logMsg = StringFormat("ModuleCheck agendado para timer (+%d sec)", m_checkDelaySec);
      return(true);
   }

   void OnTimerStep(string &logMsg)
   {
      logMsg = "";
      if(!m_moduleCheckScheduled || m_modulesReady)
         return;

      if(!NeedCheckNow())
         return;

      datetime now = TimeCurrent();
      if((now - m_lastModuleCheckLog) >= 5)
      {
         m_lastModuleCheckLog = now;
         logMsg = "ModuleCheck aguardando execucao no Main";
      }
   }

   bool NeedCheckNow() const
   {
      if(!m_moduleCheckScheduled || m_modulesReady)
         return(false);
      datetime now = TimeCurrent();
      return(now >= m_moduleCheckDue);
   }

   void ApplyCheckResult(const bool ok,
                         const string detailOrErr,
                         string &logMsg,
                         bool &fatal)
   {
      logMsg = "";
      fatal = false;

      if(ok)
      {
         m_modulesReady = true;
         m_moduleCheckScheduled = false;
         m_moduleCheckMsg = StringFormat("ok: %s", detailOrErr);
         logMsg = StringFormat("ModuleCheck ok: %s", detailOrErr);
         return;
      }

      m_modulesReady = false;
      m_moduleCheckMsg = StringFormat("fail: %s", detailOrErr);

      bool transient = IsTransientModuleCheckError(detailOrErr);
      if(transient)
      {
         m_moduleCheckScheduled = true;
         m_moduleCheckDue = TimeCurrent() + (datetime)MathMax(1, m_checkDelaySec);
         logMsg = StringFormat("ModuleCheck pendente (transiente): %s", detailOrErr);
         return;
      }

      if(m_checkHardFail)
      {
         m_moduleCheckScheduled = false;
         fatal = true;
         logMsg = StringFormat("ModuleCheck fatal: %s", detailOrErr);
         return;
      }

      m_moduleCheckScheduled = true;
      m_moduleCheckDue = TimeCurrent() + (datetime)MathMax(1, m_checkDelaySec);
      logMsg = StringFormat("ModuleCheck pendente: %s", detailOrErr);
   }

   bool ModulesReady() const
   {
      return(m_modulesReady);
   }

   bool NeedTimer() const
   {
      return(m_moduleCheckScheduled && !m_modulesReady);
   }

   string ModuleCheckMessage() const
   {
      return(m_moduleCheckMsg);
   }
};

#endif
