#ifndef ORDER_EXECUTION_MQH
#define ORDER_EXECUTION_MQH

#include <Trade/Trade.mqh>
#include "../Logger.mqh"
#include "../MarketContext.mqh"
#include "../CircuitBreaker.mqh"
#include "../JsonLog.mqh"
#include "../Constants.mqh"

//+------------------------------------------------------------------+
//| Classe para execução de ordens                                   |
//+------------------------------------------------------------------+
class COrderExecution
{
private:
   CTrade          *m_trade;
   CLogger         *m_logger;
   CJSONLogger     *m_jsonlog;
   CMarketContext  *m_marketcontext;
   CCircuitBreaker *m_circuitBreaker;
   bool             m_tradeAllowed;
   int              m_maxRetries;
   int              m_retryDelay;
   int              m_lastError;
   string           m_lastErrorDesc;

   bool IsRetryableError(int error_code);
   bool ValidateAndAdjustStops(string symbol, ENUM_ORDER_TYPE type,
                               double &entryPrice, double &stopLoss, double &takeProfit);
   bool ClosePartialPosition(ulong ticket, double volume);

public:
   COrderExecution();
   ~COrderExecution();
   bool Initialize(CLogger *logger, CJSONLogger *jsonlog, CMarketContext *context,
                   CCircuitBreaker *breaker=NULL);
   bool Execute(OrderRequest &request);
   bool ModifyPosition(ulong ticket, double stopLoss, double takeProfit);
   bool ClosePosition(ulong ticket, double volume=0.0);
   bool CloseAllPositions(string symbol="");

   void  SetTradeAllowed(bool allowed) { m_tradeAllowed = allowed; }
   void  SetMaxRetries(int retries)    { m_maxRetries = retries;   }
   void  SetRetryDelay(int delay)      { m_retryDelay = delay;     }
   int   GetLastError() const          { return m_lastError;       }
   string GetLastErrorDescription()const { return m_lastErrorDesc; }
   CTrade* GetTrade() { return m_trade; }
};

#endif // ORDER_EXECUTION_MQH

//+------------------------------------------------------------------+
//| Implementação                                                    |
//+------------------------------------------------------------------+
COrderExecution::COrderExecution()
{
   m_trade = NULL;
   m_logger = NULL;
   m_jsonlog = NULL;
   m_marketcontext = NULL;
   m_circuitBreaker = NULL;
   m_tradeAllowed = true;
   m_maxRetries = 3;
   m_retryDelay = 1000;
   m_lastError = 0;
   m_lastErrorDesc = "";
}

COrderExecution::~COrderExecution()
{
   if(m_trade!=NULL)
   {
      delete m_trade;
      m_trade=NULL;
   }
}

bool COrderExecution::Initialize(CLogger *logger, CJSONLogger *jsonlog,
                                CMarketContext *context,
                                CCircuitBreaker *breaker)
{
   if(logger==NULL)
      return false;
   m_logger = logger;
   m_jsonlog = jsonlog;
   m_marketcontext = context;
   m_circuitBreaker = breaker;

   m_trade = new CTrade();
   if(m_trade==NULL)
      return false;

   m_trade.SetExpertMagicNumber(MAGIC_NUMBER);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(Symbol());
   m_trade.SetDeviationInPoints(10);
   return true;
}

bool COrderExecution::IsRetryableError(int error_code)
{
   switch(error_code)
   {
      case TRADE_RETCODE_REQUOTE:
      case TRADE_RETCODE_CONNECTION:
      case TRADE_RETCODE_PRICE_CHANGED:
      case TRADE_RETCODE_TIMEOUT:
      case TRADE_RETCODE_PRICE_OFF:
      case TRADE_RETCODE_REJECT:
      case TRADE_RETCODE_TOO_MANY_REQUESTS:
         return true;
      case TRADE_RETCODE_INVALID_VOLUME:
      case TRADE_RETCODE_INVALID_PRICE:
      case TRADE_RETCODE_INVALID_STOPS:
      case TRADE_RETCODE_TRADE_DISABLED:
      case TRADE_RETCODE_MARKET_CLOSED:
      case TRADE_RETCODE_NO_MONEY:
      case TRADE_RETCODE_POSITION_CLOSED:
         return false;
      default:
         return false;
   }
}


