// [POLICY] PROIBIDO: EA nao pode compartilhar/passar inputs para indicador.
// [POLICY] Indicadores devem rodar com seus proprios inputs internos (iCustom sem parametros do EA).

#ifndef __CSM_CHART_VIEW_MQH__
#define __CSM_CHART_VIEW_MQH__

#include "..\\Contracts\\CoreTypes.mqh"
#include "..\\Indicators\\IndicatorModule.mqh"

class CChartView
{
private:
   string m_prefix;
   string m_tradeTapeText[];
   color  m_tradeTapeColor[];
   bool   m_showStateHeader;
   bool   m_showSyncTelemetry;
   bool   m_showIndicatorValues;
   bool   m_showConditionRules;
   bool   m_showTradeTape;

   enum
   {
      TRADE_TAPE_MAX = 16
   };

   string ObjName(const string id) const
   {
      return(m_prefix + id);
   }

   color ColorByPair(const bool buyOn, const bool sellOn) const
   {
      if(buyOn && !sellOn)
         return(clrLime);
      if(!buyOn && sellOn)
         return(clrTomato);
      return(clrSilver);
   }

   color ColorByAuthority(const string status) const
   {
      if(StringFind(status, "BLOCKED") == 0)
         return(clrOrangeRed);
      if(StringFind(status, "IDLE") == 0)
         return(clrSilver);
      return(clrLimeGreen);
   }

   string HumanBlockStatus(const string status) const
   {
      if(StringFind(status, "BLOCKED") == 0)
         return("BLOQUEADO");
      if(StringFind(status, "IDLE") == 0)
         return("AGUARDANDO");
      if(status == "ALLOW")
         return("LIBERADO");
      if(status == "")
         return("-");
      return(status);
   }

   string Clip(const string text, const int maxChars) const
   {
      if(maxChars <= 0)
         return("");
      if((int)StringLen(text) <= maxChars)
         return(text);
      return(StringSubstr(text, 0, maxChars - 3) + "...");
   }

   string BoolText(const bool v) const
   {
      return(v ? "true" : "false");
   }

   color BoolColor(const bool v) const
   {
      return(v ? clrLime : clrTomato);
   }

   string PairText(const double curr, const double prev, const int digits = 6) const
   {
      return(StringFormat("%s / %s",
                          DoubleToString(curr, digits),
                          DoubleToString(prev, digits)));
   }

   bool NameMatchesHints(const string name, const string &hints[]) const
   {
      if(name == "")
         return(false);
      int n = ArraySize(hints);
      for(int i = 0; i < n; i++)
      {
         if(hints[i] != "" && StringFind(name, hints[i]) >= 0)
            return(true);
      }
      return(false);
   }

   int RemoveByHints(const long chartId, const string &hints[]) const
   {
      if(ArraySize(hints) <= 0)
         return(0);

      int removed = 0;
      int windows = (int)ChartGetInteger(chartId, CHART_WINDOWS_TOTAL);
      for(int w = windows - 1; w >= 0; w--)
      {
         int total = ChartIndicatorsTotal(chartId, w);
         for(int i = total - 1; i >= 0; i--)
         {
            string name = ChartIndicatorName(chartId, w, i);
            if(!NameMatchesHints(name, hints))
               continue;
            if(ChartIndicatorDelete(chartId, w, name))
               removed++;
         }
      }
      return(removed);
   }

   int RemoveAllRegisteredIndicators(const long chartId,
                                     const CIndicatorModule &indicators) const
   {
      string hints[];
      if(!indicators.GetRegistryAttachHints(hints))
         return(0);
      return(RemoveByHints(chartId, hints));
   }

