//+------------------------------------------------------------------+
//|                                            TradeExecutor.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

// Inclusão de bibliotecas necessárias
#include <Trade/Trade.mqh>
#include "../Core/Structures.mqh"
#include "../Logging/Logger.mqh"
#include "../Logging/JsonLog.mqh"
#include "../Core/Constants.mqh"
#include "../Analysis/MarketContext.mqh"
#include "../Risk/CircuitBreaker.mqh"

// Constantes de erro definidas como macros
#define TRADE_ERROR_NO_ERROR 0
#define TRADE_ERROR_SERVER_BUSY 4
#define TRADE_ERROR_NO_CONNECTION 6
#define TRADE_ERROR_TRADE_TIMEOUT 128
#define TRADE_ERROR_INVALID_PRICE 129
#define TRADE_ERROR_PRICE_CHANGED 135
#define TRADE_ERROR_OFF_QUOTES 136
#define TRADE_ERROR_BROKER_BUSY 137
#define TRADE_ERROR_REQUOTE 138
#define TRADE_ERROR_TOO_MANY_REQUESTS 141
#define TRADE_ERROR_TRADE_CONTEXT_BUSY 146

//+------------------------------------------------------------------+
//| Classe para execução e gerenciamento de ordens                   |
//+------------------------------------------------------------------+
class CTradeExecutor
{
private:
   // Objetos internos
   CTrade *m_trade;
   CLogger *m_logger;
   CMarketContext *m_marketcontext;
   CJSONLogger *m_jsonlog;
   CCircuitBreaker *m_circuitBreaker;


   // Configurações
   bool m_tradeAllowed;
   int m_maxRetries;
   int m_retryDelay;

   // Estado
   int m_lastError;
   string m_lastErrorDesc;

   // Enumeração para tipos de trailing stop
   enum ENUM_TRAILING_TYPE
   {
      TRAILING_FIXED, // Trailing fixo em pontos
      TRAILING_ATR,   // Trailing baseado em ATR
      TRAILING_MA     // Trailing baseado em média móvel
   };

   // Estrutura para armazenar configurações de trailing stop
   struct TrailingStopConfig
   {
      ulong ticket;                    // Ticket da posição
      string symbol;                   // Símbolo
      ENUM_TIMEFRAMES timeframe;       // Timeframe para indicadores
      double fixedPoints;              // Pontos fixos para trailing
      double atrMultiplier;            // Multiplicador de ATR
      int maPeriod;                    // Período da média móvel
      ENUM_TRAILING_TYPE trailingType; // Tipo de trailing
      datetime lastUpdateTime;         // Última atualização
      double lastStopLoss;             // Último stop loss
   };

   // Array de configurações de trailing stop
   TrailingStopConfig m_trailingConfigs[];

   // ✅ ESTRUTURA APRIMORADA: Controle inteligente de parciais com timing automático
   struct PartialControlConfig
   {
      ulong ticket;                    // Ticket da posição
      string symbol;                   // Símbolo
      ENUM_TIMEFRAMES timeframe;       // Timeframe para cálculo automático de timing
      datetime lastPartialTime;        // Timestamp da última parcial
      double lastPartialPrice;         // Preço da última parcial
      int partialsExecuted;           // Número de parciais já executadas
      double nextPartialRR;           // Próximo R:R necessário para parcial
      bool isActive;                  // Se controle está ativo
      double entryPrice;              // Preço de entrada (para cálculos)
      double initialVolume;           // Volume inicial da posição
      datetime entryTime;             // Timestamp de entrada (para análises)
   };

   // Array de configurações de controle de parciais
   PartialControlConfig m_partialConfigs[];

   // Métodos privados
   bool IsRetryableError(int errorCode);
   double CalculateFixedTrailingStop(ulong ticket, double fixedPoints);
   double CalculateATRTrailingStop(string symbol, ENUM_TIMEFRAMES timeframe, double atrMultiplier, ulong ticket);
   double CalculateMATrailingStop(string symbol, ENUM_TIMEFRAMES timeframe, int maPeriod, ulong ticket);
   // Array de configurações de breakeven (adicionar à classe CTradeExecutor)
   BreakevenConfig m_breakevenConfigs[];
   // Métodos privados para breakeven

   void RemoveBreakevenConfig(int index);
   double CalculateATRForBreakeven(string symbol, ulong ticket);

   bool ShouldTriggerBreakeven(int configIndex);
   bool ExecuteBreakeven(int configIndex);
   void CleanupBreakevenConfigs();

   bool IsPositionReadyForTrailing(ulong ticket);

   // Métodos para gerenciamento contínuo
   double CalculateNewTrailingStop(int configIndex);
   bool ShouldUpdateStopLoss(int configIndex, double newStopLoss);
   void RemoveTrailingConfig(int index);
   void ManagePositionRisk();
   void CleanupInvalidConfigurations();

   bool SetBreakevenFixed(ulong ticket, double triggerPoints, double offsetPoints);

   bool SetBreakevenATR(ulong ticket, double atrMultiplier, double offsetPoints);

   bool SetBreakevenRiskRatio(ulong ticket, double riskRatio, double offsetPoints);

   void ManageBreakevens();

   // ✅ NOVO MÉTODO: Verificar se breakeven foi acionado
   bool IsBreakevenTriggered(ulong ticket);

   // ✅ NOVOS MÉTODOS: Controle inteligente de parciais
   bool ConfigurePartialControl(ulong ticket, string symbol, double entryPrice, double initialVolume);
   int FindPartialConfigIndex(ulong ticket);
   void RemovePartialConfig(int index);
   void CleanupPartialConfigs();
   bool ShouldTakePartialNowIntelligent(ulong ticket, double currentPrice);
   double CalculatePartialVolumeIntelligent(ulong ticket, double currentVolume);
   bool IsMinimumTimeElapsed(ulong ticket);
   bool IsMinimumDistanceAchieved(ulong ticket, double currentPrice);
   bool IsPriceMovingFavorably(ulong ticket, double currentPrice);

   // ✅ NOVOS MÉTODOS: Sistema de timing automático
   int CalculateAutomaticTiming(string symbol, ENUM_TIMEFRAMES timeframe, int partialNumber);
   double GetAssetMultiplier(string symbol);
   double GetPartialMultiplier(int partialNumber);
   int GetBaseTimeByTimeframe(ENUM_TIMEFRAMES timeframe);
   double GetVolatilityMultiplier(string symbol);
   double GetSessionMultiplier(string symbol);

   bool ValidateAndAdjustStops(string symbol, ENUM_ORDER_TYPE orderType,
                               double &entryPrice, double &stopLoss, double &takeProfit);

   bool ClosePartialPosition(ulong position_ticket, double partial_volume);

public:
   // Construtores e destrutor
   CTradeExecutor();
   ~CTradeExecutor();

   // Métodos de inicialização
   bool Initialize(CLogger *logger, CMarketContext *marketContext, CCircuitBreaker *circuitBreaker=NULL);

   bool Initialize(CLogger *logger, CJSONLogger *jsonlog, CMarketContext *marketcontext, CCircuitBreaker *circuitBreaker=NULL);

   // Métodos de execução
   bool Execute(OrderRequest &request);
   bool ModifyPosition(ulong ticket, double stopLoss, double takeProfit);
   bool ClosePosition(ulong ticket, double volume = 0.0);
   bool CloseAllPositions(string symbol = "");

   // Métodos de trailing stop
   bool ApplyTrailingStop(ulong ticket, double points);
   bool ApplyATRTrailingStop(ulong ticket, string symbol, ENUM_TIMEFRAMES timeframe, double multiplier);
   bool ApplyMATrailingStop(ulong ticket, string symbol, ENUM_TIMEFRAMES timeframe, int period);
   void ManageOpenPositions();

   void ManagePartialTakeProfits();

   bool ShouldTakePartialNow(string symbol, ulong ticket, double currentPrice, double entryPrice, double stopLoss);

   double CalculatePartialVolume(string symbol, ulong ticket, double currentVolume);

   void ManageTrailingStops();

   // Métodos de configuração
   void SetTradeAllowed(bool allowed) { m_tradeAllowed = allowed; }
   void SetMaxRetries(int retries) { m_maxRetries = retries; }
   void SetRetryDelay(int delay) { m_retryDelay = delay; }

