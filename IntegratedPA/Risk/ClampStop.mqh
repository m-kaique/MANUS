#ifndef CLAMP_STOP_MQH
#define CLAMP_STOP_MQH

//+------------------------------------------------------------------+
//| Helper: Clamp stop distance and adjust lot size                  |
//+------------------------------------------------------------------+
double CRiskManager::ClampStopAndLot(string symbol,
                                     ENUM_ORDER_TYPE type,
                                     double entryPrice,
                                     double riskPercent,
                                     double &stopLoss,
                                     double currentVolume)
{
   int index = FindSymbolIndex(symbol);
   if(index < 0)
      return currentVolume;

   double point       = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double distancePts = MathAbs(entryPrice - stopLoss) / point;

   double maxPts   = m_symbolParams[index].maxStopPoints;
   double atr      = CalculateATRValue(symbol, PERIOD_CURRENT, 14);
   double atrLimit = (atr > 0) ? (atr * m_symbolParams[index].atrMultiplier) / point : 0.0;
   double allowed  = maxPts;
   if(atrLimit > 0 && (allowed == 0 || atrLimit < allowed))
      allowed = atrLimit;

   bool clamped = false;
   if(allowed > 0 && distancePts > allowed)
   {
      if(m_logger != NULL)
         m_logger.LogRiskEvent(symbol, "STOP_TOO_WIDE", distancePts, "Clamping stop");
      distancePts = allowed;
      if(type == ORDER_TYPE_BUY)
         stopLoss = entryPrice - distancePts * point;
      else
         stopLoss = entryPrice + distancePts * point;
      clamped = true;
   }

   double newVolume = CalculatePositionSize(symbol, entryPrice, stopLoss, riskPercent, clamped);
   if(clamped && newVolume < currentVolume && m_logger != NULL)
      m_logger.LogRiskEvent(symbol, "LOT_REDUCED", newVolume, "Stop clamped");

   return newVolume;
}

#endif // CLAMP_STOP_MQH
