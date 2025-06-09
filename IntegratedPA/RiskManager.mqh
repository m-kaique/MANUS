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
#include "Constants.mqh"

//+------------------------------------------------------------------+
//| Classe para gestão de risco e dimensionamento de posições        |
//+------------------------------------------------------------------+
class CRiskManager {
private:
   // Objetos internos
   CLogger*        m_logger;
   CMarketContext* m_marketContext;
   
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
   
   // ✅ MÉTODOS PRIVADOS ORIGINAIS MANTIDOS
   double CalculatePositionSize(string symbol, double entryPrice, double stopLoss, double riskPercentage);
   double AdjustLotSize(string symbol, double lotSize);
   double GetSymbolTickValue(string symbol);
   double GetSymbolPointValue(string symbol);
   int FindSymbolIndex(string symbol);
   double CalculateATRValue(string symbol, ENUM_TIMEFRAMES timeframe, int period);
   bool ValidateMarketPrice(string symbol, double &price);
   
   // ✅ NOVOS MÉTODOS PARA PARCIAIS UNIVERSAIS - CORRIGIDOS PARA MQL5
   ASSET_TYPE ClassifyAssetType(string symbol);
   LotCharacteristics GetLotCharacteristics(string symbol);
   AdaptivePartialConfig CalculateUniversalPartials(string symbol, double baseVolume, 
                                                   double &originalPercentages[], 
                                                   double &originalLevels[], 
                                                   int numPartials);
   PARTIAL_STRATEGY DetermineOptimalStrategy(string symbol, double volume, 
                                           LotCharacteristics &lotChar, 
                                           double &percentages[], int numPartials);
   AdaptivePartialConfig ApplyScaledStrategy(string symbol, AdaptivePartialConfig &config, 
                                           LotCharacteristics &lotChar, 
                                           double &percentages[], int numPartials);
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

public:
   // ✅ CONSTRUTORES E DESTRUTOR ORIGINAIS MANTIDOS
   CRiskManager(double defaultRiskPercentage = 1.0, double maxTotalRisk = 5.0);
   ~CRiskManager();
   
   // ✅ MÉTODOS DE INICIALIZAÇÃO ORIGINAIS MANTIDOS
   bool Initialize(CLogger* logger, CMarketContext* marketContext);
   
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
//| ✅ IMPLEMENTAÇÃO - CONSTRUTORES E MÉTODOS ORIGINAIS MANTIDOS    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager(double defaultRiskPercentage = 1.0, double maxTotalRisk = 5.0) {
   m_logger = NULL;
   m_marketContext = NULL;
   m_defaultRiskPercentage = defaultRiskPercentage;
   m_maxTotalRisk = maxTotalRisk;
   m_accountBalance = 0;
   m_accountEquity = 0;
   m_accountFreeMargin = 0;
   
   // ✅ INICIALIZAR MÉTRICAS DE PARCIAIS
   m_partialMetrics.lastReset = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager() {
   // Nada a liberar, apenas objetos referenciados
}

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool CRiskManager::Initialize(CLogger* logger, CMarketContext* marketContext) {
   // Verificar parâmetros
   if(logger == NULL || marketContext == NULL) {
      Print("CRiskManager::Initialize - Logger ou MarketContext não podem ser NULL");
      return false;
   }
   
   // Atribuir objetos
   m_logger = logger;
   m_marketContext = marketContext;
   
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

//+------------------------------------------------------------------+
//| ✅ SISTEMA DE PARCIAIS UNIVERSAL - IMPLEMENTAÇÃO CORRIGIDA      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO: ClassifyAssetType                                    |
//| Classifica automaticamente o tipo de ativo                      |
//+------------------------------------------------------------------+
ASSET_TYPE CRiskManager::ClassifyAssetType(string symbol)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   
   // Validar informações do símbolo
   if (minLot <= 0 || stepLot <= 0 || maxLot <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("Informações de lote inválidas para %s: min=%.3f, step=%.3f, max=%.1f", 
                                     symbol, minLot, stepLot, maxLot));
      }
      return ASSET_UNKNOWN;
   }
   
   // Classificação baseada nas características de lote
   if (minLot <= 0.01 && stepLot <= 0.01)
   {
      // Ativos com lotes fracionários (Forex, Crypto)
      if (m_logger != NULL)
      {
         m_logger.Debug(StringFormat("%s classificado como ASSET_FRACTIONAL (min=%.3f, step=%.3f)", 
                                   symbol, minLot, stepLot));
      }
      return ASSET_FRACTIONAL;
   }
   else if (minLot >= 100.0)
   {
      // Ativos com lotes grandes (Ações em lotes de 100)
      if (m_logger != NULL)
      {
         m_logger.Debug(StringFormat("%s classificado como ASSET_LARGE_LOT (min=%.1f)", 
                                   symbol, minLot));
      }
      return ASSET_LARGE_LOT;
   }
   else if (minLot >= 1.0 && stepLot >= 1.0)
   {
      // Ativos com lotes inteiros (Futuros brasileiros)
      if (m_logger != NULL)
      {
         m_logger.Debug(StringFormat("%s classificado como ASSET_INTEGER (min=%.1f, step=%.1f)", 
                                   symbol, minLot, stepLot));
      }
      return ASSET_INTEGER;
   }
   
   // Caso não se encaixe em nenhuma categoria conhecida
   if (m_logger != NULL)
   {
      m_logger.Warning(StringFormat("%s não se encaixa em nenhuma categoria conhecida (min=%.3f, step=%.3f)", 
                                  symbol, minLot, stepLot));
   }
   return ASSET_UNKNOWN;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO: GetLotCharacteristics                                |