   // Métodos de acesso
   int GetLastError() const { return m_lastError; }
   string GetLastErrorDescription() const { return m_lastErrorDesc; }
   int FindBreakevenConfigIndex(ulong ticket);
   bool AutoConfigureBreakeven(ulong ticket, string symbol);
   bool AutoConfigureTrailingStop(ulong ticket, string symbol);
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CTradeExecutor::CTradeExecutor()
{
   m_trade = NULL;
   m_logger = NULL;
   m_jsonlog = NULL;
   m_marketcontext = NULL;
   m_circuitBreaker = NULL;
   m_tradeAllowed = true;
   m_maxRetries = 3;
   m_retryDelay = 1000; // 1 segundo
   m_lastError = 0;
   m_lastErrorDesc = "";
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CTradeExecutor::~CTradeExecutor()
{
   if (m_trade != NULL)
   {
      delete m_trade;
      m_trade = NULL;
   }
}

bool CTradeExecutor::Initialize(CLogger *logger, CMarketContext *marketContext, CCircuitBreaker *circuitBreaker)
{
   return Initialize(logger, NULL, marketContext, circuitBreaker);
}

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool CTradeExecutor::Initialize(CLogger *logger, CJSONLogger *jsonlog, CMarketContext *  marketcontext, CCircuitBreaker *circuitBreaker)
{
   // Verificar parâmetros
   if (logger == NULL)
   {
      Print("CTradeExecutor::Initialize - Logger não pode ser NULL");
      return false;
   }

   // Atribuir logger
   m_logger = logger;
   m_circuitBreaker = circuitBreaker;
   m_logger.Info("Inicializando TradeExecutor");

   // Atribuir MarketContext
   m_marketcontext = marketcontext;

   // Atribuit jsonlogger
   m_jsonlog = jsonlog;
   // Criar objeto de trade
   m_trade = new CTrade();
   if (m_trade == NULL)
   {
      m_logger.Error("Falha ao criar objeto CTrade");
      return false;
   }

   // Configurar objeto de trade
   m_trade.SetExpertMagicNumber(MAGIC_NUMBER); // Magic number para identificar ordens deste EA
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(Symbol());
   m_trade.SetDeviationInPoints(10); // Desvio máximo de preço em pontos

   m_logger.Info("TradeExecutor inicializado com sucesso");
   return true;
}


//+------------------------------------------------------------------+
//| Aplicar trailing stop fixo                                       |
//+------------------------------------------------------------------+
bool CTradeExecutor::ApplyTrailingStop(ulong ticket, double points)
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   // Verificar parâmetros
   if (ticket <= 0 || points <= 0)
   {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros inválidos para trailing stop";
      m_logger.Error(m_lastErrorDesc);
      return false;
   }

   // Verificar se a posição existe
   if (!PositionSelectByTicket(ticket))
   {
      m_lastError = -3;
      m_lastErrorDesc = "Posição não encontrada";
      m_logger.Error(StringFormat("Falha ao selecionar posição #%d para trailing stop", ticket));
      return false;
   }

   // Obter símbolo da posição
   string symbol = PositionGetString(POSITION_SYMBOL);

   // Verificar se já existe configuração para esta posição
   int index = -1;
   int size = ArraySize(m_trailingConfigs);

   for (int i = 0; i < size; i++)
   {
      if (m_trailingConfigs[i].ticket == ticket)
      {
         index = i;
         break;
      }
   }

   // Se não existir, criar nova configuração
   if (index < 0)
   {
      index = size;
      ArrayResize(m_trailingConfigs, size + 1);

      m_trailingConfigs[index].ticket = ticket;
      m_trailingConfigs[index].symbol = symbol;
      m_trailingConfigs[index].timeframe = PERIOD_CURRENT;
      m_trailingConfigs[index].trailingType = TRAILING_FIXED;
      m_trailingConfigs[index].lastUpdateTime = 0;
      m_trailingConfigs[index].lastStopLoss = 0;
   }

   // Atualizar configuração
   m_trailingConfigs[index].fixedPoints = points;
   m_trailingConfigs[index].trailingType = TRAILING_FIXED;

   m_logger.Info(StringFormat("Trailing stop fixo aplicado à posição #%d: %.1f pontos", ticket, points));

   // Calcular e aplicar stop loss imediatamente
   double newStopLoss = CalculateFixedTrailingStop(ticket, points);

   if (newStopLoss > 0)
   {
      double currentStopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);

      // Verificar se o novo stop loss é melhor que o atual
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool isImprovement = false;

      if (posType == POSITION_TYPE_BUY && (currentStopLoss < newStopLoss || currentStopLoss == 0))
      {
         isImprovement = true;
      }
      else if (posType == POSITION_TYPE_SELL && (currentStopLoss > newStopLoss || currentStopLoss == 0))
      {
         isImprovement = true;
      }

      // Modificar posição se o novo stop loss for melhor
      if (isImprovement)
      {
         if (ModifyPosition(ticket, newStopLoss, takeProfit))
         {
            m_trailingConfigs[index].lastStopLoss = newStopLoss;
            m_trailingConfigs[index].lastUpdateTime = TimeCurrent();
            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Aplicar trailing stop baseado em ATR                             |
//+------------------------------------------------------------------+
bool CTradeExecutor::ApplyATRTrailingStop(ulong ticket, string symbol, ENUM_TIMEFRAMES timeframe, double multiplier)
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   // Verificar parâmetros
   if (ticket <= 0 || symbol == "" || multiplier <= 0)
   {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros inválidos para trailing stop ATR";
      m_logger.Error(m_lastErrorDesc);
      return false;
   }

   // Verificar se a posição existe
   if (!PositionSelectByTicket(ticket))
   {
      m_lastError = -3;
      m_lastErrorDesc = "Posição não encontrada";
      m_logger.Error(StringFormat("Falha ao selecionar posição #%d para trailing stop ATR", ticket));
      return false;
   }

   // Verificar se o símbolo corresponde à posição
   string posSymbol = PositionGetString(POSITION_SYMBOL);
   if (posSymbol != symbol)
   {
      m_lastError = -4;
      m_lastErrorDesc = "Símbolo não corresponde à posição";
      m_logger.Error(StringFormat("Símbolo %s não corresponde à posição #%d (%s)", symbol, ticket, posSymbol));
      return false;
   }

   // Verificar se já existe configuração para esta posição
   int index = -1;
   int size = ArraySize(m_trailingConfigs);

   for (int i = 0; i < size; i++)
   {
      if (m_trailingConfigs[i].ticket == ticket)
      {
         index = i;
         break;
      }
   }

   // Se não existir, criar nova configuração
   if (index < 0)
   {
      index = size;
      ArrayResize(m_trailingConfigs, size + 1);

      m_trailingConfigs[index].ticket = ticket;
      m_trailingConfigs[index].symbol = symbol;
      m_trailingConfigs[index].timeframe = timeframe;
      m_trailingConfigs[index].trailingType = TRAILING_ATR;
      m_trailingConfigs[index].lastUpdateTime = 0;
      m_trailingConfigs[index].lastStopLoss = 0;
   }

   // Atualizar configuração
   m_trailingConfigs[index].atrMultiplier = multiplier;
   m_trailingConfigs[index].timeframe = timeframe;
   m_trailingConfigs[index].trailingType = TRAILING_ATR;

   m_logger.Info(StringFormat("Trailing stop ATR aplicado à posição #%d: multiplicador %.1f", ticket, multiplier));

   // Calcular e aplicar stop loss imediatamente
   double newStopLoss = CalculateATRTrailingStop(symbol, timeframe, multiplier, ticket);

   if (newStopLoss > 0)
   {
      double currentStopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);

      // Verificar se o novo stop loss é melhor que o atual
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool isImprovement = false;

      if (posType == POSITION_TYPE_BUY && (currentStopLoss < newStopLoss || currentStopLoss == 0))
      {
         isImprovement = true;
      }
      else if (posType == POSITION_TYPE_SELL && (currentStopLoss > newStopLoss || currentStopLoss == 0))
      {
         isImprovement = true;
      }

      // Modificar posição se o novo stop loss for melhor
      if (isImprovement)
      {
         if (ModifyPosition(ticket, newStopLoss, takeProfit))
         {
            m_trailingConfigs[index].lastStopLoss = newStopLoss;
            m_trailingConfigs[index].lastUpdateTime = TimeCurrent();
            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Aplicar trailing stop baseado em média móvel                     |
//+------------------------------------------------------------------+
bool CTradeExecutor::ApplyMATrailingStop(ulong ticket, string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   // Verificar parâmetros
   if (ticket <= 0 || symbol == "" || period <= 0)
   {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros inválidos para trailing stop MA";
      m_logger.Error(m_lastErrorDesc);
      return false;
   }

   // Verificar se a posição existe
   if (!PositionSelectByTicket(ticket))
   {
      m_lastError = -3;
      m_lastErrorDesc = "Posição não encontrada";
      m_logger.Error(StringFormat("Falha ao selecionar posição #%d para trailing stop MA", ticket));
      return false;
   }

   // Verificar se o símbolo corresponde à posição
   string posSymbol = PositionGetString(POSITION_SYMBOL);
   if (posSymbol != symbol)
   {
      m_lastError = -4;
      m_lastErrorDesc = "Símbolo não corresponde à posição";
      m_logger.Error(StringFormat("Símbolo %s não corresponde à posição #%d (%s)", symbol, ticket, posSymbol));
      return false;
   }

   // Verificar se já existe configuração para esta posição
   int index = -1;
   int size = ArraySize(m_trailingConfigs);

   for (int i = 0; i < size; i++)
   {
      if (m_trailingConfigs[i].ticket == ticket)
      {
         index = i;
         break;
      }
   }

   // Se não existir, criar nova configuração
   if (index < 0)
   {
      index = size;
      ArrayResize(m_trailingConfigs, size + 1);

      m_trailingConfigs[index].ticket = ticket;
      m_trailingConfigs[index].symbol = symbol;
      m_trailingConfigs[index].timeframe = timeframe;
      m_trailingConfigs[index].trailingType = TRAILING_MA;
      m_trailingConfigs[index].lastUpdateTime = 0;
      m_trailingConfigs[index].lastStopLoss = 0;
   }

   // Atualizar configuração
   m_trailingConfigs[index].maPeriod = period;
   m_trailingConfigs[index].timeframe = timeframe;
   m_trailingConfigs[index].trailingType = TRAILING_MA;

   m_logger.Info(StringFormat("Trailing stop MA aplicado à posição #%d: período %d", ticket, period));

   // Calcular e aplicar stop loss imediatamente
   double newStopLoss = CalculateMATrailingStop(symbol, timeframe, period, ticket);

   if (newStopLoss > 0)
   {
      double currentStopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);

      // Verificar se o novo stop loss é melhor que o atual
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool isImprovement = false;

      if (posType == POSITION_TYPE_BUY && (currentStopLoss < newStopLoss || currentStopLoss == 0))
      {
         isImprovement = true;
      }
      else if (posType == POSITION_TYPE_SELL && (currentStopLoss > newStopLoss || currentStopLoss == 0))
      {
         isImprovement = true;
      }

      // Modificar posição se o novo stop loss for melhor
      if (isImprovement)
      {
         if (ModifyPosition(ticket, newStopLoss, takeProfit))
         {
            m_trailingConfigs[index].lastStopLoss = newStopLoss;
            m_trailingConfigs[index].lastUpdateTime = TimeCurrent();
            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Verificar se o erro é recuperável                                |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| ✅ FUNÇÃO AUXILIAR: Verificar Erros Recuperáveis               |
//| Determina se vale a pena tentar novamente                       |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsRetryableError(int error_code)
{
   switch(error_code)
   {
      case TRADE_RETCODE_REQUOTE:          // Requote
      case TRADE_RETCODE_CONNECTION:       // Sem conexão
      case TRADE_RETCODE_PRICE_CHANGED:    // Preço mudou
      case TRADE_RETCODE_TIMEOUT:          // Timeout
      case TRADE_RETCODE_PRICE_OFF:        // Preço inválido
      case TRADE_RETCODE_REJECT:           // Requisição rejeitada
      case TRADE_RETCODE_TOO_MANY_REQUESTS: // Muitas requisições
         return true;
         
      case TRADE_RETCODE_INVALID_VOLUME:   // Volume inválido
      case TRADE_RETCODE_INVALID_PRICE:    // Preço inválido
      case TRADE_RETCODE_INVALID_STOPS:    // Stops inválidos
      case TRADE_RETCODE_TRADE_DISABLED:   // Trading desabilitado
      case TRADE_RETCODE_MARKET_CLOSED:    // Mercado fechado
      case TRADE_RETCODE_NO_MONEY:         // Sem dinheiro
      case TRADE_RETCODE_POSITION_CLOSED:  // Posição já fechada
         return false;
         
      default:
         return false;
   }
}
//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA CRÍTICA: CalculateFixedTrailingStop         |
//| CORREÇÃO: Remove proteção excessiva que bloqueava trailing      |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculateFixedTrailingStop(ulong ticket, double fixedPoints)
{
   if (ticket <= 0 || fixedPoints <= 0)
   {
      return 0.0;
   }

   if (!PositionSelectByTicket(ticket))
   {
      return 0.0;
   }

   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double currentStopLoss = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   string symbol = PositionGetString(POSITION_SYMBOL);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   if (entryPrice <= 0 || currentPrice <= 0 || point <= 0)
   {
      return 0.0;
   }

   // ✅ CORREÇÃO: Usar valores configurados diretamente
   double adjustedPoints = fixedPoints;
   double stopDistance = adjustedPoints * point;
   double newStopLoss = 0.0;

   // ✅ VERIFICAR SE BREAKEVEN FOI ACIONADO
   bool breakevenTriggered = IsBreakevenTriggered(ticket);

   if (posType == POSITION_TYPE_BUY)
   {
      newStopLoss = currentPrice - stopDistance;

      // ✅ CORREÇÃO CRÍTICA: Lógica diferente ANTES e APÓS breakeven
      if (!breakevenTriggered)
      {
         // ANTES do breakeven: proteção normal
         double minSafeSL = entryPrice * 0.98; // Máximo 2% de perda
         newStopLoss = MathMax(newStopLoss, minSafeSL);
      }
      else
      {
         // ✅ APÓS breakeven: SL nunca pode ir abaixo da entrada
         newStopLoss = MathMax(newStopLoss, entryPrice);
         
         if (m_logger != NULL)
         {
            static datetime lastBreakevenLog = 0;
            if (TimeCurrent() - lastBreakevenLog > 300) // A cada 5 minutos
            {
               m_logger.Debug(StringFormat("Trailing #%d PÓS-BREAKEVEN: SL mínimo = entrada (%.5f)", 
                                         ticket, entryPrice));
               lastBreakevenLog = TimeCurrent();
            }
         }
      }
      
      // ✅ SEMPRE: NUNCA mover SL para trás
      newStopLoss = MathMax(newStopLoss, currentStopLoss);

      // ✅ CORREÇÃO CRÍTICA: Remover verificação que bloqueava trailing
      // A verificação de prejuízo foi removida - trailing sempre funciona
   }
   else if (posType == POSITION_TYPE_SELL)
   {
      newStopLoss = currentPrice + stopDistance;

      // ✅ CORREÇÃO CRÍTICA: Lógica diferente ANTES e APÓS breakeven
      if (!breakevenTriggered)
      {
         // ANTES do breakeven: proteção normal
         double maxSafeSL = entryPrice * 1.02; // Máximo 2% de perda
         newStopLoss = MathMin(newStopLoss, maxSafeSL);
      }
      else
      {
         // ✅ APÓS breakeven: SL nunca pode ir acima da entrada
         newStopLoss = MathMin(newStopLoss, entryPrice);
         
         if (m_logger != NULL)
         {
            static datetime lastBreakevenLog = 0;
            if (TimeCurrent() - lastBreakevenLog > 300) // A cada 5 minutos
            {
               m_logger.Debug(StringFormat("Trailing #%d PÓS-BREAKEVEN: SL máximo = entrada (%.5f)", 
                                         ticket, entryPrice));
               lastBreakevenLog = TimeCurrent();
            }
         }
      }
      
      // ✅ SEMPRE: NUNCA mover SL para trás
      newStopLoss = MathMin(newStopLoss, currentStopLoss);

      // ✅ CORREÇÃO CRÍTICA: Remover verificação que bloqueava trailing
      // A verificação de prejuízo foi removida - trailing sempre funciona
   }
   else
   {
      return 0.0;
   }

   newStopLoss = NormalizeDouble(newStopLoss, digits);

   // ✅ ADICIONADO: Log detalhado para monitoramento
   if (m_logger != NULL)
   {
      double profitPoints = 0;
      if (posType == POSITION_TYPE_BUY)
      {
         profitPoints = (currentPrice - entryPrice) / point;
      }
      else
      {
         profitPoints = (entryPrice - currentPrice) / point;
      }
      
      static datetime lastDetailLog = 0;
      if (TimeCurrent() - lastDetailLog > 60) // A cada minuto
      {
         m_logger.Debug(StringFormat("Trailing #%d: preço=%.5f, lucro=%.1fpts, SL_atual=%.5f, SL_novo=%.5f, breakeven=%s",
                                   ticket, currentPrice, profitPoints, currentStopLoss, newStopLoss,
                                   breakevenTriggered ? "SIM" : "NÃO"));
         lastDetailLog = TimeCurrent();
      }
   }

   return newStopLoss;
}
//+------------------------------------------------------------------+
//| Calcular stop loss para trailing stop baseado em ATR             |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculateATRTrailingStop(string symbol, ENUM_TIMEFRAMES timeframe, double atrMultiplier, ulong ticket)
{
   // Verificar parâmetros
   if (symbol == "" || atrMultiplier <= 0 || ticket <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Parâmetros inválidos para cálculo de trailing stop ATR");
      }
      return 0.0;
   }
   
   // ✅ Verificar se o contexto de mercado está disponível
   if (m_marketcontext == NULL)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Contexto de mercado não inicializado");
      }
      return 0.0;
   }
   
   // ✅ Verificar se o contexto tem dados válidos
   if (!m_marketcontext.HasValidData())
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("Dados de mercado insuficientes para cálculo de trailing stop ATR");
      }
      return 0.0;
   }
   
   // ✅ Atualizar contexto para o símbolo correto
   if (!m_marketcontext.UpdateSymbol(symbol))
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Falha ao atualizar contexto para " + symbol);
      }
      return 0.0;
   }
   
   // Verificar se a posição existe
   if (!PositionSelectByTicket(ticket))
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Falha ao selecionar posição #" + IntegerToString(ticket));
      }
      return 0.0;
   }
   
