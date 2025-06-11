//+------------------------------------------------------------------+
//|                                          VolatilityAdjuster.mqh  |
//|  Dynamic volatility adjustment system for IntegratedPA           |
//+------------------------------------------------------------------+
#ifndef VOLATILITYADJUSTER_MQH
#define VOLATILITYADJUSTER_MQH

#include "Logger.mqh"
#include "Indicators/IndicatorHandlePool.mqh"

//+------------------------------------------------------------------+
//| Simple thread lock using atomic operations                       |
//+------------------------------------------------------------------+
class CSimpleLock
{
private:
   int m_lock;
public:
   CSimpleLock() { m_lock = 0; }
   void Lock()   { while(AtomicCompareExchange(m_lock,1,0)!=0) Sleep(0); }
   void Unlock() { AtomicExchange(m_lock,0); }
};

//+------------------------------------------------------------------+
//| Class for ATR based volatility adjustments                       |
//+------------------------------------------------------------------+
class CVolatilityAdjuster
{
private:
   int          m_atrPeriod;                     // ATR lookback period
   int          m_baselinePeriod;                // Bars used to build baseline
   CHandlePool *m_handlePool;                    // Pool de handles para indicadores

   struct BaselineInfo
   {
      string symbol;
      double value;
   };
   BaselineInfo m_baselines[];               // Baselines by symbol
   CSimpleLock  m_lock;                      // Thread safety lock

   int  FindIndex(string symbol);

public:
   // Constructor
   CVolatilityAdjuster(CHandlePool *handlePool,int atrPeriod=14,int baselinePeriod=20);

   // Calculate factor based on current ATR versus baseline
   double CalculateVolatilityAdjustment(string symbol);

   // Recalculate baseline for a symbol
   void   UpdateBaseline(string symbol);

   // Get current ATR for symbol
   double GetCurrentATR(string symbol);

   // Retrieve stored baseline value
   double GetBaselineVolatility(string symbol);
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+

// Constructor
CVolatilityAdjuster::CVolatilityAdjuster(CHandlePool *handlePool,int atrPeriod,int baselinePeriod)
{
   m_handlePool     = handlePool;
   m_atrPeriod      = atrPeriod;
   m_baselinePeriod = baselinePeriod;
}

// Find index of symbol in baseline array
int CVolatilityAdjuster::FindIndex(string symbol)
{
   for(int i=0;i<ArraySize(m_baselines);++i)
      if(m_baselines[i].symbol==symbol)
         return i;
   return -1;
}

// Obtain current ATR value
double CVolatilityAdjuster::GetCurrentATR(string symbol)
{
   if(m_handlePool==NULL)
      return 0.0;

   CIndicatorHandle *atrHandle = m_handlePool.GetATR(symbol, PERIOD_CURRENT, m_atrPeriod);
   if(atrHandle==NULL || !atrHandle.IsValid())
      return 0.0;

   double atr[];
   ArraySetAsSeries(atr,true);
   if(atrHandle.CopyBuffer(0,0,1,atr)<=0)
      return 0.0;

   return atr[0];
}

// Update baseline for symbol using recent ATR values
void CVolatilityAdjuster::UpdateBaseline(string symbol)
{
   if(m_handlePool==NULL)
      return;

   double atr[];
   ArraySetAsSeries(atr,true);

   CIndicatorHandle *atrHandle = m_handlePool.GetATR(symbol, PERIOD_CURRENT, m_atrPeriod);
   if(atrHandle==NULL || !atrHandle.IsValid())
      return;

   int copied=atrHandle.CopyBuffer(0,0,m_baselinePeriod,atr);
   if(copied<=0)
      return;

   double sum=0.0;
   for(int i=0;i<copied && i<m_baselinePeriod;i++)
      sum+=atr[i];

   double baseline=sum/copied;
   m_lock.Lock();
   int idx=FindIndex(symbol);
   if(idx<0)
   {
      int newSize=ArraySize(m_baselines)+1;
      if(ArrayResize(m_baselines,newSize)==newSize)
         idx=newSize-1;
      else
      {
         m_lock.Unlock();
         return;
      }
      m_baselines[idx].symbol=symbol;
   }
   m_baselines[idx].value=baseline;
   m_lock.Unlock();
}

// Retrieve stored baseline value
double CVolatilityAdjuster::GetBaselineVolatility(string symbol)
{
   double value=0.0;
   m_lock.Lock();
   int idx=FindIndex(symbol);
   if(idx>=0)
      value=m_baselines[idx].value;
   m_lock.Unlock();
   return value;
}

// Calculate adjustment factor based on volatility ratio
double CVolatilityAdjuster::CalculateVolatilityAdjustment(string symbol)
{
   double currentATR=GetCurrentATR(symbol);
   double baseline = GetBaselineVolatility(symbol);
   if(baseline<=0)
   {
      baseline=currentATR;
      m_lock.Lock();
      int idx=FindIndex(symbol);
      if(idx<0)
      {
         int newSize=ArraySize(m_baselines)+1;
         if(ArrayResize(m_baselines,newSize)==newSize)
            idx=newSize-1;
         else
         {
            m_lock.Unlock();
            return 1.0;
         }
         m_baselines[idx].symbol=symbol;
      }
      m_baselines[idx].value=baseline;
      m_lock.Unlock();
      return 1.0;
   }

   double ratio = currentATR/baseline;
   if(ratio>2.0) return 0.3;
   if(ratio>1.5) return 0.5;
   if(ratio>1.2) return 0.7;
   if(ratio<0.5) return 1.3;
   if(ratio<0.8) return 1.1;
   return 1.0;
}

#endif // VOLATILITYADJUSTER_MQH