   bool FindIndicatorNameByHandle(const long chartId,
                                  const int handle,
                                  string &outName) const
   {
      outName = "";
      if(handle == INVALID_HANDLE)
         return(false);

      int windows = (int)ChartGetInteger(chartId, CHART_WINDOWS_TOTAL);
      for(int w = 0; w < windows; w++)
      {
         int total = ChartIndicatorsTotal(chartId, w);
         for(int i = 0; i < total; i++)
         {
            string name = ChartIndicatorName(chartId, w, i);
            if(name == "")
               continue;
            int h = (int)ChartIndicatorGet(chartId, w, name);
            if(h == handle)
            {
               outName = name;
               return(true);
            }
         }
      }
      return(false);
   }

   void EnsureSingleByHandle(const long chartId, const int keepHandle) const
   {
      string shortName = "";
      if(!FindIndicatorNameByHandle(chartId, keepHandle, shortName) || shortName == "")
         return;

      int guard = 0;
      while(guard < 32)
      {
         guard++;
         int matches = 0;
         int deleteWindow = -1;

         int windows = (int)ChartGetInteger(chartId, CHART_WINDOWS_TOTAL);
         for(int w = windows - 1; w >= 0; w--)
         {
            int total = ChartIndicatorsTotal(chartId, w);
            for(int i = total - 1; i >= 0; i--)
            {
               string name = ChartIndicatorName(chartId, w, i);
               if(name != shortName)
                  continue;
               matches++;
               if(deleteWindow < 0)
                  deleteWindow = w;
            }
         }

         if(matches <= 1 || deleteWindow < 0)
            return;

         ResetLastError();
         if(!ChartIndicatorDelete(chartId, deleteWindow, shortName))
            return;
      }
   }

   void SetLabel(const string id,
                 const int y,
                 const string text,
                 const color clr,
                 const int size = 10)
   {
      string name = ObjName(id);
      if(ObjectFind(0, name) < 0)
      {
         if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
            return;
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }

      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
   }

public:
   CChartView()
   {
      m_prefix = "CSM_V1_";
      ArrayResize(m_tradeTapeText, 0);
      ArrayResize(m_tradeTapeColor, 0);
      m_showStateHeader = false;
      m_showSyncTelemetry = false;
      m_showIndicatorValues = false;
      m_showConditionRules = true;
      m_showTradeTape = true;
   }

   void ConfigureSections(const bool showStateHeader,
                          const bool showSyncTelemetry,
                          const bool showIndicatorValues,
                          const bool showConditionRules,
                          const bool showTradeTape)
   {
      m_showStateHeader = showStateHeader;
      m_showSyncTelemetry = showSyncTelemetry;
      m_showIndicatorValues = showIndicatorValues;
      m_showConditionRules = showConditionRules;
      m_showTradeTape = showTradeTape;
   }

   void PushTradeTape(const string text, const color clr)
   {
      if(text == "")
         return;

      int n = ArraySize(m_tradeTapeText);
      if(n < TRADE_TAPE_MAX)
      {
         ArrayResize(m_tradeTapeText, n + 1);
         ArrayResize(m_tradeTapeColor, n + 1);
         m_tradeTapeText[n] = text;
         m_tradeTapeColor[n] = clr;
         return;
      }

      for(int i = 0; i < TRADE_TAPE_MAX - 1; i++)
      {
         m_tradeTapeText[i] = m_tradeTapeText[i + 1];
         m_tradeTapeColor[i] = m_tradeTapeColor[i + 1];
      }
      m_tradeTapeText[TRADE_TAPE_MAX - 1] = text;
      m_tradeTapeColor[TRADE_TAPE_MAX - 1] = clr;
   }