   // Obter informações da posição
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   // Verificar se os valores são válidos
   if (openPrice <= 0 || currentPrice <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Valores inválidos para cálculo de trailing stop ATR");
      }
      return 0.0;
   }
   
   // ✅ Obter handle do ATR através do contexto de mercado
   CIndicatorHandle* atrHandle = m_marketcontext.GetATRHandle(timeframe);
   if (atrHandle == NULL || !atrHandle.IsValid())
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Falha ao obter handle do ATR do pool para " + symbol);
      }
      return 0.0;
   }
   
   // ✅ Copiar valores do ATR usando o método do handle
   double atrValues[];
   // ✅ Configurar array como série temporal
   ArraySetAsSeries(atrValues, true);

   if (atrHandle.CopyBuffer(0, 0, 1, atrValues) <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Falha ao copiar valores do ATR: " + IntegerToString(GetLastError()));
      }
      return 0.0;
   }  
  
   // Calcular distância baseada no ATR
   double atrValue = atrValues[0];
   double stopDistance = atrValue * atrMultiplier;
   
   // Verificar se o valor do ATR é válido
   if (atrValue <= 0 || stopDistance <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("Valor do ATR inválido para cálculo de trailing stop");
      }
      return 0.0;
   }
   
   // Calcular novo stop loss
   double newStopLoss = 0.0;
   if (posType == POSITION_TYPE_BUY)
   {
      newStopLoss = currentPrice - stopDistance;
      // Verificar se o preço está em lucro
      if (currentPrice <= openPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Debug("Trailing stop ATR não aplicado: posição de compra não está em lucro");
         }
         return 0.0;
      }
   }
   else if (posType == POSITION_TYPE_SELL)
   {
      newStopLoss = currentPrice + stopDistance;
      // Verificar se o preço está em lucro
      if (currentPrice >= openPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Debug("Trailing stop ATR não aplicado: posição de venda não está em lucro");
         }
         return 0.0;
      }
   }
   else
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Tipo de posição inválido para cálculo de trailing stop ATR");
      }
      return 0.0;
   }
   
   // Normalizar o stop loss
   newStopLoss = NormalizeDouble(newStopLoss, digits);
   
   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Trailing stop ATR calculado para posição #%d: %.5f (ATR: %.5f)",
                                  ticket, newStopLoss, atrValue));
   }
   
   return newStopLoss;
}
//+------------------------------------------------------------------+
//| Calcular stop loss para trailing stop baseado em média móvel     |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculateMATrailingStop(string symbol, ENUM_TIMEFRAMES timeframe, int maPeriod, ulong ticket)
{
   // Verificar parâmetros
   if (symbol == "" || maPeriod <= 0 || ticket <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Parâmetros inválidos para cálculo de trailing stop MA");
      }
      return 0.0;
   }

   // Verificar se a posição existe
   if (!PositionSelectByTicket(ticket))
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Falha ao selecionar posição #" + IntegerToString(ticket));
      }
      return 0.0;
   }

   // Obter informações da posição
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   // Verificar se os valores são válidos
   if (openPrice <= 0 || currentPrice <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Valores inválidos para cálculo de trailing stop MA");
      }
      return 0.0;
   }

   // Criar handle da média móvel
   int maHandle = iMA(symbol, timeframe, maPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if (maHandle == INVALID_HANDLE)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Falha ao criar handle da média móvel: " + IntegerToString(GetLastError()));
      }
      return 0.0;
   }

   // Copiar valores da média móvel
   double maValues[];
   ArraySetAsSeries(maValues, true);
   int copied = CopyBuffer(maHandle, 0, 0, 1, maValues);
   IndicatorRelease(maHandle);

   if (copied <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Falha ao copiar valores da média móvel: " + IntegerToString(GetLastError()));
      }
      return 0.0;
   }

   // Obter valor da média móvel
   double maValue = maValues[0];

   // Verificar se o valor da média móvel é válido
   if (maValue <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("Valor da média móvel inválido para cálculo de trailing stop");
      }
      return 0.0;
   }

   // Calcular novo stop loss
   double newStopLoss = 0.0;

   if (posType == POSITION_TYPE_BUY)
   {
      // Para compras, usar a média móvel como stop loss se estiver abaixo do preço atual
      if (maValue < currentPrice)
      {
         newStopLoss = maValue;
      }
      else
      {
         if (m_logger != NULL)
         {
            m_logger.Debug("Trailing stop MA não aplicado: média móvel acima do preço atual para compra");
         }
         return 0.0;
      }

      // Verificar se o preço está em lucro
      if (currentPrice <= openPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Debug("Trailing stop MA não aplicado: posição de compra não está em lucro");
         }
         return 0.0;
      }
   }
   else if (posType == POSITION_TYPE_SELL)
   {
      // Para vendas, usar a média móvel como stop loss se estiver acima do preço atual
      if (maValue > currentPrice)
      {
         newStopLoss = maValue;
      }
      else
      {
         if (m_logger != NULL)
         {
            m_logger.Debug("Trailing stop MA não aplicado: média móvel abaixo do preço atual para venda");
         }
         return 0.0;
      }

      // Verificar se o preço está em lucro
      if (currentPrice >= openPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Debug("Trailing stop MA não aplicado: posição de venda não está em lucro");
         }
         return 0.0;
      }
   }
   else
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Tipo de posição inválido para cálculo de trailing stop MA");
      }
      return 0.0;
   }

   // Normalizar o stop loss
   newStopLoss = NormalizeDouble(newStopLoss, digits);

   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Trailing stop MA calculado para posição #%d: %.5f (MA: %.5f)",
                                  ticket, newStopLoss, maValue));
   }

   return newStopLoss;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO APRIMORADA: ManageTrailingStops                       |
//| CORREÇÃO: Logs detalhados para identificar problemas            |
//+------------------------------------------------------------------+
void CTradeExecutor::ManageTrailingStops()
{
   int size = ArraySize(m_trailingConfigs);
   if (size == 0)
   {
      static datetime lastLogTime = 0;
      if (TimeCurrent() - lastLogTime > 60)
      {
         if (m_logger != NULL)
         {
            m_logger.Debug("ManageTrailingStops: Nenhuma configuração ativa");
         }
         lastLogTime = TimeCurrent();
      }
      return;
   }

   // ✅ CORREÇÃO: Log mais frequente para monitoramento crítico
   static datetime lastStatusLog = 0;
   if (TimeCurrent() - lastStatusLog > 60) // A cada minuto (era 5 minutos)
   {
      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("ManageTrailingStops: Gerenciando %d configurações ativas", size));
         
         // ✅ ADICIONADO: Log detalhado de cada configuração ativa
         for (int j = 0; j < size; j++)
         {
            if (PositionSelectByTicket(m_trailingConfigs[j].ticket))
            {
               double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
               double currentSL = PositionGetDouble(POSITION_SL);
               double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               
               m_logger.Info(StringFormat("  Ticket #%d: entrada=%.5f, atual=%.5f, SL=%.5f",
                                        m_trailingConfigs[j].ticket, entryPrice, currentPrice, currentSL));
            }
         }
      }
      lastStatusLog = TimeCurrent();
   }

   for (int i = size - 1; i >= 0; i--)
   {
      if (!PositionSelectByTicket(m_trailingConfigs[i].ticket))
      {
         if (m_logger != NULL)
         {
            m_logger.Info(StringFormat("Removendo configuração trailing #%d (posição fechada)",
                                     m_trailingConfigs[i].ticket));
         }
         RemoveTrailingConfig(i);
         size--;
         continue;
      }

      // ✅ VERIFICAR SE ESTÁ PRONTO PARA TRAILING
      if (!IsPositionReadyForTrailing(m_trailingConfigs[i].ticket))
      {
         continue;
      }

      // ✅ ADICIONADO: Log antes do cálculo crítico
      if (m_logger != NULL)
      {
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double currentSL = PositionGetDouble(POSITION_SL);
         m_logger.Debug(StringFormat("Calculando trailing #%d: preço=%.5f, SL_atual=%.5f",
                                   m_trailingConfigs[i].ticket, currentPrice, currentSL));
      }

      // Calcular novo stop loss
      double newStopLoss = CalculateNewTrailingStop(i);

      // ✅ ADICIONADO: Log crítico do resultado
      if (m_logger != NULL)
      {
         double currentStopLoss = PositionGetDouble(POSITION_SL);
         if (newStopLoss > 0)
         {
            double improvement = MathAbs(newStopLoss - currentStopLoss) / SymbolInfoDouble(m_trailingConfigs[i].symbol, SYMBOL_POINT);
            m_logger.Debug(StringFormat("Resultado cálculo #%d: SL_novo=%.5f, melhoria=%.1f pontos",
                                      m_trailingConfigs[i].ticket, newStopLoss, improvement));
         }
         else
         {
            m_logger.Warning(StringFormat("❌ CRÍTICO: Cálculo #%d retornou 0 - investigar!",
                                        m_trailingConfigs[i].ticket));
         }
      }

      if (newStopLoss > 0)
      {
         if (ShouldUpdateStopLoss(i, newStopLoss))
         {
            double takeProfit = PositionGetDouble(POSITION_TP);

            if (ModifyPosition(m_trailingConfigs[i].ticket, newStopLoss, takeProfit))
            {
               m_trailingConfigs[i].lastStopLoss = newStopLoss;
               m_trailingConfigs[i].lastUpdateTime = TimeCurrent();

               if (m_logger != NULL)
               {
                  double oldSL = PositionGetDouble(POSITION_SL);
                  double improvement = MathAbs(newStopLoss - oldSL) / SymbolInfoDouble(m_trailingConfigs[i].symbol, SYMBOL_POINT);
                  m_logger.Info(StringFormat("✅ TRAILING ATUALIZADO #%d: %.5f → %.5f (melhoria: %.1f pontos)",
                                           m_trailingConfigs[i].ticket, oldSL, newStopLoss, improvement));
               }
            }
            else
            {
               if (m_logger != NULL)
               {
                  m_logger.Error(StringFormat("❌ FALHA trailing #%d: %s",
                                            m_trailingConfigs[i].ticket, GetLastErrorDescription()));
               }
            }
         }
         else
         {
            // ✅ ADICIONADO: Log detalhado da rejeição
            if (m_logger != NULL)
            {
               double currentStopLoss = PositionGetDouble(POSITION_SL);
               double improvement = MathAbs(newStopLoss - currentStopLoss) / SymbolInfoDouble(m_trailingConfigs[i].symbol, SYMBOL_POINT);
               m_logger.Debug(StringFormat("Trailing #%d rejeitado: melhoria %.1f < 15 pontos mínimos",
                                         m_trailingConfigs[i].ticket, improvement));
            }
         }
      }
   }
}


