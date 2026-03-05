#ifndef __CSM_INDICATOR_CLOSESCALE_FORECAST_FEED_MQH__
#define __CSM_INDICATOR_CLOSESCALE_FORECAST_FEED_MQH__

#include "..\\..\\Contracts\\Interfaces.mqh"
#include "PluginDefaults.mqh"

class CIndicatorPlugin_CloseScaleForecastFeed : public IIndicatorPlugin
{
private:
   int m_handle;
   int m_maLongHandle;
   int m_maShortHandle;
   int m_lastLevelCount;

   enum
   {
      DEF_LONG_PERIOD = 65,
      DEF_SHORT_PERIOD = 7,
      DEF_MA_METHOD = MODE_LWMA,
      DEF_MA_PRICE = PRICE_CLOSE
   };

   bool IsUsableBufferValue(const double v) const
   {
      if(!MathIsValidNumber(v))
         return(false);
      if(v == EMPTY_VALUE)
         return(false);
      // EMPTY_VALUE em alguns cenarios chega como ~DBL_MAX.
      if(MathAbs(v) >= (DBL_MAX * 0.5))
         return(false);
      return(true);
   }

   bool ReadValueAtShift(const int bufferIdx, const int shift, double &out, string &err) const
   {
      err = "";
      out = 0.0;

      double tmp[1];
      ResetLastError();
      int copied = CopyBuffer(m_handle, bufferIdx, shift, 1, tmp);
      if(copied < 1)
      {
         int le = (int)GetLastError();
         err = StringFormat("CopyBuffer insuficiente no buffer=%d shift=%d (err=%d)", bufferIdx, shift, le);
         return(false);
      }
      out = tmp[0];
      return(true);
   }

   bool ReadPairAtShift(const int bufferIdx,
                        const int currShift,
                        const int prevShift,
                        double &curr,
                        double &prev,
                        string &err) const
   {
      err = "";
      curr = 0.0;
      prev = 0.0;
      if(currShift < 0 || prevShift <= currShift)
      {
         err = StringFormat("shifts invalidos curr=%d prev=%d", currShift, prevShift);
         return(false);
      }

      string oneErr = "";
      if(prevShift == (currShift + 1))
      {
         double pair[2];
         ResetLastError();
         int copied = CopyBuffer(m_handle, bufferIdx, currShift, 2, pair);
         if(copied < 2)
         {
            int le = (int)GetLastError();
            err = StringFormat("CopyBuffer insuficiente no buffer=%d shift=%d count=2 (copied=%d err=%d)",
                               bufferIdx, currShift, copied, le);
            return(false);
         }
         curr = pair[0];
         prev = pair[1];
      }
      else
      {
         if(!ReadValueAtShift(bufferIdx, currShift, curr, oneErr))
         {
            err = oneErr;
            return(false);
         }
         if(!ReadValueAtShift(bufferIdx, prevShift, prev, oneErr))
         {
            err = oneErr;
            return(false);
         }
      }
      return(true);
   }

