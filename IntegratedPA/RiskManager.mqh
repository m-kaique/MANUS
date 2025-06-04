#ifndef RISKMANAGER_MQH_
#define RISKMANAGER_MQH_

//+------------------------------------------------------------------+
//|                                             RiskManager.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Inclusão de bibliotecas necessárias
#include "Structures.mqh"
#include "Logger.mqh"
#include "MarketContext.mqh"

//+------------------------------------------------------------------+
//| Classe para gestão de risco e dimensionamento de posições        |
//+------------------------------------------------------------------+
class CRiskManager {
public:
   // Estrutura para armazenar parâmetros específicos por símbolo (TORNADA PÚBLICA)
   struct SymbolRiskParams {
      string         symbol;
      double         riskPercentage;       // Risco base para cálculo de lote
      double         maxLotSize;           // Lote máximo permitido
      double         defaultStopPoints;    // Stop loss padrão em pontos (usado se ATR falhar)
      double         atrMultiplier;        // Multiplicador ATR para stop loss
      bool           usePartials;          // Usar fechamentos parciais?
      double         partialLevels[10];    // Níveis de R:R para parciais
      double         partialVolumes[10];   // Volumes para cada parcial (em %)
      
      // --- CAMPOS PARA CONSTANTES DE RISCO ---
      double         firstTargetPoints;    // Pontos para o primeiro TP
      double         spikeMaxStopPoints;   // Pontos máximos de SL em Spike
      double         channelMaxStopPoints; // Pontos máximos de SL em Canal
      double         trailingStopPoints;   // Pontos para Trailing Stop
   };

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
   
   // Array de parâmetros por símbolo
   SymbolRiskParams m_symbolParams[];
   
   // Métodos privados
   double CalculatePositionSize(string symbol, double entryPrice, double stopLoss, double riskPercentage);
   double AdjustLotSize(string symbol, double lotSize);
   double GetSymbolTickValue(string symbol);
   double GetSymbolPointValue(string symbol);
   int FindSymbolIndex(string symbol);
   double CalculateATRValue(string symbol, ENUM_TIMEFRAMES timeframe, int period);
   bool ValidateMarketPrice(string symbol, double &price);

public:
   // Construtores e destrutor
   CRiskManager(double defaultRiskPercentage = 1.0, double maxTotalRisk = 5.0);
   ~CRiskManager();
   
   // Métodos de inicialização
   bool Initialize(CLogger* logger, CMarketContext* marketContext);
   
   // Métodos de configuração
   void SetDefaultRiskPercentage(double percentage) { m_defaultRiskPercentage = percentage; }
   void SetMaxTotalRisk(double percentage) { m_maxTotalRisk = percentage; }
   
   // Métodos para configuração de símbolos
   bool AddSymbol(string symbol, double riskPercentage, double maxLotSize);
   bool ConfigureSymbolStopLoss(string symbol, double defaultStopPoints, double atrMultiplier);
   bool ConfigureSymbolPartials(string symbol, bool usePartials, double &levels[], double &volumes[]);
   bool ConfigureSymbolRiskConstants(string symbol, double tp1Points, double spikeStopPoints, double channelStopPoints, double trailingPoints);
   bool GetSymbolRiskParams(string symbol, SymbolRiskParams &params); // MODIFICADO: Pass-by-reference
   
   // Métodos para cálculo de risco
   OrderRequest BuildRequest(string symbol, Signal &signal, MARKET_PHASE phase);
   double CalculateStopLoss(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice, MARKET_PHASE phase);
   double CalculateTakeProfit(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice, double stopLoss);
   
   // Métodos para gestão de posições
   bool ShouldTakePartial(string symbol, ulong ticket, double currentPrice, double entryPrice, double stopLoss);
   double GetPartialVolume(string symbol, ulong ticket, double currentRR);
   
   // Métodos de acesso
   double GetCurrentTotalRisk();
   void UpdateAccountInfo();
};

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
   
   // Inicializar array de símbolos
   ArrayResize(m_symbolParams, 0);
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
   if(!logger || !marketContext) {
      Print("CRiskManager::Initialize - Logger ou MarketContext não podem ser NULL");
      return false;
   }
   
   // Atribuir objetos
   m_logger = logger;
   m_marketContext = marketContext;
   
   m_logger.Info("Inicializando RiskManager");
   
   // Atualizar informações da conta
   UpdateAccountInfo();
   
   m_logger.Info(StringFormat("RiskManager inicializado com risco padrão de %.2f%% e risco máximo de %.2f%%", 
                             m_defaultRiskPercentage, m_maxTotalRisk));
   
   return true;
}