//+------------------------------------------------------------------+
//| ✅ FUNÇÃO COMPLETAMENTE CORRIGIDA: IsPositionReadyForTrailing   |
//| CORREÇÃO CRÍTICA: Remove verificação contínua problemática      |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsPositionReadyForTrailing(ulong ticket)
{
   if (!PositionSelectByTicket(ticket))
   {
      return false;
   }

   // ✅ CORREÇÃO CRÍTICA: Verificar se breakeven foi acionado PRIMEIRO
   if (!IsBreakevenTriggered(ticket))
   {
      if (m_logger != NULL)
      {
         static datetime lastBreakevenLog = 0;
         if (TimeCurrent() - lastBreakevenLog > 300) // A cada 5 minutos
         {
            m_logger.Debug(StringFormat("Trailing #%d AGUARDANDO breakeven ser acionado primeiro", ticket));
            lastBreakevenLog = TimeCurrent();
         }
      }
      return false; // ❌ NÃO permitir trailing antes do breakeven
   }

   // ✅ ADICIONADO: Log quando trailing é liberado após breakeven
   if (m_logger != NULL)
   {
      static datetime lastReleaseLog = 0;
      if (TimeCurrent() - lastReleaseLog > 300) // A cada 5 minutos
      {
         m_logger.Info(StringFormat("Trailing #%d LIBERADO: breakeven já foi acionado", ticket));
         lastReleaseLog = TimeCurrent();
      }
   }

   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double stopLoss = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   string symbol = PositionGetString(POSITION_SYMBOL);

   // Calcular lucro atual em pontos
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double profitPoints = 0;

   if (posType == POSITION_TYPE_BUY)
   {
      profitPoints = (currentPrice - entryPrice) / point;
   }
   else
   {
      profitPoints = (entryPrice - currentPrice) / point;
   }

   // ✅ CORREÇÃO CRÍTICA: Verificação simplificada e robusta
   // Só verificar lucro mínimo - R:R é verificado apenas na ativação inicial
   bool hasMinimumProfit = (profitPoints >= TRAILING_MIN_PROFIT_POINTS);

   // ✅ CORREÇÃO CRÍTICA: Verificar se trailing já foi ativado
   // Se SL já está em lucro (acima da entrada para BUY), trailing já está ativo
   bool trailingAlreadyActive = false;
   
   if (posType == POSITION_TYPE_BUY)
   {
      trailingAlreadyActive = (stopLoss > entryPrice);
   }
   else
   {
      trailingAlreadyActive = (stopLoss < entryPrice);
   }

   // ✅ LÓGICA CORRIGIDA: Se trailing já ativo OU condições iniciais atendidas
   if (trailingAlreadyActive)
   {
      // Trailing já está ativo, apenas verificar se ainda há lucro suficiente
      bool hasMinimumActiveProfit = (profitPoints >= 10); // Mínimo 10 pontos para manter ativo
      
      // ✅ ADICIONADO: Log detalhado quando trailing já está ativo
      if (m_logger != NULL)
      {
         static datetime lastActiveLog = 0;
         if (TimeCurrent() - lastActiveLog > 300) // A cada 5 minutos
         {
            m_logger.Debug(StringFormat("Trailing #%d JÁ ATIVO: lucro=%.1f, SL=%.5f (%.1f pts acima entrada)",
                                      ticket, profitPoints, stopLoss, 
                                      MathAbs(stopLoss - entryPrice) / point));
            lastActiveLog = TimeCurrent();
         }
      }
      
      return hasMinimumActiveProfit;
   }
   else
   {
      // Trailing ainda não ativo, verificar condições de ativação inicial
      bool hasMinimumRR = false;
      
      if (stopLoss > 0)
      {
         double riskPoints = 0;
         
         // ✅ CORREÇÃO CRÍTICA: Usar valor absoluto para evitar negativos
         if (posType == POSITION_TYPE_BUY)
         {
            riskPoints = MathAbs(entryPrice - stopLoss) / point;
         }
         else
         {
            riskPoints = MathAbs(stopLoss - entryPrice) / point;
         }

         if (riskPoints > 0)
         {
            double currentRR = profitPoints / riskPoints;
            hasMinimumRR = (currentRR >= TRAILING_ACTIVATION_RR);
            
            // ✅ ADICIONADO: Log detalhado da verificação inicial
            if (m_logger != NULL)
            {
               static datetime lastInitLog = 0;
               if (TimeCurrent() - lastInitLog > 60) // A cada minuto
               {
                  m_logger.Debug(StringFormat("Trailing #%d VERIFICAÇÃO INICIAL: lucro=%.1f (min=%d), risco=%.1f, R:R=%.2f (min=%.1f), pronto=%s",
                                           ticket, profitPoints, TRAILING_MIN_PROFIT_POINTS,
                                           riskPoints, currentRR, TRAILING_ACTIVATION_RR,
                                           (hasMinimumProfit && hasMinimumRR) ? "SIM" : "NÃO"));
                  lastInitLog = TimeCurrent();
               }
            }
         }
         else
         {
            // ✅ ADICIONADO: Log quando risco é zero ou inválido
            if (m_logger != NULL)
            {
               m_logger.Warning(StringFormat("Trailing #%d: risco calculado = 0 (SL=%.5f, entrada=%.5f)",
                                           ticket, stopLoss, entryPrice));
            }
         }
      }
      else
      {
         // ✅ ADICIONADO: Log quando não há SL definido
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Trailing #%d: SL não definido (stopLoss=%.5f)",
                                        ticket, stopLoss));
         }
      }

      return hasMinimumProfit && hasMinimumRR;
   }
}

