//+------------------------------------------------------------------+
//|                                             RiskManager.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Include Guards para evitar múltiplas inclusões                   |
//+------------------------------------------------------------------+
#ifndef RISKMANAGER_MQH
#define RISKMANAGER_MQH

// Inclusão de bibliotecas necessárias
#include "Structures.mqh"
#include "Logger.mqh"
#include "MarketContext.mqh"
#include "Indicators/IndicatorHandlePool.mqh"
#include "Constants.mqh"
#include "CircuitBreaker.mqh"
#include "VolatilityAdjuster.mqh"
#include "DrawdownController.mqh"
#include "MetricsCollector.mqh"

//+------------------------------------------------------------------+
//| Setup-risk correlation matrix                                    |
//+------------------------------------------------------------------+
struct SetupRiskMatrix
{
   SETUP_QUALITY      quality;   // Qualidade do setup
   int                minFactors;// Fatores mínimos de confluência
   double             minRiskReward; // R:R mínimo
   double             maxScaling;    // Escalonamento máximo permitido
   bool               allowPartials; // Permite parciais
};

// Matriz de correlação padrão
SetupRiskMatrix riskMatrix[] =
   {
      {SETUP_A_PLUS, 6, 3.0, 5.0, true},
      {SETUP_A,      5, 2.5, 3.0, true},
      {SETUP_B,      3, 2.0, 2.0, true},
      {SETUP_C,      1, 1.5, 1.0, false}
   };

// Avaliar qualidade de setup com base em fatores e R:R
SETUP_QUALITY EvaluateSetupQuality(int factors, double riskReward)
{
   for(int i=0;i<ArraySize(riskMatrix);i++)
   {
      if(factors>=riskMatrix[i].minFactors &&
         riskReward>=riskMatrix[i].minRiskReward)
      {
         return(riskMatrix[i].quality);
      }
   }
   return(SETUP_C);
}

#include "Risk/PositionSizing.mqh"
#include "Risk/RiskValidation.mqh"
#include "Risk/PartialManager.mqh"

//+------------------------------------------------------------------+
//| Classe para gestão de risco e dimensionamento de posições        |
//+------------------------------------------------------------------+
class CRiskManager {
private:
   // Objetos internos
   CStructuredLogger* m_logger;
   CMarketContext* m_marketContext;
   CCircuitBreaker *m_circuitBreaker;
   CHandlePool    *m_handlePool;
   
   // Configurações gerais
   double          m_defaultRiskPercentage;
   double          m_maxTotalRisk;
   
   // Informações da conta
   double          m_accountBalance;
   double          m_accountEquity;
   double          m_accountFreeMargin;
   
   // ✅ ESTRUTURA ORIGINAL MANTIDA E EXPANDIDA
   struct SymbolRiskParams {
      string         symbol;
      double         riskPercentage;
      double         maxLotSize;
      double         defaultStopPoints;
      double         atrMultiplier;
      bool           usePartials;
      double         partialLevels[10];    // Níveis de R:R para parciais
      double         partialVolumes[10];   // Volumes para cada parcial (em %)
      
      // ✅ NOVOS CAMPOS PARA PARCIAIS UNIVERSAIS
      PARTIAL_STRATEGY partialStrategy;        // Estratégia de parciais
      double minVolumeForPartials;             // Volume mínimo para parciais
      bool allowVolumeScaling;                 // Permitir escalonamento de volume
      double maxScalingFactor;                 // Fator máximo de escalonamento
      ASSET_TYPE assetType;                    // Tipo de ativo detectado
      LotCharacteristics lotChar;              // Características de lote
      AdaptivePartialConfig lastPartialConfig; // Última configuração aplicada
   };
   
   // Array de parâmetros por símbolo
   SymbolRiskParams m_symbolParams[];
   
   // ✅ MÉTRICAS DE PERFORMANCE PARA PARCIAIS UNIVERSAIS
   PartialMetrics m_partialMetrics;
   CMetricsCollector *m_metricsCollector;

   // ✅ NOVA ESTRUTURA: Tiers de escalonamento por qualidade de setup
   struct QualityScalingTiers {
      double tiers[5];
      int    count;
   };
   QualityScalingTiers m_qualityScaling[5];
   
   // ✅ MÉTODOS PRIVADOS ORIGINAIS MANTIDOS
   double CalculatePositionSize(string symbol, double entryPrice, double stopLoss, double riskPercentage);
   double AdjustLotSize(string symbol, double lotSize);
   double GetSymbolTickValue(string symbol);
   double GetSymbolPointValue(string symbol);
   int FindSymbolIndex(string symbol);
   double CalculateATRValue(string symbol, ENUM_TIMEFRAMES timeframe, int period);
   bool ValidateMarketPrice(string symbol, double &price);
   bool ValidateStopLoss(string symbol, ENUM_ORDER_TYPE type, double price, double &stopLoss);
   
