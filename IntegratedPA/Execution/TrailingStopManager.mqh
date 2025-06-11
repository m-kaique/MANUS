#ifndef TRAILING_STOP_MANAGER_MQH
#define TRAILING_STOP_MANAGER_MQH

#include "../Logger.mqh"
#include "../Constants.mqh"
#include <Trade/Trade.mqh>
#include "../Structures.mqh"

class CTrailingStopManager
{
private:
   CTrade  *m_trade;
   CLogger *m_logger;

   struct TrailingConfig
   {
      ulong ticket;
      string symbol;
      ENUM_TIMEFRAMES timeframe;
      double fixedPoints;
      double atrMultiplier;
      int    maPeriod;
      int    trailingType;
      datetime lastUpdate;
      double lastStop;
   };

   TrailingConfig m_configs[];

   double CalculateFixed(ulong ticket,double points);

public:
   CTrailingStopManager();
   void Initialize(CLogger *logger,CTrade *trade);
   bool ApplyTrailingStop(ulong ticket,double points);
   void Manage();
};

// implementation
CTrailingStopManager::CTrailingStopManager()
{
   m_trade=NULL;
   m_logger=NULL;
}

void CTrailingStopManager::Initialize(CLogger *logger,CTrade *trade)
{
   m_logger=logger;
   m_trade=trade;
}

double CTrailingStopManager::CalculateFixed(ulong ticket,double points)
{
   if(!PositionSelectByTicket(ticket)) return 0.0;
   double point=SymbolInfoDouble(PositionGetString(POSITION_SYMBOL),SYMBOL_POINT);
   ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double price=PositionGetDouble(type==POSITION_TYPE_BUY?POSITION_PRICE_CURRENT:POSITION_PRICE_CURRENT);
   if(type==POSITION_TYPE_BUY)
      return price - points*point;
   return price + points*point;
}

bool CTrailingStopManager::ApplyTrailingStop(ulong ticket,double points)
{
   int size=ArraySize(m_configs);
   int idx=-1;
   for(int i=0;i<size;i++) if(m_configs[i].ticket==ticket){idx=i;break;}
   if(idx<0){idx=size;ArrayResize(m_configs,size+1);m_configs[idx].ticket=ticket;m_configs[idx].symbol=PositionGetString(POSITION_SYMBOL);} 
   m_configs[idx].fixedPoints=points;
   m_configs[idx].trailingType=0;
   double newSL=CalculateFixed(ticket,points);
   double tp=PositionGetDouble(POSITION_TP);
   return m_trade.PositionModify(ticket,newSL,tp);
}

void CTrailingStopManager::Manage()
{
   for(int i=ArraySize(m_configs)-1;i>=0;i--)
   {
      if(!PositionSelectByTicket(m_configs[i].ticket))
      {
         ArrayRemove(m_configs,i);
         continue;
      }
      double newSL=CalculateFixed(m_configs[i].ticket,m_configs[i].fixedPoints);
      double curSL=PositionGetDouble(POSITION_SL);
      if((curSL==0)||( (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY && newSL>curSL) ||
           (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL && newSL<curSL)))
      {
         double tp=PositionGetDouble(POSITION_TP);
         m_trade.PositionModify(m_configs[i].ticket,newSL,tp);
      }
   }
}

#endif // TRAILING_STOP_MANAGER_MQH