//| Obtém características completas de lote para um símbolo         |
//+------------------------------------------------------------------+
LotCharacteristics CRiskManager::GetLotCharacteristics(string symbol)
{
   LotCharacteristics lotChar;
   
   // Obter informações básicas do símbolo
   lotChar.minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   lotChar.maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   lotChar.stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Classificar tipo de ativo
   lotChar.type = ClassifyAssetType(symbol);
   
   // Determinar suporte a parciais e estratégia recomendada
   switch (lotChar.type)
   {
      case ASSET_FRACTIONAL:
         lotChar.supportsPartials = true;
         lotChar.minVolumeForPartials = 0.03; // 3 parciais de 0.01 cada
         lotChar.recommendedStrategy = PARTIAL_STRATEGY_ORIGINAL;
         break;
         
      case ASSET_INTEGER:
         lotChar.supportsPartials = true;
         lotChar.minVolumeForPartials = 10.0; // 10 lotes para parciais efetivas
         lotChar.recommendedStrategy = PARTIAL_STRATEGY_ADAPTIVE;
         break;
         
      case ASSET_LARGE_LOT:
         lotChar.supportsPartials = false;
         lotChar.minVolumeForPartials = 1000.0; // Muito alto, desencorajar parciais
         lotChar.recommendedStrategy = PARTIAL_STRATEGY_DISABLED;
         break;
         
      default:
         lotChar.supportsPartials = false;
         lotChar.minVolumeForPartials = 0.0;
         lotChar.recommendedStrategy = PARTIAL_STRATEGY_CONDITIONAL;
         break;
   }
   
   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Características de %s: tipo=%s, suporta_parciais=%s, vol_min=%.2f", 
                                symbol, EnumToString(lotChar.type), 
                                lotChar.supportsPartials ? "SIM" : "NÃO", 
                                lotChar.minVolumeForPartials));
   }
   
   return lotChar;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: CalculateUniversalPartials                |
