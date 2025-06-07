//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                             RiskManager.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#ifndef RISKMANAGER_MQH
#define RISKMANAGER_MQH

// Inclusão de bibliotecas necessárias
#include "Structures.mqh"
#include "Constants.mqh"
#include "Logger.mqh"
#include "MarketContext.mqh"

//+------------------------------------------------------------------+
//| Classe para gestão de risco e dimensionamento de posições        |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   // Objetos internos
   CLogger *m_logger;
   CMarketContext *m_marketContext;

   // Configurações gerais
   double m_defaultRiskPercentage;
   double m_maxTotalRisk;

   // Informações da conta
   double m_accountBalance;
   double m_accountEquity;
   double m_accountFreeMargin;

   // Estrutura para armazenar parâmetros específicos por símbolo
   struct SymbolRiskParams
   {
      string symbol;
      double riskPercentage;
      double maxLotSize;
      double defaultStopPoints;
      double atrMultiplier;
      bool usePartials;
      double partialLevels[10];  // Níveis de R:R para parciais
      double partialVolumes[10]; // Volumes para cada parcial (em %)
   };

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
   bool Initialize(CLogger *logger, CMarketContext *marketContext);

   // Métodos de configuração
   void SetDefaultRiskPercentage(double percentage) { m_defaultRiskPercentage = percentage; }
   void SetMaxTotalRisk(double percentage) { m_maxTotalRisk = percentage; }

   // Métodos para configuração de símbolos
   bool AddSymbol(string symbol, double riskPercentage, double maxLotSize);
   bool ConfigureSymbolStopLoss(string symbol, double defaultStopPoints, double atrMultiplier);
   bool ConfigureSymbolPartials(string symbol, bool usePartials, double &levels[], double &volumes[]);

   // Métodos para cálculo de risco
   OrderRequest BuildRequest(string symbol, Signal &signal, MARKET_PHASE phase);
   double CalculateStopLoss(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice, MARKET_PHASE phase, Signal &signal);
   double CalculateTakeProfit(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice, double stopLoss);

   // Métodos para gestão de posições
   bool ShouldTakePartial(string symbol, ulong ticket, double currentPrice, double entryPrice, double stopLoss);
   double GetPartialVolume(string symbol, ulong ticket, double currentRR);

   void ResetPartialControl(ulong ticket);

   double CalculatePositionRisk(string symbol, double volume, double openPrice, double stopLoss, ENUM_POSITION_TYPE posType);

   // Métodos de acesso
   double GetCurrentTotalRisk();
   bool CanOpenNewPosition(string symbol, double volume, double entryPrice, double stopLoss, double requestedRisk);
   double GetAvailableRisk();
   void GenerateRiskReport();
   double CalculateCurrentRR(double entryPrice, double currentPrice, double stopLoss, ENUM_POSITION_TYPE posType);
   void UpdateAccountInfo();
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager(double defaultRiskPercentage = 1.0, double maxTotalRisk = 5.0)
{
   m_logger = NULL;
   m_marketContext = NULL;
   m_defaultRiskPercentage = defaultRiskPercentage;
   m_maxTotalRisk = maxTotalRisk;
   m_accountBalance = 0;
   m_accountEquity = 0;
   m_accountFreeMargin = 0;
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager()
{
   // Nada a liberar, apenas objetos referenciados
}

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool CRiskManager::Initialize(CLogger *logger, CMarketContext *marketContext)
{
   // Verificar parâmetros
   if (logger == NULL || marketContext == NULL)
   {
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
//| Atualizar informações da conta                                   |
//+------------------------------------------------------------------+
void CRiskManager::UpdateAccountInfo()
{
   m_accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   m_accountFreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Informações da conta atualizadas: Saldo=%.2f, Equity=%.2f, Margem Livre=%.2f",
                                  m_accountBalance, m_accountEquity, m_accountFreeMargin));
   }
}

//+------------------------------------------------------------------+
//| Adicionar símbolo à lista de configurações                       |
//+------------------------------------------------------------------+
bool CRiskManager::AddSymbol(string symbol, double riskPercentage, double maxLotSize)
{
   // Verificar se o símbolo já existe
   int index = FindSymbolIndex(symbol);

   if (index >= 0)
   {
      // Atualizar parâmetros existentes
      m_symbolParams[index].riskPercentage = riskPercentage;
      m_symbolParams[index].maxLotSize = maxLotSize;

      if (m_logger != NULL)
      {
         m_logger.Info("RiskManager: Parâmetros atualizados para " + symbol);
      }

      return true;
   }

   // Adicionar novo símbolo
   int size = ArraySize(m_symbolParams);
   int newSize = size + 1;

   // Verificar se o redimensionamento foi bem-sucedido
   if (ArrayResize(m_symbolParams, newSize) != newSize)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Falha ao redimensionar array de parâmetros");
      }
      return false;
   }

   m_symbolParams[size].symbol = symbol;
   m_symbolParams[size].riskPercentage = riskPercentage;
   m_symbolParams[size].maxLotSize = maxLotSize;
   m_symbolParams[size].defaultStopPoints = 100; // Valor padrão
   m_symbolParams[size].atrMultiplier = 2.0;     // Valor padrão
   m_symbolParams[size].usePartials = false;

   // Inicializar arrays de parciais
   double tempLevels[3] = {1.0, 2.0, 3.0};
   double tempVolumes[3] = {0.3, 0.3, 0.4};

   for (int i = 0; i < 3; i++)
   {
      m_symbolParams[size].partialLevels[i] = tempLevels[i];
      m_symbolParams[size].partialVolumes[i] = tempVolumes[i];
   }

   if (m_logger != NULL)
   {
      m_logger.Info("RiskManager: Símbolo " + symbol + " adicionado à lista com risco de " +
                    DoubleToString(m_symbolParams[size].riskPercentage, 2) + "%");
   }

   return true;
}

