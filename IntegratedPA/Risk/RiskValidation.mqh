#ifndef RISK_VALIDATION_MQH
#define RISK_VALIDATION_MQH

// Risk validation related methods and helpers

//| ✅ FUNÇÃO ORIGINAL MANTIDA: ValidateMarketPrice                |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateMarketPrice(string symbol, double &price) {
   if(symbol == "" || StringLen(symbol) == 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Símbolo inválido para validação de preço");
      }
      return false;
   }
   
   MqlTick lastTick;
   if(!SymbolInfoTick(symbol, lastTick)) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Falha ao obter tick para " + symbol);
      }
      return false;
   }
   
   if(lastTick.ask <= 0 || lastTick.bid <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Preços inválidos para " + symbol);
      }
      return false;
   }
   
   price = (lastTick.ask + lastTick.bid) / 2.0;
   return true;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO: ValidateStopLoss                                      |
//| Verifica SL com regras de distância e normalização               |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateStopLoss(string symbol, ENUM_ORDER_TYPE type, double price, double &stopLoss) {
   if(stopLoss <= 0) {
      if(m_logger != NULL)
         m_logger.Error("RiskManager: Stop loss inválido (<=0) para " + symbol);
      return false;
   }

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int stopsLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);

   stopLoss = NormalizeDouble(stopLoss, digits);

   double distance = MathAbs(price - stopLoss);

   if(type == ORDER_TYPE_BUY && stopLoss >= price) {
      if(m_logger != NULL)
         m_logger.Error("RiskManager: Stop loss acima do preço de compra para " + symbol);
      return false;
   }
   if(type == ORDER_TYPE_SELL && stopLoss <= price) {
      if(m_logger != NULL)
         m_logger.Error("RiskManager: Stop loss abaixo do preço de venda para " + symbol);
      return false;
   }

   double minDist = stopsLevel * point;
   if(stopsLevel > 0 && distance < minDist) {
      if(m_logger != NULL)
         m_logger.Error(StringFormat("RiskManager: Stop loss muito próximo para %s (%.5f < mínimo %.5f)",
                                     symbol, distance, minDist));
      return false;
   }

   double maxDist = price * 0.10;
   if(distance > maxDist) {
      if(m_logger != NULL)
         m_logger.Error(StringFormat("RiskManager: Stop loss muito distante para %s (%.5f > %.5f)",
                                     symbol, distance, maxDist));
      return false;
   }

   MqlTick tick;
   if(SymbolInfoTick(symbol, tick)) {
      double spread = tick.ask - tick.bid;
      if(spread > distance * 0.5 && m_logger != NULL)
         m_logger.Warning(StringFormat("RiskManager: Spread %.5f grande em relação ao SL %.5f para %s",
                                        spread, distance, symbol));
   }

   return true;
}

#endif // RISK_VALIDATION_MQH