   void Render(const SRuntimeViewState &st)
   {
      int row = 0;
      int y = 12;
      int dy = 18;

      if(m_showStateHeader)
      {
         SetLabel("L" + IntegerToString(row++), y, StringFormat("CloseScale_ModularEA v1.001 | %s", st.strategyId), clrWhite, 10);
         y += dy;
         SetLabel("L" + IntegerToString(row++), y, StringFormat("Signal=%s | Pos=%d | BUY/SELL=%d/%d",
                                         st.signalText,
                                         st.positions,
                                         st.buySignals,
                                         st.sellSignals), clrWhite, 10);
         y += dy;
      }

      if(m_showSyncTelemetry)
      {
         bool b0Ok = (st.busReadRcBuf0 == 0 && st.busReadValidBuf0 == 1 && st.tickSeqReadBuf0 == st.tickSeqLocal);
         bool b2Ok = (st.busReadRcBuf2 == 0 && st.busReadValidBuf2 == 1 && st.tickSeqReadBuf2 == st.tickSeqLocal);
         bool b4Ok = (st.busReadRcBuf4 == 0 && st.busReadValidBuf4 == 1 && st.tickSeqReadBuf4 == st.tickSeqLocal);
         bool b5Ok = (st.busReadRcBuf5 == 0 && st.busReadValidBuf5 == 1 && st.tickSeqReadBuf5 == st.tickSeqLocal);
         bool syncOk = (st.busOnline && st.busLastRc == 0 && b0Ok && b2Ok && b4Ok && b5Ok);
         color syncClr = (syncOk ? clrLime : clrOrangeRed);
         SetLabel("L" + IntegerToString(row++), y,
                  StringFormat("bus_last_rc=%d | tick_seq_local=%I64d | bus_online=%s",
                               st.busLastRc,
                               st.tickSeqLocal,
                               BoolText(st.busOnline)),
                  syncClr, 9);
         y += dy;
         SetLabel("L" + IntegerToString(row++), y,
                  StringFormat("tick_seq_lido: b0=%I64d(rc=%d,v=%d) b2=%I64d(rc=%d,v=%d) b4=%I64d(rc=%d,v=%d) b5=%I64d(rc=%d,v=%d)",
                               st.tickSeqReadBuf0, st.busReadRcBuf0, st.busReadValidBuf0,
                               st.tickSeqReadBuf2, st.busReadRcBuf2, st.busReadValidBuf2,
                               st.tickSeqReadBuf4, st.busReadRcBuf4, st.busReadValidBuf4,
                               st.tickSeqReadBuf5, st.busReadRcBuf5, st.busReadValidBuf5),
                  syncClr, 9);
         y += dy;
      }

      if(m_showIndicatorValues)
      {
         SetLabel("L" + IntegerToString(row++), y, StringFormat("ind1_buf0 (BridgeFeed1)   = %s", PairText(st.waveCurr, st.wavePrev, 6)), clrDeepSkyBlue, 9);
         y += dy;
         SetLabel("L" + IntegerToString(row++), y, StringFormat("ind1_buf1 (BridgeFeed2)   = %s", PairText(st.feed2Curr, st.feed2Prev, 6)), clrDeepSkyBlue, 9);
         y += dy;
         SetLabel("L" + IntegerToString(row++), y, StringFormat("ind1_buf2 (BridgeBBUpper) = %s", PairText(st.bandUpCurr, st.bandUpPrev, 6)), clrDeepSkyBlue, 9);
         y += dy;
         SetLabel("L" + IntegerToString(row++), y, StringFormat("ind1_buf3 (BridgeBBMiddle)= %s", PairText(st.bandMidCurr, st.bandMidPrev, 6)), clrDeepSkyBlue, 9);
         y += dy;
         SetLabel("L" + IntegerToString(row++), y, StringFormat("ind1_buf4 (BridgeBBLower) = %s", PairText(st.bandDnCurr, st.bandDnPrev, 6)), clrDeepSkyBlue, 9);
         y += dy;
         SetLabel("L" + IntegerToString(row++), y, StringFormat("ind1_buf5 (BridgeZero)    = %s", PairText(st.zeroCurr, st.zeroPrev, 6)), clrDeepSkyBlue, 9);
         y += dy;
      }

      if(m_showConditionRules)
      {
         SetLabel("L" + IntegerToString(row++), y, StringFormat("exec.bb_cross_buy       (closescale.exec_buy_bb_cross)      = %s", BoolText(st.condBuyCross)), BoolColor(st.condBuyCross), 9);
         y += dy;
         SetLabel("L" + IntegerToString(row++), y, StringFormat("exec.bb_cross_sell      (closescale.exec_sell_bb_cross)     = %s", BoolText(st.condSellCross)), BoolColor(st.condSellCross), 9);
         y += dy;
         SetLabel("L" + IntegerToString(row++), y, StringFormat("auth.above_zero         (closescale.auth_above_zero)        = %s", BoolText(st.condBuyZero)), BoolColor(st.condBuyZero), 9);
         y += dy;
         SetLabel("L" + IntegerToString(row++), y, StringFormat("auth.below_zero         (closescale.auth_below_zero)        = %s", BoolText(st.condSellZero)), BoolColor(st.condSellZero), 9);
         y += dy;
         SetLabel("L" + IntegerToString(row++), y, StringFormat("zero.cross_up           (prev<=zero_prev && curr>zero)     = %s", BoolText(st.condBuyZeroCross)), BoolColor(st.condBuyZeroCross), 9);
         y += dy;
         SetLabel("L" + IntegerToString(row++), y, StringFormat("zero.cross_dn           (prev>=zero_prev && curr<zero)     = %s", BoolText(st.condSellZeroCross)), BoolColor(st.condSellZeroCross), 9);
         y += dy;
         SetLabel("L" + IntegerToString(row++), y, StringFormat("regime.bull_trend       (wave>bb_up && wave>zero)           = %s", BoolText(st.regimeTrendBull)), BoolColor(st.regimeTrendBull), 9);
         y += dy;
         SetLabel("L" + IntegerToString(row++), y, StringFormat("regime.bull_counter     (wave<bb_dn && wave>zero)           = %s", BoolText(st.regimeCounterBull)), BoolColor(st.regimeCounterBull), 9);
         y += dy;
         SetLabel("L" + IntegerToString(row++), y, StringFormat("regime.bear_trend       (wave<bb_dn && wave<zero)           = %s", BoolText(st.regimeTrendBear)), BoolColor(st.regimeTrendBear), 9);
         y += dy;
         SetLabel("L" + IntegerToString(row++), y, StringFormat("regime.bear_counter     (wave>bb_up && wave<zero)           = %s", BoolText(st.regimeCounterBear)), BoolColor(st.regimeCounterBear), 9);
         y += dy;

         if(st.useEffortAuth)
         {
            SetLabel("L" + IntegerToString(row++), y, StringFormat("buy.effort (ind2_buf0 > ind2_buf1)  = %s", BoolText(st.condBuyEffort)), BoolColor(st.condBuyEffort), 9);
            y += dy;
            SetLabel("L" + IntegerToString(row++), y, StringFormat("sell.effort(ind2_buf0 > ind2_buf1)  = %s", BoolText(st.condSellEffort)), BoolColor(st.condSellEffort), 9);
            y += dy;
         }

         if(st.useMfiAuth)
         {
            SetLabel("L" + IntegerToString(row++), y, StringFormat("buy.mfi (ind3_buf0 <= ind3_buf3) = %s", BoolText(st.condBuyMfi)), BoolColor(st.condBuyMfi), 9);
            y += dy;
            SetLabel("L" + IntegerToString(row++), y, StringFormat("sell.mfi(ind3_buf0 >= ind3_buf4) = %s", BoolText(st.condSellMfi)), BoolColor(st.condSellMfi), 9);
            y += dy;
         }
      }

      if(m_showTradeTape)
      {
         int tapeCount = ArraySize(m_tradeTapeText);
         if(tapeCount > 0)
         {
            SetLabel("T_HDR", y, "Trades:", clrWhite, 10);
            y += dy;
         }
         for(int i = 0; i < tapeCount; i++)
         {
            int idx = tapeCount - 1 - i; // mais recente primeiro
            SetLabel("T" + IntegerToString(i), y, m_tradeTapeText[idx], m_tradeTapeColor[idx], 10);
            y += dy;
         }
         for(int i = tapeCount; i < TRADE_TAPE_MAX; i++)
         {
            string n = ObjName("T" + IntegerToString(i));
            if(ObjectFind(0, n) >= 0)
               ObjectDelete(0, n);
         }
         string h = ObjName("T_HDR");
         if(tapeCount <= 0 && ObjectFind(0, h) >= 0)
            ObjectDelete(0, h);
      }
      else
      {
         for(int i = 0; i < TRADE_TAPE_MAX; i++)
         {
            string n = ObjName("T" + IntegerToString(i));
            if(ObjectFind(0, n) >= 0)
               ObjectDelete(0, n);
         }
         string h = ObjName("T_HDR");
         if(ObjectFind(0, h) >= 0)
            ObjectDelete(0, h);
      }

      for(int i = row; i <= 64; i++)
      {
         string n = ObjName("L" + IntegerToString(i));
         if(ObjectFind(0, n) >= 0)
            ObjectDelete(0, n);
      }
   }

