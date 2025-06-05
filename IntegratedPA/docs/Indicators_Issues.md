1. Problemas de Cálculo Prematuro de R:R
SignalEngine.mqh - TODOS os métodos de geração de sinais têm o mesmo problema:

// GeneratePullbackToEMASignal() - linha não implementada mas seguirá o padrão
// GenerateBreakoutPullbackSignal() - linha não implementada mas seguirá o padrão
// GenerateRangeExtremesRejectionSignal() - linha não implementada mas seguirá o padrão
// GenerateFailedBreakoutSignal() - linha não implementada mas seguirá o padrão
// GenerateReversalPatternSignal() - linha não implementada mas seguirá o padrão
// GenerateDivergenceSignal() - linha não implementada mas seguirá o padrão

Problema: Todas essas estratégias terão o mesmo problema quando implementadas - calcularão R:R antes de ter take profit.
SetupClassifier.mqh - Problema na análise:

bool CSetupClassifier::CheckRiskReward(Signal &signal, double minRatio) {
   // Recalcular R:R para garantir precisão
   signal.CalculateRiskRewardRatio(); // ← PROBLEMA: Pode não ter TP ainda!
   
   return (signal.riskRewardRatio >= minRatio);
}

2. Problemas de Handles de Indicadores Criados e Liberados Imediatamente
MarketContext.mqh - Mesmo problema do ATR:

double CMarketContext::CalculateATRValue(string symbol, ENUM_TIMEFRAMES timeframe, int period) {
   // Criar handle do indicador ATR
   int atrHandle = iATR(symbol, timeframe, period);
   // ... código ...
   int copied = CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
   IndicatorRelease(atrHandle); // ← PROBLEMA: Libera imediatamente!
}


SetupClassifier.mqh - Múltiplos casos:

bool CSetupClassifier::CheckMomentum(...) {
   int rsiHandle = iRSI(symbol, timeframe, 14, PRICE_CLOSE);
   // ...
   IndicatorRelease(rsiHandle); // ← PROBLEMA!
}

bool CSetupClassifier::CheckMultiTimeframeConfirmation(...) {
   int ema21Handle = iMA(symbol, higherTF, 21, 0, MODE_EMA, PRICE_CLOSE);
   int ema50Handle = iMA(symbol, higherTF, 50, 0, MODE_EMA, PRICE_CLOSE);
   // ...
   IndicatorRelease(ema21Handle); // ← PROBLEMA!
   IndicatorRelease(ema50Handle); // ← PROBLEMA!
}

Utils.mqh - Vários indicadores temporários:

bool CheckMeanReversion50to200(...) {
   int ema50Handle = iMA(symbol, timeframe, EMA_SLOW_PERIOD, 0, MODE_EMA, PRICE_CLOSE);
   int sma200Handle = iMA(symbol, timeframe, SMA_LONG_PERIOD, 0, MODE_SMA, PRICE_CLOSE);
   // ...
   IndicatorRelease(ema50Handle);  // ← PROBLEMA!
   IndicatorRelease(sma200Handle); // ← PROBLEMA!
}

bool CheckRSIDivergence(...) {
   int rsiHandle = iRSI(symbol, timeframe, RSI_PERIOD, PRICE_CLOSE);
   // ...
   IndicatorRelease(rsiHandle); // ← PROBLEMA!
}

TradeExecutor.mqh - Trailing stops:

double CTradeExecutor::CalculateATRTrailingStop(...) {
   int atrHandle = iATR(symbol, timeframe, 14);
   // ...
   IndicatorRelease(atrHandle); // ← PROBLEMA!
}

double CTradeExecutor::CalculateMATrailingStop(...) {
   int maHandle = iMA(symbol, timeframe, maPeriod, 0, MODE_SMA, PRICE_CLOSE);
   // ...
   IndicatorRelease(maHandle); // ← PROBLEMA!
}

3. Problemas de Validação de Dados
SignalEngine.mqh - ValidateIndicatorAccess tem retry mas é insuficiente:

bool CSignalEngine::ValidateIndicatorAccess(...) {
   // ...
   int attempts = 0;
   int maxAttempts = 3;
   // ...
   Sleep(10); // ← PROBLEMA: 10ms pode ser insuficiente!
}

4. Solução Global Recomendada
A. Criar uma classe gerenciadora de handles global:

// IndicatorManager.mqh - NOVO ARQUIVO
class CIndicatorManager {
private:
   struct IndicatorHandle {
      string key;        // symbol+timeframe+type+params
      int handle;
      datetime lastUsed;
      int useCount;
   };
   
   IndicatorHandle m_handles[];
   int m_maxHandles;
   int m_cacheTimeout;
   
   string GenerateKey(string symbol, ENUM_TIMEFRAMES tf, string type, string params);
   void CleanupOldHandles();
   
public:
   CIndicatorManager(int maxHandles = 100, int cacheTimeout = 3600);
   ~CIndicatorManager();
   
   int GetMA(string symbol, ENUM_TIMEFRAMES tf, int period, int shift, ENUM_MA_METHOD method, ENUM_APPLIED_PRICE price);
   int GetRSI(string symbol, ENUM_TIMEFRAMES tf, int period, ENUM_APPLIED_PRICE price);
   int GetATR(string symbol, ENUM_TIMEFRAMES tf, int period);
   int GetMACD(string symbol, ENUM_TIMEFRAMES tf, int fast, int slow, int signal, ENUM_APPLIED_PRICE price);
   int GetStochastic(string symbol, ENUM_TIMEFRAMES tf, int k, int d, int slowing, ENUM_MA_METHOD method, ENUM_STO_PRICE price);
   int GetBollinger(string symbol, ENUM_TIMEFRAMES tf, int period, double deviation, int shift, ENUM_APPLIED_PRICE price);
   