   // ✅ NOVOS MÉTODOS PARA PARCIAIS UNIVERSAIS - CORRIGIDOS PARA MQL5
   ASSET_TYPE ClassifyAssetType(string symbol);
   LotCharacteristics GetLotCharacteristics(string symbol);
   AdaptivePartialConfig CalculateUniversalPartials(string symbol, double baseVolume,
                                                   double &originalPercentages[],
                                                   double &originalLevels[],
                                                   int numPartials,
                                                   SETUP_QUALITY quality);
   PARTIAL_STRATEGY DetermineOptimalStrategy(string symbol, double volume, 
                                           LotCharacteristics &lotChar, 
                                           double &percentages[], int numPartials);
   AdaptivePartialConfig ApplyScaledStrategy(string symbol, AdaptivePartialConfig &config,
                                           LotCharacteristics &lotChar,
                                           double &percentages[], int numPartials,
                                           SETUP_QUALITY quality);
   AdaptivePartialConfig ApplyAdaptiveStrategy(string symbol, AdaptivePartialConfig &config, 
                                             LotCharacteristics &lotChar, 
                                             double &percentages[], int numPartials);
   AdaptivePartialConfig ApplyConditionalStrategy(string symbol, AdaptivePartialConfig &config, 
                                                 LotCharacteristics &lotChar, 
                                                 double &percentages[], int numPartials);
   
   // ✅ FUNÇÕES DE VALIDAÇÃO ESPECÍFICAS POR TIPO DE ATIVO - CORRIGIDAS
   bool ValidateFractionalPartials(string symbol, double totalVolume, double &partialPercentages[], int numPartials);
   bool ValidateIntegerPartials(string symbol, double totalVolume, double &partialPercentages[], int numPartials);
   bool ValidateLargeLotPartials(string symbol, double totalVolume, double &partialPercentages[], int numPartials);
   bool ValidateUniversalPartials(string symbol, double totalVolume, double &partialPercentages[], int numPartials);
   
   // ✅ FUNÇÕES AUXILIARES
   void LogPartialDecision(string symbol, AdaptivePartialConfig &config);
   void UpdatePartialMetrics(AdaptivePartialConfig &config);
   double GetScalingTier(SETUP_QUALITY quality, double requiredFactor, double maxFactor);
   double CalculateRiskBasedScaling(SETUP_QUALITY quality, double baseScaling);
   bool   ValidateSetupForScaling(SETUP_QUALITY quality, double requestedScaling);

public:
   // ✅ CONSTRUTORES E DESTRUTOR ORIGINAIS MANTIDOS
   CRiskManager(double defaultRiskPercentage = 1.0, double maxTotalRisk = 5.0);
   ~CRiskManager();
   
   // ✅ MÉTODOS DE INICIALIZAÇÃO ORIGINAIS MANTIDOS
   bool Initialize(CStructuredLogger* logger, CMarketContext* marketContext, CCircuitBreaker *circuitBreaker=NULL);
   
   // ✅ MÉTODOS DE CONFIGURAÇÃO ORIGINAIS MANTIDOS
   void SetDefaultRiskPercentage(double percentage) { m_defaultRiskPercentage = percentage; }
   void SetMaxTotalRisk(double percentage) { m_maxTotalRisk = percentage; }
   
   // ✅ MÉTODOS PARA CONFIGURAÇÃO DE SÍMBOLOS ORIGINAIS MANTIDOS
   bool AddSymbol(string symbol, double riskPercentage, double maxLotSize);
   bool ConfigureSymbolStopLoss(string symbol, double defaultStopPoints, double atrMultiplier);
   bool ConfigureSymbolPartials(string symbol, bool usePartials, double &levels[], double &volumes[]);
   
   // ✅ NOVOS MÉTODOS PARA CONFIGURAÇÃO DE PARCIAIS UNIVERSAIS
   bool ConfigureUniversalPartials(string symbol, PARTIAL_STRATEGY strategy, double minVolume, 
                                  bool allowScaling, double maxScaling);
   bool AutoConfigureSymbol(string symbol);
   
   // ✅ MÉTODOS PARA CÁLCULO DE RISCO ORIGINAIS MANTIDOS
   OrderRequest BuildRequest(string symbol, Signal &signal, MARKET_PHASE phase);
   double CalculateStopLoss(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice, MARKET_PHASE phase);
   double CalculateTakeProfit(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice, double stopLoss);
   
   // ✅ MÉTODOS PARA GESTÃO DE POSIÇÕES ORIGINAIS MANTIDOS
   bool ShouldTakePartial(string symbol, ulong ticket, double currentPrice, double entryPrice, double stopLoss);
   double GetPartialVolume(string symbol, ulong ticket, double currentRR);
   