//+------------------------------------------------------------------+
//| Configurar parâmetros de stop loss para um símbolo               |
//+------------------------------------------------------------------+
bool CRiskManager::ConfigureSymbolStopLoss(string symbol, double defaultStopPoints, double atrMultiplier)
{
   // Encontrar índice do símbolo
   int index = FindSymbolIndex(symbol);

   if (index < 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Símbolo " + symbol + " não encontrado para configuração de stop loss");
      }
      return false;
   }

   // Atualizar parâmetros
   m_symbolParams[index].defaultStopPoints = defaultStopPoints;
   m_symbolParams[index].atrMultiplier = atrMultiplier;

   if (m_logger != NULL)
   {
      m_logger.Info(StringFormat("RiskManager: Stop loss configurado para %s: %.1f pontos, ATR x%.1f",
                                 symbol, defaultStopPoints, atrMultiplier));
   }

   return true;
}

//+------------------------------------------------------------------+
//| Configurar parciais para um símbolo                              |
//+------------------------------------------------------------------+
bool CRiskManager::ConfigureSymbolPartials(string symbol, bool usePartials, double &levels[], double &volumes[])
{
   // Encontrar índice do símbolo
   int index = FindSymbolIndex(symbol);

   if (index < 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Símbolo " + symbol + " não encontrado para configuração de parciais");
      }
      return false;
   }

   // Verificar tamanhos dos arrays
   int levelsSize = ArraySize(levels);
   int volumesSize = ArraySize(volumes);

   if (levelsSize != volumesSize || levelsSize == 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Arrays de níveis e volumes devem ter o mesmo tamanho e não podem ser vazios");
      }
      return false;
   }

   // Verificar se os níveis estão em ordem crescente
   for (int i = 1; i < levelsSize; i++)
   {
      if (levels[i] <= levels[i - 1])
      {
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("RiskManager: Níveis de parciais devem estar em ordem crescente. Nível %d (%.2f) <= Nível %d (%.2f)",
                                          i, levels[i], i - 1, levels[i - 1]));
         }
         return false;
      }
   }

   // Verificar se a soma dos volumes é aproximadamente 1.0
   double totalVolume = 0;
   for (int i = 0; i < volumesSize; i++)
   {
      totalVolume += volumes[i];
   }

   if (MathAbs(totalVolume - 1.0) > 0.01)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("RiskManager: Soma dos volumes (%.2f) não é igual a 1.0", totalVolume));
      }
   }

   // Atualizar parâmetros
   m_symbolParams[index].usePartials = usePartials;

   // Copiar arrays
   int maxSize = MathMin(levelsSize, 10); // Limitar a 10 níveis

   for (int i = 0; i < maxSize; i++)
   {
      m_symbolParams[index].partialLevels[i] = levels[i];
      m_symbolParams[index].partialVolumes[i] = volumes[i];
   }

   if (m_logger != NULL)
   {
      string levelsStr = "";
      string volumesStr = "";

      for (int i = 0; i < maxSize; i++)
      {
         levelsStr += DoubleToString(levels[i], 1) + " ";
         volumesStr += DoubleToString(volumes[i] * 100, 0) + "% ";
      }

      m_logger.Info(StringFormat("RiskManager: Parciais configuradas para %s: %s, Níveis: %s, Volumes: %s",
                                 symbol, usePartials ? "Ativado" : "Desativado", levelsStr, volumesStr));
   }

   return true;
}

//+------------------------------------------------------------------+
//| Validar e obter preço de mercado atual                           |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateMarketPrice(string symbol, double &price)
{
   // Verificar se o símbolo é válido
   if (symbol == "" || StringLen(symbol) == 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Símbolo inválido para validação de preço");
      }
      return false;
   }

   // Obter preço atual
   MqlTick lastTick;
   if (!SymbolInfoTick(symbol, lastTick))
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Falha ao obter tick para " + symbol + ": " + IntegerToString(GetLastError()));
      }
      return false;
   }

   // Verificar se o preço é válido
   if (lastTick.ask <= 0 || lastTick.bid <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Preços inválidos para " + symbol + ": Bid=" +
                        DoubleToString(lastTick.bid, 5) + ", Ask=" + DoubleToString(lastTick.ask, 5));
      }
      return false;
   }

   // Usar preço médio
   price = (lastTick.ask + lastTick.bid) / 2.0;
   return true;
}

//+------------------------------------------------------------------+
//| Construir requisição de ordem baseada em sinal                   |
//+------------------------------------------------------------------+
// Modificar o método BuildRequest no RiskManager.mqh:

OrderRequest CRiskManager::BuildRequest(string symbol, Signal &signal, MARKET_PHASE phase)
{
   OrderRequest request;

   // Preencher dados básicos
   request.symbol = symbol;
   request.type = signal.direction;

   // Validar símbolo
   if (symbol == "" || StringLen(symbol) == 0) {
      if (m_logger != NULL) {
         m_logger.Error("RiskManager: Símbolo inválido para construção de requisição");
      }
      request.volume = 0;
      return request;
   }

   // NOVA LÓGICA: Obter preço atual do mercado para cálculos
   MqlTick currentTick;
   if (!SymbolInfoTick(symbol, currentTick)) {
      if (m_logger != NULL) {
         m_logger.Error("RiskManager: Falha ao obter tick atual para " + symbol);
      }
      request.volume = 0;
      return request;
   }

   // Determinar preço de referência para cálculos (será o preço de execução real)
   double referencePrice = (signal.direction == ORDER_TYPE_BUY) ? currentTick.ask : currentTick.bid;
   
   // IMPORTANTE: O preço na requisição é apenas referência - a execução será sempre a mercado
   request.price = referencePrice;
   request.comment = "IntegratedPA: " + EnumToString(signal.quality) + " " + EnumToString(phase) + " (MERCADO)";

   if (m_logger != NULL) {
      m_logger.Info(StringFormat("RiskManager: Usando preço de referência %.5f (%s = %.5f)", 
                               referencePrice,
                               signal.direction == ORDER_TYPE_BUY ? "ASK" : "BID",
                               signal.direction == ORDER_TYPE_BUY ? currentTick.ask : currentTick.bid));
   }

   // Calcular stop loss baseado no preço de referência
   if (signal.stopLoss > 0) {
      // Verificar se o stop loss do sinal é válido em relação ao preço de mercado
      bool isValidSL = false;
      
      if (signal.direction == ORDER_TYPE_BUY && signal.stopLoss < referencePrice) {
         isValidSL = true;
      } else if (signal.direction == ORDER_TYPE_SELL && signal.stopLoss > referencePrice) {
         isValidSL = true;
      }
      
      if (isValidSL) {
         request.stopLoss = signal.stopLoss;
         if (m_logger != NULL) {
            m_logger.Info("RiskManager: Usando stop loss do sinal: " + DoubleToString(signal.stopLoss, 5));
         }
      } else {
         if (m_logger != NULL) {
            m_logger.Warning(StringFormat("RiskManager: Stop loss do sinal inválido (%.5f vs mercado %.5f), recalculando...", 
                                        signal.stopLoss, referencePrice));
         }
         request.stopLoss = CalculateStopLoss(symbol, signal.direction, referencePrice, phase, signal);
      }
   } else {
      request.stopLoss = CalculateStopLoss(symbol, signal.direction, referencePrice, phase, signal);
   }

   // Verificar distância mínima do stop loss
   double stopDistance = MathAbs(referencePrice - request.stopLoss);
   long minStopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minStopDistance = minStopLevel * point;

   if (minStopLevel > 0 && stopDistance < minStopDistance) {
      if (m_logger != NULL) {
         m_logger.Warning(StringFormat("RiskManager: Stop muito próximo: %.0f pontos (mínimo: %d)", 
                                     stopDistance / point, minStopLevel));
      }
      
      // Ajustar para distância mínima + margem de segurança
      double safetyMargin = minStopDistance * 0.5; // 50% de margem
      double adjustedDistance = minStopDistance + safetyMargin;
      
      if (signal.direction == ORDER_TYPE_BUY) {
         request.stopLoss = referencePrice - adjustedDistance;
      } else {
         request.stopLoss = referencePrice + adjustedDistance;
      }
      
      if (m_logger != NULL) {
         m_logger.Info(StringFormat("RiskManager: Stop ajustado para %.5f (distância: %.0f pontos)", 
                                   request.stopLoss, adjustedDistance / point));
      }
   }

   // Calcular take profit baseado no preço de referência e stop loss final
   request.takeProfit = CalculateTakeProfit(symbol, signal.direction, referencePrice, request.stopLoss);

   // Normalizar preços
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   request.price = NormalizeDouble(request.price, digits);
   request.stopLoss = NormalizeDouble(request.stopLoss, digits);
   request.takeProfit = NormalizeDouble(request.takeProfit, digits);

   // Validação final dos preços
   bool pricesValid = true;
   
   if (signal.direction == ORDER_TYPE_BUY) {
      if (request.stopLoss >= referencePrice) {
         if (m_logger != NULL) {
            m_logger.Error(StringFormat("RiskManager: SL inválido para COMPRA: %.5f >= %.5f", request.stopLoss, referencePrice));
         }
         pricesValid = false;
      }
      if (request.takeProfit > 0 && request.takeProfit <= referencePrice) {
         if (m_logger != NULL) {
            m_logger.Error(StringFormat("RiskManager: TP inválido para COMPRA: %.5f <= %.5f", request.takeProfit, referencePrice));
         }
         pricesValid = false;
      }
   } else {
      if (request.stopLoss <= referencePrice) {
         if (m_logger != NULL) {
            m_logger.Error(StringFormat("RiskManager: SL inválido para VENDA: %.5f <= %.5f", request.stopLoss, referencePrice));
         }
         pricesValid = false;
      }
      if (request.takeProfit > 0 && request.takeProfit >= referencePrice) {
         if (m_logger != NULL) {
            m_logger.Error(StringFormat("RiskManager: TP inválido para VENDA: %.5f >= %.5f", request.takeProfit, referencePrice));
         }
         pricesValid = false;
      }
   }

   if (!pricesValid) {
      if (m_logger != NULL) {
         m_logger.Error("RiskManager: Preços inválidos calculados, cancelando operação");
      }
      request.volume = 0;
      return request;
   }

   // Encontrar índice do símbolo para ajuste de risco
   int index = FindSymbolIndex(symbol);
   double riskPercentage = (index >= 0) ? m_symbolParams[index].riskPercentage : m_defaultRiskPercentage;

   // Ajustar risco com base na qualidade do setup
   switch (signal.quality) {
      case SETUP_A_PLUS: riskPercentage *= 1.5; break;
      case SETUP_A:      riskPercentage *= 1.2; break;
      case SETUP_B:      riskPercentage *= 1.0; break;
      case SETUP_C:      riskPercentage *= 0.5; break;
      default:           riskPercentage *= 0.3; break;
   }

   // Ajustar risco com base na fase de mercado
   switch (phase) {
      case PHASE_TREND:    riskPercentage *= 1.0; break;
      case PHASE_RANGE:    riskPercentage *= 0.8; break;
      case PHASE_REVERSAL: riskPercentage *= 0.7; break;
      default:             riskPercentage *= 0.5; break;
   }

   // Verificar risco disponível
   double availableRisk = GetAvailableRisk();
   if (availableRisk <= 0) {
      if (m_logger != NULL) {
         m_logger.Warning(StringFormat("RiskManager: Risco máximo atingido. Operação cancelada.",""));
      }
      request.volume = 0;
      return request;
   }

   riskPercentage = MathMin(riskPercentage, availableRisk);

   // Calcular tamanho da posição baseado no preço de referência
   request.volume = CalculatePositionSize(symbol, referencePrice, request.stopLoss, riskPercentage);

   if (request.volume <= 0) {
      if (m_logger != NULL) {
         m_logger.Error("RiskManager: Volume inválido calculado: " + DoubleToString(request.volume, 2));
      }
      request.volume = 0;
      return request;
   }

   // Limitar tamanho máximo
   if (index >= 0 && request.volume > m_symbolParams[index].maxLotSize) {
      request.volume = m_symbolParams[index].maxLotSize;
   }

   // Calcular R:R baseado nos preços finais
   double riskDistance = MathAbs(referencePrice - request.stopLoss);
   double rewardDistance = MathAbs(request.takeProfit - referencePrice);
   double riskRewardRatio = (riskDistance > 0) ? rewardDistance / riskDistance : 0;

   if (m_logger != NULL) {
      m_logger.Info(StringFormat("RiskManager: ✅ REQUISIÇÃO CRIADA PARA EXECUÇÃO A MERCADO",""));
      m_logger.Info(StringFormat("   Símbolo: %s", symbol));
      m_logger.Info(StringFormat("   Tipo: %s", request.type == ORDER_TYPE_BUY ? "COMPRA" : "VENDA"));
      m_logger.Info(StringFormat("   Volume: %.2f lotes", request.volume));
      m_logger.Info(StringFormat("   Preço referência: %.5f (%s)", referencePrice, 
                                request.type == ORDER_TYPE_BUY ? "ASK" : "BID"));
      m_logger.Info(StringFormat("   Stop Loss: %.5f", request.stopLoss));
      m_logger.Info(StringFormat("   Take Profit: %.5f", request.takeProfit));
      m_logger.Info(StringFormat("   Risco: %.2f%% | R:R: %.2f:1", riskPercentage, riskRewardRatio));
   }

   return request;
}
//+------------------------------------------------------------------+
//| Calcular stop loss baseado na fase de mercado                    |
//+------------------------------------------------------------------+
double CRiskManager::CalculateStopLoss(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice, MARKET_PHASE phase, Signal &signal)
{

   // Verificar se signal já tem stop loss válido
   if (signal.stopLoss > 0)
   {
      // Validar se está no lado correto
      if ((orderType == ORDER_TYPE_BUY && signal.stopLoss < entryPrice) ||
          (orderType == ORDER_TYPE_SELL && signal.stopLoss > entryPrice))
      {

         if (m_logger != NULL)
         {
            m_logger.Debug(StringFormat("RiskManager: Usando stop loss do sinal: %.5f", signal.stopLoss));
         }
         return signal.stopLoss;
      }
   }

   // Continuar com cálculo padrão se não tiver stop válido...
   // Verificar parâmetros
   if (symbol == "" || StringLen(symbol) == 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Símbolo inválido para cálculo de stop loss");
      }
      return 0;
   }

   if (entryPrice <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Preço de entrada inválido para cálculo de stop loss: " + DoubleToString(entryPrice, 5));
      }
      return 0;
   }

   // Validar preço de mercado atual para comparação
   double marketPrice = 0;
   if (!ValidateMarketPrice(symbol, marketPrice))
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Falha ao validar preço de mercado para cálculo de stop loss");
      }
      return 0;
   }

   // Verificar se o preço de entrada está muito distante do preço de mercado (possível erro)
   double maxDeviation = 0.05; // 5% de desvio máximo
   double deviation = MathAbs(entryPrice - marketPrice) / marketPrice;

   if (deviation > maxDeviation)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("RiskManager: Preço de entrada (%.5f) muito distante do preço de mercado (%.5f): %.2f%%",
                                       entryPrice, marketPrice, deviation * 100));
      }
      // Continuar mesmo assim, mas com aviso
   }

   // Encontrar índice do símbolo
   int index = FindSymbolIndex(symbol);

   if (index < 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("RiskManager: Símbolo " + symbol + " não encontrado para cálculo de stop loss");
      }
      return 0;
   }

   // Obter informações do símbolo
   double point = GetSymbolPointValue(symbol);
   if (point <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Valor de ponto inválido para " + symbol);
      }
      return 0;
   }

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   // Calcular distância do stop loss
   double stopDistance = 0;

   switch (phase)
   {
   case PHASE_TREND:
      // Em tendência, usar ATR para stop loss
      if (m_marketContext != NULL)
      {
         double atr = CalculateATRValue(symbol, PERIOD_CURRENT, 14);
         if (atr > 0)
         {
            stopDistance = atr * m_symbolParams[index].atrMultiplier;
         }
         else
         {
            stopDistance = m_symbolParams[index].defaultStopPoints * point;
         }
      }
      else
      {
         stopDistance = m_symbolParams[index].defaultStopPoints * point;
      }
      break;

   case PHASE_RANGE:
      // Em range, usar distância fixa ou suporte/resistência
      stopDistance = m_symbolParams[index].defaultStopPoints * point * 0.8; // 20% menos em range
      break;

   case PHASE_REVERSAL:
      // Em reversão, usar distância maior
      stopDistance = m_symbolParams[index].defaultStopPoints * point * 1.2; // 20% mais em reversão
      break;

   default:
      // Caso padrão, usar distância fixa
      stopDistance = m_symbolParams[index].defaultStopPoints * point;
   }

   // Aplicar limites específicos por ativo baseado nas constantes
   double maxStopDistance = 0;

   if (StringFind(symbol, "WIN") >= 0)
   {
      if (phase == PHASE_TREND)
      {
         maxStopDistance = WIN_SPIKE_MAX_STOP * point;
      }
      else if (phase == PHASE_RANGE)
      {
         maxStopDistance = WIN_CHANNEL_MAX_STOP * point;
      }
      else
      {
         maxStopDistance = WIN_SPIKE_MAX_STOP * point;
      }
   }
   else if (StringFind(symbol, "WDO") >= 0)
   {
      if (phase == PHASE_TREND)
      {
         maxStopDistance = WDO_SPIKE_MAX_STOP * point;
      }
      else if (phase == PHASE_RANGE)
      {
         maxStopDistance = WDO_CHANNEL_MAX_STOP * point;
      }
      else
      {
         maxStopDistance = WDO_SPIKE_MAX_STOP * point;
      }
   }
   else if (StringFind(symbol, "BIT") >= 0)
   {
      if (phase == PHASE_TREND)
      {
         maxStopDistance = BTC_SPIKE_MAX_STOP * point;
      }
      else if (phase == PHASE_RANGE)
      {
         maxStopDistance = BTC_CHANNEL_MAX_STOP * point;
      }
      else
      {
         maxStopDistance = BTC_SPIKE_MAX_STOP * point;
      }
   }

   // Aplicar o limite se definido
   if (maxStopDistance > 0)
   {
      stopDistance = MathMin(stopDistance, maxStopDistance);
   }

   // Garantir distância mínima
   double minStopDistance = 10 * point; // Mínimo de 10 pontos
   stopDistance = MathMax(stopDistance, minStopDistance);

   // Calcular preço do stop loss
   double stopLoss = 0;

   if (orderType == ORDER_TYPE_BUY)
   {
      stopLoss = entryPrice - stopDistance;

      // Verificar se o stop loss está muito próximo do preço atual
      if (stopLoss >= entryPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Error("RiskManager: Stop loss calculado acima do preço de entrada para compra");
         }
         return 0;
      }
   }
   else if (orderType == ORDER_TYPE_SELL)
   {
      stopLoss = entryPrice + stopDistance;

      // Verificar se o stop loss está muito próximo do preço atual
      if (stopLoss <= entryPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Error("RiskManager: Stop loss calculado abaixo do preço de entrada para venda");
         }
         return 0;
      }
   }
   else
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Tipo de ordem inválido para cálculo de stop loss");
      }
      return 0;
   }

   // Normalizar o preço do stop loss
   stopLoss = NormalizeDouble(stopLoss, digits);

   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("RiskManager: Stop loss calculado para %s: %.5f (distância: %.5f)",
                                  symbol, stopLoss, stopDistance));
   }

   return stopLoss;
}

