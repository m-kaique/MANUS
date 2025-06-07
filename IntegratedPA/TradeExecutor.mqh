//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                            TradeExecutor.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#ifndef TRADEEXECUTOR_MQH
#define TRADEEXECUTOR_MQH

// Inclusão de bibliotecas necessárias
#include <Trade/Trade.mqh>
#include "Structures.mqh"
#include "Logger.mqh"

// Constantes de erro definidas como macros
#define TRADE_ERROR_NO_ERROR           0
#define TRADE_ERROR_SERVER_BUSY        4
#define TRADE_ERROR_NO_CONNECTION      6
#define TRADE_ERROR_TRADE_TIMEOUT      128
#define TRADE_ERROR_INVALID_PRICE      129
#define TRADE_ERROR_PRICE_CHANGED      135
#define TRADE_ERROR_OFF_QUOTES         136
#define TRADE_ERROR_BROKER_BUSY        137
#define TRADE_ERROR_REQUOTE            138
#define TRADE_ERROR_TOO_MANY_REQUESTS  141
#define TRADE_ERROR_TRADE_CONTEXT_BUSY 146

//+------------------------------------------------------------------+
//| Classe para execução e gerenciamento de ordens                   |
//+------------------------------------------------------------------+
class CTradeExecutor {
private:
   // Objetos internos
   CTrade*         m_trade;
   CLogger*        m_logger;
   
   // Configurações
   bool            m_tradeAllowed;
   int             m_maxRetries;
   int             m_retryDelay;
   
   // Estado
   int             m_lastError;
   string          m_lastErrorDesc;
   
   // Enumeração para tipos de trailing stop
   enum ENUM_TRAILING_TYPE {
      TRAILING_FIXED,       // Trailing fixo em pontos
      TRAILING_ATR,         // Trailing baseado em ATR
      TRAILING_MA           // Trailing baseado em média móvel
   };
   
   // Estrutura para armazenar configurações de trailing stop
   struct TrailingStopConfig {
      ulong          ticket;                // Ticket da posição
      string         symbol;                // Símbolo
      ENUM_TIMEFRAMES timeframe;            // Timeframe para indicadores
      double         fixedPoints;           // Pontos fixos para trailing
      double         atrMultiplier;         // Multiplicador de ATR
      int            maPeriod;              // Período da média móvel
      ENUM_TRAILING_TYPE trailingType;      // Tipo de trailing
      datetime       lastUpdateTime;        // Última atualização
      double         lastStopLoss;          // Último stop loss
   };
   
   // Array de configurações de trailing stop
   TrailingStopConfig m_trailingConfigs[];
   
   // Métodos privados
   bool IsRetryableError(int errorCode);
   double CalculateFixedTrailingStop(ulong ticket, double fixedPoints);
   double CalculateATRTrailingStop(string symbol, ENUM_TIMEFRAMES timeframe, double atrMultiplier, ulong ticket);
   double CalculateMATrailingStop(string symbol, ENUM_TIMEFRAMES timeframe, int maPeriod, ulong ticket);

public:
   // Construtores e destrutor
   CTradeExecutor();
   ~CTradeExecutor();
   
   // Métodos de inicialização
   bool Initialize(CLogger* logger);

   bool ExecuteInBatches(OrderRequest &request, double maxBatchSize);

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
   
   // Métodos de configuração
   void SetTradeAllowed(bool allowed) { m_tradeAllowed = allowed; }
   void SetMaxRetries(int retries) { m_maxRetries = retries; }
   void SetRetryDelay(int delay) { m_retryDelay = delay; }
   
