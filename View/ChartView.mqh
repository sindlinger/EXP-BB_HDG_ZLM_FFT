#ifndef __CSM_CHART_VIEW_MQH__
#define __CSM_CHART_VIEW_MQH__

#include "..\\Contracts\\CoreTypes.mqh"
#include "..\\Indicators\\IndicatorModule.mqh"

class CChartView
{
private:
   string m_prefix;

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
   }

   void Render(const SRuntimeViewState &st)
   {
      int row = 0;
      int y = 12;
      int dy = 18;

      SetLabel("L" + IntegerToString(row++), y, StringFormat("CloseScale_ModularEA v1.001 | %s", st.strategyId), clrWhite, 10);
      y += dy;

      SetLabel("L" + IntegerToString(row++), y, StringFormat("Signal=%s | Pos=%d | BUY/SELL=%d/%d",
                                      st.signalText,
                                      st.positions,
                                      st.buySignals,
                                      st.sellSignals), clrWhite, 10);
      y += dy;

      SetLabel("L" + IntegerToString(row++), y, st.buyExpr, (st.buyArmed ? clrLime : clrSilver), 9);
      y += dy;
      SetLabel("L" + IntegerToString(row++), y, st.sellExpr, (st.sellArmed ? clrTomato : clrSilver), 9);
      y += dy;

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
      SetLabel("L" + IntegerToString(row++), y, StringFormat("band_top (max 2|3|4)      = %s", PairText(st.bandTopCurr, st.bandTopPrev, 6)), clrDeepSkyBlue, 9);
      y += dy;
      SetLabel("L" + IntegerToString(row++), y, StringFormat("band_bot (min 2|3|4)      = %s", PairText(st.bandBotCurr, st.bandBotPrev, 6)), clrDeepSkyBlue, 9);
      y += dy;

      SetLabel("L" + IntegerToString(row++), y, StringFormat("buy.cross3 (prev<=band_bot && curr>band_top) = %s", BoolText(st.condBuyCross)), BoolColor(st.condBuyCross), 9);
      y += dy;
      SetLabel("L" + IntegerToString(row++), y, StringFormat("buy.start (ind1_buf0_prev <= band_bot_prev) = %s", BoolText(st.condBuyZero)), BoolColor(st.condBuyZero), 9);
      y += dy;
      SetLabel("L" + IntegerToString(row++), y, StringFormat("sell.cross3(prev>=band_top && curr<band_bot) = %s", BoolText(st.condSellCross)), BoolColor(st.condSellCross), 9);
      y += dy;
      SetLabel("L" + IntegerToString(row++), y, StringFormat("sell.start(ind1_buf0_prev >= band_top_prev) = %s", BoolText(st.condSellZero)), BoolColor(st.condSellZero), 9);
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

      for(int i = row; i <= 48; i++)
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

      int total = indicators.Count();
      for(int i = 0; i < total; i++)
      {
         string id = "";
         int handle = INVALID_HANDLE;
         string hints[];
         if(!indicators.GetChartAttachMeta(i, id, handle, hints))
            continue;

         RemoveByHints(chartId, hints);

         if(i < ArraySize(attachSlots) && !attachSlots[i])
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
         int targetSubwindow = i + 1;
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
      int removed = 0;
      int total = indicators.Count();
      for(int i = 0; i < total; i++)
      {
         string id = "";
         int handle = INVALID_HANDLE;
         string hints[];
         if(!indicators.GetChartAttachMeta(i, id, handle, hints))
            continue;
         removed += RemoveByHints(chartId, hints);
      }
      return(removed);
   }

   void Clear()
   {
      for(int i = 0; i <= 48; i++)
      {
         string n = ObjName("L" + IntegerToString(i));
         if(ObjectFind(0, n) >= 0)
            ObjectDelete(0, n);
      }
   }
};

#endif