//+------------------------------------------------------------------+
//| Calcular take profit baseado no stop loss                        |
//+------------------------------------------------------------------+

double CRiskManager::CalculateTakeProfit(string symbol, ENUM_ORDER_TYPE orderType, double entryPrice, double stopLoss)
{
   // Verificar parâmetros
   if(symbol == "" || entryPrice <= 0 || stopLoss <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Parâmetros inválidos para cálculo de take profit");
      }
      return 0;
   }

   // Verificar se o stop loss está no lado correto da entrada
   if(orderType == ORDER_TYPE_BUY && stopLoss >= entryPrice) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Stop loss inválido para compra: deve estar abaixo do preço de entrada");
      }
      return 0;
   }

   if(orderType == ORDER_TYPE_SELL && stopLoss <= entryPrice) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Stop loss inválido para venda: deve estar acima do preço de entrada");
      }
      return 0;
   }

   // Calcular distância do risco
   double riskDistance = MathAbs(entryPrice - stopLoss);
   if(riskDistance <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("RiskManager: Distância de risco inválida");
      }
      return 0;
   }

   // Obter informações do símbolo
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   // Calcular take profit baseado nas constantes específicas do ativo
   double takeProfitDistance = 0;
   double defaultRRRatio = 2.0; // Razão padrão de 2:1

   if(StringFind(symbol, "WIN") >= 0) {
      // Para WIN$D: usar constante específica ou 2x o risco
      takeProfitDistance = MathMax(WIN_FIRST_TARGET * point, riskDistance * defaultRRRatio);
   } 
   else if(StringFind(symbol, "WDO") >= 0) {
      // Para WDO$D: usar constante específica ou 2x o risco  
      takeProfitDistance = MathMax(WDO_FIRST_TARGET * point, riskDistance * defaultRRRatio);
   } 
   else if(StringFind(symbol, "BIT") >= 0) {
      // Para BIT$D: usar constante específica ou 2x o risco
      takeProfitDistance = MathMax(BTC_FIRST_TARGET * point, riskDistance * defaultRRRatio);
   } 
   else {
      // Para outros símbolos: usar relação risco/retorno padrão
      takeProfitDistance = riskDistance * defaultRRRatio;
   }

   // Calcular preço do take profit
   double takeProfit = 0;

   if(orderType == ORDER_TYPE_BUY) {
      takeProfit = entryPrice + takeProfitDistance;
   } else {
      takeProfit = entryPrice - takeProfitDistance;
   }

   // Normalizar o preço do take profit
   takeProfit = NormalizeDouble(takeProfit, digits);

   // Verificação de sanidade
   if(orderType == ORDER_TYPE_BUY && takeProfit <= entryPrice) {
      if(m_logger != NULL) {
         m_logger.Warning("Take profit calculado está incorreto para compra, usando fallback");
      }
      takeProfit = entryPrice + (riskDistance * 2.0);
      takeProfit = NormalizeDouble(takeProfit, digits);
   }
   
   if(orderType == ORDER_TYPE_SELL && takeProfit >= entryPrice) {
      if(m_logger != NULL) {
         m_logger.Warning("Take profit calculado está incorreto para venda, usando fallback");
      }
      takeProfit = entryPrice - (riskDistance * 2.0);
      takeProfit = NormalizeDouble(takeProfit, digits);
   }

   if(m_logger != NULL) {
      double calculatedRR = takeProfitDistance / riskDistance;
      m_logger.Debug(StringFormat("RiskManager: Take profit calculado para %s: %.5f (R:R: %.2f)", 
                                symbol, takeProfit, calculatedRR));
   }

   return takeProfit;
}
//+------------------------------------------------------------------+
//| Calcular tamanho da posição baseado no risco                     |
//+------------------------------------------------------------------+
double CRiskManager::CalculatePositionSize(string symbol, double entryPrice, double stopLoss, double riskPercentage)
{
   // Verificar parâmetros
   if (symbol == "" || entryPrice <= 0 || stopLoss <= 0 || riskPercentage <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Parâmetros inválidos para cálculo de tamanho de posição");
      }
      return 0;
   }

   // Atualizar informações da conta
   UpdateAccountInfo();

   // Verificar se há saldo suficiente
   if (m_accountBalance <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Saldo da conta inválido para cálculo de tamanho de posição");
      }
      return 0;
   }

   // Calcular valor em risco
   double riskAmount = m_accountBalance * (riskPercentage / 100.0);

   // Calcular distância do stop loss em pontos
   double stopDistance = MathAbs(entryPrice - stopLoss);
   if (stopDistance <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Distância do stop loss inválida para cálculo de tamanho de posição");
      }
      return 0;
   }

   // Obter valor do tick
   double tickValue = GetSymbolTickValue(symbol);
   if (tickValue <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Valor do tick inválido para " + symbol);
      }
      return 0;
   }

   // Obter valor do ponto
   double pointValue = GetSymbolPointValue(symbol);
   if (pointValue <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Valor do ponto inválido para " + symbol);
      }
      return 0;
   }

   // Calcular tamanho da posição
   double stopDistanceInPoints = stopDistance / pointValue;
   double lotSize = riskAmount / (stopDistanceInPoints * tickValue);

   // Ajustar tamanho do lote
   lotSize = AdjustLotSize(symbol, lotSize);

   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("RiskManager: Tamanho de posição calculado para %s: %.2f lotes (risco: %.2f, distância: %.2f pontos)",
                                  symbol, lotSize, riskPercentage, stopDistanceInPoints));
   }

   return lotSize;
}