//| Calcula parciais universais para qualquer tipo de ativo        |
//+------------------------------------------------------------------+
AdaptivePartialConfig CRiskManager::CalculateUniversalPartials(string symbol, double baseVolume, 
                                                              double &originalPercentages[], 
                                                              double &originalLevels[], 
                                                              int numPartials)
{
   AdaptivePartialConfig config;
   
   // Inicializar configuração
   config.originalVolume = baseVolume;
   config.finalVolume = baseVolume;
   config.numPartials = numPartials;
   
   // Copiar percentuais originais
   for (int i = 0; i < numPartials && i < 10; i++)
   {
      config.originalPercentages[i] = originalPercentages[i];
      config.adaptedPercentages[i] = originalPercentages[i];
   }
   
   // Obter características do ativo
   LotCharacteristics lotChar = GetLotCharacteristics(symbol);
   
   // Determinar estratégia baseada no tipo de ativo e volume
   PARTIAL_STRATEGY strategy = DetermineOptimalStrategy(symbol, baseVolume, lotChar, originalPercentages, numPartials);
   config.strategy = strategy;
   
   // Aplicar estratégia escolhida
   switch (strategy)
   {
      case PARTIAL_STRATEGY_ORIGINAL:
         config.enabled = true;
         config.reason = "Ativo suporta lotes fracionários";
         break;
         
      case PARTIAL_STRATEGY_SCALED:
         config = ApplyScaledStrategy(symbol, config, lotChar, originalPercentages, numPartials);
         break;
         
      case PARTIAL_STRATEGY_ADAPTIVE:
         config = ApplyAdaptiveStrategy(symbol, config, lotChar, originalPercentages, numPartials);
         break;
         
      case PARTIAL_STRATEGY_CONDITIONAL:
         config = ApplyConditionalStrategy(symbol, config, lotChar, originalPercentages, numPartials);
         break;
         
      case PARTIAL_STRATEGY_DISABLED:
         config.enabled = false;
         config.reason = "Tipo de ativo não suporta parciais efetivas";
         break;
   }
   
   // Validar configuração final
   if (config.enabled)
   {
      config.enabled = ValidateUniversalPartials(symbol, config.finalVolume, config.adaptedPercentages, numPartials);
      if (!config.enabled)
      {
         config.reason = "Validação final falhou";
      }
   }
   
   // Log da decisão
   LogPartialDecision(symbol, config);
   
   // ✅ ATUALIZAR MÉTRICAS
   UpdatePartialMetrics(config);
   
   return config;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: DetermineOptimalStrategy                  |
//| Determina a estratégia ótima baseada nas características        |
//+------------------------------------------------------------------+
PARTIAL_STRATEGY CRiskManager::DetermineOptimalStrategy(string symbol, double volume, 
                                                       LotCharacteristics &lotChar, 
                                                       double &percentages[], int numPartials)
{
   // Para ativos fracionários, sempre usar estratégia original
   if (lotChar.type == ASSET_FRACTIONAL)
   {
      return PARTIAL_STRATEGY_ORIGINAL;
   }
   
   // Para ativos com lotes grandes, desabilitar parciais
   if (lotChar.type == ASSET_LARGE_LOT)
   {
      return PARTIAL_STRATEGY_DISABLED;
   }
   
   // Para ativos com lotes inteiros (WIN$, WDO$)
   if (lotChar.type == ASSET_INTEGER)
   {
      // Verificar se volume é suficiente para parciais diretas
      bool canUseDirectPartials = true;
      for (int i = 0; i < numPartials; i++)
      {
         if (percentages[i] > 0)
         {
            double partialVolume = volume * percentages[i];
            if (partialVolume < lotChar.minLot)
            {
               canUseDirectPartials = false;
               break;
            }
         }
      }
      
      if (canUseDirectPartials)
      {
         return PARTIAL_STRATEGY_ADAPTIVE; // Adaptar percentuais
      }
      
      // Verificar se vale a pena escalar volume
      if (volume < lotChar.minVolumeForPartials)
      {
         double scalingFactor = lotChar.minVolumeForPartials / volume;
         if (scalingFactor <= 3.0) // Máximo 3x o volume original
         {
            return PARTIAL_STRATEGY_SCALED;
         }
      }
      
      // Se não for viável escalar, usar estratégia condicional
      return PARTIAL_STRATEGY_CONDITIONAL;
   }
   
   // Para tipos desconhecidos, usar estratégia condicional
   return PARTIAL_STRATEGY_CONDITIONAL;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ApplyScaledStrategy                       |
//| Aplica estratégia de volume escalado                            |
//+------------------------------------------------------------------+
AdaptivePartialConfig CRiskManager::ApplyScaledStrategy(string symbol, AdaptivePartialConfig &config, 
                                                       LotCharacteristics &lotChar, 
                                                       double &percentages[], int numPartials)
{
   // Encontrar menor percentual
   double smallestPercentage = 1.0;
   for (int i = 0; i < numPartials; i++)
   {
      if (percentages[i] > 0)
      {
         smallestPercentage = MathMin(smallestPercentage, percentages[i]);
      }
   }
   
   // Calcular volume mínimo necessário
   double minVolumeNeeded = lotChar.minLot / smallestPercentage;
   
   // Arredondar para cima para o próximo lote inteiro
   minVolumeNeeded = MathCeil(minVolumeNeeded / lotChar.minLot) * lotChar.minLot;
   
   // Aplicar escalonamento
   config.finalVolume = MathMax(config.originalVolume, minVolumeNeeded);
   config.volumeWasScaled = (config.finalVolume > config.originalVolume);
   config.scalingFactor = config.finalVolume / config.originalVolume;
   config.enabled = true;
   config.reason = StringFormat("Volume escalado %.1fx para permitir parciais", config.scalingFactor);
   
   if (m_logger != NULL)
   {
      m_logger.Info(StringFormat("Volume escalado para %s: %.2f → %.2f (fator: %.1fx)", 
                                symbol, config.originalVolume, config.finalVolume, config.scalingFactor));
   }
   
   return config;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ApplyAdaptiveStrategy                     |
//| Aplica estratégia de parciais adaptativas                       |
//+------------------------------------------------------------------+
AdaptivePartialConfig CRiskManager::ApplyAdaptiveStrategy(string symbol, AdaptivePartialConfig &config, 
                                                         LotCharacteristics &lotChar, 
                                                         double &percentages[], int numPartials)
{
   double totalAdaptedVolume = 0;
   int adaptedLots[10];
   
   // Calcular lotes inteiros para cada parcial
   for (int i = 0; i < numPartials && i < 10; i++)
   {
      if (percentages[i] > 0)
      {
         double partialVolume = config.finalVolume * percentages[i];
         adaptedLots[i] = (int)MathMax(1, MathRound(partialVolume / lotChar.minLot));
         totalAdaptedVolume += adaptedLots[i] * lotChar.minLot;
      }
      else
      {
         adaptedLots[i] = 0;
      }
   }
   
   // Verificar se adaptação é viável
   if (totalAdaptedVolume > config.originalVolume * 1.5) // Tolerância de 50%
   {
      config.enabled = false;
      config.reason = StringFormat("Adaptação resultaria em volume muito alto (%.1f vs %.1f)", 
                                  totalAdaptedVolume, config.originalVolume);
      return config;
   }
   
   // Atualizar volume final e calcular percentuais adaptados
   config.finalVolume = totalAdaptedVolume;
   for (int i = 0; i < numPartials && i < 10; i++)
   {
      if (adaptedLots[i] > 0)
      {
         config.adaptedPercentages[i] = (adaptedLots[i] * lotChar.minLot) / totalAdaptedVolume;
      }
      else
      {
         config.adaptedPercentages[i] = 0;
      }
   }
   
   config.enabled = true;
   config.reason = StringFormat("Percentuais adaptados para lotes inteiros (volume: %.1f)", totalAdaptedVolume);
   
   if (m_logger != NULL)
   {
      m_logger.Info(StringFormat("Parciais adaptadas para %s: volume %.1f → %.1f", 
                                symbol, config.originalVolume, config.finalVolume));
   }
   
   return config;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ApplyConditionalStrategy                  |
//| Aplica estratégia condicional (desabilita se não viável)        |
//+------------------------------------------------------------------+
AdaptivePartialConfig CRiskManager::ApplyConditionalStrategy(string symbol, AdaptivePartialConfig &config, 
                                                           LotCharacteristics &lotChar, 
                                                           double &percentages[], int numPartials)
{
   // Verificar se cada parcial é viável
   for (int i = 0; i < numPartials; i++)
   {
      if (percentages[i] > 0)
      {
         double partialVolume = config.finalVolume * percentages[i];
         if (partialVolume < lotChar.minLot)
         {
            config.enabled = false;
            config.reason = StringFormat("Parcial %d resultaria em %.3f lotes (< %.1f mínimo)", 
                                        i+1, partialVolume, lotChar.minLot);
            return config;
         }
      }
   }
   
   // Se chegou até aqui, parciais são viáveis
   config.enabled = true;
   config.reason = "Parciais viáveis com volume atual";
   
   return config;
}


//+------------------------------------------------------------------+
//| ✅ FUNÇÕES DE VALIDAÇÃO ESPECÍFICAS - CORRIGIDAS PARA MQL5     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ValidateFractionalPartials                |
//| Valida parciais para ativos com lotes fracionários              |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateFractionalPartials(string symbol, double totalVolume, double &partialPercentages[], int numPartials)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Usar valores padrão se informações inválidas
   if (minLot <= 0) minLot = 0.01;
   if (stepLot <= 0) stepLot = 0.01;
   
   // Para ativos fracionários, validação é mais simples
   double totalPercentage = 0;
   double minPartialVolume = totalVolume;
   
   for (int i = 0; i < numPartials; i++)
   {
      if (partialPercentages[i] > 0)
      {
         totalPercentage += partialPercentages[i];
         
         double partialVolume = totalVolume * partialPercentages[i];
         minPartialVolume = MathMin(minPartialVolume, partialVolume);
         
         // Verificar se parcial é maior que lote mínimo
         if (partialVolume < minLot)
         {
            if (m_logger != NULL)
            {
               m_logger.Warning(StringFormat("Parcial %d para %s muito pequena: %.3f < %.3f (mínimo)", 
                                           i+1, symbol, partialVolume, minLot));
            }
            return false;
         }
         
         // Verificar se parcial é múltiplo do step
         double remainder = fmod(partialVolume, stepLot);
         if (remainder > stepLot * 0.01) // Tolerância de 1%
         {
            if (m_logger != NULL)
            {
               m_logger.Debug(StringFormat("Parcial %d para %s será ajustada para step: %.3f → %.3f", 
                                         i+1, symbol, partialVolume, 
                                         MathFloor(partialVolume / stepLot) * stepLot));
            }
         }
      }
   }
   
   // Verificar soma dos percentuais
   if (MathAbs(totalPercentage - 1.0) > 0.01)
   {
      if (m_logger != NULL)
      {
         m_logger.Error(StringFormat("Soma dos percentuais inválida para %s: %.3f (deveria ser 1.0)", 
                                   symbol, totalPercentage));
      }
      return false;
   }
   
   // Verificar volume mínimo total
   if (totalVolume < minLot)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("Volume total muito pequeno para %s: %.3f < %.3f", 
                                     symbol, totalVolume, minLot));
      }
      return false;
   }
   
   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Validação de parciais fracionárias para %s: APROVADA (volume: %.3f, menor parcial: %.3f)", 
                                symbol, totalVolume, minPartialVolume));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ValidateIntegerPartials                   |