   bool AttachIndicators(const long chartId,
                         const CIndicatorModule &indicators,
                         const bool &attachSlots[],
                         string &err) const
   {
      err = "";
      bool allOk = true;

      // Sempre limpa indicadores registrados para evitar sobras quando a lista
      // de indicadores selecionados muda entre execucoes.
      RemoveAllRegisteredIndicators(chartId, indicators);

      int enabledSlots[];
      ArrayResize(enabledSlots, 0);
      for(int s = 0; s < ArraySize(attachSlots); s++)
      {
         if(!attachSlots[s])
            continue;
         int nSlots = ArraySize(enabledSlots);
         ArrayResize(enabledSlots, nSlots + 1);
         enabledSlots[nSlots] = s + 1; // subwindow absoluto (1..N)
      }

      int total = indicators.Count();
      int slotCursor = 0;
      for(int i = 0; i < total; i++)
      {
         string id = "";
         int handle = INVALID_HANDLE;
         string hints[];
         if(!indicators.GetChartAttachMeta(i, id, handle, hints))
            continue;

         RemoveByHints(chartId, hints);

         if(slotCursor >= ArraySize(enabledSlots))
            continue;

         if(handle == INVALID_HANDLE)
         {
            allOk = false;
            err = StringFormat("%s%s[%s] handle invalido para attach",
                               err,
                               (err == "" ? "" : " | "),
                               (id == "" ? "indicator" : id));
            continue;
         }

         int windows = (int)ChartGetInteger(chartId, CHART_WINDOWS_TOTAL);
         int targetSubwindow = enabledSlots[slotCursor++];
         if(targetSubwindow < 1 || targetSubwindow > windows)
            targetSubwindow = windows;

         ResetLastError();
         if(!ChartIndicatorAdd(chartId, targetSubwindow, handle))
         {
            allOk = false;
            int le = (int)GetLastError();
            err = StringFormat("%s%s[%s] ChartIndicatorAdd falhou (err=%d)",
                               err,
                               (err == "" ? "" : " | "),
                               (id == "" ? "indicator" : id),
                               le);
            continue;
         }

         EnsureSingleByHandle(chartId, handle);
      }

      return(allOk);
   }

   int DetachIndicators(const long chartId,
                        const CIndicatorModule &indicators) const
   {
      return(RemoveAllRegisteredIndicators(chartId, indicators));
   }

   void Clear()
   {
      for(int i = 0; i <= 48; i++)
      {
         string n = ObjName("L" + IntegerToString(i));
         if(ObjectFind(0, n) >= 0)
            ObjectDelete(0, n);
      }
      for(int i = 0; i < TRADE_TAPE_MAX; i++)
      {
         string n = ObjName("T" + IntegerToString(i));
         if(ObjectFind(0, n) >= 0)
            ObjectDelete(0, n);
      }
      string h = ObjName("T_HDR");
      if(ObjectFind(0, h) >= 0)
         ObjectDelete(0, h);
      ArrayResize(m_tradeTapeText, 0);
      ArrayResize(m_tradeTapeColor, 0);
   }
};

#endif