   bool ReadWindowAtShift(const int currShift,
                          const int prevShift,
                          double &waveCurr,
                          double &wavePrev,
                          double &feed2Curr,
                          double &feed2Prev,
                          double &upCurr,
                          double &upPrev,
                          double &midCurr,
                          double &midPrev,
                          double &dnCurr,
                          double &dnPrev,
                          double &zeroCurr,
                          double &zeroPrev,
                          string &err) const
   {
      err = "";
      string oneErr = "";
      if(!ReadPairAtShift(0, currShift, prevShift, waveCurr, wavePrev, oneErr))
      {
         err = StringFormat("wave(shift=%d/%d): %s", currShift, prevShift, oneErr);
         return(false);
      }
      if(!ReadPairAtShift(1, currShift, prevShift, feed2Curr, feed2Prev, oneErr))
      {
         err = StringFormat("feed2(shift=%d/%d): %s", currShift, prevShift, oneErr);
         return(false);
      }
      if(!ReadPairAtShift(2, currShift, prevShift, upCurr, upPrev, oneErr))
      {
         err = StringFormat("band_up(shift=%d/%d): %s", currShift, prevShift, oneErr);
         return(false);
      }
      if(!ReadPairAtShift(3, currShift, prevShift, midCurr, midPrev, oneErr))
      {
         err = StringFormat("band_mid(shift=%d/%d): %s", currShift, prevShift, oneErr);
         return(false);
      }
      if(!ReadPairAtShift(4, currShift, prevShift, dnCurr, dnPrev, oneErr))
      {
         err = StringFormat("band_dn(shift=%d/%d): %s", currShift, prevShift, oneErr);
         return(false);
      }
      if(!ReadPairAtShift(5, currShift, prevShift, zeroCurr, zeroPrev, oneErr))
      {
         err = StringFormat("zero(shift=%d/%d): %s", currShift, prevShift, oneErr);
         return(false);
      }
      return(true);
   }

   bool FindSynchronizedShift(const int &bufferIdxs[],
                              const int bufferCount,
                              int &outCurrShift,
                              int &outPrevShift,
                              string &err) const
   {
      err = "";
      outCurrShift = -1;
      outPrevShift = -1;
      const int maxProbeShift = 16;

      for(int s = 0; s < maxProbeShift; s++)
      {
         bool allOk = true;
         for(int i = 0; i < bufferCount; i++)
         {
            double c = 0.0, p = 0.0;
            string oneErr = "";
            if(!ReadPairAtShift(bufferIdxs[i], s, s + 1, c, p, oneErr))
            {
               allOk = false;
               break;
            }
         }
         if(allOk)
         {
            outCurrShift = s;
            outPrevShift = s + 1;
            return(true);
         }
      }

      err = "nenhuma janela sincronizada com valores validos (buffers com EMPTY_VALUE)";
      return(false);
   }

   bool IsHandleReady(const int handle, const int minBars, string &err) const
   {
      err = "";
      if(handle == INVALID_HANDLE)
      {
         err = "handle invalido";
         return(false);
      }

      int bc = BarsCalculated(handle);
      if(bc <= 0)
      {
         err = StringFormat("BarsCalculated<=0 (bc=%d)", bc);
         return(false);
      }
      if(bc < minBars)
      {
         err = StringFormat("BarsCalculated insuficiente (bc=%d need=%d)", bc, minBars);
         return(false);
      }
      return(true);
   }

