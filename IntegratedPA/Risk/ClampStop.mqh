#ifndef CLAMP_STOP_MQH
#define CLAMP_STOP_MQH
// Este arquivo depende da definição de CRiskManager

// Ajusta stop e volume de acordo com limites configurados
bool CRiskManager::ClampStopAndLot(string symbol, ENUM_ORDER_TYPE type, SETUP_QUALITY quality,
                     double entryPrice, double &stopLoss)
{
   int idx = FindSymbolIndex(symbol);
   if(idx < 0)
      return true;

   double point   = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double stopPts = MathAbs(entryPrice - stopLoss) / point;
   double allowed = m_symbolParams[idx].maxStopPoints;
   double atrVal  = CalculateATRValue(symbol, PERIOD_M5, 14);
   if(m_symbolParams[idx].atrMultiplierLimit > 0 && atrVal > 0)
   {
      double atrLimit = atrVal * m_symbolParams[idx].atrMultiplierLimit / point;
      if(allowed == 0 || atrLimit < allowed)
         allowed = atrLimit;
   }

   if(quality == SETUP_B && stopPts > m_symbolParams[idx].defaultStopPoints * 1.5)
   {
      if(m_logger != NULL)
         m_logger.LogCategorized(LOG_RISK_MANAGEMENT, LOG_LEVEL_WARNING, symbol,
                                    "STOP_TOO_WIDE", "", "");
      return false;
   }

   if(allowed > 0 && stopPts > allowed)
   {
      double newSL = (type==ORDER_TYPE_BUY || type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP)
                      ? entryPrice - allowed*point
                      : entryPrice + allowed*point;
      stopLoss = newSL;
      if(m_logger != NULL)
         m_logger.LogCategorized(LOG_RISK_MANAGEMENT, LOG_LEVEL_INFO, symbol,
                                   "STOP_CLAMPED",
                                   StringFormat("%.1f->%.1f", stopPts, allowed), "");
   }
   return true;
}
#endif