//+------------------------------------------------------------------+
//| Ajustar tamanho do lote para os limites do símbolo               |
//+------------------------------------------------------------------+
double CRiskManager::AdjustLotSize(string symbol, double lotSize)
{
   // Obter informações do símbolo
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   // Verificar se as informações são válidas
   if (minLot <= 0 || maxLot <= 0 || stepLot <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("RiskManager: Informações de lote inválidas para %s: min=%.2f, max=%.2f, step=%.2f",
                                       symbol, minLot, maxLot, stepLot));
      }
      // Usar valores padrão
      minLot = 0.01;
      maxLot = 100.0;
      stepLot = 0.01;
   }

   // Limitar ao mínimo e máximo
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, maxLot);

   // Arredondar para o step mais próximo
   lotSize = MathFloor(lotSize / stepLot) * stepLot;

   return lotSize;
}

//+------------------------------------------------------------------+
//| Obter valor do tick para o símbolo                               |
//+------------------------------------------------------------------+
double CRiskManager::GetSymbolTickValue(string symbol)
{
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);

   // Verificar se o valor é válido
   if (tickValue <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("RiskManager: Valor do tick inválido para " + symbol + ", usando valor padrão");
      }
      // Usar valor padrão
      tickValue = 1.0;
   }

   return tickValue;
}