   // Métodos de acesso
   int GetLastError() const { return m_lastError; }
   string GetLastErrorDescription() const { return m_lastErrorDesc; }
   ulong GetMagicNumber() const { return m_trade.RequestMagic(); }
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CTradeExecutor::CTradeExecutor() {
   m_trade = NULL;
   m_logger = NULL;
   m_tradeAllowed = true;
   m_maxRetries = 3;
   m_retryDelay = 1000; // 1 segundo
   m_lastError = 0;
   m_lastErrorDesc = "";
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CTradeExecutor::~CTradeExecutor() {
   if(m_trade != NULL) {
      delete m_trade;
      m_trade = NULL;
   }
}

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool CTradeExecutor::Initialize(CLogger* logger) {
   // Verificar parâmetros
   if(logger == NULL) {
      Print("CTradeExecutor::Initialize - Logger não pode ser NULL");
      return false;
   }
   
   // Atribuir logger
   m_logger = logger;
   m_logger.Info("Inicializando TradeExecutor");
   
   // Criar objeto de trade
   m_trade = new CTrade();
   if(m_trade == NULL) {
      m_logger.Error("Falha ao criar objeto CTrade");
      return false;
   }
   
   // Configurar objeto de trade
   m_trade.SetExpertMagicNumber(123456); // Magic number para identificar ordens deste EA
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(Symbol());
   m_trade.SetDeviationInPoints(10); // Desvio máximo de preço em pontos
   
   m_logger.Info("TradeExecutor inicializado com sucesso");
   return true;
}

//+------------------------------------------------------------------+
//| Modificação de posição                                           |
//+------------------------------------------------------------------+
bool CTradeExecutor::ModifyPosition(ulong ticket, double stopLoss, double takeProfit) {
   // Verificar se trading está permitido
   if(!m_tradeAllowed) {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }
   
   // Registrar detalhes da modificação
   m_logger.Info(StringFormat("Modificando posição #%d: SL: %.5f, TP: %.5f", ticket, stopLoss, takeProfit));
   
   // Executar modificação com retry
   bool result = false;
   int retries = 0;
   
   while(retries < m_maxRetries && !result) {
      if(retries > 0) {
         m_logger.Warning(StringFormat("Tentativa %d de %d após erro: %d", retries + 1, m_maxRetries, m_lastError));
         Sleep(m_retryDelay);
      }
      
      result = m_trade.PositionModify(ticket, stopLoss, takeProfit);
      
      // Verificar resultado
      if(!result) {
         m_lastError = (int)m_trade.ResultRetcode();
         m_lastErrorDesc = "Erro na modificação da posição: " + IntegerToString(m_lastError);
         
         // Verificar se o erro é recuperável
         if(!IsRetryableError(m_lastError)) {
            m_logger.Error(m_lastErrorDesc);
            return false;
         }
      }
      
      retries++;
   }
   
   // Verificar resultado final
   if(result) {
      m_logger.Info(StringFormat("Posição #%d modificada com sucesso", ticket));
      return true;
   } else {
      m_logger.Error(StringFormat("Falha na modificação da posição #%d após %d tentativas. Último erro: %d", ticket, m_maxRetries, m_lastError));
      return false;
   }
}

//+------------------------------------------------------------------+
//| Fechamento de posição                                            |
//+------------------------------------------------------------------+
bool CTradeExecutor::ClosePosition(ulong ticket, double volume = 0.0) {
   // Verificar se trading está permitido
   if(!m_tradeAllowed) {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }
   
   // Registrar detalhes do fechamento
   if(volume <= 0.0) {
      m_logger.Info(StringFormat("Fechando posição #%d completamente", ticket));
   } else {
      m_logger.Info(StringFormat("Fechando posição #%d parcialmente: %.2f lotes", ticket, volume));
   }
   
   // Executar fechamento com retry
   bool result = false;
   int retries = 0;
   
   while(retries < m_maxRetries && !result) {
      if(retries > 0) {
         m_logger.Warning(StringFormat("Tentativa %d de %d após erro: %d", retries + 1, m_maxRetries, m_lastError));
         Sleep(m_retryDelay);
      }
      
      result = m_trade.PositionClose(ticket, (ulong)volume);
      
      // Verificar resultado
      if(!result) {
         m_lastError = (int)m_trade.ResultRetcode();
         m_lastErrorDesc = "Erro no fechamento da posição: " + IntegerToString(m_lastError);
         
         // Verificar se o erro é recuperável
         if(!IsRetryableError(m_lastError)) {
            m_logger.Error(m_lastErrorDesc);
            return false;
         }
      }
      
      retries++;
   }
   
   // Verificar resultado final
   if(result) {
      m_logger.Info(StringFormat("Posição #%d fechada com sucesso", ticket));
      return true;
   } else {
      m_logger.Error(StringFormat("Falha no fechamento da posição #%d após %d tentativas. Último erro: %d", ticket, m_maxRetries, m_lastError));
      return false;
   }
}

//+------------------------------------------------------------------+
//| Fechamento de todas as posições                                  |
//+------------------------------------------------------------------+
bool CTradeExecutor::CloseAllPositions(string symbol = "") {
   // Verificar se trading está permitido
   if(!m_tradeAllowed) {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }
   
   // Registrar detalhes do fechamento
   if(symbol == "") {
      m_logger.Info("Fechando todas as posições");
   } else {
      m_logger.Info(StringFormat("Fechando todas as posições de %s", symbol));
   }
   
   // Contar posições abertas
   int totalPositions = PositionsTotal();
   int closedPositions = 0;
   
   // Fechar cada posição
   for(int i = totalPositions - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      
      if(ticket <= 0) {
         m_logger.Warning(StringFormat("Falha ao obter ticket da posição %d", i));
         continue;
      }
      
      // Verificar símbolo se especificado
      if(symbol != "") {
         if(!PositionSelectByTicket(ticket)) {
            m_logger.Warning(StringFormat("Falha ao selecionar posição #%d", ticket));
            continue;
         }
         
         string posSymbol = PositionGetString(POSITION_SYMBOL);
         if(posSymbol != symbol) {
            continue; // Pular posições de outros símbolos
         }
      }
      
      // Fechar posição
      if(ClosePosition(ticket)) {
         closedPositions++;
      }
   }
   
   // Verificar resultado
   if(closedPositions > 0) {
      m_logger.Info(StringFormat("%d posições fechadas com sucesso", closedPositions));
      return true;
   } else if(totalPositions == 0) {
      m_logger.Info("Nenhuma posição aberta para fechar");
      return true;
   } else {
      m_logger.Warning(StringFormat("Nenhuma posição fechada de %d posições abertas", totalPositions));
      return false;
   }
}

//+------------------------------------------------------------------+
//| Aplicar trailing stop fixo                                       |
//+------------------------------------------------------------------+
bool CTradeExecutor::ApplyTrailingStop(ulong ticket, double points) {
   // Verificar se trading está permitido
   if(!m_tradeAllowed) {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }
   
   // Verificar parâmetros
   if(ticket <= 0 || points <= 0) {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros inválidos para trailing stop";
      m_logger.Error(m_lastErrorDesc);
      return false;
   }
   
   // Verificar se a posição existe
   if(!PositionSelectByTicket(ticket)) {
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
   
   for(int i = 0; i < size; i++) {
      if(m_trailingConfigs[i].ticket == ticket) {
         index = i;
         break;
      }
   }
   
   // Se não existir, criar nova configuração
   if(index < 0) {
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
   
   if(newStopLoss > 0) {
      double currentStopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);
      
      // Verificar se o novo stop loss é melhor que o atual
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool isImprovement = false;
      
      if(posType == POSITION_TYPE_BUY && (currentStopLoss < newStopLoss || currentStopLoss == 0)) {
         isImprovement = true;
      } else if(posType == POSITION_TYPE_SELL && (currentStopLoss > newStopLoss || currentStopLoss == 0)) {
         isImprovement = true;
      }
      
      // Modificar posição se o novo stop loss for melhor
      if(isImprovement) {
         if(ModifyPosition(ticket, newStopLoss, takeProfit)) {
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
bool CTradeExecutor::ApplyATRTrailingStop(ulong ticket, string symbol, ENUM_TIMEFRAMES timeframe, double multiplier) {
   // Verificar se trading está permitido
   if(!m_tradeAllowed) {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }
   
   // Verificar parâmetros
   if(ticket <= 0 || symbol == "" || multiplier <= 0) {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros inválidos para trailing stop ATR";
      m_logger.Error(m_lastErrorDesc);
      return false;
   }
   
   // Verificar se a posição existe
   if(!PositionSelectByTicket(ticket)) {
      m_lastError = -3;
      m_lastErrorDesc = "Posição não encontrada";
      m_logger.Error(StringFormat("Falha ao selecionar posição #%d para trailing stop ATR", ticket));
      return false;
   }
   
   // Verificar se o símbolo corresponde à posição
   string posSymbol = PositionGetString(POSITION_SYMBOL);
   if(posSymbol != symbol) {
      m_lastError = -4;
      m_lastErrorDesc = "Símbolo não corresponde à posição";
      m_logger.Error(StringFormat("Símbolo %s não corresponde à posição #%d (%s)", symbol, ticket, posSymbol));
      return false;
   }
   
   // Verificar se já existe configuração para esta posição
   int index = -1;
   int size = ArraySize(m_trailingConfigs);
   
   for(int i = 0; i < size; i++) {
      if(m_trailingConfigs[i].ticket == ticket) {
         index = i;
         break;
      }
   }
   
   // Se não existir, criar nova configuração
   if(index < 0) {
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
   
   if(newStopLoss > 0) {
      double currentStopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);
      
      // Verificar se o novo stop loss é melhor que o atual
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool isImprovement = false;
      
      if(posType == POSITION_TYPE_BUY && (currentStopLoss < newStopLoss || currentStopLoss == 0)) {
         isImprovement = true;
      } else if(posType == POSITION_TYPE_SELL && (currentStopLoss > newStopLoss || currentStopLoss == 0)) {
         isImprovement = true;
      }
      
      // Modificar posição se o novo stop loss for melhor
      if(isImprovement) {
         if(ModifyPosition(ticket, newStopLoss, takeProfit)) {
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
bool CTradeExecutor::ApplyMATrailingStop(ulong ticket, string symbol, ENUM_TIMEFRAMES timeframe, int period) {
   // Verificar se trading está permitido
   if(!m_tradeAllowed) {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }
   
   // Verificar parâmetros
   if(ticket <= 0 || symbol == "" || period <= 0) {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros inválidos para trailing stop MA";
      m_logger.Error(m_lastErrorDesc);
      return false;
   }
   
   // Verificar se a posição existe
   if(!PositionSelectByTicket(ticket)) {
      m_lastError = -3;
      m_lastErrorDesc = "Posição não encontrada";
      m_logger.Error(StringFormat("Falha ao selecionar posição #%d para trailing stop MA", ticket));
      return false;
   }
   
   // Verificar se o símbolo corresponde à posição
   string posSymbol = PositionGetString(POSITION_SYMBOL);
   if(posSymbol != symbol) {
      m_lastError = -4;
      m_lastErrorDesc = "Símbolo não corresponde à posição";
      m_logger.Error(StringFormat("Símbolo %s não corresponde à posição #%d (%s)", symbol, ticket, posSymbol));
      return false;
   }
   
   // Verificar se já existe configuração para esta posição
   int index = -1;
   int size = ArraySize(m_trailingConfigs);
   
   for(int i = 0; i < size; i++) {
      if(m_trailingConfigs[i].ticket == ticket) {
         index = i;
         break;
      }
   }
   
   // Se não existir, criar nova configuração
   if(index < 0) {
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
   
   if(newStopLoss > 0) {
      double currentStopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);
      
      // Verificar se o novo stop loss é melhor que o atual
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool isImprovement = false;
      
      if(posType == POSITION_TYPE_BUY && (currentStopLoss < newStopLoss || currentStopLoss == 0)) {
         isImprovement = true;
      } else if(posType == POSITION_TYPE_SELL && (currentStopLoss > newStopLoss || currentStopLoss == 0)) {
         isImprovement = true;
      }
      
      // Modificar posição se o novo stop loss for melhor
      if(isImprovement) {
         if(ModifyPosition(ticket, newStopLoss, takeProfit)) {
            m_trailingConfigs[index].lastStopLoss = newStopLoss;
            m_trailingConfigs[index].lastUpdateTime = TimeCurrent();
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Gerenciar posições abertas                                       |
//+------------------------------------------------------------------+
void CTradeExecutor::ManageOpenPositions() {
   // Verificar se trading está permitido
   if(!m_tradeAllowed) {
      return;
   }
   
   // Verificar se há configurações de trailing stop
   int size = ArraySize(m_trailingConfigs);
   if(size == 0) {
      return;
   }
   
   // Obter hora atual
   datetime currentTime = TimeCurrent();
   
   // Processar cada configuração
   for(int i = size - 1; i >= 0; i--) {
      // Verificar se a posição ainda existe
      if(!PositionSelectByTicket(m_trailingConfigs[i].ticket)) {
         // Remover configuração se a posição não existir mais
         for(int j = i; j < size - 1; j++) {
            m_trailingConfigs[j] = m_trailingConfigs[j + 1];
         }
         ArrayResize(m_trailingConfigs, size - 1);
         size--;
         continue;
      }
      
      // Verificar se é hora de atualizar (a cada 10 segundos)
      if(currentTime - m_trailingConfigs[i].lastUpdateTime < 10) {
         continue;
      }
      
      // Calcular novo stop loss de acordo com o tipo de trailing
      double newStopLoss = 0;
      
      switch(m_trailingConfigs[i].trailingType) {
         case TRAILING_FIXED:
            newStopLoss = CalculateFixedTrailingStop(m_trailingConfigs[i].ticket, m_trailingConfigs[i].fixedPoints);
            break;
            
         case TRAILING_ATR:
            newStopLoss = CalculateATRTrailingStop(m_trailingConfigs[i].symbol, m_trailingConfigs[i].timeframe, 
                                                 m_trailingConfigs[i].atrMultiplier, m_trailingConfigs[i].ticket);
            break;
            
         case TRAILING_MA:
            newStopLoss = CalculateMATrailingStop(m_trailingConfigs[i].symbol, m_trailingConfigs[i].timeframe, 
                                                m_trailingConfigs[i].maPeriod, m_trailingConfigs[i].ticket);
            break;
      }
      
      // Verificar se o novo stop loss é válido
      if(newStopLoss <= 0) {
         continue;
      }
      
      // Obter stop loss e take profit atuais
      double currentStopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);
      
      // Verificar se o novo stop loss é melhor que o atual
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool isImprovement = false;
      
      if(posType == POSITION_TYPE_BUY && newStopLoss > currentStopLoss) {
         isImprovement = true;
      } else if(posType == POSITION_TYPE_SELL && newStopLoss < currentStopLoss) {
         isImprovement = true;
      }
      
      // Modificar posição se o novo stop loss for melhor
      if(isImprovement) {
         if(ModifyPosition(m_trailingConfigs[i].ticket, newStopLoss, takeProfit)) {
            m_trailingConfigs[i].lastStopLoss = newStopLoss;
            m_trailingConfigs[i].lastUpdateTime = currentTime;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Verificar se o erro é recuperável                                |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsRetryableError(int errorCode) {
   switch(errorCode) {
      case TRADE_ERROR_SERVER_BUSY:
      case TRADE_ERROR_NO_CONNECTION:
      case TRADE_ERROR_TRADE_TIMEOUT:
      case TRADE_ERROR_PRICE_CHANGED:
      case TRADE_ERROR_OFF_QUOTES:
      case TRADE_ERROR_BROKER_BUSY:
      case TRADE_ERROR_REQUOTE:
      case TRADE_ERROR_TOO_MANY_REQUESTS:
      case TRADE_ERROR_TRADE_CONTEXT_BUSY:
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calcular stop loss para trailing stop fixo                       |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculateFixedTrailingStop(ulong ticket, double fixedPoints) {
   // Verificar parâmetros
   if(ticket <= 0 || fixedPoints <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("Parâmetros inválidos para cálculo de trailing stop fixo");
      }
      return 0.0;
   }
   
   // Verificar se a posição existe
   if(!PositionSelectByTicket(ticket)) {
      if(m_logger != NULL) {
         m_logger.Error("Falha ao selecionar posição #" + IntegerToString(ticket));
      }
      return 0.0;
   }
   
   // Obter informações da posição
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   string symbol = PositionGetString(POSITION_SYMBOL);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   // Verificar se os valores são válidos
   if(openPrice <= 0 || currentPrice <= 0 || point <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("Valores inválidos para cálculo de trailing stop fixo");
      }
      return 0.0;
   }
   
   // Calcular distância em pontos
   double stopDistance = fixedPoints * point;
   
   // Calcular novo stop loss
   double newStopLoss = 0.0;
   
   if(posType == POSITION_TYPE_BUY) {
      newStopLoss = currentPrice - stopDistance;
      
      // Verificar se o preço está em lucro
      if(currentPrice <= openPrice) {
         if(m_logger != NULL) {
            m_logger.Debug("Trailing stop fixo não aplicado: posição de compra não está em lucro");
         }
         return 0.0;
      }
   } else if(posType == POSITION_TYPE_SELL) {
      newStopLoss = currentPrice + stopDistance;
      
      // Verificar se o preço está em lucro
      if(currentPrice >= openPrice) {
         if(m_logger != NULL) {
            m_logger.Debug("Trailing stop fixo não aplicado: posição de venda não está em lucro");
         }
         return 0.0;
      }
   } else {
      if(m_logger != NULL) {
         m_logger.Error("Tipo de posição inválido para cálculo de trailing stop fixo");
      }
      return 0.0;
   }
   
   // Normalizar o stop loss
   newStopLoss = NormalizeDouble(newStopLoss, digits);
   
   if(m_logger != NULL) {
      m_logger.Debug(StringFormat("Trailing stop fixo calculado para posição #%d: %.5f", ticket, newStopLoss));
   }
   
   return newStopLoss;
}

//+------------------------------------------------------------------+
//| Calcular stop loss para trailing stop baseado em ATR             |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculateATRTrailingStop(string symbol, ENUM_TIMEFRAMES timeframe, double atrMultiplier, ulong ticket) {
   // Verificar parâmetros
   if(symbol == "" || atrMultiplier <= 0 || ticket <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("Parâmetros inválidos para cálculo de trailing stop ATR");
      }
      return 0.0;
   }
   
   // Verificar se a posição existe
   if(!PositionSelectByTicket(ticket)) {
      if(m_logger != NULL) {
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
   if(openPrice <= 0 || currentPrice <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("Valores inválidos para cálculo de trailing stop ATR");
      }
      return 0.0;
   }
   
   // Criar handle do ATR
   int atrHandle = iATR(symbol, timeframe, 14);
   if(atrHandle == INVALID_HANDLE) {
      if(m_logger != NULL) {
         m_logger.Error("Falha ao criar handle do ATR: " + IntegerToString(GetLastError()));
      }
      return 0.0;
   }
   
   // Copiar valores do ATR
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   int copied = CopyBuffer(atrHandle, 0, 0, 1, atrValues);
   IndicatorRelease(atrHandle);
   
   if(copied <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("Falha ao copiar valores do ATR: " + IntegerToString(GetLastError()));
      }
      return 0.0;
   }
   
   // Calcular distância baseada no ATR
   double atrValue = atrValues[0];
   double stopDistance = atrValue * atrMultiplier;
   
   // Verificar se o valor do ATR é válido
   if(atrValue <= 0 || stopDistance <= 0) {
      if(m_logger != NULL) {
         m_logger.Warning("Valor do ATR inválido para cálculo de trailing stop");
      }
      return 0.0;
   }
   
   // Calcular novo stop loss
   double newStopLoss = 0.0;
   
   if(posType == POSITION_TYPE_BUY) {
      newStopLoss = currentPrice - stopDistance;
      
      // Verificar se o preço está em lucro
      if(currentPrice <= openPrice) {
         if(m_logger != NULL) {
            m_logger.Debug("Trailing stop ATR não aplicado: posição de compra não está em lucro");
         }
         return 0.0;
      }
   } else if(posType == POSITION_TYPE_SELL) {
      newStopLoss = currentPrice + stopDistance;
      
      // Verificar se o preço está em lucro
      if(currentPrice >= openPrice) {
         if(m_logger != NULL) {
            m_logger.Debug("Trailing stop ATR não aplicado: posição de venda não está em lucro");
         }
         return 0.0;
      }
   } else {
      if(m_logger != NULL) {
         m_logger.Error("Tipo de posição inválido para cálculo de trailing stop ATR");
      }
      return 0.0;
   }
   
   // Normalizar o stop loss
   newStopLoss = NormalizeDouble(newStopLoss, digits);
   
   if(m_logger != NULL) {
      m_logger.Debug(StringFormat("Trailing stop ATR calculado para posição #%d: %.5f (ATR: %.5f)", 
                                ticket, newStopLoss, atrValue));
   }
   
   return newStopLoss;
}

//+------------------------------------------------------------------+
//| Calcular stop loss para trailing stop baseado em média móvel     |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculateMATrailingStop(string symbol, ENUM_TIMEFRAMES timeframe, int maPeriod, ulong ticket) {
   // Verificar parâmetros
   if(symbol == "" || maPeriod <= 0 || ticket <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("Parâmetros inválidos para cálculo de trailing stop MA");
      }
      return 0.0;
   }
   
   // Verificar se a posição existe
   if(!PositionSelectByTicket(ticket)) {
      if(m_logger != NULL) {
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
   if(openPrice <= 0 || currentPrice <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("Valores inválidos para cálculo de trailing stop MA");
      }
      return 0.0;
   }
   
   // Criar handle da média móvel
   int maHandle = iMA(symbol, timeframe, maPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(maHandle == INVALID_HANDLE) {
      if(m_logger != NULL) {
         m_logger.Error("Falha ao criar handle da média móvel: " + IntegerToString(GetLastError()));
      }
      return 0.0;
   }
   
   // Copiar valores da média móvel
   double maValues[];
   ArraySetAsSeries(maValues, true);
   int copied = CopyBuffer(maHandle, 0, 0, 1, maValues);
   IndicatorRelease(maHandle);
   
   if(copied <= 0) {
      if(m_logger != NULL) {
         m_logger.Error("Falha ao copiar valores da média móvel: " + IntegerToString(GetLastError()));
      }
      return 0.0;
   }
   
   // Obter valor da média móvel
   double maValue = maValues[0];
   
   // Verificar se o valor da média móvel é válido
   if(maValue <= 0) {
      if(m_logger != NULL) {
         m_logger.Warning("Valor da média móvel inválido para cálculo de trailing stop");
      }
      return 0.0;
   }
   
   // Calcular novo stop loss
   double newStopLoss = 0.0;
   
   if(posType == POSITION_TYPE_BUY) {
      // Para compras, usar a média móvel como stop loss se estiver abaixo do preço atual
      if(maValue < currentPrice) {
         newStopLoss = maValue;
      } else {
         if(m_logger != NULL) {
            m_logger.Debug("Trailing stop MA não aplicado: média móvel acima do preço atual para compra");
         }
         return 0.0;
      }
      
      // Verificar se o preço está em lucro
      if(currentPrice <= openPrice) {
         if(m_logger != NULL) {
            m_logger.Debug("Trailing stop MA não aplicado: posição de compra não está em lucro");
         }
         return 0.0;
      }
   } else if(posType == POSITION_TYPE_SELL) {
      // Para vendas, usar a média móvel como stop loss se estiver acima do preço atual
      if(maValue > currentPrice) {
         newStopLoss = maValue;
      } else {
         if(m_logger != NULL) {
            m_logger.Debug("Trailing stop MA não aplicado: média móvel abaixo do preço atual para venda");
         }
         return 0.0;
      }
      
      // Verificar se o preço está em lucro
      if(currentPrice >= openPrice) {
         if(m_logger != NULL) {
            m_logger.Debug("Trailing stop MA não aplicado: posição de venda não está em lucro");
         }
         return 0.0;
      }
   } else {
      if(m_logger != NULL) {
         m_logger.Error("Tipo de posição inválido para cálculo de trailing stop MA");
      }
      return 0.0;
   }
   
   // Normalizar o stop loss
   newStopLoss = NormalizeDouble(newStopLoss, digits);
   
   if(m_logger != NULL) {
      m_logger.Debug(StringFormat("Trailing stop MA calculado para posição #%d: %.5f (MA: %.5f)", 
                                ticket, newStopLoss, maValue));
   }
   
   return newStopLoss;
}
//+------------------------------------------------------------------+

#endif // TRADEEXECUTOR_MQH

//+------------------------------------------------------------------+
//| Método ExecuteInBatches para execução de ordens em lotes menores |
//+------------------------------------------------------------------+
bool CTradeExecutor::ExecuteInBatches(OrderRequest &request, double maxBatchSize = 1.0)
{
   if(!m_tradeAllowed) {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      if(m_logger != NULL)
         m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   if(request.symbol == "" || request.volume <= 0 || maxBatchSize <= 0) {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros de ordem inválidos";
      if(m_logger != NULL)
         m_logger.Error(m_lastErrorDesc);
      return false;
   }

   if(m_logger != NULL) {
      m_logger.Info(StringFormat("Executando ordem em lotes: %s %s %.2f @ %.5f, SL: %.5f, TP: %.5f, Lote máximo: %.2f",
                                request.symbol,
                                request.type == ORDER_TYPE_BUY ? "BUY" : "SELL",
                                request.volume,
                                request.price,
                                request.stopLoss,
                                request.takeProfit,
                                maxBatchSize));
   }

   double remainingVolume = request.volume;
   bool allSuccess = true;
   int batchCount = 0;

   while(remainingVolume > 0) {
      double batchVolume = MathMin(remainingVolume, maxBatchSize);
      batchCount++;

      OrderRequest batchRequest = request;
      batchRequest.volume = batchVolume;

      // Obter o preço atual do símbolo
      MqlTick tick;
      if(!SymbolInfoTick(batchRequest.symbol, tick)) {
         m_lastError = -4;
         m_lastErrorDesc = "Falha ao obter o tick de preço atual";
         if(m_logger != NULL)
            m_logger.Error(m_lastErrorDesc);
         return false;
      }

      // Verificar se o SL foi ultrapassado (evitar entrada inválida)
      if(batchRequest.type == ORDER_TYPE_SELL && tick.bid >= batchRequest.stopLoss) {
         m_lastError = -5;
         m_lastErrorDesc = "Preço atual (bid) ultrapassou o stop loss antes da execução do lote SELL";
         if(m_logger != NULL)
            m_logger.Error(m_lastErrorDesc);
         allSuccess = false;
         break;
      }

      if(batchRequest.type == ORDER_TYPE_BUY && tick.ask <= batchRequest.stopLoss) {
         m_lastError = -6;
         m_lastErrorDesc = "Preço atual (ask) ultrapassou o stop loss antes da execução do lote BUY";
         if(m_logger != NULL)
            m_logger.Error(m_lastErrorDesc);
         allSuccess = false;
         break;
      }

      // (Opcional) Verificar se o TP já foi atingido
      if(batchRequest.type == ORDER_TYPE_SELL && tick.bid <= batchRequest.takeProfit) {
         m_lastError = -7;
         m_lastErrorDesc = "Preço atual (bid) já atingiu o take profit antes da execução do lote SELL";
         if(m_logger != NULL)
            m_logger.Warning(m_lastErrorDesc);  // Warning, pois pode não ser crítico
         allSuccess = false;
         break;
      }

      if(batchRequest.type == ORDER_TYPE_BUY && tick.ask >= batchRequest.takeProfit) {
         m_lastError = -8;
         m_lastErrorDesc = "Preço atual (ask) já atingiu o take profit antes da execução do lote BUY";
         if(m_logger != NULL)
            m_logger.Warning(m_lastErrorDesc);
         allSuccess = false;
         break;
      }

      if(m_logger != NULL) {
         m_logger.Info(StringFormat("Executando lote %d: %.2f de %.2f", batchCount, batchVolume, request.volume));
      }

      bool result = false;
      int retries = 0;

      while(retries < m_maxRetries && !result) {
         if(retries > 0) {
            if(m_logger != NULL)
               m_logger.Warning(StringFormat("Tentativa %d de %d após erro: %d", retries + 1, m_maxRetries, m_lastError));
            Sleep(m_retryDelay);
         }

         switch(batchRequest.type) {
            case ORDER_TYPE_BUY:
               result = m_trade.Buy(batchRequest.volume, batchRequest.symbol, batchRequest.price, batchRequest.stopLoss, batchRequest.takeProfit, batchRequest.comment);
               break;
            case ORDER_TYPE_SELL:
               result = m_trade.Sell(batchRequest.volume, batchRequest.symbol, batchRequest.price, batchRequest.stopLoss, batchRequest.takeProfit, batchRequest.comment);
               break;
            case ORDER_TYPE_BUY_LIMIT:
               result = m_trade.BuyLimit(batchRequest.volume, batchRequest.price, batchRequest.symbol, batchRequest.stopLoss, batchRequest.takeProfit, ORDER_TIME_GTC, 0, batchRequest.comment);
               break;
            case ORDER_TYPE_SELL_LIMIT:
               result = m_trade.SellLimit(batchRequest.volume, batchRequest.price, batchRequest.symbol, batchRequest.stopLoss, batchRequest.takeProfit, ORDER_TIME_GTC, 0, batchRequest.comment);
               break;
            case ORDER_TYPE_BUY_STOP:
               result = m_trade.BuyStop(batchRequest.volume, batchRequest.price, batchRequest.symbol, batchRequest.stopLoss, batchRequest.takeProfit, ORDER_TIME_GTC, 0, batchRequest.comment);
               break;
            case ORDER_TYPE_SELL_STOP:
               result = m_trade.SellStop(batchRequest.volume, batchRequest.price, batchRequest.symbol, batchRequest.stopLoss, batchRequest.takeProfit, ORDER_TIME_GTC, 0, batchRequest.comment);
               break;
            default:
               m_lastError = -3;
               m_lastErrorDesc = "Tipo de ordem não suportado";
               if(m_logger != NULL)
                  m_logger.Error(m_lastErrorDesc);
               return false;
         }

         if(!result) {
            m_lastError = (int)m_trade.ResultRetcode();
            m_lastErrorDesc = "Erro na execução da ordem: " + IntegerToString(m_lastError);
            if(!IsRetryableError(m_lastError)) {
               if(m_logger != NULL)
                  m_logger.Error(m_lastErrorDesc);
               return false;
            }
         }

         retries++;
      }

      if(!result) {
         if(m_logger != NULL)
            m_logger.Error(StringFormat("Falha ao executar lote %d: %.2f", batchCount, batchVolume));
         allSuccess = false;
         break;
      }

      remainingVolume -= batchVolume;

      if(remainingVolume > 0)
         Sleep(100);
   }

   if(allSuccess) {
      if(m_logger != NULL)
         m_logger.Info(StringFormat("Todos os %d lotes executados com sucesso", batchCount));
   } else {
      if(m_logger != NULL)
         m_logger.Warning(StringFormat("Execução parcial: %d de %d lotes executados", batchCount - 1, (int)MathCeil(request.volume / maxBatchSize)));
   }

   return allSuccess;
}

//+------------------------------------------------------------------+
//| Modificação do método Execute para usar ExecuteInBatches         |
//+------------------------------------------------------------------+
bool CTradeExecutor::Execute(OrderRequest &request)
{
   // Verificar se o volume é grande e se deve usar execução em lotes
   if(request.volume > 1.0) {
      return ExecuteInBatches(request, 1.0);
   }
   
   // Código original do método Execute para volumes pequenos
   // Verificar se trading está permitido
   if(!m_tradeAllowed) {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      if(m_logger != NULL) {
         m_logger.Warning(m_lastErrorDesc);
      }
      return false;
   }
   
   // Verificar parâmetros
   if(request.symbol == "" || request.volume <= 0) {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros de ordem inválidos";
      if(m_logger != NULL) {
         m_logger.Error(m_lastErrorDesc);
      }
      return false;
   }
   
   // Registrar detalhes da ordem
   if(m_logger != NULL) {
      m_logger.Info(StringFormat("Executando ordem: %s %s %.2f @ %.5f, SL: %.5f, TP: %.5f",
                                request.symbol,
                                request.type == ORDER_TYPE_BUY ? "BUY" : "SELL",
                                request.volume,
                                request.price,
                                request.stopLoss,
                                request.takeProfit));
   }
   
   // Executar ordem com retry
   bool result = false;
   int retries = 0;
   
   while(retries < m_maxRetries && !result) {
      if(retries > 0) {
         if(m_logger != NULL) {
            m_logger.Warning(StringFormat("Tentativa %d de %d após erro: %d", retries + 1, m_maxRetries, m_lastError));
         }
         Sleep(m_retryDelay);
      }
      
      // Executar ordem de acordo com o tipo
      switch(request.type) {
         case ORDER_TYPE_BUY:
            result = m_trade.Buy(request.volume, request.symbol, request.price, request.stopLoss, request.takeProfit, request.comment);
            break;
         case ORDER_TYPE_SELL:
            result = m_trade.Sell(request.volume, request.symbol, request.price, request.stopLoss, request.takeProfit, request.comment);
            break;
         case ORDER_TYPE_BUY_LIMIT:
            result = m_trade.BuyLimit(request.volume, request.price, request.symbol, request.stopLoss, request.takeProfit, ORDER_TIME_GTC, 0, request.comment);
            break;
         case ORDER_TYPE_SELL_LIMIT:
            result = m_trade.SellLimit(request.volume, request.price, request.symbol, request.stopLoss, request.takeProfit, ORDER_TIME_GTC, 0, request.comment);
            break;
         case ORDER_TYPE_BUY_STOP:
            result = m_trade.BuyStop(request.volume, request.price, request.symbol, request.stopLoss, request.takeProfit, ORDER_TIME_GTC, 0, request.comment);
            break;
         case ORDER_TYPE_SELL_STOP:
            result = m_trade.SellStop(request.volume, request.price, request.symbol, request.stopLoss, request.takeProfit, ORDER_TIME_GTC, 0, request.comment);
            break;
         default:
            m_lastError = -3;
            m_lastErrorDesc = "Tipo de ordem não suportado";
            if(m_logger != NULL) {
               m_logger.Error(m_lastErrorDesc);
            }
            return false;
      }
      
      // Verificar resultado
      if(!result) {
         m_lastError = (int)m_trade.ResultRetcode();
         m_lastErrorDesc = "Erro na execução da ordem: " + IntegerToString(m_lastError);
         
         // Verificar se o erro é recuperável
         if(!IsRetryableError(m_lastError)) {
            if(m_logger != NULL) {
               m_logger.Error(m_lastErrorDesc);
            }
            return false;
         }
      }
      
      retries++;
   }
   
   // Verificar resultado final
   if(result) {
      if(m_logger != NULL) {
         m_logger.Info(StringFormat("Ordem executada com sucesso. Ticket: %d", m_trade.ResultOrder()));
      }
      return true;
   } else {
      if(m_logger != NULL) {
         m_logger.Error(StringFormat("Falha na execução da ordem após %d tentativas. Último erro: %d", m_maxRetries, m_lastError));
      }
      return false;
   }
}