//+------------------------------------------------------------------+
//| Calcular novo trailing stop baseado no tipo                      |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculateNewTrailingStop(int configIndex)
{
   if (configIndex < 0 || configIndex >= ArraySize(m_trailingConfigs))
   {
      return 0.0;
   }

   TrailingStopConfig config = m_trailingConfigs[configIndex];

   switch (config.trailingType)
   {
   case TRAILING_FIXED:
      return CalculateFixedTrailingStop(config.ticket, config.fixedPoints);

   case TRAILING_ATR:
      return CalculateATRTrailingStop(config.symbol, config.timeframe,
                                      config.atrMultiplier, config.ticket);

   case TRAILING_MA:
      return CalculateMATrailingStop(config.symbol, config.timeframe,
                                     config.maPeriod, config.ticket);
   }

   return 0.0;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ShouldUpdateStopLoss                       |
//| CORREÇÃO: Valores de melhoria reduzidos após breakeven          |
//+------------------------------------------------------------------+
bool CTradeExecutor::ShouldUpdateStopLoss(int configIndex, double newStopLoss)
{
   if (configIndex < 0 || configIndex >= ArraySize(m_trailingConfigs))
   {
      return false;
   }

   double currentStopLoss = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   string symbol = m_trailingConfigs[configIndex].symbol;
   ulong ticket = m_trailingConfigs[configIndex].ticket;

   // ✅ VERIFICAR SE BREAKEVEN FOI ACIONADO
   bool breakevenTriggered = IsBreakevenTriggered(ticket);

   // ✅ CORREÇÃO CRÍTICA: Valores diferentes ANTES e APÓS breakeven
   double minImprovement = 0;

   if (StringFind(symbol, "WIN") >= 0)
   {
      minImprovement = breakevenTriggered ? 5 : 15; // ✅ Reduzido após breakeven
   }
   else if (StringFind(symbol, "WDO") >= 0)
   {
      minImprovement = breakevenTriggered ? 1 : 2;  // ✅ Reduzido após breakeven
   }
   else if (StringFind(symbol, "BIT") >= 0)
   {
      minImprovement = breakevenTriggered ? 25 : 50; // ✅ Reduzido após breakeven
   }
   else
   {
      minImprovement = breakevenTriggered ? 5 : 10;  // ✅ Padrão reduzido após breakeven
   }

   // Verificar se há melhoria suficiente
   double improvement = 0;
   bool isImprovement = false;

   if (posType == POSITION_TYPE_BUY)
   {
      if (newStopLoss > currentStopLoss)
      {
         improvement = (newStopLoss - currentStopLoss) / SymbolInfoDouble(symbol, SYMBOL_POINT);
         isImprovement = (improvement >= minImprovement);
      }
   }
   else
   {
      if (newStopLoss < currentStopLoss)
      {
         improvement = (currentStopLoss - newStopLoss) / SymbolInfoDouble(symbol, SYMBOL_POINT);
         isImprovement = (improvement >= minImprovement);
      }
   }

   // ✅ ADICIONADO: Log detalhado da decisão
   if (m_logger != NULL)
   {
      static datetime lastDecisionLog = 0;
      if (TimeCurrent() - lastDecisionLog > 120) // A cada 2 minutos
      {
         m_logger.Debug(StringFormat("Decisão trailing #%d: melhoria=%.1f, mínimo=%.1f, breakeven=%s, atualizar=%s",
                                   ticket, improvement, minImprovement, 
                                   breakevenTriggered ? "SIM" : "NÃO",
                                   isImprovement ? "SIM" : "NÃO"));
         lastDecisionLog = TimeCurrent();
      }
   }

   return isImprovement;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO COMPLETAMENTE REESCRITA: ManagePartialTakeProfits     |
//| CORREÇÃO: Sistema inteligente com controle de tempo e distância |
//+------------------------------------------------------------------+
void CTradeExecutor::ManagePartialTakeProfits()
{
   static datetime lastPartialCheck = 0;
   datetime currentTime = TimeCurrent();

   // ✅ CORREÇÃO: Verificar parciais a cada 30 segundos (não 5)
   if (currentTime - lastPartialCheck < 30)
   {
      return;
   }
   lastPartialCheck = currentTime;

   int totalPositions = PositionsTotal();

   for (int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket <= 0)
         continue;

      if (!PositionSelectByTicket(ticket))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentVolume = PositionGetDouble(POSITION_VOLUME);

      // ✅ CONFIGURAR CONTROLE DE PARCIAIS SE NÃO EXISTE
      int configIndex = FindPartialConfigIndex(ticket);
      if (configIndex < 0)
      {
         // Configurar controle para posições existentes
         double initialVolume = currentVolume; // Assumir volume atual como inicial
         ConfigurePartialControl(ticket, symbol, entryPrice, initialVolume);
         continue; // Pular para próxima iteração para dar tempo de configurar
      }

      // ✅ VERIFICAR SE DEVE TOMAR PARCIAL COM LÓGICA INTELIGENTE
      if (ShouldTakePartialNowIntelligent(ticket, currentPrice))
      {
         double partialVolume = CalculatePartialVolumeIntelligent(ticket, currentVolume);

         if (partialVolume > 0 && partialVolume < currentVolume)
         {
            if (ClosePosition(ticket, partialVolume))
            {
               // ✅ ATUALIZAR CONTROLE APÓS EXECUÇÃO
               m_partialConfigs[configIndex].lastPartialTime = currentTime;
               m_partialConfigs[configIndex].lastPartialPrice = currentPrice;
               m_partialConfigs[configIndex].partialsExecuted++;
               
               // ✅ DEFINIR PRÓXIMO R:R NECESSÁRIO
               if (m_partialConfigs[configIndex].partialsExecuted == 1)
               {
                  m_partialConfigs[configIndex].nextPartialRR = 3.0; // Segunda parcial em 3:1
               }
               else if (m_partialConfigs[configIndex].partialsExecuted == 2)
               {
                  m_partialConfigs[configIndex].nextPartialRR = 4.5; // Terceira parcial em 4.5:1
               }
               else
               {
                  m_partialConfigs[configIndex].nextPartialRR = 999.0; // Sem mais parciais
               }

               if (m_logger != NULL)
               {
                  m_logger.Info(StringFormat("✅ PARCIAL INTELIGENTE #%d executada: %.2f lotes em %.5f (parcial %d/3, próximo R:R: %.1f)",
                                           ticket, partialVolume, currentPrice, 
                                           m_partialConfigs[configIndex].partialsExecuted,
                                           m_partialConfigs[configIndex].nextPartialRR));
               }
            }
         }
      }
   }

   // ✅ LIMPEZA PERIÓDICA
   static datetime lastCleanup = 0;
   if (currentTime - lastCleanup > 300) // A cada 5 minutos
   {
      CleanupPartialConfigs();
      lastCleanup = currentTime;
   }
}

//+------------------------------------------------------------------+
//| Verificar se deve tomar parcial agora                            |
//+------------------------------------------------------------------+
bool CTradeExecutor::ShouldTakePartialNow(string symbol, ulong ticket, double currentPrice, double entryPrice, double stopLoss)
{
   if (stopLoss <= 0)
      return false;

   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   // Calcular R:R atual
   double risk = MathAbs(entryPrice - stopLoss);
   double currentReward = 0;

   if (posType == POSITION_TYPE_BUY)
   {
      currentReward = currentPrice - entryPrice;
   }
   else
   {
      currentReward = entryPrice - currentPrice;
   }

   if (risk <= 0 || currentReward <= 0)
      return false;

   double currentRR = currentReward / risk;

   // ✅ VERIFICAR NÍVEIS DE PARCIAIS PREDEFINIDOS
   static double partialLevels[] = {1.5, 2.5, 4.0}; // R:R levels
   static bool partialsExecuted[][3];               // Para cada posição, track de parciais executadas

   // Simplificado: tomar parcial em 2:1 se não foi executada ainda
   if (currentRR >= 2.0)
   {
      string comment = PositionGetString(POSITION_COMMENT);
      if (StringFind(comment, "Partial") < 0)
      { // Ainda não tomou parcial
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Calcular volume da parcial                                       |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculatePartialVolume(string symbol, ulong ticket, double currentVolume)
{
   // ✅ TOMAR 50% NA PRIMEIRA PARCIAL
   double partialVolume = currentVolume * 0.5;

   // Ajustar para step de lote mínimo
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if (stepLot > 0)
   {
      partialVolume = MathFloor(partialVolume / stepLot) * stepLot;
   }

   // Verificar volume mínimo
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   if (partialVolume < minLot)
   {
      return 0; // Não pode tomar parcial
   }

   return partialVolume;
}

//+------------------------------------------------------------------+
//| Gerenciar risco de posições                                      |
//+------------------------------------------------------------------+
void CTradeExecutor::ManagePositionRisk()
{
   int totalPositions = PositionsTotal();

   for (int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket <= 0)
         continue;

      if (!PositionSelectByTicket(ticket))
         continue;

      // ✅ VERIFICAR RISCO EXCESSIVO
      double currentProfit = PositionGetDouble(POSITION_PROFIT);
      double currentSwap = PositionGetDouble(POSITION_SWAP);
      double totalPnL = currentProfit + currentSwap;

      // Se perda está muito grande (exemplo: -500 pontos), considerar fechamento
      if (totalPnL < -500)
      { // Ajustar conforme tolerância
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Posição #%d com perda excessiva: %.2f", ticket, totalPnL));
         }
         // Aqui poderia implementar fechamento de emergência ou alerta
      }
   }
}

//+------------------------------------------------------------------+
//| Remover configuração de trailing stop                            |
//+------------------------------------------------------------------+
void CTradeExecutor::RemoveTrailingConfig(int index)
{
   int size = ArraySize(m_trailingConfigs);
   if (index < 0 || index >= size)
      return;

   // Mover elementos para frente
   for (int i = index; i < size - 1; i++)
   {
      m_trailingConfigs[i] = m_trailingConfigs[i + 1];
   }

   // Redimensionar array
   ArrayResize(m_trailingConfigs, size - 1);
}

//+------------------------------------------------------------------+
//| Limpar configurações inválidas                                   |
//+------------------------------------------------------------------+
void CTradeExecutor::CleanupInvalidConfigurations()
{
   for (int i = ArraySize(m_trailingConfigs) - 1; i >= 0; i--)
   {
      if (!PositionSelectByTicket(m_trailingConfigs[i].ticket))
      {
         RemoveTrailingConfig(i);
      }
   }
}

/////////
//+------------------------------------------------------------------+
//| Configurar breakeven fixo para uma posição                       |
//+------------------------------------------------------------------+
bool CTradeExecutor::SetBreakevenFixed(ulong ticket, double triggerPoints, double offsetPoints = 2.0)
{
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      return false;
   }

   if (ticket <= 0 || triggerPoints <= 0)
   {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros inválidos para breakeven";
      return false;
   }

   // Verificar se a posição existe
   if (!PositionSelectByTicket(ticket))
   {
      m_lastError = -3;
      m_lastErrorDesc = "Posição não encontrada";
      return false;
   }

   string symbol = PositionGetString(POSITION_SYMBOL);

   // Verificar se já existe configuração
   int index = FindBreakevenConfigIndex(ticket);

   if (index < 0)
   {
      // Criar nova configuração
      int size = ArraySize(m_breakevenConfigs);
      ArrayResize(m_breakevenConfigs, size + 1);
      index = size;

      m_breakevenConfigs[index].ticket = ticket;
      m_breakevenConfigs[index].symbol = symbol;
      m_breakevenConfigs[index].configTime = TimeCurrent();
   }

   // Configurar parâmetros
   m_breakevenConfigs[index].breakevenType = BREAKEVEN_FIXED;
   m_breakevenConfigs[index].triggerPoints = triggerPoints;
   m_breakevenConfigs[index].breakevenOffset = offsetPoints;
   m_breakevenConfigs[index].isActive = true;
   m_breakevenConfigs[index].wasTriggered = false;

   if (m_logger != NULL)
   {
      m_logger.Info(StringFormat("Breakeven fixo configurado para #%d: trigger %.1f pontos, offset %.1f pontos",
                                 ticket, triggerPoints, offsetPoints));
   }

   return true;
}

//+------------------------------------------------------------------+
//| Configurar breakeven baseado em ATR                              |
//+------------------------------------------------------------------+
bool CTradeExecutor::SetBreakevenATR(ulong ticket, double atrMultiplier = 1.0, double offsetPoints = 2.0)
{
   if (!m_tradeAllowed)
   {
      return false;
   }

   if (ticket <= 0 || atrMultiplier <= 0)
   {
      return false;
   }

   if (!PositionSelectByTicket(ticket))
   {
      return false;
   }

   string symbol = PositionGetString(POSITION_SYMBOL);

   int index = FindBreakevenConfigIndex(ticket);
   if (index < 0)
   {
      int size = ArraySize(m_breakevenConfigs);
      ArrayResize(m_breakevenConfigs, size + 1);
      index = size;

      m_breakevenConfigs[index].ticket = ticket;
      m_breakevenConfigs[index].symbol = symbol;
      m_breakevenConfigs[index].configTime = TimeCurrent();
   }

   m_breakevenConfigs[index].breakevenType = BREAKEVEN_ATR;
   m_breakevenConfigs[index].atrMultiplier = atrMultiplier;
   m_breakevenConfigs[index].breakevenOffset = offsetPoints;
   m_breakevenConfigs[index].isActive = true;
   m_breakevenConfigs[index].wasTriggered = false;

   if (m_logger != NULL)
   {
      m_logger.Info(StringFormat("Breakeven ATR configurado para #%d: ATR x%.1f, offset %.1f pontos",
                                 ticket, atrMultiplier, offsetPoints));
   }

   return true;
}

//+------------------------------------------------------------------+
//| Configurar breakeven baseado em relação risco/retorno            |
//+------------------------------------------------------------------+
bool CTradeExecutor::SetBreakevenRiskRatio(ulong ticket, double riskRatio = 1.0, double offsetPoints = 2.0)
{
   if (!m_tradeAllowed || ticket <= 0 || riskRatio <= 0)
   {
      return false;
   }

   if (!PositionSelectByTicket(ticket))
   {
      return false;
   }

   string symbol = PositionGetString(POSITION_SYMBOL);

   int index = FindBreakevenConfigIndex(ticket);
   if (index < 0)
   {
      int size = ArraySize(m_breakevenConfigs);
      ArrayResize(m_breakevenConfigs, size + 1);
      index = size;

      m_breakevenConfigs[index].ticket = ticket;
      m_breakevenConfigs[index].symbol = symbol;
      m_breakevenConfigs[index].configTime = TimeCurrent();
   }

   m_breakevenConfigs[index].breakevenType = BREAKEVEN_RISK_RATIO;
   m_breakevenConfigs[index].riskRatio = riskRatio;
   m_breakevenConfigs[index].breakevenOffset = offsetPoints;
   m_breakevenConfigs[index].isActive = true;
   m_breakevenConfigs[index].wasTriggered = false;

   if (m_logger != NULL)
   {
      m_logger.Info(StringFormat("Breakeven R:R configurado para #%d: %.1f:1, offset %.1f pontos",
                                 ticket, riskRatio, offsetPoints));
   }

   return true;
}

//+------------------------------------------------------------------+
//| Gerenciar breakevens (chamado no ManageOpenPositions)            |
//+------------------------------------------------------------------+
void CTradeExecutor::ManageBreakevens()
{
   int size = ArraySize(m_breakevenConfigs);
   if (size == 0)
      return;

   for (int i = size - 1; i >= 0; i--)
   {
      // Verificar se a posição ainda existe
      if (!PositionSelectByTicket(m_breakevenConfigs[i].ticket))
      {
         RemoveBreakevenConfig(i);
         size--;
         continue;
      }

      // Pular se breakeven não está ativo ou já foi acionado
      if (!m_breakevenConfigs[i].isActive || m_breakevenConfigs[i].wasTriggered)
      {
         continue;
      }

      // Verificar se deve acionar breakeven
      if (ShouldTriggerBreakeven(i))
      {
         ExecuteBreakeven(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Verificar se deve acionar breakeven                              |
//+------------------------------------------------------------------+
bool CTradeExecutor::ShouldTriggerBreakeven(int configIndex)
{
   if (configIndex < 0 || configIndex >= ArraySize(m_breakevenConfigs))
   {
      return false;
   }

   BreakevenConfig config = m_breakevenConfigs[configIndex];

   if (!PositionSelectByTicket(config.ticket))
   {
      return false;
   }

   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double stopLoss = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   double point = SymbolInfoDouble(config.symbol, SYMBOL_POINT);
   double profitPoints = 0;

   // Calcular lucro atual em pontos
   if (posType == POSITION_TYPE_BUY)
   {
      profitPoints = (currentPrice - entryPrice) / point;
   }
   else
   {
      profitPoints = (entryPrice - currentPrice) / point;
   }

   // Verificar se está em lucro
   if (profitPoints <= 0)
   {
      return false;
   }

   double triggerLevel = 0;

   switch (config.breakevenType)
   {
   case BREAKEVEN_FIXED:
      triggerLevel = config.triggerPoints;
      break;

   case BREAKEVEN_ATR:
   {
      double atr = CalculateATRForBreakeven(config.symbol, config.ticket);
      if (atr > 0)
      {
         triggerLevel = (atr / point) * config.atrMultiplier;
      }
   }
   break;

   case BREAKEVEN_RISK_RATIO:
   {
      if (stopLoss > 0)
      {
         double riskPoints = 0;
         if (posType == POSITION_TYPE_BUY)
         {
            riskPoints = (entryPrice - stopLoss) / point;
         }
         else
         {
            riskPoints = (stopLoss - entryPrice) / point;
         }
         triggerLevel = riskPoints * config.riskRatio;
      }
   }
   break;
   }

   bool shouldTrigger = (profitPoints >= triggerLevel);

   if (shouldTrigger && m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Breakeven trigger detectado para #%d: lucro %.1f >= trigger %.1f pontos",
                                  config.ticket, profitPoints, triggerLevel));
   }

   return shouldTrigger;
}

//+------------------------------------------------------------------+
//| Executar breakeven                                               |
//+------------------------------------------------------------------+
bool CTradeExecutor::ExecuteBreakeven(int configIndex)
{
   if (configIndex < 0 || configIndex >= ArraySize(m_breakevenConfigs))
   {
      return false;
   }

   // ✅ CORREÇÃO MQL5: Acessar diretamente pelo índice (sem referência)
   if (!PositionSelectByTicket(m_breakevenConfigs[configIndex].ticket))
   {
      return false;
   }

   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double takeProfit = PositionGetDouble(POSITION_TP);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   double point = SymbolInfoDouble(m_breakevenConfigs[configIndex].symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(m_breakevenConfigs[configIndex].symbol, SYMBOL_DIGITS);

   // Calcular novo stop loss (entrada + offset)
   double newStopLoss = 0;

   if (posType == POSITION_TYPE_BUY)
   {
      newStopLoss = entryPrice + (m_breakevenConfigs[configIndex].breakevenOffset * point);
   }
   else
   {
      newStopLoss = entryPrice - (m_breakevenConfigs[configIndex].breakevenOffset * point);
   }

   newStopLoss = NormalizeDouble(newStopLoss, digits);

   // Verificar se o novo stop loss é válido e melhor que o atual
   double currentStopLoss = PositionGetDouble(POSITION_SL);
   bool isImprovement = false;

   if (posType == POSITION_TYPE_BUY)
   {
      isImprovement = (newStopLoss > currentStopLoss || currentStopLoss == 0);
   }
   else
   {
      isImprovement = (newStopLoss < currentStopLoss || currentStopLoss == 0);
   }

   if (!isImprovement)
   {
      if (m_logger != NULL)
      {
         m_logger.Debug(StringFormat("Breakeven não aplicado para #%d: novo SL %.5f não é melhor que atual %.5f",
                                     m_breakevenConfigs[configIndex].ticket, newStopLoss, currentStopLoss));
      }
      return false;
   }

   // Executar modificação
   if (ModifyPosition(m_breakevenConfigs[configIndex].ticket, newStopLoss, takeProfit))
   {
      // ✅ CORREÇÃO MQL5: Modificar diretamente o array pelo índice
      m_breakevenConfigs[configIndex].wasTriggered = true;

      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("BREAKEVEN ACIONADO para #%d: SL movido para %.5f (entrada + %.1f pontos)",
                                    m_breakevenConfigs[configIndex].ticket, newStopLoss, m_breakevenConfigs[configIndex].breakevenOffset));
      }

      // ✅ NOVO: Configurar trailing stop automaticamente após breakeven
      AutoConfigureTrailingStop(m_breakevenConfigs[configIndex].ticket, m_breakevenConfigs[configIndex].symbol);
      
      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("Trailing stop ativado automaticamente para #%d após breakeven", m_breakevenConfigs[configIndex].ticket));
      }

      return true;
   }
   else
   {
      if (m_logger != NULL)
      {
         m_logger.Error(StringFormat("Falha ao executar breakeven para #%d: %s",
                                     m_breakevenConfigs[configIndex].ticket, GetLastErrorDescription()));
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| ✅ NOVO MÉTODO: Verificar se breakeven foi acionado              |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsBreakevenTriggered(ulong ticket)
{
   // Verificar se existe configuração de breakeven para esta posição
   int index = FindBreakevenConfigIndex(ticket);
   
   if (index >= 0)
   {
      // Se existe configuração, verificar se foi acionada
      return m_breakevenConfigs[index].wasTriggered;
   }
   
   // Se não existe configuração de breakeven, verificar se SL está em lucro
   // (indica que breakeven foi feito manualmente ou por outro sistema)
   if (!PositionSelectByTicket(ticket))
   {
      return false; // Posição não existe
   }
   
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double stopLoss = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   if (stopLoss == 0)
   {
      return false; // Sem stop loss definido
   }
   
   // Verificar se SL está em lucro (acima da entrada para BUY, abaixo para SELL)
   if (posType == POSITION_TYPE_BUY)
   {
      return (stopLoss > entryPrice); // SL acima da entrada = breakeven acionado
   }
   else
   {
      return (stopLoss < entryPrice); // SL abaixo da entrada = breakeven acionado
   }
}

//+------------------------------------------------------------------+
//| Encontrar índice de configuração de breakeven                    |
//+------------------------------------------------------------------+
int CTradeExecutor::FindBreakevenConfigIndex(ulong ticket)
{
   int size = ArraySize(m_breakevenConfigs);

   for (int i = 0; i < size; i++)
   {
      if (m_breakevenConfigs[i].ticket == ticket)
      {
         return i;
      }
   }

   return -1;
}

//+------------------------------------------------------------------+
//| Remover configuração de breakeven                                |
//+------------------------------------------------------------------+
void CTradeExecutor::RemoveBreakevenConfig(int index)
{
   int size = ArraySize(m_breakevenConfigs);
   if (index < 0 || index >= size)
      return;

   // Mover elementos
   for (int i = index; i < size - 1; i++)
   {
      m_breakevenConfigs[i] = m_breakevenConfigs[i + 1];
   }

   ArrayResize(m_breakevenConfigs, size - 1);
}

//+------------------------------------------------------------------+
//| Calcular ATR para breakeven                                      |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculateATRForBreakeven(string symbol, ulong ticket)
{
   int atrHandle = iATR(symbol, PERIOD_CURRENT, 14);
   if (atrHandle == INVALID_HANDLE)
   {
      return 0.0;
   }

   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);

   int copied = CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
   IndicatorRelease(atrHandle);

   if (copied <= 0)
   {
      return 0.0;
   }

   return atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Configuração automática de breakeven em novas posições           |
//+------------------------------------------------------------------+
bool CTradeExecutor::AutoConfigureBreakeven(ulong ticket, string symbol)
{
   // Configurar breakeven padrão baseado no símbolo

   if (StringFind(symbol, "WIN") >= 0)
   {
      // WIN: Breakeven em 100 pontos com offset de 10 pontos
      return SetBreakevenFixed(ticket, 50.0, 10.0);
   }
   else if (StringFind(symbol, "WDO") >= 0)
   {
      // WDO: Breakeven em 30 pontos com offset de 5 pontos
      return SetBreakevenFixed(ticket, 30.0, 5.0);
   }
   else if (StringFind(symbol, "BIT") >= 0)
   {
      // BTC: Breakeven baseado em ATR
      return SetBreakevenATR(ticket, 1.0, 50.0);
   }
   else
   {
      // Padrão: Breakeven em 1:1 R:R
      return SetBreakevenRiskRatio(ticket, 1.0, 5.0);
   }
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: AutoConfigureTrailingStop                  |
//| Aumenta os valores de trailing distance para proteção adequada   |
//+------------------------------------------------------------------+
bool CTradeExecutor::AutoConfigureTrailingStop(ulong ticket, string symbol)
{
   if (m_logger != NULL)
   {
      m_logger.Info(StringFormat("Configurando trailing stop automático para #%d (%s)", ticket, symbol));
   }

   if (StringFind(symbol, "WIN") >= 0)
   {
      // ✅ CORRIGIDO: Aumentado de 20 para 100 pontos
      bool result = ApplyTrailingStop(ticket, 100);
      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("Trailing stop WIN configurado: %d pontos para #%d", 100, ticket));
      }
      return result;
   }
   else if (StringFind(symbol, "WDO") >= 0)
   {
      // ✅ CORRIGIDO: Configurado para 8 pontos
      bool result = ApplyTrailingStop(ticket, 8);
      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("Trailing stop WDO configurado: %d pontos para #%d", 8, ticket));
      }
      return result;
   }
   else if (StringFind(symbol, "BIT") >= 0)
   {
      // ✅ CORRIGIDO: Configurado para 200 USD
      bool result = ApplyTrailingStop(ticket, 200);
      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("Trailing stop BTC configurado: %d USD para #%d", 200, ticket));
      }
      return result;
   }
   else
   {
      // Padrão: Trailing stop fixo
      bool result = ApplyTrailingStop(ticket, 50.0);
      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("Trailing stop padrão configurado: %.1f pontos para #%d", 50.0, ticket));
      }
      return result;
   }
}