//+------------------------------------------------------------------+
//| Obter valor do ponto para o símbolo                              |
//+------------------------------------------------------------------+
double CRiskManager::GetSymbolPointValue(string symbol)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   // Verificar se o valor é válido
   if (point <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("RiskManager: Valor do ponto inválido para " + symbol + ", usando valor padrão");
      }
      // Usar valor padrão
      point = 0.00001;
   }

   return point;
}

//+------------------------------------------------------------------+
//| Encontrar índice do símbolo no array de parâmetros               |
//+------------------------------------------------------------------+
int CRiskManager::FindSymbolIndex(string symbol)
{
   int size = ArraySize(m_symbolParams);

   for (int i = 0; i < size; i++)
   {
      if (m_symbolParams[i].symbol == symbol)
      {
         return i;
      }
   }

   return -1;
}

//+------------------------------------------------------------------+
//| Calcular valor do ATR                                            |
//+------------------------------------------------------------------+
double CRiskManager::CalculateATRValue(string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
   // Criar handle do indicador ATR
   int atrHandle = iATR(symbol, timeframe, period);

   if (atrHandle == INVALID_HANDLE)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Falha ao criar handle do ATR: " + IntegerToString(GetLastError()));
      }
      return 0.0;
   }

   // Copiar dados do ATR
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);

   int copied = CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
   IndicatorRelease(atrHandle);

   if (copied <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("RiskManager: Falha ao copiar dados do ATR: " + IntegerToString(GetLastError()));
      }
      return 0.0;
   }

   // Retornar valor do ATR
   return atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Verificar se deve realizar parcial                               |