   bool IsReady(int handle, int minBars = 50);
   void ReleaseAll();
};

B. Modificar o fluxo de cálculo de R:R:

// Em SignalEngine.mqh - método Generate()
Signal CSignalEngine::Generate(string symbol, MARKET_PHASE phase, ENUM_TIMEFRAMES timeframe) {
   // ... gerar sinal ...
   
   if (signal.id > 0 && IsValidSignal(signal)) {
      // NÃO calcular R:R aqui - remover signal.CalculateRiskRewardRatio()
      
      // Classificar sem R:R
      signal.quality = SETUP_INVALID; // Temporário
      
      // Log sem R:R
      if (m_logger != NULL) {
         m_logger.Debug("Sinal gerado, aguardando cálculo de R:R");
      }
   }
   
   return signal;
}

// Em IntegratedPA_EA.mq5 - ProcessSignal()
bool ProcessSignal(string symbol, Signal &signal, MARKET_PHASE phase) {
   // ... validações ...
   
   // Criar requisição (aqui o TP será calculado)
   OrderRequest request = CreateOrderRequest(symbol, signal, phase);
   
   // AGORA classificar com R:R completo
   if(signal.riskRewardRatio > 0) {
      signal.quality = g_signalEngine.ClassifySetupQuality(symbol, MainTimeframe, signal);
      
      // Filtrar APÓS classificação correta
      if(signal.quality <= MinSetupQuality) {
         if(g_logger != NULL) {
            g_logger.Debug(StringFormat("%s: Setup %s descartado (R:R=%.2f)", 
                                      symbol, EnumToString(signal.quality), 
                                      signal.riskRewardRatio));
         }
         return false;
      }
   }
   
   // ... continuar processamento ...
}

C. Adicionar timeout progressivo para indicadores:

// Utils.mqh - Nova função auxiliar
bool WaitForIndicator(int handle, int maxWaitMs = 500, int checkIntervalMs = 50) {
   if(handle == INVALID_HANDLE) return false;
   
   int waited = 0;
   while(waited < maxWaitMs) {
      int calculated = BarsCalculated(handle);
      if(calculated > 0) {
         return true;
      }
      
      Sleep(checkIntervalMs);
      waited += checkIntervalMs;
   }
   
   return false;
}

D. Modificar SetupClassifier para não recalcular R:R:

bool CSetupClassifier::CheckRiskReward(Signal &signal, double minRatio) {
   // NÃO recalcular - apenas verificar
   // signal.CalculateRiskRewardRatio(); // ← REMOVER
   
   // Verificar se já foi calculado
   if(signal.riskRewardRatio <= 0) {
      if(m_logger != NULL) {
         m_logger.Warning("SetupClassifier: R:R não calculado ainda");
      }
      return false;
   }
   
   return (signal.riskRewardRatio >= minRatio);
}

5. Implementação Incremental Sugerida
Fase 1 - Correções Críticas:

Corrigir fluxo de cálculo R:R (mover para após TP ser definido)
Implementar cache básico de handles no RiskManager para ATR

Fase 2 - Melhorias de Robustez:

Criar CIndicatorManager global
Migrar todos os componentes para usar o manager
Adicionar timeouts progressivos

Fase 3 - Otimizações:

Implementar limpeza automática de handles antigos
Adicionar métricas de performance do cache
Ajustar timeouts baseado em estatísticas

6. Exemplo de Implementação Rápida para o RiskManager

// RiskManager.mqh - Adicionar ao início da classe
class CRiskManager {
private:
   // Cache de handles
   int m_atrHandles[][3];  // [symbol_index][timeframe_index] = handle
   
   // Inicializar no construtor
   void InitializeHandleCache() {
      int symbolCount = ArraySize(m_symbolParams);
      ArrayResize(m_atrHandles, symbolCount);
      for(int i = 0; i < symbolCount; i++) {
         ArrayResize(m_atrHandles[i], 3); // 3 timeframes típicos
         for(int j = 0; j < 3; j++) {
            m_atrHandles[i][j] = INVALID_HANDLE;
         }
      }
   }
   
   // Obter handle com cache
   int GetCachedATRHandle(int symbolIndex, ENUM_TIMEFRAMES timeframe) {
      if(symbolIndex < 0 || symbolIndex >= ArraySize(m_symbolParams)) {
         return INVALID_HANDLE;
      }
      
      int tfIndex = TimeframeToIndex(timeframe);
      if(tfIndex < 0 || tfIndex >= 3) {
         return INVALID_HANDLE;
      }
      
      // Verificar cache
      if(m_atrHandles[symbolIndex][tfIndex] != INVALID_HANDLE) {
         return m_atrHandles[symbolIndex][tfIndex];
      }
      
      // Criar novo handle
      int handle = iATR(m_symbolParams[symbolIndex].symbol, timeframe, ATR_PERIOD);
      if(handle != INVALID_HANDLE) {
         m_atrHandles[symbolIndex][tfIndex] = handle;
         
         // Esperar estar pronto
         WaitForIndicator(handle, 300, 50);
      }
      
      return handle;
   }
};