//+------------------------------------------------------------------+
//| ✅ NOVOS MÉTODOS: Sistema Inteligente de Controle de Parciais   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Configurar controle de parciais para uma posição                 |
//+------------------------------------------------------------------+
bool CTradeExecutor::ConfigurePartialControl(ulong ticket, string symbol, double entryPrice, double initialVolume)
{
   // Verificar se já existe configuração
   int existingIndex = FindPartialConfigIndex(ticket);
   if (existingIndex >= 0)
   {
      return true; // Já configurado
   }

   // ✅ DETECTAR TIMEFRAME AUTOMATICAMENTE
   ENUM_TIMEFRAMES currentTimeframe = Period();

   // Adicionar nova configuração
   int size = ArraySize(m_partialConfigs);
   ArrayResize(m_partialConfigs, size + 1);

   m_partialConfigs[size].ticket = ticket;
   m_partialConfigs[size].symbol = symbol;
   m_partialConfigs[size].timeframe = currentTimeframe; // ✅ NOVO: Timeframe automático
   m_partialConfigs[size].lastPartialTime = 0; // Nunca executou parcial
   m_partialConfigs[size].lastPartialPrice = 0.0;
   m_partialConfigs[size].partialsExecuted = 0;
   m_partialConfigs[size].nextPartialRR = 2.0; // Primeira parcial em 2:1
   m_partialConfigs[size].isActive = true;
   m_partialConfigs[size].entryPrice = entryPrice;
   m_partialConfigs[size].initialVolume = initialVolume;
   m_partialConfigs[size].entryTime = TimeCurrent(); // ✅ NOVO: Timestamp de entrada

   if (m_logger != NULL)
   {
      string timeframeStr = EnumToString(currentTimeframe);
      m_logger.Info(StringFormat("✅ CONTROLE DE PARCIAIS configurado para #%d: entrada=%.5f, volume=%.2f, timeframe=%s",
                                 ticket, entryPrice, initialVolume, timeframeStr));
   }

   return true;
}

//+------------------------------------------------------------------+
//| Encontrar índice da configuração de parciais                     |
//+------------------------------------------------------------------+
int CTradeExecutor::FindPartialConfigIndex(ulong ticket)
{
   int size = ArraySize(m_partialConfigs);
   for (int i = 0; i < size; i++)
   {
      if (m_partialConfigs[i].ticket == ticket && m_partialConfigs[i].isActive)
      {
         return i;
      }
   }
   return -1; // Não encontrado
}

//+------------------------------------------------------------------+
//| Remover configuração de parciais                                 |
//+------------------------------------------------------------------+
void CTradeExecutor::RemovePartialConfig(int index)
{
   int size = ArraySize(m_partialConfigs);
   if (index < 0 || index >= size)
      return;

   // Mover elementos para frente
   for (int i = index; i < size - 1; i++)
   {
      m_partialConfigs[i] = m_partialConfigs[i + 1];
   }

   ArrayResize(m_partialConfigs, size - 1);
}

//+------------------------------------------------------------------+
//| Limpeza de configurações inválidas                               |
//+------------------------------------------------------------------+
void CTradeExecutor::CleanupPartialConfigs()
{
   int size = ArraySize(m_partialConfigs);
   for (int i = size - 1; i >= 0; i--)
   {
      // Verificar se posição ainda existe
      if (!PositionSelectByTicket(m_partialConfigs[i].ticket))
      {
         if (m_logger != NULL)
         {
            m_logger.Debug(StringFormat("Removendo controle de parciais para posição fechada #%d",
                                      m_partialConfigs[i].ticket));
         }
         RemovePartialConfig(i);
      }
   }
}

//+------------------------------------------------------------------+
//| ✅ LÓGICA INTELIGENTE: Verificar se deve tomar parcial           |
//+------------------------------------------------------------------+
bool CTradeExecutor::ShouldTakePartialNowIntelligent(ulong ticket, double currentPrice)
{
   int configIndex = FindPartialConfigIndex(ticket);
   if (configIndex < 0)
   {
      return false; // Sem configuração
   }

   if (!PositionSelectByTicket(ticket))
   {
      return false;
   }

   // ✅ VERIFICAR SE JÁ EXECUTOU MÁXIMO DE PARCIAIS
   if (m_partialConfigs[configIndex].partialsExecuted >= 3)
   {
      return false; // Máximo 3 parciais
   }

   // ✅ CALCULAR R:R ATUAL
   double entryPrice = m_partialConfigs[configIndex].entryPrice;
   double stopLoss = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   if (stopLoss <= 0)
   {
      return false; // Sem stop loss definido
   }

   double risk = MathAbs(entryPrice - stopLoss);
   double currentReward = 0;

   if (posType == POSITION_TYPE_BUY)
   {
      currentReward = currentPrice - entryPrice;
   }
   else
   {
      currentReward = entryPrice - currentPrice;
   }

   if (risk <= 0 || currentReward <= 0)
   {
      return false; // Sem lucro ou risco inválido
   }

   double currentRR = currentReward / risk;

   // ✅ VERIFICAR SE ATINGIU R:R NECESSÁRIO
   if (currentRR < m_partialConfigs[configIndex].nextPartialRR)
   {
      return false; // R:R insuficiente
   }

   // ✅ VERIFICAR TEMPO MÍNIMO ENTRE PARCIAIS
   if (!IsMinimumTimeElapsed(ticket))
   {
      if (m_logger != NULL)
      {
         static datetime lastTimeLog = 0;
         if (TimeCurrent() - lastTimeLog > 60)
         {
            m_logger.Debug(StringFormat("Parcial #%d aguardando tempo mínimo (R:R %.2f atingido)",
                                      ticket, currentRR));
            lastTimeLog = TimeCurrent();
         }
      }
      return false;
   }

   // ✅ VERIFICAR DISTÂNCIA MÍNIMA
   if (!IsMinimumDistanceAchieved(ticket, currentPrice))
   {
      if (m_logger != NULL)
      {
         static datetime lastDistLog = 0;
         if (TimeCurrent() - lastDistLog > 60)
         {
            m_logger.Debug(StringFormat("Parcial #%d aguardando distância mínima (R:R %.2f atingido)",
                                      ticket, currentRR));
            lastDistLog = TimeCurrent();
         }
      }
      return false;
   }

   // ✅ VERIFICAR SE PREÇO ESTÁ MOVENDO FAVORAVELMENTE
   if (!IsPriceMovingFavorably(ticket, currentPrice))
   {
      if (m_logger != NULL)
      {
         static datetime lastMoveLog = 0;
         if (TimeCurrent() - lastMoveLog > 120)
         {
            m_logger.Debug(StringFormat("Parcial #%d aguardando movimento favorável (R:R %.2f atingido)",
                                      ticket, currentRR));
            lastMoveLog = TimeCurrent();
         }
      }
      return false;
   }

   // ✅ TODAS AS CONDIÇÕES ATENDIDAS
   if (m_logger != NULL)
   {
      m_logger.Info(StringFormat("🎯 PARCIAL #%d APROVADA: R:R %.2f (necessário %.1f), parcial %d/3",
                                 ticket, currentRR, m_partialConfigs[configIndex].nextPartialRR,
                                 m_partialConfigs[configIndex].partialsExecuted + 1));
   }

   return true;
}

//+------------------------------------------------------------------+
//| ✅ VOLUME INTELIGENTE: Calcular volume da parcial                |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculatePartialVolumeIntelligent(ulong ticket, double currentVolume)
{
   int configIndex = FindPartialConfigIndex(ticket);
   if (configIndex < 0)
   {
      return 0.0;
   }

   string symbol = m_partialConfigs[configIndex].symbol;
   int partialsExecuted = m_partialConfigs[configIndex].partialsExecuted;
   double initialVolume = m_partialConfigs[configIndex].initialVolume;

   double partialVolume = 0.0;

   // ✅ ESTRATÉGIA DE VOLUME INTELIGENTE
   if (partialsExecuted == 0)
   {
      // Primeira parcial: 30% do volume inicial
      partialVolume = initialVolume * 0.30;
   }
   else if (partialsExecuted == 1)
   {
      // Segunda parcial: 40% do volume inicial
      partialVolume = initialVolume * 0.40;
   }
   else if (partialsExecuted == 2)
   {
      // Terceira parcial: 20% do volume inicial (deixa 10% como runner)
      partialVolume = initialVolume * 0.20;
   }
   else
   {
      return 0.0; // Sem mais parciais
   }

   // ✅ AJUSTAR PARA STEP DE LOTE
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if (stepLot > 0)
   {
      partialVolume = MathFloor(partialVolume / stepLot) * stepLot;
   }

   // ✅ VERIFICAR VOLUME MÍNIMO
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   if (partialVolume < minLot)
   {
      return 0.0;
   }

   // ✅ VERIFICAR SE NÃO EXCEDE VOLUME ATUAL
   if (partialVolume >= currentVolume)
   {
      // Deixar pelo menos 1 lote como runner
      partialVolume = currentVolume - minLot;
      if (partialVolume < minLot)
      {
         return 0.0;
      }
   }

   return partialVolume;
}

