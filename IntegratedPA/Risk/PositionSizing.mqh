#ifndef POSITION_SIZING_MQH
#define POSITION_SIZING_MQH

// Position sizing related methods
//+------------------------------------------------------------------+
//| ✅ FUNÇÃO ORIGINAL MANTIDA: CalculatePositionSize              |
//+------------------------------------------------------------------+
double CRiskManager::CalculatePositionSize(string symbol, double entryPrice, double stopLoss, double riskPercentage, bool stopClamped=false) {
   // Validar parâmetros
   if(entryPrice <= 0 || stopLoss <= 0 || riskPercentage <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Parâmetros inválidos para cálculo de posição");
      }
      return 0;
   }
   
   // Calcular risco em pontos
   double riskPoints = MathAbs(entryPrice - stopLoss);
   if(riskPoints <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Risco em pontos inválido");
      }
      return 0;
   }
   
   // Calcular valor do risco
   double riskAmount = m_accountBalance * (riskPercentage / 100.0);
   
   // Obter valor do tick
   double tickValue = GetSymbolTickValue(symbol);
   if(tickValue <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Valor do tick inválido para " + symbol);
      }
      return 0;
   }
   
   // Calcular tamanho da posição
   double positionSize = riskAmount / (riskPoints * tickValue);
   
   // Ajustar para lotes válidos
   positionSize = AdjustLotSize(symbol, positionSize);

   if(stopClamped && m_logger != NULL)
      m_logger.LogRiskEvent(symbol, "LOT_REDUCED", positionSize, "Stop clamped");
   
   if(m_logger != NULL) {
      m_logger.Debug(StringFormat("RiskManager: Posição calculada para %s: %.3f lotes (risco: %.2f, pontos: %.1f)", 
                                 symbol, positionSize, riskAmount, riskPoints));
   }
   
   return positionSize;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO ORIGINAL MANTIDA: AdjustLotSize                      |
//+------------------------------------------------------------------+
double CRiskManager::AdjustLotSize(string symbol, double lotSize) {
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   if(minLot <= 0 || maxLot <= 0 || stepLot <= 0) {
      if(m_logger != NULL) {
         m_logger.Warning("RiskManager: Informações de lote inválidas para " + symbol);
      }
      return 0.01; // Valor padrão
   }
   
   // Ajustar para o step
   lotSize = MathRound(lotSize / stepLot) * stepLot;
   
   // Aplicar limites
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, maxLot);
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO ORIGINAL MANTIDA: GetSymbolTickValue                 |
//+------------------------------------------------------------------+
double CRiskManager::GetSymbolTickValue(string symbol) {
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   
   if(tickValue <= 0) {
      // Calcular manualmente se não disponível
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      
      if(tickSize > 0 && contractSize > 0) {
         tickValue = tickSize * contractSize;
      } else {
         tickValue = 1.0; // Valor padrão
      }
   }
   
   return tickValue;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO ORIGINAL MANTIDA: GetSymbolPointValue                |
//+------------------------------------------------------------------+
double CRiskManager::GetSymbolPointValue(string symbol) {
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tickValue = GetSymbolTickValue(symbol);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(point > 0 && tickSize > 0) {
      return tickValue * (point / tickSize);
   }
   
   return tickValue; // Fallback
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO ORIGINAL MANTIDA: CalculateATRValue                  |
//+------------------------------------------------------------------+
double CRiskManager::CalculateATRValue(string symbol, ENUM_TIMEFRAMES timeframe, int period) {
   // Implementação básica do ATR
   double atrValues[];
   
   if(CopyBuffer(iATR(symbol, timeframe, period), 0, 0, 1, atrValues) <= 0) {
      if(m_logger != NULL) {
         m_logger.Warning("RiskManager: Falha ao obter ATR para " + symbol);
      }
      return 0;
   }
   
   return atrValues[0];
}

//+------------------------------------------------------------------+
#endif // POSITION_SIZING_MQH