   void ReleaseHandles()
   {
      if(m_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle);
         m_handle = INVALID_HANDLE;
      }
      if(m_maLongHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_maLongHandle);
         m_maLongHandle = INVALID_HANDLE;
      }
      if(m_maShortHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_maShortHandle);
         m_maShortHandle = INVALID_HANDLE;
      }
   }

   bool EnsureMaHandles(string &err)
   {
      err = "";
      if(m_maLongHandle == INVALID_HANDLE)
         m_maLongHandle = iMA(_Symbol, _Period, DEF_LONG_PERIOD, 0, (ENUM_MA_METHOD)DEF_MA_METHOD, (ENUM_APPLIED_PRICE)DEF_MA_PRICE);
      if(m_maShortHandle == INVALID_HANDLE)
         m_maShortHandle = iMA(_Symbol, _Period, DEF_SHORT_PERIOD, 0, (ENUM_MA_METHOD)DEF_MA_METHOD, (ENUM_APPLIED_PRICE)DEF_MA_PRICE);

      if(m_maLongHandle == INVALID_HANDLE)
      {
         err = "falha handle MA longa";
         return(false);
      }
      if(m_maShortHandle == INVALID_HANDLE)
      {
         err = "falha handle MA curta";
         return(false);
      }
      return(true);
   }

   bool ReadLongShortMa(double &maLong, double &maShort, string &err)
   {
      maLong = 0.0;
      maShort = 0.0;
      err = "";

      if(!EnsureMaHandles(err))
         return(false);

      if(!IsHandleReady(m_maLongHandle, 1, err))
      {
         err = StringFormat("MA longa nao pronta: %s", err);
         return(false);
      }
      if(!IsHandleReady(m_maShortHandle, 1, err))
      {
         err = StringFormat("MA curta nao pronta: %s", err);
         return(false);
      }

      double l[1], s[1];
      ResetLastError();
      int cl = CopyBuffer(m_maLongHandle, 0, 0, 1, l);
      int leL = (int)GetLastError();
      ResetLastError();
      int cs = CopyBuffer(m_maShortHandle, 0, 0, 1, s);
      int leS = (int)GetLastError();
      if(cl < 1 || !MathIsValidNumber(l[0]) || l[0] <= 0.0)
      {
         err = StringFormat("falha leitura MA longa (copied=%d err=%d)", cl, leL);
         return(false);
      }
      if(cs < 1 || !MathIsValidNumber(s[0]) || s[0] <= 0.0)
      {
         err = StringFormat("falha leitura MA curta (copied=%d err=%d)", cs, leS);
         return(false);
      }

      maLong = l[0];
      maShort = s[0];
      return(true);
   }

   bool ParsePositiveLevels(double &outLevels[], string &err) const
   {
      err = "";
      ArrayResize(outLevels, 0);
      string src = CSM_CLOSESCALE_DEFAULT_LEVELS;

      string tokens[];
      ushort sep = (ushort)(StringFind(src, ";") >= 0 ? ';' : ',');
      int n = StringSplit(src, sep, tokens);
      if(n <= 0)
      {
         err = "sem tokens de niveis";
         return(false);
      }

      for(int i = 0; i < n; i++)
      {
         string t = tokens[i];
         StringTrimLeft(t);
         StringTrimRight(t);
         if(t == "")
            continue;

         StringReplace(t, ",", ".");
         double v = MathAbs(StringToDouble(t));
         if(!MathIsValidNumber(v) || v <= 0.0)
            continue;
         if(v > 1.0)
            v /= 100.0;

         bool exists = false;
         int sz = ArraySize(outLevels);
         for(int j = 0; j < sz; j++)
         {
            if(MathAbs(outLevels[j] - v) <= 1e-12)
            {
               exists = true;
               break;
            }
         }
         if(!exists)
         {
            ArrayResize(outLevels, sz + 1);
            outLevels[sz] = v;
         }
      }

      if(ArraySize(outLevels) <= 0)
      {
         err = "nenhum nivel positivo valido";
         return(false);
      }
      ArraySort(outLevels);
      return(true);
   }

   double PercentToScale(const double pctPoints) const
   {
      return(pctPoints / 0.10);
   }

   bool BuildScaledLevels(double &levelsScaled[], string &err) const
   {
      err = "";
      ArrayResize(levelsScaled, 0);

      double pos[];
      if(!ParsePositiveLevels(pos, err))
         return(false);

      int posCount = ArraySize(pos);
      int total = posCount * 2 + 1;
      ArrayResize(levelsScaled, total);

      int idx = 0;
      for(int i = posCount - 1; i >= 0; --i)
         levelsScaled[idx++] = -PercentToScale(pos[i]);
      levelsScaled[idx++] = 0.0;
      for(int i = 0; i < posCount; ++i)
         levelsScaled[idx++] = PercentToScale(pos[i]);
      return(true);
   }

   bool ScaleLevelToPrice(const double levelScaled,
                          const double maLong,
                          const double maShort,
                          double &outPrice,
                          string &err) const
   {
      err = "";
      outPrice = 0.0;

      if(!MathIsValidNumber(levelScaled) ||
         !MathIsValidNumber(maLong) || maLong <= 0.0 ||
         !MathIsValidNumber(maShort) || maShort <= 0.0)
      {
         err = "dados invalidos na conversao de nivel";
         return(false);
      }

      double refPct = (maShort - maLong) / MathAbs(maLong) * 100.0;
      double refScaled = PercentToScale(refPct);
      if(!MathIsValidNumber(refScaled) || MathAbs(refScaled) <= 1e-12)
      {
         err = "refScaled invalido (maShort~maLong)";
         return(false);
      }

      double price = maLong + (levelScaled / refScaled) * (maShort - maLong);
      if(!MathIsValidNumber(price) || price <= 0.0)
      {
         err = "preco convertido invalido";
         return(false);
      }

      outPrice = price;
      return(true);
   }

   void UpsertLevelKeys(CIndicatorSnapshot &snapshot,
                        const double &levelsScaled[],
                        const double &levelsPrice[])
   {
      int n = ArraySize(levelsScaled);
      snapshot.Upsert("forecast.level.count", (double)n, (double)n, true);
      for(int i = 0; i < n; i++)
      {
         string keyS = StringFormat("forecast.level.scaled.%d", i);
         string keyP = StringFormat("forecast.level.price.%d", i);
         snapshot.Upsert(keyS, levelsScaled[i], levelsScaled[i], true);
         snapshot.Upsert(keyP, levelsPrice[i], levelsPrice[i], true);
      }

      if(m_lastLevelCount > n)
      {
         for(int i = n; i < m_lastLevelCount; i++)
         {
            string keyS = StringFormat("forecast.level.scaled.%d", i);
            string keyP = StringFormat("forecast.level.price.%d", i);
            snapshot.Upsert(keyS, 0.0, 0.0, false);
            snapshot.Upsert(keyP, 0.0, 0.0, false);
         }
      }

      m_lastLevelCount = n;
   }

   bool ExtractAnchorPrices(const double &levelsScaled[],
                            const double &levelsPrice[],
                            double &zeroPrice,
                            double &up1Price,
                            double &dn1Price,
                            string &err) const
   {
      err = "";
      zeroPrice = 0.0;
      up1Price = 0.0;
      dn1Price = 0.0;

      int n = ArraySize(levelsScaled);
      if(n <= 2 || ArraySize(levelsPrice) != n)
      {
         err = "niveis insuficientes para anchor";
         return(false);
      }

      int zeroIdx = -1;
      for(int i = 0; i < n; i++)
      {
         if(MathAbs(levelsScaled[i]) <= 1e-10)
         {
            zeroIdx = i;
            break;
         }
      }
      if(zeroIdx <= 0 || zeroIdx >= (n - 1))
      {
         err = "zero index invalido para anchor";
         return(false);
      }

      zeroPrice = levelsPrice[zeroIdx];
      up1Price = levelsPrice[zeroIdx + 1];
      dn1Price = levelsPrice[zeroIdx - 1];
      if(!MathIsValidNumber(zeroPrice) || !MathIsValidNumber(up1Price) || !MathIsValidNumber(dn1Price) ||
         zeroPrice <= 0.0 || up1Price <= 0.0 || dn1Price <= 0.0)
      {
         err = "anchor prices invalidos";
         return(false);
      }
      if(!(up1Price > zeroPrice && zeroPrice > dn1Price))
      {
         err = "anchor ordering invalido";
         return(false);
      }

      return(true);
   }