//+------------------------------------------------------------------+
//| ✅ TIMING AUTOMÁTICO: Verificar se tempo mínimo foi atingido     |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsMinimumTimeElapsed(ulong ticket)
{
   int configIndex = FindPartialConfigIndex(ticket);
   if (configIndex < 0)
   {
      return false;
   }

   datetime lastPartialTime = m_partialConfigs[configIndex].lastPartialTime;
   
   // Se nunca executou parcial, pode executar
   if (lastPartialTime == 0)
   {
      return true;
   }

   // ✅ CALCULAR TIMING AUTOMÁTICO BASEADO EM TIMEFRAME E ATIVO
   string symbol = m_partialConfigs[configIndex].symbol;
   ENUM_TIMEFRAMES timeframe = m_partialConfigs[configIndex].timeframe;
   int partialNumber = m_partialConfigs[configIndex].partialsExecuted + 1; // Próxima parcial

   int minTimeSeconds = CalculateAutomaticTiming(symbol, timeframe, partialNumber);

   datetime currentTime = TimeCurrent();
   bool timeElapsed = (currentTime - lastPartialTime) >= minTimeSeconds;

   // ✅ LOG DETALHADO PARA MONITORAMENTO
   if (!timeElapsed && m_logger != NULL)
   {
      static datetime lastLog = 0;
      if (currentTime - lastLog > 60) // Log a cada minuto
      {
         // ✅ CORREÇÃO: Cast explícito para evitar warning de conversão
         int elapsedSeconds = (int)(currentTime - lastPartialTime);
         int remainingSeconds = minTimeSeconds - elapsedSeconds;
         int remainingMinutes = remainingSeconds / 60;
         
         m_logger.Debug(StringFormat("⏰ TIMING AUTOMÁTICO #%d: aguardando %d min %d seg (parcial %d, %s %s)",
                                   ticket, remainingMinutes, remainingSeconds % 60, 
                                   partialNumber, symbol, EnumToString(timeframe)));
         lastLog = currentTime;
      }
   }

   return timeElapsed;
}

//+------------------------------------------------------------------+
//| Verificar se distância mínima foi atingida                       |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsMinimumDistanceAchieved(ulong ticket, double currentPrice)
{
   int configIndex = FindPartialConfigIndex(ticket);
   if (configIndex < 0)
   {
      return false;
   }

   double lastPartialPrice = m_partialConfigs[configIndex].lastPartialPrice;
   
   // Se nunca executou parcial, pode executar
   if (lastPartialPrice == 0.0)
   {
      return true;
   }

   string symbol = m_partialConfigs[configIndex].symbol;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if (point <= 0)
   {
      return true; // Fallback
   }

   // ✅ DISTÂNCIA MÍNIMA BASEADA NO SÍMBOLO
   double minDistancePoints = 50; // Padrão
   
   if (StringFind(symbol, "WIN") >= 0)
   {
      minDistancePoints = 100; // 100 pontos para WIN
   }
   else if (StringFind(symbol, "WDO") >= 0)
   {
      minDistancePoints = 25; // 25 pontos para WDO
   }
   else if (StringFind(symbol, "BIT") >= 0)
   {
      minDistancePoints = 200; // 200 USD para BTC
   }

   double minDistancePrice = minDistancePoints * point;
   double actualDistance = MathAbs(currentPrice - lastPartialPrice);

   return actualDistance >= minDistancePrice;
}

//+------------------------------------------------------------------+
//| Verificar se preço está movendo favoravelmente                   |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsPriceMovingFavorably(ulong ticket, double currentPrice)
{
   int configIndex = FindPartialConfigIndex(ticket);
   if (configIndex < 0)
   {
      return false;
   }

   if (!PositionSelectByTicket(ticket))
   {
      return false;
   }

   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double lastPartialPrice = m_partialConfigs[configIndex].lastPartialPrice;

   // Se nunca executou parcial, verificar movimento desde entrada
   if (lastPartialPrice == 0.0)
   {
      double entryPrice = m_partialConfigs[configIndex].entryPrice;
      
      if (posType == POSITION_TYPE_BUY)
      {
         return currentPrice > entryPrice; // Preço acima da entrada
      }
      else
      {
         return currentPrice < entryPrice; // Preço abaixo da entrada
      }
   }

   // ✅ VERIFICAR SE PREÇO MELHOROU DESDE ÚLTIMA PARCIAL
   if (posType == POSITION_TYPE_BUY)
   {
      return currentPrice >= lastPartialPrice; // Preço igual ou melhor
   }
   else
   {
      return currentPrice <= lastPartialPrice; // Preço igual ou melhor
   }
}

//+------------------------------------------------------------------+
//| ATUALIZAÇÃO da função ManageOpenPositions para incluir breakeven |
//+------------------------------------------------------------------+
void CTradeExecutor::ManageOpenPositions()
{
   if (!m_tradeAllowed)
   {
      return;
   }

   if(m_circuitBreaker != NULL && !m_circuitBreaker.CanOperate())
   {
      return;
   }

   datetime currentTime = TimeCurrent();
   static datetime lastFullCheck = 0;

   // ✅ CORREÇÃO CRÍTICA: SEQUÊNCIA CORRETA DE GERENCIAMENTO
   // 1. PRIMEIRO: Gerenciar breakevens (prioridade máxima)
   ManageBreakevens();
   
   // 2. SEGUNDO: Gerenciar trailing stops (após breakeven)
   ManageTrailingStops();
   
   // 3. TERCEIRO: Gerenciar parciais
   ManagePartialTakeProfits();

   // ✅ VERIFICAÇÃO COMPLETA A CADA 10 SEGUNDOS
   if (currentTime - lastFullCheck >= 10)
   {
      ManagePositionRisk();
      CleanupInvalidConfigurations();
      CleanupBreakevenConfigs();
      lastFullCheck = currentTime;
   }
}

//+------------------------------------------------------------------+
//| Limpar configurações de breakeven inválidas                      |
//+------------------------------------------------------------------+
void CTradeExecutor::CleanupBreakevenConfigs()
{
   for (int i = ArraySize(m_breakevenConfigs) - 1; i >= 0; i--)
   {
      if (!PositionSelectByTicket(m_breakevenConfigs[i].ticket))
      {
         RemoveBreakevenConfig(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Valida e ajusta stops para respeitar regras do broker           |
//| - Verifica STOPLEVEL mínimo                                      |
//| - Ajusta stops muito próximos                                    |
//| - Normaliza preços para tick size                                |
//| Retorna: true se válido, false se impossível ajustar             |
//+------------------------------------------------------------------+
// Novo método para validar e ajustar stops antes da execução
bool CTradeExecutor::ValidateAndAdjustStops(string symbol, ENUM_ORDER_TYPE orderType,
                                            double &entryPrice, double &stopLoss, double &takeProfit)
{

   // Obter informações do símbolo
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double stopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

   // Se stopLevel for 0, usar valor mínimo seguro
   if (stopLevel == 0)
   {
      stopLevel = 5 * tickSize; // 5 ticks mínimo
   }

   // Obter preço atual de mercado
   MqlTick lastTick;
   if (!SymbolInfoTick(symbol, lastTick))
   {
      if (m_logger != NULL)
      {
         m_logger.Error("ValidateAndAdjustStops: Falha ao obter tick para " + symbol);
      }
      return false;
   }

   // Determinar preço de referência baseado no tipo de ordem
   double referencePrice = 0;

   if (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT)
   {
      referencePrice = lastTick.ask;

      // Para ordens de compra
      // Stop Loss deve estar abaixo do ASK - stopLevel
      double minStopDistance = stopLevel + lastTick.ask - lastTick.bid; // Incluir spread
      double maxStopLoss = lastTick.ask - minStopDistance;

      if (stopLoss > maxStopLoss)
      {
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("ValidateAndAdjustStops: Ajustando SL de compra de %.5f para %.5f (stopLevel: %.5f)",
                                          stopLoss, maxStopLoss, stopLevel));
         }
         stopLoss = NormalizeDouble(maxStopLoss, digits);
      }

      // Take Profit deve estar acima do ASK + stopLevel
      if (takeProfit > 0 && takeProfit < lastTick.ask + stopLevel)
      {
         takeProfit = NormalizeDouble(lastTick.ask + stopLevel + tickSize, digits);
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("ValidateAndAdjustStops: Ajustando TP de compra para %.5f", takeProfit));
         }
      }
   }
   else
   { // SELL orders
      referencePrice = lastTick.bid;

      // Para ordens de venda
      // Stop Loss deve estar acima do BID + stopLevel
      double minStopDistance = stopLevel + lastTick.ask - lastTick.bid; // Incluir spread
      double minStopLoss = lastTick.bid + minStopDistance;

      if (stopLoss < minStopLoss)
      {
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("ValidateAndAdjustStops: Ajustando SL de venda de %.5f para %.5f (stopLevel: %.5f)",
                                          stopLoss, minStopLoss, stopLevel));
         }
         stopLoss = NormalizeDouble(minStopLoss, digits);
      }

      // Take Profit deve estar abaixo do BID - stopLevel
      if (takeProfit > 0 && takeProfit > lastTick.bid - stopLevel)
      {
         takeProfit = NormalizeDouble(lastTick.bid - stopLevel - tickSize, digits);
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("ValidateAndAdjustStops: Ajustando TP de venda para %.5f", takeProfit));
         }
      }
   }

   // Normalizar todos os preços para o tick size do símbolo
   entryPrice = NormalizeDouble(MathRound(entryPrice / tickSize) * tickSize, digits);
   stopLoss = NormalizeDouble(MathRound(stopLoss / tickSize) * tickSize, digits);
   if (takeProfit > 0)
   {
      takeProfit = NormalizeDouble(MathRound(takeProfit / tickSize) * tickSize, digits);
   }

   // Validação final
   if (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT)
   {
      if (stopLoss >= entryPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Error(StringFormat("ValidateAndAdjustStops: SL de compra (%.5f) >= entrada (%.5f)",
                                        stopLoss, entryPrice));
         }
         return false;
      }
      if (takeProfit > 0 && takeProfit <= entryPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Error(StringFormat("ValidateAndAdjustStops: TP de compra (%.5f) <= entrada (%.5f)",
                                        takeProfit, entryPrice));
         }
         return false;
      }
   }
   else
   {
      if (stopLoss <= entryPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Error(StringFormat("ValidateAndAdjustStops: SL de venda (%.5f) <= entrada (%.5f)",
                                        stopLoss, entryPrice));
         }
         return false;
      }
      if (takeProfit > 0 && takeProfit >= entryPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Error(StringFormat("ValidateAndAdjustStops: TP de venda (%.5f) >= entrada (%.5f)",
                                        takeProfit, entryPrice));
         }
         return false;
      }
   }

   // Log final dos valores ajustados
   if (m_logger != NULL)
   {
      m_logger.Info(StringFormat("ValidateAndAdjustStops: %s %s - Entry: %.5f, SL: %.5f (dist: %.1f pts), TP: %.5f",
                                 symbol,
                                 (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT) ? "BUY" : "SELL",
                                 entryPrice,
                                 stopLoss,
                                 MathAbs(entryPrice - stopLoss) / point,
                                 takeProfit));
   }

   return true;
}