bool COrderExecution::ValidateAndAdjustStops(string symbol, ENUM_ORDER_TYPE orderType,
                                             double &entryPrice, double &stopLoss, double &takeProfit)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double stopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   if(stopLevel==0)
      stopLevel = 5 * tickSize;

   MqlTick lastTick;
   if(!SymbolInfoTick(symbol, lastTick))
      return false;

   double referencePrice = 0;
   if(orderType==ORDER_TYPE_BUY || orderType==ORDER_TYPE_BUY_STOP || orderType==ORDER_TYPE_BUY_LIMIT)
   {
      referencePrice = lastTick.ask;
      double minStopDistance = stopLevel + lastTick.ask - lastTick.bid;
      double maxStopLoss = lastTick.ask - minStopDistance;
      if(stopLoss>maxStopLoss)
         stopLoss = NormalizeDouble(maxStopLoss, digits);
      if(takeProfit>0 && takeProfit<lastTick.ask + stopLevel)
         takeProfit = NormalizeDouble(lastTick.ask + stopLevel + tickSize, digits);
   }
   else
   {
      referencePrice = lastTick.bid;
      double minStopDistance = stopLevel + lastTick.ask - lastTick.bid;
      double minStopLoss = lastTick.bid + minStopDistance;
      if(stopLoss<minStopLoss)
         stopLoss = NormalizeDouble(minStopLoss, digits);
      if(takeProfit>0 && takeProfit>lastTick.bid - stopLevel)
         takeProfit = NormalizeDouble(lastTick.bid - stopLevel - tickSize, digits);
   }

   entryPrice = NormalizeDouble(MathRound(entryPrice / tickSize) * tickSize, digits);
   stopLoss   = NormalizeDouble(MathRound(stopLoss / tickSize) * tickSize, digits);
   if(takeProfit>0)
      takeProfit = NormalizeDouble(MathRound(takeProfit / tickSize) * tickSize, digits);

   if(orderType==ORDER_TYPE_BUY || orderType==ORDER_TYPE_BUY_STOP || orderType==ORDER_TYPE_BUY_LIMIT)
   {
      if(stopLoss>=entryPrice)
         return false;
      if(takeProfit>0 && takeProfit<=entryPrice)
         return false;
   }
   else
   {
      if(stopLoss<=entryPrice)
         return false;
      if(takeProfit>0 && takeProfit>=entryPrice)
         return false;
   }
   return true;
}


bool COrderExecution::Execute(OrderRequest &request)
{
   if(!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading nao permitido";
      return false;
   }
   if(m_circuitBreaker!=NULL && !m_circuitBreaker.CanOperate())
   {
      m_lastError = -5;
      m_lastErrorDesc = "Circuit Breaker ativo";
      return false;
   }
   if(request.symbol=="" || request.volume<=0)
   {
      m_lastError = -2;
      m_lastErrorDesc = "Parametros invalidos";
      return false;
   }

   double entry=request.price;
   double sl=request.stopLoss;
   double tp=request.takeProfit;
   if(!ValidateAndAdjustStops(request.symbol, request.type, entry, sl, tp))
      return false;
   request.price = entry;
   request.stopLoss = sl;
   request.takeProfit = tp;

   bool result=false;
   int retries=0;
   while(retries < m_maxRetries && !result)
   {
      if(retries>0)
         Sleep(m_retryDelay);

      double execPrice=request.price;
      if(request.type==ORDER_TYPE_BUY || request.type==ORDER_TYPE_SELL)
         execPrice=0;

      switch(request.type)
      {
         case ORDER_TYPE_BUY:       result=m_trade.Buy(request.volume,request.symbol,execPrice,request.stopLoss,request.takeProfit,request.comment); break;
         case ORDER_TYPE_SELL:      result=m_trade.Sell(request.volume,request.symbol,execPrice,request.stopLoss,request.takeProfit,request.comment); break;
         case ORDER_TYPE_BUY_LIMIT: result=m_trade.BuyLimit(request.volume,request.price,request.symbol,request.stopLoss,request.takeProfit,ORDER_TIME_GTC,0,request.comment); break;
         case ORDER_TYPE_SELL_LIMIT:result=m_trade.SellLimit(request.volume,request.price,request.symbol,request.stopLoss,request.takeProfit,ORDER_TIME_GTC,0,request.comment); break;
         case ORDER_TYPE_BUY_STOP:  result=m_trade.BuyStop(request.volume,request.price,request.symbol,request.stopLoss,request.takeProfit,ORDER_TIME_GTC,0,request.comment); break;
         case ORDER_TYPE_SELL_STOP: result=m_trade.SellStop(request.volume,request.price,request.symbol,request.stopLoss,request.takeProfit,ORDER_TIME_GTC,0,request.comment); break;
         default: return false;
      }
      if(!result)
      {
         m_lastError=(int)m_trade.ResultRetcode();
         if(!IsRetryableError(m_lastError))
            return false;
      }
      retries++;
   }
   return result;
}