//+------------------------------------------------------------------+
//| Adiciona um símbolo para gestão de risco                         |
//+------------------------------------------------------------------+
bool CRiskManager::AddSymbol(string symbol, double riskPercentage, double maxLotSize) {
   // Validar parâmetros
   if(symbol == "" || StringLen(symbol) == 0) {
      if(m_logger) {
         m_logger.Error("RiskManager: Símbolo inválido para AddSymbol");
      }
      return false;
   }
   
   if(riskPercentage <= 0 || riskPercentage > 100) {
      if(m_logger) {
         m_logger.Error("RiskManager: Percentual de risco inválido: " + DoubleToString(riskPercentage, 2));
      }
      return false;
   }
   
   if(maxLotSize <= 0) {
      if(m_logger) {
         m_logger.Error("RiskManager: Tamanho máximo de lote inválido: " + DoubleToString(maxLotSize, 2));
      }
      return false;
   }
   
   // Verificar se o símbolo já existe
   int existingIndex = FindSymbolIndex(symbol);
   if(existingIndex >= 0) {
      // Atualizar símbolo existente
      m_symbolParams[existingIndex].riskPercentage = riskPercentage;
      m_symbolParams[existingIndex].maxLotSize = maxLotSize;
      
      if(m_logger) {
         m_logger.Info("RiskManager: Símbolo " + symbol + " atualizado");
      }
      return true;
   }
   
   // Adicionar novo símbolo
   int newSize = ArraySize(m_symbolParams) + 1;
   if(ArrayResize(m_symbolParams, newSize) != newSize) {
      if(m_logger) {
         m_logger.Error("RiskManager: Falha ao redimensionar array para novo símbolo");
      }
      return false;
   }
   
   // Configurar parâmetros do novo símbolo
   int newIndex = newSize - 1;
   m_symbolParams[newIndex].symbol = symbol;
   m_symbolParams[newIndex].riskPercentage = riskPercentage;
   m_symbolParams[newIndex].maxLotSize = maxLotSize;
   m_symbolParams[newIndex].defaultStopPoints = 50.0; // Padrão
   m_symbolParams[newIndex].atrMultiplier = 2.0; // Padrão
   m_symbolParams[newIndex].usePartials = false;
   
   // Inicializar constantes de risco com valores padrão
   m_symbolParams[newIndex].firstTargetPoints = 100.0;
   m_symbolParams[newIndex].spikeMaxStopPoints = 150.0;
   m_symbolParams[newIndex].channelMaxStopPoints = 100.0;
   m_symbolParams[newIndex].trailingStopPoints = 50.0;
   
   // Inicializar arrays de parciais
   ArrayInitialize(m_symbolParams[newIndex].partialLevels, 0.0);
   ArrayInitialize(m_symbolParams[newIndex].partialVolumes, 0.0);
   
   if(m_logger) {
      m_logger.Info(StringFormat("RiskManager: Símbolo %s adicionado - Risco: %.2f%%, Max Lot: %.2f", 
                                symbol, riskPercentage, maxLotSize));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Configura stop loss para um símbolo                              |
//+------------------------------------------------------------------+
bool CRiskManager::ConfigureSymbolStopLoss(string symbol, double defaultStopPoints, double atrMultiplier) {
   // Encontrar índice do símbolo
   int index = FindSymbolIndex(symbol);
   
   if(index < 0) {
      if(m_logger) {
         m_logger.Error("RiskManager: Símbolo " + symbol + " não encontrado para configuração de stop loss");
      }
      return false;
   }
   
   // Validar parâmetros
   if(defaultStopPoints <= 0 || atrMultiplier <= 0) {
      if(m_logger) {
         m_logger.Error("RiskManager: Parâmetros de stop loss inválidos");
      }
      return false;
   }
   
   // Atualizar parâmetros
   m_symbolParams[index].defaultStopPoints = defaultStopPoints;
   m_symbolParams[index].atrMultiplier = atrMultiplier;
   
   if(m_logger) {
      m_logger.Info(StringFormat("RiskManager: Stop loss configurado para %s: %.1f pontos, ATR x%.2f", 
                                symbol, defaultStopPoints, atrMultiplier));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Configura fechamentos parciais para um símbolo                   |
//+------------------------------------------------------------------+
bool CRiskManager::ConfigureSymbolPartials(string symbol, bool usePartials, double &levels[], double &volumes[]) {
   // Encontrar índice do símbolo
   int index = FindSymbolIndex(symbol);
   
   if(index < 0) {
      if(m_logger) {
         m_logger.Error("RiskManager: Símbolo " + symbol + " não encontrado para configuração de parciais");
      }
      return false;
   }
   
   // Configurar uso de parciais
   m_symbolParams[index].usePartials = usePartials;
   
   if(usePartials && ArraySize(levels) > 0 && ArraySize(volumes) > 0) {
      // Copiar níveis e volumes (limitado a 10 elementos)
      int maxElements = MathMin(ArraySize(levels), MathMin(ArraySize(volumes), 10));
      
      for(int i = 0; i < maxElements; i++) {
         if(levels[i] > 0 && volumes[i] > 0 && volumes[i] <= 1.0) {
            m_symbolParams[index].partialLevels[i] = levels[i];
            m_symbolParams[index].partialVolumes[i] = volumes[i];
         } else {
            if(m_logger) {
               m_logger.Warning(StringFormat("RiskManager: Parâmetros de parcial inválidos no índice %d", i));
            }
            break;
         }
      }
      
      if(m_logger) {
         m_logger.Info(StringFormat("RiskManager: Parciais configuradas para %s: %d níveis", 
                                   symbol, maxElements));
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Configura constantes de risco específicas por símbolo           |
//+------------------------------------------------------------------+
bool CRiskManager::ConfigureSymbolRiskConstants(string symbol, double tp1Points, double spikeStopPoints, double channelStopPoints, double trailingPoints) {
   // Encontrar índice do símbolo
   int index = FindSymbolIndex(symbol);
   
   if(index < 0) {
      if(m_logger) {
         m_logger.Error("RiskManager: Símbolo " + symbol + " não encontrado para configuração de constantes de risco");
      }
      return false;
   }
   
   // Validar parâmetros
   if(tp1Points <= 0 || spikeStopPoints <= 0 || channelStopPoints <= 0 || trailingPoints <= 0) {
      if(m_logger) {
         m_logger.Error("RiskManager: Constantes de risco inválidas para " + symbol);
      }
      return false;
   }
   
   // Atualizar parâmetros
   m_symbolParams[index].firstTargetPoints = tp1Points;
   m_symbolParams[index].spikeMaxStopPoints = spikeStopPoints;
   m_symbolParams[index].channelMaxStopPoints = channelStopPoints;
   m_symbolParams[index].trailingStopPoints = trailingPoints;
   
   if(m_logger) {
      m_logger.Info(StringFormat("RiskManager: Constantes de risco configuradas para %s: TP1=%.1f, SpikeStop=%.1f, ChannelStop=%.1f, Trailing=%.1f", 
                                symbol, tp1Points, spikeStopPoints, channelStopPoints, trailingPoints));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Obter parâmetros de risco para um símbolo                        |
//+------------------------------------------------------------------+
bool CRiskManager::GetSymbolRiskParams(string symbol, SymbolRiskParams &params) {
   // Encontrar índice do símbolo
   int index = FindSymbolIndex(symbol);
   
   if(index < 0) {
      if(m_logger) {
         m_logger.Warning("RiskManager: Símbolo " + symbol + " não encontrado para obtenção de parâmetros");
      }
      return false;
   }
   
   // Copiar parâmetros para a referência fornecida
   params = m_symbolParams[index];
   return true;
}

//+------------------------------------------------------------------+
//| Encontrar índice do símbolo no array de parâmetros               |
//+------------------------------------------------------------------+
int CRiskManager::FindSymbolIndex(string symbol) {
   int size = ArraySize(m_symbolParams);
   
   for(int i = 0; i < size; i++) {
      if(m_symbolParams[i].symbol == symbol) {
         return i;
      }
   }
   
   return -1;
}

//+------------------------------------------------------------------+
//| Calcular stop loss baseado no símbolo e fase de mercado          |
//+------------------------------------------------------------------+
double CRiskManager::CalculateStopLoss(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice, MARKET_PHASE phase) {
   if(entryPrice <= 0) {
      if(m_logger) {
         m_logger.Error("RiskManager: Preço de entrada inválido para cálculo de stop loss");
      }
      return 0;
   }
   
   // Obter parâmetros do símbolo
   SymbolRiskParams params;
   if(!GetSymbolRiskParams(symbol, params)) {
      if(m_logger) {
         m_logger.Error("RiskManager: Parâmetros não encontrados para " + symbol);
      }
      return 0;
   }
   
   // Obter valor do ponto
   double pointValue = GetSymbolPointValue(symbol);
   if(pointValue <= 0) {
      if(m_logger) {
         m_logger.Error("RiskManager: Valor do ponto inválido para " + symbol);
      }
      return 0;
   }
   
   // Determinar stop loss máximo baseado na fase de mercado
   double maxStopPoints = 0;
   
   if(phase == PHASE_SPIKE) {
      maxStopPoints = params.spikeMaxStopPoints;
   } else {
      maxStopPoints = params.channelMaxStopPoints;
   }
   
   // Calcular stop loss
   double stopLoss = 0;
   
   if(orderType == ORDER_TYPE_BUY) {
      stopLoss = entryPrice - (maxStopPoints * pointValue);
   } else if(orderType == ORDER_TYPE_SELL) {
      stopLoss = entryPrice + (maxStopPoints * pointValue);
   } else {
      if(m_logger) {
         m_logger.Error("RiskManager: Tipo de ordem inválido para cálculo de stop loss");
      }
      return 0;
   }
   
   // Normalizar stop loss
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   stopLoss = NormalizeDouble(stopLoss, digits);
   
   if(m_logger) {
      m_logger.Debug(StringFormat("RiskManager: Stop loss calculado para %s: %.5f (Entrada: %.5f, Pontos: %.1f)", 
                                 symbol, stopLoss, entryPrice, maxStopPoints));
   }
   
   return stopLoss;
}

//+------------------------------------------------------------------+
//| Calcular take profit baseado no símbolo e stop loss              |
//+------------------------------------------------------------------+
double CRiskManager::CalculateTakeProfit(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice, double stopLoss) {
   if(entryPrice <= 0 || stopLoss <= 0) {
      if(m_logger) {
         m_logger.Error("RiskManager: Preços inválidos para cálculo de take profit");
      }
      return 0;
   }
   
   // Obter parâmetros do símbolo
   SymbolRiskParams params;
   if(!GetSymbolRiskParams(symbol, params)) {
      if(m_logger) {
         m_logger.Error("RiskManager: Parâmetros não encontrados para " + symbol);
      }
      return 0;
   }
   
   // Obter valor do ponto
   double pointValue = GetSymbolPointValue(symbol);
   if(pointValue <= 0) {
      if(m_logger) {
         m_logger.Error("RiskManager: Valor do ponto inválido para " + symbol);
      }
      return 0;
   }
   
   // Calcular take profit usando firstTargetPoints
   double takeProfit = 0;
   
   if(orderType == ORDER_TYPE_BUY) {
      takeProfit = entryPrice + (params.firstTargetPoints * pointValue);
   } else if(orderType == ORDER_TYPE_SELL) {
      takeProfit = entryPrice - (params.firstTargetPoints * pointValue);
   } else {
      if(m_logger) {
         m_logger.Error("RiskManager: Tipo de ordem inválido para cálculo de take profit");
      }
      return 0;
   }
   
   // Normalizar take profit
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   takeProfit = NormalizeDouble(takeProfit, digits);
   
   if(m_logger) {
      m_logger.Debug(StringFormat("RiskManager: Take profit calculado para %s: %.5f (Entrada: %.5f, Pontos: %.1f)", 
                                 symbol, takeProfit, entryPrice, params.firstTargetPoints));
   }
   
   return takeProfit;
}

//+------------------------------------------------------------------+
//| Verificar se deve fazer fechamento parcial                       |
//+------------------------------------------------------------------+
bool CRiskManager::ShouldTakePartial(string symbol, ulong ticket, double currentPrice, double entryPrice, double stopLoss) {
   // Obter parâmetros do símbolo
   SymbolRiskParams params;
   if(!GetSymbolRiskParams(symbol, params)) {
      return false;
   }
   
   // Verificar se parciais estão habilitadas
   if(!params.usePartials) {
      return false;
   }
   
   // Calcular R:R atual
   double risk = MathAbs(entryPrice - stopLoss);
   if(risk <= 0) return false;
   
   double reward = MathAbs(currentPrice - entryPrice);
   double currentRR = reward / risk;
   
   // Verificar se algum nível de parcial foi atingido
   for(int i = 0; i < 10; i++) {
      if(params.partialLevels[i] > 0 && currentRR >= params.partialLevels[i]) {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Obter volume para fechamento parcial                             |
//+------------------------------------------------------------------+
double CRiskManager::GetPartialVolume(string symbol, ulong ticket, double currentRR) {
   // Obter parâmetros do símbolo
   SymbolRiskParams params;
   if(!GetSymbolRiskParams(symbol, params)) {
      return 0;
   }
   
   // Verificar se parciais estão habilitadas
   if(!params.usePartials) {
      return 0;
   }
   
   // Encontrar o nível de parcial correspondente
   for(int i = 0; i < 10; i++) {
      if(params.partialLevels[i] > 0 && currentRR >= params.partialLevels[i]) {
         return params.partialVolumes[i];
      }
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Obter risco total atual                                          |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentTotalRisk() {
   double totalRisk = 0;
   
   // Calcular risco de todas as posições abertas
   int totalPositions = PositionsTotal();
   
   for(int i = 0; i < totalPositions; i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0) {
         string symbol = PositionGetString(POSITION_SYMBOL);
         double volume = PositionGetDouble(POSITION_VOLUME);
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double stopLoss = PositionGetDouble(POSITION_SL);
         
         if(stopLoss > 0) {
            double risk = MathAbs(entryPrice - stopLoss);
            double riskValue = risk * volume * GetSymbolTickValue(symbol);
            totalRisk += riskValue;
         }
      }
   }
   
   // Converter para percentual da conta
   if(m_accountBalance > 0) {
      return (totalRisk / m_accountBalance) * 100.0;
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Atualizar informações da conta                                   |
//+------------------------------------------------------------------+
void CRiskManager::UpdateAccountInfo() {
   m_accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   m_accountFreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   
   if(m_logger) {
      m_logger.Debug(StringFormat("RiskManager: Conta atualizada - Saldo: %.2f, Equity: %.2f, Margem Livre: %.2f", 
                                 m_accountBalance, m_accountEquity, m_accountFreeMargin));
   }
}

OrderRequest CRiskManager::BuildRequest(string symbol, Signal &signal, MARKET_PHASE phase)
{
    OrderRequest request;
 
    
    return request;
}

//+------------------------------------------------------------------+
//| Obter valor do tick para o símbolo                               |
//+------------------------------------------------------------------+
double CRiskManager::GetSymbolTickValue(string symbol) {
   return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
}

//+------------------------------------------------------------------+
//| Obter valor do ponto para o símbolo                              |
//+------------------------------------------------------------------+
double CRiskManager::GetSymbolPointValue(string symbol) {
   return SymbolInfoDouble(symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Calcular tamanho da posição                                      |
//+------------------------------------------------------------------+
double CRiskManager::CalculatePositionSize(string symbol, double entryPrice, double stopLoss, double riskPercentage) {
   // Implementação será adicionada conforme necessário
   return 0.1; // Placeholder
}

//+------------------------------------------------------------------+
//| Ajustar tamanho do lote                                          |
//+------------------------------------------------------------------+
double CRiskManager::AdjustLotSize(string symbol, double lotSize) {
   // Implementação será adicionada conforme necessário
   return lotSize; // Placeholder
}

//+------------------------------------------------------------------+
//| Calcular valor do ATR                                            |
//+------------------------------------------------------------------+
double CRiskManager::CalculateATRValue(string symbol, ENUM_TIMEFRAMES timeframe, int period) {
   // Implementação será adicionada conforme necessário
   return 0; // Placeholder
}

//+------------------------------------------------------------------+
//| Validar preço de mercado                                         |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateMarketPrice(string symbol, double &price) {
   // Implementação será adicionada conforme necessário
   return true; // Placeholder
}

#endif // RISKMANAGER_MQH_