/////////////////////////////////////////////////////////////////
//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRETA: ClosePartialPosition                         |
//| Implementação oficial MQL5 para fechamento de parciais          |
//+------------------------------------------------------------------+
bool CTradeExecutor::ClosePartialPosition(ulong position_ticket, double partial_volume)
{
   // Validar e selecionar posição
   if(!PositionSelectByTicket(position_ticket))
   {
      m_lastError = ERR_TRADE_POSITION_NOT_FOUND;
      m_lastErrorDesc = "Posição não encontrada: " + IntegerToString(position_ticket);
      m_logger.Error(m_lastErrorDesc);
      return false;
   }
   
   // Obter informações da posição
   string symbol = PositionGetString(POSITION_SYMBOL);
   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   // Validar volume parcial
   if(partial_volume <= 0)
   {
      m_lastError = ERR_TRADE_WRONG_PROPERTY;
      m_lastErrorDesc = "Volume inválido para fechamento parcial: " + DoubleToString(partial_volume, 2);
      m_logger.Error(m_lastErrorDesc);
      return false;
   }
   
   // Se volume >= volume total, fechar posição inteira
   if(partial_volume >= currentVolume)
   {
      m_logger.Info(StringFormat("Volume parcial (%.2f) >= volume total (%.2f), fechando posição inteira #%d", 
                                partial_volume, currentVolume, position_ticket));
      return m_trade.PositionClose(position_ticket);
   }
   
   // ✅ IMPLEMENTAÇÃO OFICIAL MQL5 PARA FECHAMENTO PARCIAL
   m_logger.Info(StringFormat("Executando fechamento parcial: %.2f de %.2f lotes (posição #%d)", 
                             partial_volume, currentVolume, position_ticket));
   
   // Obter preço atual
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
   {
      m_lastError = ERR_TRADE_DEAL_NOT_FOUND;
      m_lastErrorDesc = "Falha ao obter tick para " + symbol;
      m_logger.Error(m_lastErrorDesc);
      return false;
   }
   
   // ✅ PREPARAR ESTRUTURAS OFICIAIS MQL5
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   // ✅ CONFIGURAR REQUISIÇÃO DE FECHAMENTO PARCIAL
   request.action = TRADE_ACTION_DEAL;           // ✅ Ação oficial para fechamento
   request.position = position_ticket;           // ✅ Ticket da posição a fechar
   request.symbol = symbol;                      // ✅ Símbolo da posição
   request.volume = partial_volume;              // ✅ Volume parcial a fechar
   request.magic = MAGIC_NUMBER;                      // ✅ Magic number
   request.comment = "Fechamento Parcial";      // ✅ Comentário
   request.deviation = 3;                        // ✅ Desvio permitido
   
   // ✅ DETERMINAR TIPO DE ORDEM PARA FECHAMENTO
   if(posType == POSITION_TYPE_BUY)
   {
      request.type = ORDER_TYPE_SELL;            // ✅ Vender para fechar compra
      request.price = tick.bid;                  // ✅ Preço de venda
   }
   else
   {
      request.type = ORDER_TYPE_BUY;             // ✅ Comprar para fechar venda
      request.price = tick.ask;                  // ✅ Preço de compra
   }
   
   // ✅ EXECUTAR FECHAMENTO PARCIAL COM RETRY
   bool success = false;
   int retries = 0;
   
   while(retries < m_maxRetries && !success)
   {
      if(retries > 0)
      {
         m_logger.Warning(StringFormat("Tentativa %d de %d para fechamento parcial", retries + 1, m_maxRetries));
         Sleep(m_retryDelay);
         
         // Atualizar preço para retry
         if(!SymbolInfoTick(symbol, tick))
         {
            m_logger.Error("Falha ao atualizar tick para retry");
            break;
         }
         request.price = (posType == POSITION_TYPE_BUY) ? tick.bid : tick.ask;
      }
      
      // ✅ EXECUTAR ORDEM DE FECHAMENTO PARCIAL
      success = OrderSend(request, result);
      
      if(!success)
      {
         m_lastError = (int)result.retcode;
         m_lastErrorDesc = "Erro no fechamento parcial: " + IntegerToString(result.retcode);
         
         // Log detalhado do erro
         m_logger.Error(StringFormat("Erro OrderSend: retcode=%d, deal=%d, order=%d", 
                                   result.retcode, result.deal, result.order));
         
         // Verificar se erro é recuperável
         if(!IsRetryableError(result.retcode))
         {
            m_logger.Error(StringFormat("Erro não recuperável no fechamento parcial: %d", result.retcode));
            break;
         }
      }
      else
      {
         // ✅ SUCESSO - LOG DETALHADO
         m_logger.Info(StringFormat("✅ FECHAMENTO PARCIAL EXECUTADO: %.2f lotes da posição #%d", 
                                  partial_volume, position_ticket));
         m_logger.Info(StringFormat("Deal: #%d, Order: #%d, Volume: %.2f, Preço: %.5f", 
                                  result.deal, result.order, result.volume, result.price));
      }
      
      retries++;
   }
   
   // ✅ VALIDAR RESULTADO E VOLUME RESTANTE
   if(success)
   {
      // Verificar volume restante na posição
      if(PositionSelectByTicket(position_ticket))
      {
         double remainingVolume = PositionGetDouble(POSITION_VOLUME);
         double expectedRemaining = currentVolume - partial_volume;
         
         m_logger.Info(StringFormat("Volume restante na posição #%d: %.2f lotes (esperado: %.2f)", 
                                  position_ticket, remainingVolume, expectedRemaining));
         
         // Validar se volume restante está correto (com tolerância)
         if(MathAbs(remainingVolume - expectedRemaining) > 0.01)
         {
            m_logger.Warning(StringFormat("⚠️ Volume restante diverge do esperado: %.2f vs %.2f", 
                                        remainingVolume, expectedRemaining));
         }
      }
      else
      {
         m_logger.Info(StringFormat("Posição #%d fechada completamente", position_ticket));
      }
   }
   else
   {
      m_logger.Error(StringFormat("❌ FALHA NO FECHAMENTO PARCIAL da posição #%d: %s", 
                                position_ticket, m_lastErrorDesc));
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| ✅ SISTEMA DE TIMING AUTOMÁTICO: Implementações dos Especialistas |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calcular timing automático baseado em timeframe, ativo e parcial |
//+------------------------------------------------------------------+
int CTradeExecutor::CalculateAutomaticTiming(string symbol, ENUM_TIMEFRAMES timeframe, int partialNumber)
{
   // ✅ FÓRMULA DOS ESPECIALISTAS: Tempo = TempoBase × MultiplcadorAtivo × MultiplicadorParcial
   
   int baseTimeSeconds = GetBaseTimeByTimeframe(timeframe);
   double assetMultiplier = GetAssetMultiplier(symbol);
   double partialMultiplier = GetPartialMultiplier(partialNumber);
   
   // ✅ MULTIPLICADORES ADICIONAIS PARA REFINAMENTO
   double volatilityMultiplier = GetVolatilityMultiplier(symbol);
   double sessionMultiplier = GetSessionMultiplier(symbol);
   
   // Cálculo final
   double finalTime = baseTimeSeconds * assetMultiplier * partialMultiplier * volatilityMultiplier * sessionMultiplier;
   
   // Garantir mínimo de 30 segundos e máximo de 24 horas
   int result = (int)MathMax(30, MathMin(86400, finalTime));
   
   // ✅ LOG PARA ANÁLISE E OTIMIZAÇÃO
   if (m_logger != NULL)
   {
      static datetime lastDetailLog = 0;
      if (TimeCurrent() - lastDetailLog > 300) // Log detalhado a cada 5 minutos
      {
         m_logger.Debug(StringFormat("📊 TIMING CALCULADO para %s %s parcial %d: %d seg (base:%d × ativo:%.1f × parcial:%.1f × vol:%.1f × sessão:%.1f)",
                                   symbol, EnumToString(timeframe), partialNumber, result,
                                   baseTimeSeconds, assetMultiplier, partialMultiplier, volatilityMultiplier, sessionMultiplier));
         lastDetailLog = TimeCurrent();
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Obter tempo base por timeframe (recomendações de especialistas)  |
//+------------------------------------------------------------------+
int CTradeExecutor::GetBaseTimeByTimeframe(ENUM_TIMEFRAMES timeframe)
{
   switch(timeframe)
   {
      case PERIOD_M1:  return 120;    // 2 minutos base (movimentos ultra-rápidos)
      case PERIOD_M3:  return 360;    // 6 minutos base (scalping avançado)
      case PERIOD_M5:  return 600;    // 10 minutos base (movimentos rápidos)
      case PERIOD_M15: return 1800;   // 30 minutos base (movimentos médios)
      case PERIOD_M30: return 3600;   // 1 hora base
      case PERIOD_H1:  return 7200;   // 2 horas base (movimentos lentos)
      case PERIOD_H4:  return 21600;  // 6 horas base (movimentos muito lentos)
      case PERIOD_D1:  return 86400;  // 1 dia base (swing trading)
      default:         return 600;    // Padrão: 10 minutos
   }
}

//+------------------------------------------------------------------+
//| Obter multiplicador por ativo (baseado em volatilidade)          |
//+------------------------------------------------------------------+
double CTradeExecutor::GetAssetMultiplier(string symbol)
{
   // ✅ BASEADO EM ANÁLISE DE VOLATILIDADE HISTÓRICA DOS ATIVOS
   
   if (StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "BIT") >= 0)
   {
      return 0.7; // Bitcoin: muito volátil, timing mais rápido
   }
   else if (StringFind(symbol, "WIN") >= 0)
   {
      return 1.0; // WIN: volatilidade referência (padrão brasileiro)
   }
   else if (StringFind(symbol, "WDO") >= 0)
   {
      return 1.5; // Dólar: menos volátil que WIN, timing mais lento
   }
   else if (StringFind(symbol, "ETH") >= 0)
   {
      return 0.8; // Ethereum: alta volatilidade
   }
   else if (StringFind(symbol, "PETR") >= 0 || StringFind(symbol, "VALE") >= 0 || 
            StringFind(symbol, "ITUB") >= 0 || StringFind(symbol, "BBDC") >= 0)
   {
      return 2.0; // Ações blue chips: menos voláteis
   }
   else if (StringFind(symbol, "USD") >= 0 || StringFind(symbol, "EUR") >= 0 || 
            StringFind(symbol, "GBP") >= 0 || StringFind(symbol, "JPY") >= 0)
   {
      return 1.8; // Forex majors: movimentos mais lentos
   }
   else if (StringFind(symbol, "GOLD") >= 0 || StringFind(symbol, "XAUUSD") >= 0)
   {
      return 1.3; // Ouro: volatilidade moderada
   }
   else
   {
      return 1.2; // Outros ativos: conservador
   }
}

//+------------------------------------------------------------------+
//| Obter multiplicador por número da parcial (gestão progressiva)   |
//+------------------------------------------------------------------+
double CTradeExecutor::GetPartialMultiplier(int partialNumber)
{
   // ✅ RECOMENDAÇÃO DE LARRY WILLIAMS: Timing progressivo
   switch(partialNumber)
   {
      case 1: return 0.5; // 1ª parcial: mais rápida (proteção de capital)
      case 2: return 1.0; // 2ª parcial: timing normal
      case 3: return 1.5; // 3ª parcial: mais lenta (captura de movimento)
      default: return 1.0;
   }
}

//+------------------------------------------------------------------+
//| Obter multiplicador de volatilidade (adaptação dinâmica)         |
//+------------------------------------------------------------------+
double CTradeExecutor::GetVolatilityMultiplier(string symbol)
{
   // ✅ ANÁLISE SIMPLIFICADA DE VOLATILIDADE ATUAL
   // Em implementação futura: usar ATR ou desvio padrão
   
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   // Horários de maior volatilidade = timing mais rápido
   int hour = timeStruct.hour;
   
   if (StringFind(symbol, "WIN") >= 0 || StringFind(symbol, "WDO") >= 0)
   {
      // Mercado brasileiro
      if ((hour >= 9 && hour <= 11) || (hour >= 14 && hour <= 16))
      {
         return 0.8; // Horários de maior movimento = timing mais rápido
      }
      else if (hour >= 12 && hour <= 13)
      {
         return 1.3; // Almoço = menos movimento = timing mais lento
      }
   }
   else if (StringFind(symbol, "BTC") >= 0)
   {
      // Bitcoin: 24h, mas alguns horários são mais ativos
      if ((hour >= 8 && hour <= 10) || (hour >= 14 && hour <= 16) || (hour >= 20 && hour <= 22))
      {
         return 0.9; // Horários de maior atividade
      }
   }
   
   return 1.0; // Padrão
}

//+------------------------------------------------------------------+
//| Obter multiplicador de sessão (horário de negociação)            |
//+------------------------------------------------------------------+
double CTradeExecutor::GetSessionMultiplier(string symbol)
{
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   int hour = timeStruct.hour;
   int dayOfWeek = timeStruct.day_of_week;
   
   // ✅ ANÁLISE POR SESSÃO DE MERCADO
   
   if (StringFind(symbol, "WIN") >= 0 || StringFind(symbol, "WDO") >= 0)
   {
      // Mercado brasileiro (9h-18h)
      if (hour < 9 || hour > 18)
      {
         return 2.0; // Fora do horário = movimentos mais lentos
      }
      else if (hour == 9 || hour == 17)
      {
         return 0.7; // Abertura/fechamento = mais volátil
      }
   }
   else if (StringFind(symbol, "BTC") >= 0)
   {
      // Bitcoin: 24h, mas fins de semana são diferentes
      if (dayOfWeek == 0 || dayOfWeek == 6) // Domingo ou sábado
      {
         return 1.3; // Fins de semana = menos atividade
      }
   }
   else if (StringFind(symbol, "USD") >= 0 || StringFind(symbol, "EUR") >= 0)
   {
      // Forex: considerar sobreposição de sessões
      if ((hour >= 8 && hour <= 12) || (hour >= 14 && hour <= 18))
      {
         return 0.9; // Sobreposição de sessões = mais atividade
      }
   }
   
   return 1.0; // Padrão
}

#include "OrderExecution.mqh"