public:
   CIndicatorPlugin_CloseScaleForecastFeed()
   {
      m_handle = INVALID_HANDLE;
      m_maLongHandle = INVALID_HANDLE;
      m_maShortHandle = INVALID_HANDLE;
      m_lastLevelCount = 0;
   }

   virtual string Id()
   {
      return("CloseScaleForecastFeed");
   }

   virtual int PrimaryHandle() const
   {
      return(m_handle);
   }

   virtual void ChartAttachHints(string &hints[]) const
   {
      ArrayResize(hints, 2);
      hints[0] = "CloseScaleV6Bridge";
      hints[1] = "CloseScale_v6_Bridge";
   }

   virtual bool Init(string &err)
   {
      err = "";

      m_handle = iCustom(_Symbol,
                         _Period,
                         CSM_BRIDGE_CLOSESCALE_PATH);

      if(m_handle == INVALID_HANDLE)
      {
         err = "falha ao criar iCustom para CloseScale_v6_Bridge";
         return(false);
      }

      return(true);
   }

   virtual void Deinit()
   {
      ReleaseHandles();
      m_lastLevelCount = 0;
   }

   virtual bool Update(CIndicatorSnapshot &snapshot, string &err)
   {
      err = "";
      if(m_handle == INVALID_HANDLE)
      {
         err = "plugin CloseScaleForecastFeed nao inicializado";
         return(false);
      }

      if(!IsHandleReady(m_handle, 3, err))
      {
         err = StringFormat("CloseScale bridge nao pronto: %s", err);
         return(false);
      }

      double waveCurr = 0.0, wavePrev = 0.0;
      double feed2Curr = 0.0, feed2Prev = 0.0;
      double upCurr = 0.0, upPrev = 0.0;
      double midCurr = 0.0, midPrev = 0.0;
      double dnCurr = 0.0, dnPrev = 0.0;
      double zeroCurr = 0.0, zeroPrev = 0.0;

      string oneErr = "";
      int currShift = 0;
      int prevShift = 1;
      if(!ReadWindowAtShift(currShift, prevShift,
                            waveCurr, wavePrev,
                            feed2Curr, feed2Prev,
                            upCurr, upPrev,
                            midCurr, midPrev,
                            dnCurr, dnPrev,
                            zeroCurr, zeroPrev,
                            oneErr))
      {
         err = oneErr;
         return(false);
      }

      bool waveValid = (IsUsableBufferValue(waveCurr) && IsUsableBufferValue(wavePrev));
      bool feed2Valid = (IsUsableBufferValue(feed2Curr) && IsUsableBufferValue(feed2Prev));
      bool upValid = (IsUsableBufferValue(upCurr) && IsUsableBufferValue(upPrev));
      bool midValid = (IsUsableBufferValue(midCurr) && IsUsableBufferValue(midPrev));
      bool dnValid = (IsUsableBufferValue(dnCurr) && IsUsableBufferValue(dnPrev));
      bool zeroValid = (IsUsableBufferValue(zeroCurr) && IsUsableBufferValue(zeroPrev));

      if(!waveValid)
      {
         waveCurr = 0.0;
         wavePrev = 0.0;
      }
      if(!feed2Valid)
      {
         feed2Curr = 0.0;
         feed2Prev = 0.0;
      }
      if(!upValid)
      {
         upCurr = 0.0;
         upPrev = 0.0;
      }
      if(!midValid)
      {
         midCurr = 0.0;
         midPrev = 0.0;
      }
      if(!dnValid)
      {
         dnCurr = 0.0;
         dnPrev = 0.0;
      }
      if(!zeroValid)
      {
         zeroCurr = 0.0;
         zeroPrev = 0.0;
      }

      bool signalInputsValid = (waveValid && upValid && midValid && dnValid && zeroValid);

      double bandTopCurr = 0.0, bandTopPrev = 0.0, bandBotCurr = 0.0, bandBotPrev = 0.0;
      bool crossPackUp = false;
      bool crossPackDn = false;
      if(signalInputsValid)
      {
         bandTopCurr = MathMax(upCurr, MathMax(midCurr, dnCurr));
         bandTopPrev = MathMax(upPrev, MathMax(midPrev, dnPrev));
         bandBotCurr = MathMin(upCurr, MathMin(midCurr, dnCurr));
         bandBotPrev = MathMin(upPrev, MathMin(midPrev, dnPrev));

         // BUY: Feed1 sai de baixo de todas as 3 bandas e fecha acima de todas.
         crossPackUp = (wavePrev <= bandBotPrev && waveCurr > bandTopCurr);
         // SELL: Feed1 sai de cima de todas as 3 bandas e fecha abaixo de todas.
         crossPackDn = (wavePrev >= bandTopPrev && waveCurr < bandBotCurr);
      }

      double buyTrigger = (crossPackUp ? 1.0 : 0.0);
      double sellTrigger = (crossPackDn ? 1.0 : 0.0);
      double waveAboveUpper = (waveCurr > upCurr ? 1.0 : 0.0);
      double waveBelowLower = (waveCurr < dnCurr ? 1.0 : 0.0);
      double waveAboveZero = (waveCurr > zeroCurr ? 1.0 : 0.0);
      double waveBelowZero = (waveCurr < zeroCurr ? 1.0 : 0.0);
      double waveRising = ((waveValid && waveCurr > wavePrev) ? 1.0 : 0.0);
      double waveFalling = ((waveValid && waveCurr < wavePrev) ? 1.0 : 0.0);

      snapshot.Upsert("feed.fast", waveCurr, wavePrev, waveValid);
      snapshot.Upsert("feed.slow", midCurr, midPrev, midValid);
      snapshot.Upsert("const.zero", zeroCurr, zeroPrev, zeroValid);

      snapshot.Upsert("forecast.wave", waveCurr, wavePrev, waveValid);
      snapshot.Upsert("forecast.feed2", feed2Curr, feed2Prev, feed2Valid);
      snapshot.Upsert("forecast.band_up", upCurr, upPrev, upValid);
      snapshot.Upsert("forecast.band_dn", dnCurr, dnPrev, dnValid);
      snapshot.Upsert("forecast.band_mid", midCurr, midPrev, midValid);
      snapshot.Upsert("ind1_buf0", waveCurr, wavePrev, waveValid);
      snapshot.Upsert("ind1_buf1", feed2Curr, feed2Prev, feed2Valid);
      snapshot.Upsert("ind1_buf2", upCurr, upPrev, upValid);
      snapshot.Upsert("ind1_buf3", midCurr, midPrev, midValid);
      snapshot.Upsert("ind1_buf4", dnCurr, dnPrev, dnValid);
      snapshot.Upsert("ind1_buf5", zeroCurr, zeroPrev, zeroValid);
      snapshot.Upsert("closescale.buy_trigger", buyTrigger, buyTrigger, signalInputsValid);
      snapshot.Upsert("closescale.sell_trigger", sellTrigger, sellTrigger, signalInputsValid);
      snapshot.Upsert("closescale.wave_above_upper", waveAboveUpper, waveAboveUpper, signalInputsValid);
      snapshot.Upsert("closescale.wave_below_lower", waveBelowLower, waveBelowLower, signalInputsValid);
      snapshot.Upsert("closescale.wave_above_zero", waveAboveZero, waveAboveZero, waveValid);
      snapshot.Upsert("closescale.wave_below_zero", waveBelowZero, waveBelowZero, waveValid);
      snapshot.Upsert("closescale.cross_pack_up", buyTrigger, buyTrigger, signalInputsValid);
      snapshot.Upsert("closescale.cross_pack_dn", sellTrigger, sellTrigger, signalInputsValid);
      snapshot.Upsert("forecast.band_top", bandTopCurr, bandTopPrev, signalInputsValid);
      snapshot.Upsert("forecast.band_bot", bandBotCurr, bandBotPrev, signalInputsValid);
      snapshot.Upsert("forecast.wave_rising", waveRising, waveRising, waveValid);
      snapshot.Upsert("forecast.wave_falling", waveFalling, waveFalling, waveValid);
      snapshot.Upsert("signal.buy_trigger", buyTrigger, buyTrigger, signalInputsValid);
      snapshot.Upsert("signal.sell_trigger", sellTrigger, sellTrigger, signalInputsValid);
      snapshot.Upsert("forecast.read_shift", (double)currShift, (double)currShift, true);
      snapshot.Upsert("forecast.read_prev_shift", (double)prevShift, (double)prevShift, true);
      snapshot.Upsert("forecast.read_fallback_used", 0.0, 0.0, true);
      snapshot.Upsert("signal.bias_hint_side", (waveCurr > 0.0 ? 1.0 : (waveCurr < 0.0 ? -1.0 : 0.0)),
                      (wavePrev > 0.0 ? 1.0 : (wavePrev < 0.0 ? -1.0 : 0.0)), waveValid);
      snapshot.Upsert("signal.bias_hint_strength", (crossPackUp || crossPackDn ? 1.0 : 0.0), (crossPackUp || crossPackDn ? 1.0 : 0.0), signalInputsValid);

      // Campos derivados por mapeamento para preco (nao bloqueiam o modulo).
      snapshot.Upsert("forecast.ma_long_price", 0.0, 0.0, false);
      snapshot.Upsert("forecast.ma_short_price", 0.0, 0.0, false);
      snapshot.Upsert("anchor.zero_price", 0.0, 0.0, false);
      snapshot.Upsert("anchor.up_1_price", 0.0, 0.0, false);
      snapshot.Upsert("anchor.dn_1_price", 0.0, 0.0, false);
      snapshot.Upsert("anchor.available", 0.0, 0.0, false);
      snapshot.Upsert("forecast.band_up_price", 0.0, 0.0, false);
      snapshot.Upsert("forecast.band_mid_price", 0.0, 0.0, false);
      snapshot.Upsert("forecast.band_dn_price", 0.0, 0.0, false);

      double maLong = 0.0;
      double maShort = 0.0;
      if(!ReadLongShortMa(maLong, maShort, oneErr))
      {
         return(true);
      }

      snapshot.Upsert("forecast.ma_long_price", maLong, maLong, true);
      snapshot.Upsert("forecast.ma_short_price", maShort, maShort, true);

      double levelsScaled[];
      if(!BuildScaledLevels(levelsScaled, oneErr))
      {
         return(true);
      }

      int n = ArraySize(levelsScaled);
      double levelsPrice[];
      ArrayResize(levelsPrice, n);
      for(int i = 0; i < n; i++)
      {
         double px = 0.0;
         if(!ScaleLevelToPrice(levelsScaled[i], maLong, maShort, px, oneErr))
         {
            return(true);
         }
         levelsPrice[i] = px;
      }
      UpsertLevelKeys(snapshot, levelsScaled, levelsPrice);

      double zeroPrice = 0.0;
      double up1Price = 0.0;
      double dn1Price = 0.0;
      if(!ExtractAnchorPrices(levelsScaled, levelsPrice, zeroPrice, up1Price, dn1Price, oneErr))
      {
         return(true);
      }
      snapshot.Upsert("anchor.zero_price", zeroPrice, zeroPrice, true);
      snapshot.Upsert("anchor.up_1_price", up1Price, up1Price, true);
      snapshot.Upsert("anchor.dn_1_price", dn1Price, dn1Price, true);
      snapshot.Upsert("anchor.available", 1.0, 1.0, true);

      double upPrice = 0.0;
      double midPrice = 0.0;
      double dnPrice = 0.0;
      if(!ScaleLevelToPrice(upCurr, maLong, maShort, upPrice, oneErr))
      {
         return(true);
      }
      if(!ScaleLevelToPrice(midCurr, maLong, maShort, midPrice, oneErr))
      {
         return(true);
      }
      if(!ScaleLevelToPrice(dnCurr, maLong, maShort, dnPrice, oneErr))
      {
         return(true);
      }

      snapshot.Upsert("forecast.band_up_price", upPrice, upPrice, true);
      snapshot.Upsert("forecast.band_mid_price", midPrice, midPrice, true);
      snapshot.Upsert("forecast.band_dn_price", dnPrice, dnPrice, true);

      return(true);
   }
};

IIndicatorPlugin* CreateIndicatorPlugin_CloseScaleForecastFeed()
{
   return(new CIndicatorPlugin_CloseScaleForecastFeed());
}

#endif