//| Valida parciais para ativos com lotes inteiros (WIN$, WDO$)     |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateIntegerPartials(string symbol, double totalVolume, double &partialPercentages[], int numPartials)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Usar valores padrão se informações inválidas
   if (minLot <= 0) minLot = 1.0;
   if (stepLot <= 0) stepLot = 1.0;
   
   double totalPercentage = 0;
   double totalCalculatedVolume = 0;
   int validPartials = 0;
   
   for (int i = 0; i < numPartials; i++)
   {
      if (partialPercentages[i] > 0)
      {
         totalPercentage += partialPercentages[i];
         
         double partialVolume = totalVolume * partialPercentages[i];
         
         // Para lotes inteiros, verificar se resulta em pelo menos 1 lote
         if (partialVolume < minLot)
         {
            if (m_logger != NULL)
            {
               m_logger.Warning(StringFormat("Parcial %d para %s insuficiente: %.2f < %.0f lote(s)", 
                                           i+1, symbol, partialVolume, minLot));
            }
            return false;
         }
         
         // Calcular lotes inteiros
         int lots = (int)MathRound(partialVolume / minLot);
         double adjustedVolume = lots * minLot;
         totalCalculatedVolume += adjustedVolume;
         validPartials++;
         
         if (m_logger != NULL)
         {
            m_logger.Debug(StringFormat("Parcial %d para %s: %.2f → %d lote(s) (%.2f)", 
                                      i+1, symbol, partialVolume, lots, adjustedVolume));
         }
      }
   }
   
   // Verificar soma dos percentuais
   if (MathAbs(totalPercentage - 1.0) > 0.01)
   {
      if (m_logger != NULL)
      {
         m_logger.Error(StringFormat("Soma dos percentuais inválida para %s: %.3f (deveria ser 1.0)", 
                                   symbol, totalPercentage));
      }
      return false;
   }
   
   // Verificar se há pelo menos 2 parciais válidas
   if (validPartials < 2)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("Parciais insuficientes para %s: apenas %d válida(s)", 
                                     symbol, validPartials));
      }
      return false;
   }
   
   // Verificar se volume total ajustado não excede muito o original
   double volumeIncrease = ((totalCalculatedVolume - totalVolume) / totalVolume) * 100;
   if (volumeIncrease > 50.0) // Tolerância de 50%
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("Volume ajustado muito alto para %s: %.1f → %.1f (+%.1f%%)", 
                                     symbol, totalVolume, totalCalculatedVolume, volumeIncrease));
      }
      return false;
   }
   
   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Validação de parciais inteiras para %s: APROVADA (volume: %.1f → %.1f, parciais: %d)", 
                                symbol, totalVolume, totalCalculatedVolume, validPartials));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ValidateLargeLotPartials                  |
