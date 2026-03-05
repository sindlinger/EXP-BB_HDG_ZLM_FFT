#ifndef __CSM_STRATEGY_PARAMS_MQH__
#define __CSM_STRATEGY_PARAMS_MQH__

class CStrategyParamBag
{
private:
   string m_keys[];
   int    m_vals[];

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
   void Clear()
   {
      ArrayResize(m_keys, 0);
      ArrayResize(m_vals, 0);
   }

   void SetInt(const string key, const int value)
   {
      int idx = FindIndex(key);
      if(idx < 0)
      {
         idx = ArraySize(m_keys);
         ArrayResize(m_keys, idx + 1);
         ArrayResize(m_vals, idx + 1);
         m_keys[idx] = key;
      }
      m_vals[idx] = value;
   }

   bool GetInt(const string key, int &value) const
   {
      int idx = FindIndex(key);
      if(idx < 0)
         return(false);
      value = m_vals[idx];
      return(true);
   }
};

#endif