//+------------------------------------------------------------------+
bool CRiskManager::ShouldTakePartial(string symbol, ulong ticket, double currentPrice, double entryPrice, double stopLoss) {
   // Verificar parâmetros
   if (symbol == "" || ticket == 0 || currentPrice <= 0 || entryPrice <= 0 || stopLoss <= 0) {
      return false;
   }

   // Encontrar índice do símbolo
   int index = FindSymbolIndex(symbol);

   if (index < 0 || !m_symbolParams[index].usePartials) {
      return false;
   }

   // VERIFICAÇÃO CRÍTICA: Confirmar que a posição existe
   if (!PositionSelectByTicket(ticket)) {
      if (m_logger != NULL) {
         m_logger.Debug(StringFormat("ShouldTakePartial: Posição #%d não existe", ticket));
      }
      return false;
   }

   // Obter informações atuais da posição
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double currentVolume = PositionGetDouble(POSITION_VOLUME);

   // Verificar se ainda há volume suficiente para parcial
   if (currentVolume <= m_symbolParams[index].partialVolumes[0]) {
      if (m_logger != NULL) {
         m_logger.Debug(StringFormat("Volume insuficiente para parcial: %.2f lotes", currentVolume));
      }
      return false;
   }

   // Calcular relação risco/retorno atual
   double stopDistance = MathAbs(entryPrice - stopLoss);
   double currentDistance = 0;

   if (posType == POSITION_TYPE_BUY) {
      currentDistance = currentPrice - entryPrice;
   } else {
      currentDistance = entryPrice - currentPrice;
   }

   // Verificar se está em lucro
   if (currentDistance <= 0) {
      return false;
   }

   // Calcular R:R atual
   double currentRR = currentDistance / stopDistance;

   if (m_logger != NULL) {
      m_logger.Debug(StringFormat("Analisando parcial #%d: R:R atual %.2f, Volume: %.2f", 
                                ticket, currentRR, currentVolume));
   }

   // CORREÇÃO: Verificar níveis de parcial com mais rigor
   for (int i = 0; i < 10; i++) {
      double level = m_symbolParams[index].partialLevels[i];

      if (level <= 0) {
         break; // Fim dos níveis válidos
      }

      // IMPORTANTE: Verificar se ainda não executamos esta parcial
      if (currentRR >= level) {
         // Calcular volume desta parcial
         double partialVolume = currentVolume * m_symbolParams[index].partialVolumes[i];
         
         // Verificar se é um volume válido
         double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
         if (partialVolume >= minLot) {
            if (m_logger != NULL) {
               m_logger.Info(StringFormat("✅ PARCIAL ATIVADA: Nível %.2f atingido (R:R %.2f), Volume: %.2f lotes", 
                                        level, currentRR, partialVolume));
            }
            return true;
         } else {
            if (m_logger != NULL) {
               m_logger.Debug(StringFormat("Volume de parcial muito pequeno: %.2f < %.2f", partialVolume, minLot));
            }
         }
      }
   }

   return false;
}
//+------------------------------------------------------------------+
//| Obter volume para parcial                                        |
//+------------------------------------------------------------------+
double CRiskManager::GetPartialVolume(string symbol, ulong ticket, double currentRR) {
   // Verificar parâmetros
   if (symbol == "" || ticket == 0 || currentRR <= 0) {
      return 0;
   }

   // Encontrar índice do símbolo
   int index = FindSymbolIndex(symbol);

   if (index < 0 || !m_symbolParams[index].usePartials) {
      return 0;
   }

   // VERIFICAÇÃO CRÍTICA: Confirmar que a posição existe
   if (!PositionSelectByTicket(ticket)) {
      if (m_logger != NULL) {
         m_logger.Debug(StringFormat("GetPartialVolume: Posição #%d não existe", ticket));
      }
      return 0;
   }

   // Obter volume atual da posição
   double totalVolume = PositionGetDouble(POSITION_VOLUME);

   // CORREÇÃO: Encontrar o primeiro nível atingido (menor nível)
   int levelIndex = -1;
   double targetLevel = 999999;

   for (int i = 0; i < 10; i++) {
      double level = m_symbolParams[index].partialLevels[i];

      if (level <= 0) {
         break; // Fim dos níveis válidos
      }

      // Procurar o MENOR nível que foi atingido
      if (currentRR >= level && level < targetLevel) {
         targetLevel = level;
         levelIndex = i;
      }
   }

   // Se não encontrou nível válido
   if (levelIndex < 0) {
      return 0;
   }

   // CORREÇÃO: Calcular volume baseado no volume RESTANTE, não no original
   double partialVolume = totalVolume * m_symbolParams[index].partialVolumes[levelIndex];

   // Ajustar para o tamanho mínimo de lote
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if (stepLot > 0) {
      partialVolume = MathFloor(partialVolume / stepLot) * stepLot;
   }

   if (partialVolume < minLot) {
      if (m_logger != NULL) {
         m_logger.Debug(StringFormat("Volume de parcial ajustado para mínimo: %.2f -> %.2f", 
                                   partialVolume, minLot));
      }
      partialVolume = minLot;
   }

   // IMPORTANTE: Verificar se parcial não é maior que volume disponível
   if (partialVolume >= totalVolume) {
      if (m_logger != NULL) {
         m_logger.Warning(StringFormat("Parcial seria >= volume total (%.2f >= %.2f), ajustando", 
                                     partialVolume, totalVolume));
      }
      // Deixar pelo menos 1 lote mínimo na posição
      partialVolume = totalVolume - minLot;
      
      if (partialVolume < minLot) {
         if (m_logger != NULL) {
            m_logger.Debug("Volume insuficiente para parcial segura");
         }
         return 0; // Não fazer parcial se sobraria muito pouco
      }
   }

   if (m_logger != NULL) {
      m_logger.Info(StringFormat("Calculando parcial: Nível %.2f (%.2f%%), Volume: %.2f de %.2f lotes", 
                               targetLevel, m_symbolParams[index].partialVolumes[levelIndex] * 100, 
                               partialVolume, totalVolume));
   }

   return partialVolume;
}


// ADICIONAR: Método para resetar controle de parciais quando necessário
void CRiskManager::ResetPartialControl(ulong ticket) {
   // Este método pode ser usado para resetar controle interno de parciais
   // se implementarmos um sistema de rastreamento mais sofisticado no futuro
   
   if (m_logger != NULL) {
      m_logger.Debug(StringFormat("Reset de controle de parciais para posição #%d", ticket));
   }
}

//+------------------------------------------------------------------+
//| Calcular risco de uma posição específica                         |
//+------------------------------------------------------------------+
double CRiskManager::CalculatePositionRisk(string symbol, double volume, double openPrice,
                                           double stopLoss, ENUM_POSITION_TYPE posType)
{
   // Verificar parâmetros
   if (symbol == "" || volume <= 0 || openPrice <= 0)
   {
      return 0.0;
   }

   // Se não há stop loss definido, usar ATR como estimativa
   if (stopLoss <= 0)
   {
      double atr = CalculateATRValue(symbol, PERIOD_CURRENT, 14);
      if (atr > 0)
      {
         // Estimar stop loss baseado em 2x ATR
         if (posType == POSITION_TYPE_BUY)
         {
            stopLoss = openPrice - (atr * 2.0);
         }
         else
         {
            stopLoss = openPrice + (atr * 2.0);
         }
      }
      else
      {
         // Se não conseguir calcular ATR, usar 2% do preço como estimativa
         double estimatedStop = openPrice * 0.02;
         if (posType == POSITION_TYPE_BUY)
         {
            stopLoss = openPrice - estimatedStop;
         }
         else
         {
            stopLoss = openPrice + estimatedStop;
         }
      }
   }

   // Calcular distância do stop loss
   double stopDistance = MathAbs(openPrice - stopLoss);
   if (stopDistance <= 0)
   {
      return 0.0;
   }

   // Obter valor do tick e ponto
   double tickValue = GetSymbolTickValue(symbol);
   double pointValue = GetSymbolPointValue(symbol);

   if (tickValue <= 0 || pointValue <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("Valores inválidos para %s: tick=%.5f, point=%.5f",
                                       symbol, tickValue, pointValue));
      }
      return 0.0;
   }

   // Calcular risco em valor monetário
   double stopDistanceInPoints = stopDistance / pointValue;
   double riskAmount = volume * stopDistanceInPoints * tickValue;

   return riskAmount;
}

