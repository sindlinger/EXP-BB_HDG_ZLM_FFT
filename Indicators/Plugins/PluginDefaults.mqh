// [POLICY] PROIBIDO: EA nao pode compartilhar/passar inputs para indicador.
// [POLICY] Indicadores devem rodar com seus proprios inputs internos (iCustom sem parametros do EA).

#ifndef __CSM_INDICATOR_PLUGIN_DEFAULTS_MQH__
#define __CSM_INDICATOR_PLUGIN_DEFAULTS_MQH__

// Paths dos wrappers bridge (unico ponto de manutencao).
#define CSM_BRIDGE_CLOSESCALE_PATH "IndicatorsPack-2026\\EA_Bridges\\CloseScale\\CloseScale_v6_Bridge"
#define CSM_BRIDGE_EFFORT_PATH     "IndicatorsPack-2026\\EA_Bridges\\Effort\\Effort_Result_FIR_Bridge"
#define CSM_BRIDGE_MFI_PATH        "IndicatorsPack-2026\\EA_Bridges\\Mfi\\MFI_Bridge"

// Niveis default usados no mapeamento de preco do CloseScale.
// Mantido centralizado para evitar divergencia em multiplos arquivos.
#define CSM_CLOSESCALE_DEFAULT_LEVELS "0.05;0.10;0.15;0.20;0.25"

int CsmCreateIcustomHandleNoParams(const string pluginId,
                                   const string indicatorPath,
                                   string &err)
{
   err = "";
   if(indicatorPath == "")
   {
      err = StringFormat("%s: indicatorPath vazio", pluginId);
      return(INVALID_HANDLE);
   }

   ResetLastError();
   int h = iCustom(_Symbol, _Period, indicatorPath);
   if(h == INVALID_HANDLE)
   {
      err = StringFormat("%s: falha iCustom path-only '%s' (err=%d)",
                         pluginId,
                         indicatorPath,
                         (int)GetLastError());
      return(INVALID_HANDLE);
   }
   return(h);
}

#endif
