#ifndef BREAKEVEN_MANAGER_MQH
#define BREAKEVEN_MANAGER_MQH

#include "../Logger.mqh"
#include "../Structures.mqh"
#include <Trade/Trade.mqh>
#include "../Constants.mqh"

class CBreakevenManager
{
private:
   CTrade  *m_trade;
   CLogger *m_logger;
   BreakevenConfig m_configs[];

   int FindConfig(ulong ticket);
   double CalculateATR(string symbol);

public:
   CBreakevenManager();
   void Initialize(CLogger *logger,CTrade *trade);
   bool SetBreakevenFixed(ulong ticket,double trigger,double offset);
   void Manage();
   bool IsTriggered(ulong ticket);
};

CBreakevenManager::CBreakevenManager()
{
   m_trade=NULL;
   m_logger=NULL;
}

void CBreakevenManager::Initialize(CLogger *logger,CTrade *trade)
{
   m_logger=logger;
   m_trade=trade;
}

int CBreakevenManager::FindConfig(ulong ticket)
{
   for(int i=0;i<ArraySize(m_configs);i++) if(m_configs[i].ticket==ticket) return i;
   return -1;
}

double CBreakevenManager::CalculateATR(string symbol)
{
   int h=iATR(symbol,PERIOD_CURRENT,14);
   if(h==INVALID_HANDLE) return 0.0;
   double b[]; ArraySetAsSeries(b,true); int c=CopyBuffer(h,0,0,1,b); IndicatorRelease(h);
   if(c<=0) return 0.0; return b[0];
}

bool CBreakevenManager::SetBreakevenFixed(ulong ticket,double trigger,double offset)
{
   int idx=FindConfig(ticket);
   if(idx<0){idx=ArraySize(m_configs);ArrayResize(m_configs,idx+1);m_configs[idx].ticket=ticket;m_configs[idx].symbol=PositionGetString(POSITION_SYMBOL);} 
   m_configs[idx].breakevenType=BREAKEVEN_FIXED;
   m_configs[idx].triggerPoints=trigger;
   m_configs[idx].breakevenOffset=offset;
   m_configs[idx].isActive=true;
   m_configs[idx].wasTriggered=false;
   return true;
}

void CBreakevenManager::Manage()
{
   for(int i=ArraySize(m_configs)-1;i>=0;i--)
   {
      if(!PositionSelectByTicket(m_configs[i].ticket))
      {
         ArrayRemove(m_configs,i);
         continue;
      }
      if(m_configs[i].wasTriggered || !m_configs[i].isActive) continue;
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double price=PositionGetDouble(POSITION_PRICE_CURRENT);
      double point=SymbolInfoDouble(m_configs[i].symbol,SYMBOL_POINT);
      double profit=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?(price-entry):(entry-price);
      double trigger=m_configs[i].triggerPoints*point;
      if(profit>=trigger)
      {
         double newSL=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?entry+m_configs[i].breakevenOffset*point:entry-m_configs[i].breakevenOffset*point;
         double tp=PositionGetDouble(POSITION_TP);
         if(m_trade.PositionModify(m_configs[i].ticket,newSL,tp))
            m_configs[i].wasTriggered=true;
      }
   }
}

bool CBreakevenManager::IsTriggered(ulong ticket)
{
   int idx=FindConfig(ticket);
   if(idx>=0) return m_configs[idx].wasTriggered;
   if(!PositionSelectByTicket(ticket)) return false;
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
      return sl>entry;
   else
      return sl<entry;
}

#endif // BREAKEVEN_MANAGER_MQH
