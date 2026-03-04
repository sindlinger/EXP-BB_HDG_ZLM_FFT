#ifndef __CSM_SNAPSHOT_MQH__
#define __CSM_SNAPSHOT_MQH__

class CIndicatorSnapshot
{
private:
   string m_keys[];
   double m_curr[];
   double m_prev[];
   bool   m_valid[];

   int FindIndex(const string key) const
   {
      int n = ArraySize(m_keys);
      for(int i = 0; i < n; i++)
      {
         if(m_keys[i] == key)
            return(i);
      }
      return(-1);
   }

public:
   datetime tickTime;

   void Clear()
   {
      ArrayResize(m_keys, 0);
      ArrayResize(m_curr, 0);
      ArrayResize(m_prev, 0);
      ArrayResize(m_valid, 0);
      tickTime = 0;
   }

   void Upsert(const string key, const double curr, const double prev, const bool valid)
   {
      int idx = FindIndex(key);
      if(idx < 0)
      {
         idx = ArraySize(m_keys);
         ArrayResize(m_keys, idx + 1);
         ArrayResize(m_curr, idx + 1);
         ArrayResize(m_prev, idx + 1);
         ArrayResize(m_valid, idx + 1);
         m_keys[idx] = key;
      }
      m_curr[idx] = curr;
      m_prev[idx] = prev;
      m_valid[idx] = valid;
   }

   bool Get(const string key, double &curr, double &prev) const
   {
      int idx = FindIndex(key);
      if(idx < 0)
         return(false);
      if(!m_valid[idx])
         return(false);
      curr = m_curr[idx];
      prev = m_prev[idx];
      return(MathIsValidNumber(curr) && MathIsValidNumber(prev));
   }

   int Count() const
   {
      return(ArraySize(m_keys));
   }
};

#endif