bool COrderExecution::ModifyPosition(ulong ticket, double stopLoss, double takeProfit)
{
   if(!m_tradeAllowed)
      return false;
   bool result=false;
   int retries=0;
   while(retries<m_maxRetries && !result)
   {
      if(retries>0) Sleep(m_retryDelay);
      result=m_trade.PositionModify(ticket, stopLoss, takeProfit);
      if(!result)
      {
         m_lastError=(int)m_trade.ResultRetcode();
         if(!IsRetryableError(m_lastError))
            return false;
      }
      retries++;
   }
   return result;
}

bool COrderExecution::ClosePosition(ulong ticket, double volume)
{
   if(!PositionSelectByTicket(ticket))
      return false;
   double currentVolume=PositionGetDouble(POSITION_VOLUME);
   bool full=(volume<=0 || volume>=currentVolume);
   if(full)
   {
      bool result=false; int retries=0;
      while(retries<m_maxRetries && !result)
      {
         if(retries>0) Sleep(m_retryDelay);
         result=m_trade.PositionClose(ticket);
         if(!result)
         {
            m_lastError=(int)m_trade.ResultRetcode();
            if(!IsRetryableError(m_lastError))
               break;
         }
         retries++;
      }
      return result;
   }
   else
   {
      return ClosePartialPosition(ticket, volume);
   }
}

bool COrderExecution::CloseAllPositions(string symbol)
{
   if(!m_tradeAllowed)
      return false;
   int total=PositionsTotal();
   bool any=false;
   for(int i=total-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(symbol!="")
      {
         if(!PositionSelectByTicket(ticket)) continue;
         string sym=PositionGetString(POSITION_SYMBOL);
         if(sym!=symbol) continue;
      }
      if(ClosePosition(ticket)) any=true;
   }
   return any;
}


bool COrderExecution::ClosePartialPosition(ulong position_ticket, double partial_volume)
{
   if(!PositionSelectByTicket(position_ticket))
      return false;
   string symbol = PositionGetString(POSITION_SYMBOL);
   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return false;

   MqlTradeRequest request={};
   MqlTradeResult result={};
   request.action = TRADE_ACTION_DEAL;
   request.position = position_ticket;
   request.symbol = symbol;
   request.volume = partial_volume;
   request.magic = MAGIC_NUMBER;
   request.deviation = 3;
   request.comment = "Fechamento Parcial";
   if(posType==POSITION_TYPE_BUY)
   {
      request.type=ORDER_TYPE_SELL;
      request.price=tick.bid;
   }
   else
   {
      request.type=ORDER_TYPE_BUY;
      request.price=tick.ask;
   }

   bool success=false;
   int retries=0;
   while(retries<m_maxRetries && !success)
   {
      if(retries>0)
      {
         Sleep(m_retryDelay);
         if(!SymbolInfoTick(symbol, tick)) break;
         request.price=(posType==POSITION_TYPE_BUY)?tick.bid:tick.ask;
      }
      success=OrderSend(request, result);
      if(!success)
      {
         m_lastError=(int)result.retcode;
         if(!IsRetryableError(result.retcode))
            break;
      }
      retries++;
   }
   return success;
}

#endif // ORDER_EXECUTION_MQH