//+------------------------------------------------------------------+
//| Obter risco total atual de todas as posições abertas            |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentTotalRisk()
{
   double totalRisk = 0.0;

   // Atualizar informações da conta
   UpdateAccountInfo();

   if (m_accountBalance <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("GetCurrentTotalRisk: Saldo da conta inválido");
      }
      return 0.0;
   }

   // Iterar por todas as posições abertas
   int totalPositions = PositionsTotal();

   for (int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket <= 0)
         continue;

      // Obter informações da posição
      string symbol = PositionGetString(POSITION_SYMBOL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double stopLoss = PositionGetDouble(POSITION_SL);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Calcular risco da posição
      double positionRisk = CalculatePositionRisk(symbol, volume, openPrice, stopLoss, posType);
      totalRisk += positionRisk;

      if (m_logger != NULL)
      {
         m_logger.Debug(StringFormat("Posição %s: Volume=%.2f, Risco=%.2f%%",
                                     symbol, volume, positionRisk));
      }
   }

   // Converter para percentual
   double totalRiskPercent = (totalRisk / m_accountBalance) * 100.0;

   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Risco total atual: %.2f%% (%.2f de %.2f)",
                                  totalRiskPercent, totalRisk, m_accountBalance));
   }

   return totalRiskPercent;
}

//+------------------------------------------------------------------+
//| Verificar se nova posição pode ser aberta sem exceder risco      |
//+------------------------------------------------------------------+
bool CRiskManager::CanOpenNewPosition(string symbol, double volume, double entryPrice,
                                      double stopLoss, double requestedRisk)
{
   // Calcular risco atual
   double currentRisk = GetCurrentTotalRisk();

   // Calcular risco da nova posição
   ENUM_POSITION_TYPE estimatedType = (entryPrice > stopLoss) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   double newPositionRisk = CalculatePositionRisk(symbol, volume, entryPrice, stopLoss, estimatedType);
   double newPositionRiskPercent = (newPositionRisk / m_accountBalance) * 100.0;

   // Verificar se o risco total ficaria dentro do limite
   double totalRiskAfter = currentRisk + newPositionRiskPercent;

   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Verificação de risco: Atual=%.2f%%, Nova=%.2f%%, Total=%.2f%%, Limite=%.2f%%",
                                  currentRisk, newPositionRiskPercent, totalRiskAfter, m_maxTotalRisk));
   }

   if (totalRiskAfter > m_maxTotalRisk)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("Nova posição rejeitada: Risco total seria %.2f%% (limite: %.2f%%)",
                                       totalRiskAfter, m_maxTotalRisk));
      }
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Obter percentual de risco disponível para novas posições        |
//+------------------------------------------------------------------+
double CRiskManager::GetAvailableRisk()
{
   double currentRisk = GetCurrentTotalRisk();
   double availableRisk = m_maxTotalRisk - currentRisk;

   return MathMax(0.0, availableRisk);
}

//+------------------------------------------------------------------+
//| Gerar relatório detalhado de risco                              |
//+------------------------------------------------------------------+
void CRiskManager::GenerateRiskReport()
{
   if (m_logger == NULL)
      return;

   m_logger.Info("=== RELATÓRIO DE RISCO ===");

   // Informações da conta
   UpdateAccountInfo();
   m_logger.Info(StringFormat("Saldo: %.2f | Equity: %.2f | Margem Livre: %.2f",
                              m_accountBalance, m_accountEquity, m_accountFreeMargin));

   // Risco total
   double totalRisk = GetCurrentTotalRisk();
   double availableRisk = GetAvailableRisk();

   m_logger.Info(StringFormat("Risco Total: %.2f%% de %.2f%% (%.2f%% disponível)",
                              totalRisk, m_maxTotalRisk, availableRisk));

   // Posições individuais
   int totalPositions = PositionsTotal();
   m_logger.Info(StringFormat("Posições Abertas: %d", totalPositions));

   for (int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket <= 0)
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double stopLoss = PositionGetDouble(POSITION_SL);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double profit = PositionGetDouble(POSITION_PROFIT);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      double positionRisk = CalculatePositionRisk(symbol, volume, openPrice, stopLoss, posType);
      double positionRiskPercent = (positionRisk / m_accountBalance) * 100.0;

      // Calcular R:R atual
      double rr = CalculateCurrentRR(openPrice, currentPrice, stopLoss, posType);

      m_logger.Info(StringFormat("  %s: %.2f lotes | Risco: %.2f%% | P&L: %.2f | R:R: %.2f",
                                 symbol, volume, positionRiskPercent, profit, rr));
   }

   m_logger.Info("=== FIM RELATÓRIO ===");
}

//+------------------------------------------------------------------+
//| Calcular relação risco/recompensa atual de uma posição          |
//+------------------------------------------------------------------+
double CRiskManager::CalculateCurrentRR(double entryPrice, double currentPrice,
                                        double stopLoss, ENUM_POSITION_TYPE posType)
{
   if (stopLoss <= 0 || entryPrice <= 0 || currentPrice <= 0)
   {
      return 0.0;
   }

   double riskDistance = MathAbs(entryPrice - stopLoss);
   if (riskDistance <= 0)
   {
      return 0.0;
   }

   double profitDistance;
   if (posType == POSITION_TYPE_BUY)
   {
      profitDistance = currentPrice - entryPrice;
   }
   else
   {
      profitDistance = entryPrice - currentPrice;
   }

   return profitDistance / riskDistance;
}
//+------------------------------------------------------------------+

#endif // RISKMANAGER_MQH