   // ✅ MÉTODOS DE ACESSO ORIGINAIS MANTIDOS
   double GetCurrentTotalRisk();
   void UpdateAccountInfo();
   
   // ✅ NOVOS MÉTODOS PARA MÉTRICAS E MONITORAMENTO
   PartialMetrics GetPartialMetrics() { return m_partialMetrics; }
   void ResetPartialMetrics();
   string GetPartialReport(string symbol);
};


//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| ✅ IMPLEMENTAÇÃO - CONSTRUTORES E MÉTODOS ORIGINAIS MANTIDOS    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager(double defaultRiskPercentage = 1.0, double maxTotalRisk = 5.0) {
   m_logger = NULL;
   m_marketContext = NULL;
   m_circuitBreaker = NULL;
   m_defaultRiskPercentage = defaultRiskPercentage;
   m_maxTotalRisk = maxTotalRisk;
   m_accountBalance = 0;
   m_accountEquity = 0;
   m_accountFreeMargin = 0;

   m_metricsCollector = new CMetricsCollector();
   
   // ✅ INICIALIZAR MÉTRICAS DE PARCIAIS
   m_partialMetrics.lastReset = TimeCurrent();

   // ✅ CONFIGURAR TIERS DE ESCALONAMENTO POR QUALIDADE
   m_qualityScaling[SETUP_INVALID].tiers[0] = 1.0;
   m_qualityScaling[SETUP_INVALID].count = 1;

   double tiersAPlus[4] = {2.0, 3.0, 4.0, 5.0};
   for(int i=0;i<4;i++) m_qualityScaling[SETUP_A_PLUS].tiers[i] = tiersAPlus[i];
   m_qualityScaling[SETUP_A_PLUS].count = 4;

   double tiersA[2] = {2.0, 3.0};
   for(int i=0;i<2;i++) m_qualityScaling[SETUP_A].tiers[i] = tiersA[i];
   m_qualityScaling[SETUP_A].count = 2;

   double tiersB[1] = {2.0};
   for(int i=0;i<1;i++) m_qualityScaling[SETUP_B].tiers[i] = tiersB[i];
   m_qualityScaling[SETUP_B].count = 1;

   m_qualityScaling[SETUP_C].tiers[0] = 1.0;
   m_qualityScaling[SETUP_C].count = 1;
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager() {
   if(m_metricsCollector != NULL)
   {
      delete m_metricsCollector;
      m_metricsCollector = NULL;
   }
}

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool CRiskManager::Initialize(CStructuredLogger* logger, CMarketContext* marketContext, CCircuitBreaker *circuitBreaker) {
   // Verificar parâmetros
   if(logger == NULL || marketContext == NULL) {
      Print("CRiskManager::Initialize - Logger ou MarketContext não podem ser NULL");
      return false;
   }
   
   // Atribuir objetos
   m_logger = logger;
   m_marketContext = marketContext;
   m_circuitBreaker = circuitBreaker;
   m_handlePool = (marketContext != NULL) ? marketContext.GetHandlePool() : NULL;
   
   m_logger.Info("Inicializando RiskManager com Sistema de Parciais Universal");
   
   // Atualizar informações da conta
   UpdateAccountInfo();
   
   // ✅ RESETAR MÉTRICAS DE PARCIAIS
   ResetPartialMetrics();
   
   m_logger.Info(StringFormat("RiskManager inicializado com risco padrão de %.2f%% e risco máximo de %.2f%%", 
                             m_defaultRiskPercentage, m_maxTotalRisk));
   
   return true;
}