//| Valida parciais para ativos com lotes grandes (ações)           |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateLargeLotPartials(string symbol, double totalVolume, double &partialPercentages[], int numPartials)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   
   // Usar valor padrão se informação inválida
   if (minLot <= 0) minLot = 100.0; // Padrão para ações
   
   // Para ativos com lotes grandes, geralmente não recomendamos parciais
   if (minLot >= 100.0)
   {
      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("Parciais não recomendadas para %s (lote mínimo: %.0f)", 
                                  symbol, minLot));
      }
      return false;
   }
   
   // Se mesmo assim quiser validar, verificar viabilidade
   double totalPercentage = 0;
   int viablePartials = 0;
   
   for (int i = 0; i < numPartials; i++)
   {
      if (partialPercentages[i] > 0)
      {
         totalPercentage += partialPercentages[i];
         
         double partialVolume = totalVolume * partialPercentages[i];
         
         if (partialVolume >= minLot)
         {
            viablePartials++;
         }
         else
         {
            if (m_logger != NULL)
            {
               m_logger.Warning(StringFormat("Parcial %d para %s inviável: %.0f < %.0f (lote mínimo)", 
                                           i+1, symbol, partialVolume, minLot));
            }
         }
      }
   }
   
   // Verificar soma dos percentuais
   if (MathAbs(totalPercentage - 1.0) > 0.01)
   {
      if (m_logger != NULL)
      {
         m_logger.Error(StringFormat("Soma dos percentuais inválida para %s: %.3f (deveria ser 1.0)", 
                                   symbol, totalPercentage));
      }
      return false;
   }
   
   // Para lotes grandes, exigir volume muito alto para parciais
   double minVolumeForPartials = minLot * numPartials * 2; // Pelo menos 2x o mínimo por parcial
   if (totalVolume < minVolumeForPartials)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("Volume insuficiente para parciais em %s: %.0f < %.0f", 
                                     symbol, totalVolume, minVolumeForPartials));
      }
      return false;
   }
   
   // Verificar se há parciais viáveis suficientes
   if (viablePartials < 2)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("Parciais viáveis insuficientes para %s: apenas %d", 
                                     symbol, viablePartials));
      }
      return false;
   }
   
   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Validação de parciais para lotes grandes %s: APROVADA (volume: %.0f, parciais viáveis: %d)", 
                                symbol, totalVolume, viablePartials));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ValidateUniversalPartials                 |