//+------------------------------------------------------------------+
//| Atualizar informações da conta                                   |
//+------------------------------------------------------------------+
void CRiskManager::UpdateAccountInfo() {
   m_accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   m_accountFreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   
   if(m_logger != NULL) {
      m_logger.Debug(StringFormat("Informações da conta atualizadas: Saldo=%.2f, Equity=%.2f, Margem Livre=%.2f", 
                                 m_accountBalance, m_accountEquity, m_accountFreeMargin));
   }
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO ORIGINAL MANTIDA: Adicionar símbolo                   |
//+------------------------------------------------------------------+
bool CRiskManager::AddSymbol(string symbol, double riskPercentage, double maxLotSize) {
   // Verificar se o símbolo já existe
   int index = FindSymbolIndex(symbol);
   
   if(index >= 0) {
      // Atualizar parâmetros existentes
      m_symbolParams[index].riskPercentage = riskPercentage;
      m_symbolParams[index].maxLotSize = maxLotSize;
      
      if(m_logger != NULL) {
         m_logger.Info("RiskManager: Parâmetros atualizados para " + symbol);
      }
      
      return true;
   }
   
   // Adicionar novo símbolo
   int size = ArraySize(m_symbolParams);
   int newSize = size + 1;
   
   // Verificar se o redimensionamento foi bem-sucedido
   if(ArrayResize(m_symbolParams, newSize) != newSize) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Falha ao redimensionar array de parâmetros");
      }
      return false;
   }
   
   m_symbolParams[size].symbol = symbol;
   m_symbolParams[size].riskPercentage = riskPercentage;
   m_symbolParams[size].maxLotSize = maxLotSize;
   m_symbolParams[size].defaultStopPoints = 100;  // Valor padrão
   m_symbolParams[size].atrMultiplier = 2.0;      // Valor padrão
   m_symbolParams[size].usePartials = false;
   
   // ✅ INICIALIZAR NOVOS CAMPOS PARA PARCIAIS UNIVERSAIS
   m_symbolParams[size].partialStrategy = PARTIAL_STRATEGY_ORIGINAL;
   m_symbolParams[size].minVolumeForPartials = 0.0;
   m_symbolParams[size].allowVolumeScaling = false;
   m_symbolParams[size].maxScalingFactor = 3.0;
   m_symbolParams[size].assetType = ASSET_UNKNOWN;
   
   // Inicializar arrays de parciais
   double tempLevels[3] = {1.0, 2.0, 3.0};
   double tempVolumes[3] = {0.3, 0.3, 0.4};
   
   for(int i=0; i<3; i++) {
      m_symbolParams[size].partialLevels[i] = tempLevels[i];
      m_symbolParams[size].partialVolumes[i] = tempVolumes[i];
   }
   
   // ✅ AUTO-CONFIGURAR CARACTERÍSTICAS DO SÍMBOLO
   AutoConfigureSymbol(symbol);
   
   if(m_logger != NULL) {
      m_logger.Info("RiskManager: Símbolo " + symbol + " adicionado à lista com risco de " + 
                   DoubleToString(m_symbolParams[size].riskPercentage, 2) + "%");
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO ORIGINAL MANTIDA: Configurar stop loss                |
//+------------------------------------------------------------------+
bool CRiskManager::ConfigureSymbolStopLoss(string symbol, double defaultStopPoints, double atrMultiplier) {
   // Encontrar índice do símbolo
   int index = FindSymbolIndex(symbol);
   
   if(index < 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Símbolo " + symbol + " não encontrado para configuração de stop loss");
      }
      return false;
   }
   
   // Atualizar parâmetros
   m_symbolParams[index].defaultStopPoints = defaultStopPoints;
   m_symbolParams[index].atrMultiplier = atrMultiplier;
   
   if(m_logger != NULL) {
      m_logger.Info(StringFormat("RiskManager: Stop loss configurado para %s: %.1f pontos, ATR x%.1f", 
                                symbol, defaultStopPoints, atrMultiplier));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO ORIGINAL MANTIDA: Configurar parciais                 |
//+------------------------------------------------------------------+
bool CRiskManager::ConfigureSymbolPartials(string symbol, bool usePartials, double &levels[], double &volumes[]) {
   // Encontrar índice do símbolo
   int index = FindSymbolIndex(symbol);
   
   if(index < 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Símbolo " + symbol + " não encontrado para configuração de parciais");
      }
      return false;
   }
   
   // Verificar tamanhos dos arrays
   int levelsSize = ArraySize(levels);
   int volumesSize = ArraySize(volumes);
   
   if(levelsSize != volumesSize || levelsSize == 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Arrays de níveis e volumes devem ter o mesmo tamanho e não podem ser vazios");
      }
      return false;
   }
   
   // Verificar se os níveis estão em ordem crescente
   for(int i = 1; i < levelsSize; i++) {
      if(levels[i] <= levels[i-1]) {
         if(m_logger != NULL) {
            m_logger.Warning(StringFormat("RiskManager: Níveis de parciais devem estar em ordem crescente. Nível %d (%.2f) <= Nível %d (%.2f)", 
                                        i, levels[i], i-1, levels[i-1]));
         }
         return false;
      }
   }
   
   // Verificar se a soma dos volumes é aproximadamente 1.0
   double totalVolume = 0;
   for(int i = 0; i < volumesSize; i++) {
      totalVolume += volumes[i];
   }
   
   if(MathAbs(totalVolume - 1.0) > 0.01) {
      if(m_logger != NULL) {
         m_logger.Warning(StringFormat("RiskManager: Soma dos volumes (%.2f) não é igual a 1.0", totalVolume));
      }
   }
   
   // Atualizar parâmetros
   m_symbolParams[index].usePartials = usePartials;
   
   // Copiar arrays
   int maxSize = MathMin(levelsSize, 10); // Limitar a 10 níveis
   
   for(int i = 0; i < maxSize; i++) {
      m_symbolParams[index].partialLevels[i] = levels[i];
      m_symbolParams[index].partialVolumes[i] = volumes[i];
   }
   
   if(m_logger != NULL) {
      string levelsStr = "";
      string volumesStr = "";
      
      for(int i = 0; i < maxSize; i++) {
         levelsStr += DoubleToString(levels[i], 1) + " ";
         volumesStr += DoubleToString(volumes[i] * 100, 0) + "% ";
      }
      
      m_logger.Info(StringFormat("RiskManager: Parciais configuradas para %s: %s, Níveis: %s, Volumes: %s", 
                                symbol, usePartials ? "Ativado" : "Desativado", levelsStr, volumesStr));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ✅ NOVA FUNÇÃO: Configurar parciais universais                  |
//+------------------------------------------------------------------+
bool CRiskManager::ConfigureUniversalPartials(string symbol, PARTIAL_STRATEGY strategy, double minVolume, 
                                              bool allowScaling, double maxScaling) {
   int index = FindSymbolIndex(symbol);
   
   if(index < 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Símbolo " + symbol + " não encontrado para configuração universal");
      }
      return false;
   }
   
   // Atualizar configuração universal
   m_symbolParams[index].partialStrategy = strategy;
   m_symbolParams[index].minVolumeForPartials = minVolume;
   m_symbolParams[index].allowVolumeScaling = allowScaling;
   m_symbolParams[index].maxScalingFactor = maxScaling;
   
   // Obter características atualizadas
   m_symbolParams[index].lotChar = GetLotCharacteristics(symbol);
   m_symbolParams[index].assetType = m_symbolParams[index].lotChar.type;
   
   if(m_logger != NULL) {
      m_logger.Info(StringFormat("RiskManager: Parciais universais configuradas para %s: estratégia=%s, minVol=%.2f, escala=%s (max %.1fx)", 
                                symbol, EnumToString(strategy), minVolume, 
                                allowScaling ? "SIM" : "NÃO", maxScaling));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO AUXILIAR: Configuração automática melhorada           |
//+------------------------------------------------------------------+
bool CRiskManager::AutoConfigureSymbol(string symbol) {
   int index = FindSymbolIndex(symbol);
   
   if(index < 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Símbolo " + symbol + " não encontrado para auto-configuração");
      }
      return false;
   }
   
   // Classificar tipo de ativo
   ASSET_TYPE assetType = ClassifyAssetType(symbol);
   m_symbolParams[index].assetType = assetType;
   
   // Obter características de lote
   LotCharacteristics lotChar = GetLotCharacteristics(symbol);
   m_symbolParams[index].lotChar = lotChar;
   
   // ✅ CONFIGURAÇÃO OTIMIZADA PARA PARCIAIS EFETIVAS
   switch(assetType) {
      case ASSET_FRACTIONAL:
         m_symbolParams[index].partialStrategy = PARTIAL_STRATEGY_ORIGINAL;
         m_symbolParams[index].minVolumeForPartials = 0.03;  // 3 parciais de 0.01 cada
         m_symbolParams[index].allowVolumeScaling = false;
         m_symbolParams[index].maxScalingFactor = 1.0;
         break;
         
      case ASSET_INTEGER:
         m_symbolParams[index].partialStrategy = PARTIAL_STRATEGY_ADAPTIVE;
         m_symbolParams[index].minVolumeForPartials = 10.0;  // ✅ 10 lotes para parciais efetivas
         m_symbolParams[index].allowVolumeScaling = true;    // ✅ Permitir escalonamento
         m_symbolParams[index].maxScalingFactor = 5.0;       // ✅ Até 5x o volume original
         break;
         
      case ASSET_LARGE_LOT:
         m_symbolParams[index].partialStrategy = PARTIAL_STRATEGY_DISABLED;
         m_symbolParams[index].minVolumeForPartials = 1000.0;
         m_symbolParams[index].allowVolumeScaling = false;
         m_symbolParams[index].maxScalingFactor = 1.0;
         break;
         
      default:
         m_symbolParams[index].partialStrategy = PARTIAL_STRATEGY_CONDITIONAL;
         m_symbolParams[index].minVolumeForPartials = 5.0;   // ✅ 5 lotes como padrão
         m_symbolParams[index].allowVolumeScaling = true;
         m_symbolParams[index].maxScalingFactor = 3.0;
         break;
   }
   
   if(m_logger != NULL) {
      m_logger.Info(StringFormat("✅ %s auto-configurado: tipo=%s, estratégia=%s, vol_min=%.1f, escala=%s (max %.1fx)", 
                                symbol, EnumToString(assetType), 
                                EnumToString(m_symbolParams[index].partialStrategy),
                                m_symbolParams[index].minVolumeForPartials,
                                m_symbolParams[index].allowVolumeScaling ? "SIM" : "NÃO",
                                m_symbolParams[index].maxScalingFactor));
   }
   
   return true;
}

}


//+------------------------------------------------------------------+
//| ✅ FUNÇÕES ORIGINAIS MANTIDAS E INTEGRAÇÃO UNIVERSAL           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO ORIGINAL MANTIDA: FindSymbolIndex                    |
//+------------------------------------------------------------------+
int CRiskManager::FindSymbolIndex(string symbol) {
   for(int i = 0; i < ArraySize(m_symbolParams); i++) {
      if(m_symbolParams[i].symbol == symbol) {
         return i;
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO PRINCIPAL MODIFICADA: BuildRequest                   |
//| Integra o sistema de parciais universal                         |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: BuildRequest                               |
//| Garante volume adequado para parciais efetivas                  |
//+------------------------------------------------------------------+
OrderRequest CRiskManager::BuildRequest(string symbol, Signal &signal, MARKET_PHASE phase) {
   OrderRequest request;

   if(m_metricsCollector != NULL && TimeCurrent() - m_metricsCollector.GetLastReportTime() >= 86400)
      m_metricsCollector.GenerateReport();

   if(m_circuitBreaker != NULL && !m_circuitBreaker.CanOperate()) {
      if(m_logger != NULL)
         m_logger.LogCircuitBreaker(symbol, "BLOCKED", 0, "Breaker active");
      request.volume = 0;
      m_circuitBreaker.RegisterError();
      if(m_metricsCollector != NULL)
         m_metricsCollector.RecordCircuitBreakerActivation();
      return request;
   }
   
   // Preencher dados básicos
   request.symbol = symbol;
   request.type = signal.direction;
   
   // Validar símbolo
   if(symbol == "" || StringLen(symbol) == 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Símbolo inválido para construção de requisição");
      }
      request.volume = 0;
      if(m_circuitBreaker != NULL)
         m_circuitBreaker.RegisterError();
      return request;
   }
   
   // Validar preço de mercado
   double marketPrice = 0;
   if(!ValidateMarketPrice(symbol, marketPrice)) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Falha ao validar preço de mercado para " + symbol);
      }
      request.volume = 0;
      if(m_circuitBreaker != NULL)
         m_circuitBreaker.RegisterError();
      return request;
   }
   
   // USAR PREÇOS DO SINAL
   request.price = signal.entryPrice;
   request.stopLoss = signal.stopLoss;
   request.takeProfit = signal.takeProfits[0];
   request.comment = "IntegratedPA: " + EnumToString(signal.quality) + " " + EnumToString(phase);
   
   // Validar preços
   MqlTick lastTick;
   if(!SymbolInfoTick(symbol, lastTick)) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Falha ao obter tick para " + symbol);
      }
      request.volume = 0;
      if(m_circuitBreaker != NULL)
         m_circuitBreaker.RegisterError();
      return request;
   }
   
   double currentSpread = lastTick.ask - lastTick.bid;
   double maxDeviation = currentSpread * 3.0;
   double priceDeviation = MathAbs(signal.entryPrice - marketPrice);
   
   if(priceDeviation > maxDeviation) {
      if(signal.direction == ORDER_TYPE_BUY) {
         request.price = lastTick.ask;
      } else {
         request.price = lastTick.bid;
      }
      
      if(m_logger != NULL) {
         m_logger.Info(StringFormat("RiskManager: Preço ajustado de %.5f para %.5f", 
                                  signal.entryPrice, request.price));
      }
   }
   
   // Validar stop loss com regras adicionais
   if(!ValidateStopLoss(symbol, request.type, request.price, request.stopLoss)) {
      request.volume = 0;
      if(m_circuitBreaker != NULL)
         m_circuitBreaker.RegisterError();
      return request;
   }
   
   // Encontrar índice do símbolo
   int index = FindSymbolIndex(symbol);
   double riskPercentage = (index >= 0) ? m_symbolParams[index].riskPercentage : m_defaultRiskPercentage;
   
   // ✅ CALCULAR VOLUME BASE
  double baseVolume = CalculatePositionSize(symbol, request.price, request.stopLoss, riskPercentage);

  if(baseVolume <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Volume calculado inválido para " + symbol);
      }
      request.volume = 0;
      if(m_circuitBreaker != NULL)
         m_circuitBreaker.RegisterError();
      return request;
  }

   // Controle automático de drawdown
   CDrawdownController *ddController = new CDrawdownController();
   ddController.UpdateDrawdownStatus();

   if(!ddController.IsTradingAllowed())
   {
      if(m_logger != NULL)
         m_logger.Warning("Trading paused due to excessive drawdown");
      request.volume = 0;
      if(m_circuitBreaker != NULL)
         m_circuitBreaker.RegisterError();
      delete ddController;
      return request;
   }

   double ddAdjustment = ddController.GetVolumeAdjustment();
   baseVolume         *= ddAdjustment;
   if(m_metricsCollector != NULL && ddAdjustment < 1.0)
      m_metricsCollector.RecordDrawdownIntervention(ddController.GetCurrentDrawdown(), ddAdjustment);

   if(m_logger != NULL)
      m_logger.LogDrawdownControl(ddController.GetCurrentDrawdown(),
                                  ddController.GetCurrentLevel(),
                                  ddAdjustment,
                                  ddController.IsTradingAllowed() ? "CONTINUE" : "PAUSE");
   delete ddController;

   // Adjust position size based on market volatility
   if(m_handlePool != NULL)
   {
      CVolatilityAdjuster volatilityAdjuster(m_handlePool);
      volatilityAdjuster.UpdateBaseline(symbol);
      double volatilityFactor = volatilityAdjuster.CalculateVolatilityAdjustment(symbol);
      double currentATR       = volatilityAdjuster.GetCurrentATR(symbol);
      double baseline         = volatilityAdjuster.GetBaselineVolatility(symbol);
      double beforeVol        = baseVolume;
      baseVolume             *= volatilityFactor;
      if(m_metricsCollector != NULL && volatilityFactor != 1.0)
         m_metricsCollector.RecordVolumeAdjustment(beforeVol, baseVolume, "Volatility");

      if(m_logger != NULL)
         m_logger.LogVolatilityAdjustment(symbol, currentATR, baseline, volatilityFactor, "");
   }

   // ✅ NOVA LÓGICA: GARANTIR VOLUME ADEQUADO PARA PARCIAIS
   if(index >= 0 && m_symbolParams[index].usePartials) {
      
      // Obter características do ativo
      LotCharacteristics lotChar = GetLotCharacteristics(symbol);
      double minVolumeForPartials = m_symbolParams[index].minVolumeForPartials;
      
      // ✅ CORREÇÃO CRÍTICA: Verificar se volume base é suficiente para parciais
      if(baseVolume < minVolumeForPartials) {
         
         double originalVolume = baseVolume;
         
         // ✅ ESTRATÉGIA 1: Escalonamento automático por tiers se permitido
         if(m_symbolParams[index].allowVolumeScaling) {

            double requiredFactor = minVolumeForPartials / baseVolume;
            double tier = GetScalingTier(signal.quality, requiredFactor, m_symbolParams[index].maxScalingFactor);

            if(tier > 0) {
               baseVolume = originalVolume * tier;

               if(m_logger != NULL) {
                  m_logger.LogVolumeScaling(symbol, signal.quality, originalVolume, baseVolume,
                                         "Tier selection");

                  double qualityLimit = 1.0;
                  switch(signal.quality) {
                     case SETUP_A_PLUS: qualityLimit = 5.0; break;
                     case SETUP_A:      qualityLimit = 3.0; break;
                     case SETUP_B:      qualityLimit = 2.0; break;
                     case SETUP_C:      qualityLimit = 1.0; break;
                     default:           qualityLimit = 1.0; break;
                  }

                  m_logger.Info(StringFormat("Setup Quality: %s | Max Allowed: %.1fx | Selected Tier: %.1fx | Reason: Quality-based limit",
                                           EnumToString(signal.quality), qualityLimit, tier));
               }
            } else {
               // ✅ ESTRATÉGIA 2: Escalonamento limitado
               baseVolume = originalVolume * m_symbolParams[index].maxScalingFactor;

               if(m_logger != NULL) {
                  m_logger.Warning(StringFormat("⚠️ VOLUME ESCALADO LIMITADO para %s: %.2f → %.2f lotes (máximo: %.1fx)",
                                              symbol, originalVolume, baseVolume, m_symbolParams[index].maxScalingFactor));
               }
            }
         } else {
            // ✅ ESTRATÉGIA 3: Aumentar percentual de risco automaticamente
            double requiredRiskPercentage = riskPercentage * (minVolumeForPartials / baseVolume);
            
            // Limitar aumento de risco a 3x o original
            if(requiredRiskPercentage <= riskPercentage * 3.0) {
               baseVolume = CalculatePositionSize(symbol, request.price, request.stopLoss, requiredRiskPercentage);
               
               if(m_logger != NULL) {
                  m_logger.Info(StringFormat("✅ RISCO AJUSTADO para %s: %.1f%% → %.1f%% (volume: %.2f → %.2f lotes)", 
                                           symbol, riskPercentage, requiredRiskPercentage, originalVolume, baseVolume));
               }
            } else {
               if(m_logger != NULL) {
                  m_logger.Warning(StringFormat("⚠️ VOLUME INSUFICIENTE para parciais em %s: %.2f lotes (mínimo: %.2f)", 
                                              symbol, baseVolume, minVolumeForPartials));
               }
            }
         }
      }
      
      // ✅ APLICAR SISTEMA DE PARCIAIS UNIVERSAL COM VOLUME CORRIGIDO
      // Preparar arrays de percentuais e níveis
      double percentages[10];
      double levels[10];
      int numPartials = 0;
      
      for(int i = 0; i < 10; i++) {
         if(m_symbolParams[index].partialVolumes[i] > 0) {
            percentages[numPartials] = m_symbolParams[index].partialVolumes[i];
            levels[numPartials] = m_symbolParams[index].partialLevels[i];
            numPartials++;
         }
      }
      
      if(numPartials > 0) {
         // ✅ USAR SISTEMA UNIVERSAL COM VOLUME ADEQUADO
         AdaptivePartialConfig partialConfig = CalculateUniversalPartials(
            symbol,
            baseVolume,  // Volume já ajustado para parciais
            percentages,
            levels,
            numPartials,
            signal.quality
         );
         
         // Aplicar configuração calculada
         request.volume = partialConfig.finalVolume;
         
         // Salvar configuração para uso posterior
         m_symbolParams[index].lastPartialConfig = partialConfig;
         
         if(m_logger != NULL) {
            if(partialConfig.enabled) {
               m_logger.Info(StringFormat("✅ PARCIAIS UNIVERSAIS HABILITADAS para %s: %.3f lotes (estratégia: %s)", 
                                        symbol, request.volume, EnumToString(partialConfig.strategy)));
            } else {
               m_logger.Warning(StringFormat("❌ PARCIAIS DESABILITADAS para %s: %s", 
                                           symbol, partialConfig.reason));
            }
         }
      } else {
         request.volume = baseVolume;
      }
   } else {
      request.volume = baseVolume;
   }
   
   // Aplicar limite máximo se configurado
   if(index >= 0 && m_symbolParams[index].maxLotSize > 0) {
      if(request.volume > m_symbolParams[index].maxLotSize) {
         if(m_logger != NULL) {
            m_logger.Warning(StringFormat("Volume limitado para %s: %.2f → %.2f lotes (máximo configurado)", 
                                        symbol, request.volume, m_symbolParams[index].maxLotSize));
         }
         request.volume = m_symbolParams[index].maxLotSize;
      }
   }
   
   // Ajustar para lotes válidos
   request.volume = AdjustLotSize(symbol, request.volume);

   if(m_metricsCollector != NULL)
      m_metricsCollector.RecordScaling(signal.quality, request.volume);

   // Validação final
   if(request.volume <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Volume final inválido para " + symbol);
      }
      if(m_circuitBreaker != NULL)
         m_circuitBreaker.RegisterError();
      return request;
   }
   
   // Preencher dados finais
   request.signalId = signal.id;
   request.id = (int)GetTickCount();
   
   if(m_logger != NULL) {
      m_logger.Info(StringFormat("✅ REQUISIÇÃO CRIADA para %s: %.3f lotes, preço %.5f, SL %.5f, TP %.5f", 
                                symbol, request.volume, request.price, request.stopLoss, request.takeProfit));
   }
   
   if(m_circuitBreaker != NULL)
      m_circuitBreaker.RegisterSuccess();
   return request;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÕES ORIGINAIS MANTIDAS: Gestão de posições              |
//+------------------------------------------------------------------+

double CRiskManager::CalculateStopLoss(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice, MARKET_PHASE phase) {
   // Implementação original mantida
   int index = FindSymbolIndex(symbol);
   if(index < 0) return 0;
   
   double stopPoints = m_symbolParams[index].defaultStopPoints;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(orderType == ORDER_TYPE_BUY) {
      return entryPrice - (stopPoints * point);
   } else {
      return entryPrice + (stopPoints * point);
   }
}

double CRiskManager::CalculateTakeProfit(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice, double stopLoss) {
   // Implementação original mantida
   double riskPoints = MathAbs(entryPrice - stopLoss);
   double rewardPoints = riskPoints * 2.0; // R:R 1:2
   
   if(orderType == ORDER_TYPE_BUY) {
      return entryPrice + rewardPoints;
   } else {
      return entryPrice - rewardPoints;
   }
}


double CRiskManager::GetCurrentTotalRisk() {
   // Implementação original mantida
   return 0; // Placeholder
}

#endif // RISKMANAGER_MQH