//| Valida parciais usando a função específica do tipo de ativo     |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateUniversalPartials(string symbol, double totalVolume, double &partialPercentages[], int numPartials)
{
   // Obter tipo de ativo
   ASSET_TYPE assetType = ClassifyAssetType(symbol);
   
   // Chamar função de validação específica
   switch (assetType)
   {
      case ASSET_FRACTIONAL:
         return ValidateFractionalPartials(symbol, totalVolume, partialPercentages, numPartials);
         
      case ASSET_INTEGER:
         return ValidateIntegerPartials(symbol, totalVolume, partialPercentages, numPartials);
         
      case ASSET_LARGE_LOT:
         return ValidateLargeLotPartials(symbol, totalVolume, partialPercentages, numPartials);
         
      default:
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Tipo de ativo desconhecido para %s, usando validação condicional", symbol));
         }
         return ValidateIntegerPartials(symbol, totalVolume, partialPercentages, numPartials);
   }
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÕES AUXILIARES                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO: LogPartialDecision                                   |
//| Registra logs detalhados da decisão de parciais                 |
//+------------------------------------------------------------------+
void CRiskManager::LogPartialDecision(string symbol, AdaptivePartialConfig &config)
{
   if (m_logger == NULL) return;
   
   m_logger.Info(StringFormat("=== DECISÃO DE PARCIAIS PARA %s ===", symbol));
   m_logger.Info(StringFormat("Estratégia: %s", EnumToString(config.strategy)));
   m_logger.Info(StringFormat("Habilitado: %s", config.enabled ? "SIM" : "NÃO"));
   m_logger.Info(StringFormat("Razão: %s", config.reason));
   m_logger.Info(StringFormat("Volume: %.3f → %.3f", config.originalVolume, config.finalVolume));
   
   if (config.volumeWasScaled)
   {
      m_logger.Info(StringFormat("Volume escalado: %.1fx", config.scalingFactor));
   }
   
   if (config.enabled)
   {
      for (int i = 0; i < config.numPartials; i++)
      {
         if (config.originalPercentages[i] > 0)
         {
            double originalLots = config.originalVolume * config.originalPercentages[i];
            double finalLots = config.finalVolume * config.adaptedPercentages[i];
            
            m_logger.Info(StringFormat("Parcial %d: %.1f%% (%.2f lotes) → %.1f%% (%.2f lotes)", 
                                     i+1, 
                                     config.originalPercentages[i] * 100, originalLots,
                                     config.adaptedPercentages[i] * 100, finalLots));
         }
      }
   }
   
   m_logger.Info("=== FIM DA DECISÃO DE PARCIAIS ===");
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO: UpdatePartialMetrics                                |
//| Atualiza métricas de performance das parciais                   |
//+------------------------------------------------------------------+
void CRiskManager::UpdatePartialMetrics(AdaptivePartialConfig &config)
{
   m_partialMetrics.totalOperations++;
   m_partialMetrics.totalVolumeOriginal += config.originalVolume;
   m_partialMetrics.totalVolumeFinal += config.finalVolume;
   
   if (config.enabled)
   {
      m_partialMetrics.operationsWithPartials++;
      
      if (config.volumeWasScaled)
      {
         m_partialMetrics.operationsScaled++;
      }
      
      if (config.strategy == PARTIAL_STRATEGY_ADAPTIVE)
      {
         m_partialMetrics.operationsAdapted++;
      }
   }
   else
   {
      m_partialMetrics.operationsDisabled++;
   }
   
   // Calcular médias
   if (m_partialMetrics.totalOperations > 0)
   {
      m_partialMetrics.avgVolumeIncrease = 
         ((m_partialMetrics.totalVolumeFinal - m_partialMetrics.totalVolumeOriginal) / 
          m_partialMetrics.totalVolumeOriginal) * 100.0;
          
      m_partialMetrics.avgPartialEfficiency = 
         (double)m_partialMetrics.operationsWithPartials / m_partialMetrics.totalOperations * 100.0;
   }
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO: ResetPartialMetrics                                 |
//| Reinicializa métricas de parciais                               |
//+------------------------------------------------------------------+
void CRiskManager::ResetPartialMetrics()
{
   m_partialMetrics.totalOperations = 0;
   m_partialMetrics.operationsWithPartials = 0;
   m_partialMetrics.operationsScaled = 0;
   m_partialMetrics.operationsAdapted = 0;
   m_partialMetrics.operationsDisabled = 0;
   m_partialMetrics.totalVolumeOriginal = 0.0;
   m_partialMetrics.totalVolumeFinal = 0.0;
   m_partialMetrics.avgVolumeIncrease = 0.0;
   m_partialMetrics.avgPartialEfficiency = 0.0;
   m_partialMetrics.lastReset = TimeCurrent();
   
   if (m_logger != NULL)
   {
      m_logger.Info("Métricas de parciais universais reinicializadas");
   }
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO: GetPartialReport                                    |
//| Gera relatório de parciais para um símbolo                      |
//+------------------------------------------------------------------+
string CRiskManager::GetPartialReport(string symbol)
{
   int index = FindSymbolIndex(symbol);
   
   if (index < 0)
   {
      return StringFormat("Símbolo %s não encontrado", symbol);
   }
   
   string report = StringFormat("=== RELATÓRIO DE PARCIAIS: %s ===\n", symbol);
   report += StringFormat("Tipo de Ativo: %s\n", EnumToString(m_symbolParams[index].assetType));
   report += StringFormat("Estratégia: %s\n", EnumToString(m_symbolParams[index].partialStrategy));
   report += StringFormat("Volume Mínimo: %.2f\n", m_symbolParams[index].minVolumeForPartials);
   report += StringFormat("Permite Escalonamento: %s\n", m_symbolParams[index].allowVolumeScaling ? "SIM" : "NÃO");
   report += StringFormat("Fator Máximo: %.1fx\n", m_symbolParams[index].maxScalingFactor);
   
   // Características de lote
   report += StringFormat("Lote Mínimo: %.3f\n", m_symbolParams[index].lotChar.minLot);
   report += StringFormat("Lote Máximo: %.1f\n", m_symbolParams[index].lotChar.maxLot);
   report += StringFormat("Step: %.3f\n", m_symbolParams[index].lotChar.stepLot);
   
   // Última configuração
   if (m_symbolParams[index].lastPartialConfig.enabled)
   {
      report += "\n--- ÚLTIMA CONFIGURAÇÃO ---\n";
      report += StringFormat("Volume: %.3f → %.3f\n", 
                           m_symbolParams[index].lastPartialConfig.originalVolume,
                           m_symbolParams[index].lastPartialConfig.finalVolume);
      report += StringFormat("Escalado: %s\n", 
                           m_symbolParams[index].lastPartialConfig.volumeWasScaled ? "SIM" : "NÃO");
      report += StringFormat("Razão: %s\n", m_symbolParams[index].lastPartialConfig.reason);
   }
   
   return report;
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
//| ✅ FUNÇÃO ORIGINAL MANTIDA: CalculatePositionSize              |
//+------------------------------------------------------------------+
double CRiskManager::CalculatePositionSize(string symbol, double entryPrice, double stopLoss, double riskPercentage) {
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
//| ✅ FUNÇÃO PRINCIPAL MODIFICADA: BuildRequest                   |
//| Integra o sistema de parciais universal                         |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: BuildRequest                               |
//| Garante volume adequado para parciais efetivas                  |
//+------------------------------------------------------------------+
OrderRequest CRiskManager::BuildRequest(string symbol, Signal &signal, MARKET_PHASE phase) {
   OrderRequest request;
   
   // Preencher dados básicos
   request.symbol = symbol;
   request.type = signal.direction;
   
   // Validar símbolo
   if(symbol == "" || StringLen(symbol) == 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Símbolo inválido para construção de requisição");
      }
      request.volume = 0;
      return request;
   }
   
   // Validar preço de mercado
   double marketPrice = 0;
   if(!ValidateMarketPrice(symbol, marketPrice)) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Falha ao validar preço de mercado para " + symbol);
      }
      request.volume = 0;
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
   
   // Validar stop loss
   if(request.stopLoss <= 0 || 
      (signal.direction == ORDER_TYPE_BUY && request.stopLoss >= request.price) ||
      (signal.direction == ORDER_TYPE_SELL && request.stopLoss <= request.price)) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Stop loss inválido do sinal para " + symbol);
      }
      request.volume = 0;
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
      return request;
   }
   
   // ✅ NOVA LÓGICA: GARANTIR VOLUME ADEQUADO PARA PARCIAIS
   if(index >= 0 && m_symbolParams[index].usePartials) {
      
      // Obter características do ativo
      LotCharacteristics lotChar = GetLotCharacteristics(symbol);
      double minVolumeForPartials = m_symbolParams[index].minVolumeForPartials;
      
      // ✅ CORREÇÃO CRÍTICA: Verificar se volume base é suficiente para parciais
      if(baseVolume < minVolumeForPartials) {
         
         double originalVolume = baseVolume;
         
         // ✅ ESTRATÉGIA 1: Escalonamento automático se permitido
         if(m_symbolParams[index].allowVolumeScaling) {
            
            double scalingFactor = minVolumeForPartials / baseVolume;
            
            // Limitar escalonamento ao fator máximo configurado
            if(scalingFactor <= m_symbolParams[index].maxScalingFactor) {
               baseVolume = minVolumeForPartials;
               
               if(m_logger != NULL) {
                  m_logger.Info(StringFormat("✅ VOLUME ESCALADO para %s: %.2f → %.2f lotes (fator: %.1fx) para permitir parciais", 
                                           symbol, originalVolume, baseVolume, scalingFactor));
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
            numPartials
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
   
   // Validação final
   if(request.volume <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Volume final inválido para " + symbol);
      }
      return request;
   }
   
   // Preencher dados finais
   request.signalId = signal.id;
   request.id = (int)GetTickCount();
   
   if(m_logger != NULL) {
      m_logger.Info(StringFormat("✅ REQUISIÇÃO CRIADA para %s: %.3f lotes, preço %.5f, SL %.5f, TP %.5f", 
                                symbol, request.volume, request.price, request.stopLoss, request.takeProfit));
   }
   
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

bool CRiskManager::ShouldTakePartial(string symbol, ulong ticket, double currentPrice, double entryPrice, double stopLoss) {
   // Implementação original mantida
   int index = FindSymbolIndex(symbol);
   if(index < 0 || !m_symbolParams[index].usePartials) return false;
   
   double riskPoints = MathAbs(entryPrice - stopLoss);
   double profitPoints = MathAbs(currentPrice - entryPrice);
   double currentRR = profitPoints / riskPoints;
   
   // Verificar se atingiu algum nível de parcial
   for(int i = 0; i < 10; i++) {
      if(m_symbolParams[index].partialLevels[i] > 0 && 
         currentRR >= m_symbolParams[index].partialLevels[i]) {
         return true;
      }
   }
   
   return false;
}

double CRiskManager::GetPartialVolume(string symbol, ulong ticket, double currentRR) {
   // Implementação original mantida
   int index = FindSymbolIndex(symbol);
   if(index < 0) return 0;
   
   for(int i = 0; i < 10; i++) {
      if(m_symbolParams[index].partialLevels[i] > 0 && 
         currentRR >= m_symbolParams[index].partialLevels[i]) {
         return m_symbolParams[index].partialVolumes[i];
      }
   }
   
   return 0;
}

double CRiskManager::GetCurrentTotalRisk() {
   // Implementação original mantida
   return 0; // Placeholder
}

#endif // RISKMANAGER_MQH

