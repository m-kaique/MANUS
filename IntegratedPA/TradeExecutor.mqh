//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                            TradeExecutor.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#ifndef TRADEEXECUTOR_MQH
#define TRADEEXECUTOR_MQH

// Inclusão de bibliotecas necessárias
#include <Trade/Trade.mqh>
#include "Structures.mqh"
#include "Logger.mqh"

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

   // Métodos privados
   bool QuickValidateExecution(OrderRequest &request, MqlTick &tick);
   double GetMaxAllowedSpread(string symbol);
   void DebugInvalidStopsError(OrderRequest &request, MqlTick &tick);
   bool IsRetryableError(int errorCode);
   double CalculateFixedTrailingStop(ulong ticket, double fixedPoints);
   double CalculateATRTrailingStop(string symbol, ENUM_TIMEFRAMES timeframe, double atrMultiplier, ulong ticket);
   double CalculateMATrailingStop(string symbol, ENUM_TIMEFRAMES timeframe, int maPeriod, ulong ticket);

public:
   // Construtores e destrutor
   CTradeExecutor();
   ~CTradeExecutor();

   // Métodos de inicialização
   bool Initialize(CLogger *logger);

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
CTradeExecutor::CTradeExecutor()
{
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
CTradeExecutor::~CTradeExecutor()
{
   if (m_trade != NULL)
   {
      delete m_trade;
      m_trade = NULL;
   }
}

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool CTradeExecutor::Initialize(CLogger *logger)
{
   // Verificar parâmetros
   if (logger == NULL)
   {
      Print("CTradeExecutor::Initialize - Logger não pode ser NULL");
      return false;
   }

   // Atribuir logger
   m_logger = logger;
   m_logger.Info("Inicializando TradeExecutor");

   // Criar objeto de trade
   m_trade = new CTrade();
   if (m_trade == NULL)
   {
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
bool CTradeExecutor::ModifyPosition(ulong ticket, double stopLoss, double takeProfit)
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
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

   while (retries < m_maxRetries && !result)
   {
      if (retries > 0)
      {
         m_logger.Warning(StringFormat("Tentativa %d de %d após erro: %d", retries + 1, m_maxRetries, m_lastError));
         Sleep(m_retryDelay);
      }

      result = m_trade.PositionModify(ticket, stopLoss, takeProfit);

      // Verificar resultado
      if (!result)
      {
         m_lastError = (int)m_trade.ResultRetcode();
         m_lastErrorDesc = "Erro na modificação da posição: " + IntegerToString(m_lastError);

         // Verificar se o erro é recuperável
         if (!IsRetryableError(m_lastError))
         {
            m_logger.Error(m_lastErrorDesc);
            return false;
         }
      }

      retries++;
   }

   // Verificar resultado final
   if (result)
   {
      m_logger.Info(StringFormat("Posição #%d modificada com sucesso", ticket));
      return true;
   }
   else
   {
      m_logger.Error(StringFormat("Falha na modificação da posição #%d após %d tentativas. Último erro: %d", ticket, m_maxRetries, m_lastError));
      return false;
   }
}

//+------------------------------------------------------------------+
//| Fechamento de posição                                            |
//+------------------------------------------------------------------+

bool CTradeExecutor::ClosePosition(ulong ticket, double volume = 0.0)
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   // Verificar se a posição existe
   if (!PositionSelectByTicket(ticket))
   {
      m_lastError = -2;
      m_lastErrorDesc = "Posição não encontrada: " + IntegerToString(ticket);
      if (m_logger != NULL)
      {
         m_logger.Error(m_lastErrorDesc);
      }
      return false;
   }

   // Obter informações da posição
   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   string symbol = PositionGetString(POSITION_SYMBOL);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   // CORREÇÃO: Determinar volume correto para fechamento
   double volumeToClose = 0.0;
   bool isPartialClose = false;

   if (volume <= 0.0)
   {
      // Fechar posição completa
      volumeToClose = currentVolume;
      isPartialClose = false;

      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("Fechando posição #%d COMPLETAMENTE: %.2f lotes", ticket, volumeToClose));
      }
   }
   else
   {
      // Fechar parcialmente
      if (volume >= currentVolume)
      {
         // Se volume solicitado >= volume atual, fechar tudo
         volumeToClose = currentVolume;
         isPartialClose = false;

         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Volume parcial (%.2f) >= volume atual (%.2f), fechando posição completa",
                                          volume, currentVolume));
         }
      }
      else
      {
         // Fechamento parcial real
         volumeToClose = volume;
         isPartialClose = true;

         if (m_logger != NULL)
         {
            m_logger.Info(StringFormat("Fechando posição #%d PARCIALMENTE: %.2f de %.2f lotes",
                                       ticket, volumeToClose, currentVolume));
         }
      }
   }

   // Normalizar volume
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if (stepLot > 0)
   {
      volumeToClose = MathFloor(volumeToClose / stepLot) * stepLot;
   }

   if (volumeToClose < minLot)
   {
      m_lastError = -3;
      m_lastErrorDesc = StringFormat("Volume muito pequeno para fechamento: %.2f < %.2f", volumeToClose, minLot);
      if (m_logger != NULL)
      {
         m_logger.Error(m_lastErrorDesc);
      }
      return false;
   }

   // Executar fechamento com retry
   bool result = false;
   int retries = 0;

   while (retries < m_maxRetries && !result)
   {
      if (retries > 0)
      {
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Tentativa %d de %d após erro: %d", retries + 1, m_maxRetries, m_lastError));
         }
         Sleep(m_retryDelay);

         // Revalidar posição
         if (!PositionSelectByTicket(ticket))
         {
            m_lastError = -4;
            m_lastErrorDesc = "Posição não existe mais durante retry";
            if (m_logger != NULL)
            {
               m_logger.Error(m_lastErrorDesc);
            }
            return false;
         }

         // Atualizar volume atual
         currentVolume = PositionGetDouble(POSITION_VOLUME);
         if (isPartialClose && volumeToClose >= currentVolume)
         {
            volumeToClose = currentVolume;
            isPartialClose = false;

            if (m_logger != NULL)
            {
               m_logger.Info("Ajustando para fechamento completo no retry");
            }
         }
      }

      // EXECUÇÃO CORRIGIDA: Usar PositionClosePartial para parciais
      if (isPartialClose)
      {
         // Para fechamento parcial, usar PositionClosePartial
         result = m_trade.PositionClosePartial(ticket, volumeToClose);

         if (m_logger != NULL)
         {
            m_logger.Debug(StringFormat("Tentativa %d: PositionClosePartial(#%d, %.2f)",
                                        retries + 1, ticket, volumeToClose));
         }
      }
      else
      {
         // Para fechamento completo, usar PositionClose
         result = m_trade.PositionClose(ticket);

         if (m_logger != NULL)
         {
            m_logger.Debug(StringFormat("Tentativa %d: PositionClose(#%d)", retries + 1, ticket));
         }
      }

      // Verificar resultado
      if (!result)
      {
         m_lastError = (int)m_trade.ResultRetcode();
         m_lastErrorDesc = "Erro no fechamento da posição: " + IntegerToString(m_lastError);

         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Erro %d na tentativa %d: %s", m_lastError, retries + 1, m_lastErrorDesc));
         }

         // Verificar se o erro é recuperável
         if (!IsRetryableError(m_lastError))
         {
            if (m_logger != NULL)
            {
               m_logger.Error("Erro não recuperável: " + m_lastErrorDesc);
            }
            break;
         }
      }

      retries++;
   }

   // Verificar resultado final
   if (result)
   {
      ulong dealTicket = m_trade.ResultDeal();

      if (m_logger != NULL)
      {
         if (isPartialClose)
         {
            m_logger.Info(StringFormat("✅ FECHAMENTO PARCIAL executado com sucesso!", ""));
            m_logger.Info(StringFormat("   Posição: #%d", ticket));
            m_logger.Info(StringFormat("   Volume fechado: %.2f lotes", volumeToClose));
            m_logger.Info(StringFormat("   Volume restante: %.2f lotes", currentVolume - volumeToClose));
            m_logger.Info(StringFormat("   Deal: #%d", dealTicket));
         }
         else
         {
            m_logger.Info(StringFormat("✅ FECHAMENTO COMPLETO executado com sucesso!", ""));
            m_logger.Info(StringFormat("   Posição: #%d", ticket));
            m_logger.Info(StringFormat("   Volume fechado: %.2f lotes", volumeToClose));
            m_logger.Info(StringFormat("   Deal: #%d", dealTicket));
         }
      }
      return true;
   }
   else
   {
      if (m_logger != NULL)
      {
         m_logger.Error(StringFormat("❌ FALHA no fechamento da posição #%d após %d tentativas", ticket, m_maxRetries));
         m_logger.Error(StringFormat("   Último erro: %d (%s)", m_lastError, m_lastErrorDesc));
         m_logger.Error(StringFormat("   Tipo: %s", isPartialClose ? "PARCIAL" : "COMPLETO"));
         m_logger.Error(StringFormat("   Volume solicitado: %.2f", volumeToClose));
      }
      return false;
   }
}
//+------------------------------------------------------------------+
//| Fechamento de todas as posições                                  |
//+------------------------------------------------------------------+
bool CTradeExecutor::CloseAllPositions(string symbol = "")
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   // Registrar detalhes do fechamento
   if (symbol == "")
   {
      m_logger.Info("Fechando todas as posições");
   }
   else
   {
      m_logger.Info(StringFormat("Fechando todas as posições de %s", symbol));
   }

   // Contar posições abertas
   int totalPositions = PositionsTotal();
   int closedPositions = 0;

   // Fechar cada posição
   for (int i = totalPositions - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if (ticket <= 0)
      {
         m_logger.Warning(StringFormat("Falha ao obter ticket da posição %d", i));
         continue;
      }

      // Verificar símbolo se especificado
      if (symbol != "")
      {
         if (!PositionSelectByTicket(ticket))
         {
            m_logger.Warning(StringFormat("Falha ao selecionar posição #%d", ticket));
            continue;
         }

         string posSymbol = PositionGetString(POSITION_SYMBOL);
         if (posSymbol != symbol)
         {
            continue; // Pular posições de outros símbolos
         }
      }

      // Fechar posição
      if (ClosePosition(ticket))
      {
         closedPositions++;
      }
   }

   // Verificar resultado
   if (closedPositions > 0)
   {
      m_logger.Info(StringFormat("%d posições fechadas com sucesso", closedPositions));
      return true;
   }
   else if (totalPositions == 0)
   {
      m_logger.Info("Nenhuma posição aberta para fechar");
      return true;
   }
   else
   {
      m_logger.Warning(StringFormat("Nenhuma posição fechada de %d posições abertas", totalPositions));
      return false;
   }
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
//| Gerenciar posições abertas                                       |
//+------------------------------------------------------------------+
void CTradeExecutor::ManageOpenPositions()
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      return;
   }

   // Verificar se há configurações de trailing stop
   int size = ArraySize(m_trailingConfigs);
   if (size == 0)
   {
      return;
   }

   // Obter hora atual
   datetime currentTime = TimeCurrent();

   // Processar cada configuração
   for (int i = size - 1; i >= 0; i--)
   {
      // Verificar se a posição ainda existe
      if (!PositionSelectByTicket(m_trailingConfigs[i].ticket))
      {
         // Remover configuração se a posição não existir mais
         for (int j = i; j < size - 1; j++)
         {
            m_trailingConfigs[j] = m_trailingConfigs[j + 1];
         }
         ArrayResize(m_trailingConfigs, size - 1);
         size--;
         continue;
      }

      // Verificar se é hora de atualizar (a cada 10 segundos)
      if (currentTime - m_trailingConfigs[i].lastUpdateTime < 10)
      {
         continue;
      }

      // Calcular novo stop loss de acordo com o tipo de trailing
      double newStopLoss = 0;

      switch (m_trailingConfigs[i].trailingType)
      {
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
      if (newStopLoss <= 0)
      {
         continue;
      }

      // Obter stop loss e take profit atuais
      double currentStopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);

      // Verificar se o novo stop loss é melhor que o atual
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool isImprovement = false;

      if (posType == POSITION_TYPE_BUY && newStopLoss > currentStopLoss)
      {
         isImprovement = true;
      }
      else if (posType == POSITION_TYPE_SELL && newStopLoss < currentStopLoss)
      {
         isImprovement = true;
      }

      // Modificar posição se o novo stop loss for melhor
      if (isImprovement)
      {
         if (ModifyPosition(m_trailingConfigs[i].ticket, newStopLoss, takeProfit))
         {
            m_trailingConfigs[i].lastStopLoss = newStopLoss;
            m_trailingConfigs[i].lastUpdateTime = currentTime;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Verificar se o erro é recuperável                                |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsRetryableError(int errorCode)
{
   switch (errorCode)
   {
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
double CTradeExecutor::CalculateFixedTrailingStop(ulong ticket, double fixedPoints)
{
   // Verificar parâmetros
   if (ticket <= 0 || fixedPoints <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Parâmetros inválidos para cálculo de trailing stop fixo");
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
   string symbol = PositionGetString(POSITION_SYMBOL);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   // Verificar se os valores são válidos
   if (openPrice <= 0 || currentPrice <= 0 || point <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Valores inválidos para cálculo de trailing stop fixo");
      }
      return 0.0;
   }

   // Calcular distância em pontos
   double stopDistance = fixedPoints * point;

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
            m_logger.Debug("Trailing stop fixo não aplicado: posição de compra não está em lucro");
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
            m_logger.Debug("Trailing stop fixo não aplicado: posição de venda não está em lucro");
         }
         return 0.0;
      }
   }
   else
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Tipo de posição inválido para cálculo de trailing stop fixo");
      }
      return 0.0;
   }

   // Normalizar o stop loss
   newStopLoss = NormalizeDouble(newStopLoss, digits);

   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Trailing stop fixo calculado para posição #%d: %.5f", ticket, newStopLoss));
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

   // Criar handle do ATR
   int atrHandle = iATR(symbol, timeframe, 14);
   if (atrHandle == INVALID_HANDLE)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Falha ao criar handle do ATR: " + IntegerToString(GetLastError()));
      }
      return 0.0;
   }

   // Copiar valores do ATR
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   int copied = CopyBuffer(atrHandle, 0, 0, 1, atrValues);
   IndicatorRelease(atrHandle);

   if (copied <= 0)
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

#endif // TRADEEXECUTOR_MQH

//+------------------------------------------------------------------+
//| Método ExecuteInBatches para execução de ordens em lotes menores |
//+------------------------------------------------------------------+
bool CTradeExecutor::ExecuteInBatches(OrderRequest &request, double maxBatchSize = 1.0)
{
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      if (m_logger != NULL)
         m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   if (request.symbol == "" || request.volume <= 0 || maxBatchSize <= 0)
   {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros de ordem inválidos";
      if (m_logger != NULL)
         m_logger.Error(m_lastErrorDesc);
      return false;
   }

   if (m_logger != NULL)
   {
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

   while (remainingVolume > 0)
   {
      double batchVolume = MathMin(remainingVolume, maxBatchSize);
      batchCount++;

      OrderRequest batchRequest = request;
      batchRequest.volume = batchVolume;

      // Obter o preço atual do símbolo
      MqlTick tick;
      if (!SymbolInfoTick(batchRequest.symbol, tick))
      {
         m_lastError = -4;
         m_lastErrorDesc = "Falha ao obter o tick de preço atual";
         if (m_logger != NULL)
            m_logger.Error(m_lastErrorDesc);
         return false;
      }

      // Verificar se o SL foi ultrapassado (evitar entrada inválida)
      if (batchRequest.type == ORDER_TYPE_SELL && tick.bid >= batchRequest.stopLoss)
      {
         m_lastError = -5;
         m_lastErrorDesc = "Preço atual (bid) ultrapassou o stop loss antes da execução do lote SELL";
         if (m_logger != NULL)
            m_logger.Error(m_lastErrorDesc);
         allSuccess = false;
         break;
      }

      if (batchRequest.type == ORDER_TYPE_BUY && tick.ask <= batchRequest.stopLoss)
      {
         m_lastError = -6;
         m_lastErrorDesc = "Preço atual (ask) ultrapassou o stop loss antes da execução do lote BUY";
         if (m_logger != NULL)
            m_logger.Error(m_lastErrorDesc);
         allSuccess = false;
         break;
      }

      // (Opcional) Verificar se o TP já foi atingido
      if (batchRequest.type == ORDER_TYPE_SELL && tick.bid <= batchRequest.takeProfit)
      {
         m_lastError = -7;
         m_lastErrorDesc = "Preço atual (bid) já atingiu o take profit antes da execução do lote SELL";
         if (m_logger != NULL)
            m_logger.Warning(m_lastErrorDesc); // Warning, pois pode não ser crítico
         allSuccess = false;
         break;
      }

      if (batchRequest.type == ORDER_TYPE_BUY && tick.ask >= batchRequest.takeProfit)
      {
         m_lastError = -8;
         m_lastErrorDesc = "Preço atual (ask) já atingiu o take profit antes da execução do lote BUY";
         if (m_logger != NULL)
            m_logger.Warning(m_lastErrorDesc);
         allSuccess = false;
         break;
      }

      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("Executando lote %d: %.2f de %.2f", batchCount, batchVolume, request.volume));
      }

      bool result = false;
      int retries = 0;

      while (retries < m_maxRetries && !result)
      {
         if (retries > 0)
         {
            if (m_logger != NULL)
               m_logger.Warning(StringFormat("Tentativa %d de %d após erro: %d", retries + 1, m_maxRetries, m_lastError));
            Sleep(m_retryDelay);
         }

         switch (batchRequest.type)
         {
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
            if (m_logger != NULL)
               m_logger.Error(m_lastErrorDesc);
            return false;
         }

         if (!result)
         {
            m_lastError = (int)m_trade.ResultRetcode();
            m_lastErrorDesc = "Erro na execução da ordem: " + IntegerToString(m_lastError);
            // DEBUG ESPECÍFICO para erro 10016
            if (m_lastError == 10016 && retries == 0)
            {
               MqlTick currentTick;
               DebugInvalidStopsError(request, currentTick);
            }
            if (!IsRetryableError(m_lastError))
            {
               if (m_logger != NULL)
                  m_logger.Error(m_lastErrorDesc);
               return false;
            }
         }

         retries++;
      }

      if (!result)
      {
         if (m_logger != NULL)
            m_logger.Error(StringFormat("Falha ao executar lote %d: %.2f", batchCount, batchVolume));
         allSuccess = false;
         break;
      }

      remainingVolume -= batchVolume;

      if (remainingVolume > 0)
         Sleep(100);
   }

   if (allSuccess)
   {
      if (m_logger != NULL)
         m_logger.Info(StringFormat("Todos os %d lotes executados com sucesso", batchCount));
   }
   else
   {
      if (m_logger != NULL)
         m_logger.Warning(StringFormat("Execução parcial: %d de %d lotes executados", batchCount - 1, (int)MathCeil(request.volume / maxBatchSize)));
   }

   return allSuccess;
}

//+------------------------------------------------------------------+
//| Modificação do método Execute para usar ExecuteInBatches         |
//+------------------------------------------------------------------+
bool CTradeExecutor::Execute(OrderRequest &request)
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      if (m_logger != NULL)
      {
         m_logger.Warning(m_lastErrorDesc);
      }
      return false;
   }

   // Verificar parâmetros básicos
   if (request.symbol == "" || request.volume <= 0)
   {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros de ordem inválidos";
      if (m_logger != NULL)
      {
         m_logger.Error(m_lastErrorDesc);
      }
      return false;
   }

   // NOVA LÓGICA: Sempre executar a mercado no melhor preço disponível
   MqlTick currentTick;
   if (!SymbolInfoTick(request.symbol, currentTick))
   {
      m_lastError = -3;
      m_lastErrorDesc = "Falha ao obter preços atuais do mercado";
      if (m_logger != NULL)
      {
         m_logger.Error(m_lastErrorDesc);
      }
      return false;
   }

   // Determinar preços de execução
   double executionPrice = 0; // Para ordens a mercado no MT5
   double marketPrice = 0;    // Para log/referência

   if (request.type == ORDER_TYPE_BUY)
   {
      marketPrice = currentTick.ask; // Menor preço possível para comprar
      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("COMPRA a mercado: ASK = %.5f", marketPrice));
      }
   }
   else if (request.type == ORDER_TYPE_SELL)
   {
      marketPrice = currentTick.bid; // Maior preço possível para vender
      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("VENDA a mercado: BID = %.5f", marketPrice));
      }
   }
   else
   {
      m_lastError = -4;
      m_lastErrorDesc = "Tipo de ordem não suportado para execução imediata: " + EnumToString(request.type);
      if (m_logger != NULL)
      {
         m_logger.Error(m_lastErrorDesc);
      }
      return false;
   }

   // Normalizar SL e TP (manter os calculados pela estratégia)
   int digits = (int)SymbolInfoInteger(request.symbol, SYMBOL_DIGITS);
   double normalizedSL = NormalizeDouble(request.stopLoss, digits);
   double normalizedTP = NormalizeDouble(request.takeProfit, digits);

   // Validar SL e TP em relação ao preço de mercado
   if (request.type == ORDER_TYPE_BUY)
   {
      if (normalizedSL >= marketPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Stop Loss para COMPRA deve estar abaixo do ASK: SL=%.5f, ASK=%.5f",
                                          normalizedSL, marketPrice));
         }
         // Ajustar SL para 50 pontos abaixo do ASK
         double point = SymbolInfoDouble(request.symbol, SYMBOL_POINT);
         normalizedSL = marketPrice - (50 * point);
         normalizedSL = NormalizeDouble(normalizedSL, digits);

         if (m_logger != NULL)
         {
            m_logger.Info(StringFormat("SL ajustado para: %.5f", normalizedSL));
         }
      }

      if (normalizedTP > 0 && normalizedTP <= marketPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Take Profit para COMPRA deve estar acima do ASK: TP=%.5f, ASK=%.5f",
                                          normalizedTP, marketPrice));
         }
         // Ajustar TP para 100 pontos acima do ASK
         double point = SymbolInfoDouble(request.symbol, SYMBOL_POINT);
         normalizedTP = marketPrice + (100 * point);
         normalizedTP = NormalizeDouble(normalizedTP, digits);

         if (m_logger != NULL)
         {
            m_logger.Info(StringFormat("TP ajustado para: %.5f", normalizedTP));
         }
      }
   }
   else
   { // SELL
      if (normalizedSL <= marketPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Stop Loss para VENDA deve estar acima do BID: SL=%.5f, BID=%.5f",
                                          normalizedSL, marketPrice));
         }
         // Ajustar SL para 50 pontos acima do BID
         double point = SymbolInfoDouble(request.symbol, SYMBOL_POINT);
         normalizedSL = marketPrice + (50 * point);
         normalizedSL = NormalizeDouble(normalizedSL, digits);

         if (m_logger != NULL)
         {
            m_logger.Info(StringFormat("SL ajustado para: %.5f", normalizedSL));
         }
      }

      if (normalizedTP > 0 && normalizedTP >= marketPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Take Profit para VENDA deve estar abaixo do BID: TP=%.5f, BID=%.5f",
                                          normalizedTP, marketPrice));
         }
         // Ajustar TP para 100 pontos abaixo do BID
         double point = SymbolInfoDouble(request.symbol, SYMBOL_POINT);
         normalizedTP = marketPrice - (100 * point);
         normalizedTP = NormalizeDouble(normalizedTP, digits);

         if (m_logger != NULL)
         {
            m_logger.Info(StringFormat("TP ajustado para: %.5f", normalizedTP));
         }
      }
   }

   // Log da execução
   if (m_logger != NULL)
   {
      m_logger.Info(StringFormat("Executando ordem IMEDIATA: %s %s %.2f a mercado, SL: %.5f, TP: %.5f",
                                 request.symbol,
                                 request.type == ORDER_TYPE_BUY ? "COMPRA" : "VENDA",
                                 request.volume,
                                 normalizedSL,
                                 normalizedTP));
   }

   // Executar ordem a mercado com retry
   bool result = false;
   int retries = 0;

   while (retries < m_maxRetries && !result)
   {
      if (retries > 0)
      {
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Tentativa %d de %d após erro: %d", retries + 1, m_maxRetries, m_lastError));
         }
         Sleep(m_retryDelay);

         // Atualizar tick para nova tentativa
         if (!SymbolInfoTick(request.symbol, currentTick))
         {
            m_lastError = -5;
            m_lastErrorDesc = "Falha ao atualizar preços para retry";
            if (m_logger != NULL)
            {
               m_logger.Error(m_lastErrorDesc);
            }
            break;
         }
      }

      // EXECUÇÃO SIMPLIFICADA: Sempre a mercado (preço = 0)
      if (request.type == ORDER_TYPE_BUY)
      {
         result = m_trade.Buy(request.volume, request.symbol, 0, normalizedSL, normalizedTP, request.comment);
         if (m_logger != NULL)
         {
            m_logger.Debug(StringFormat("Tentativa %d: BUY a mercado", retries + 1));
         }
      }
      else
      {
         result = m_trade.Sell(request.volume, request.symbol, 0, normalizedSL, normalizedTP, request.comment);
         if (m_logger != NULL)
         {
            m_logger.Debug(StringFormat("Tentativa %d: SELL a mercado", retries + 1));
         }
      }

      // Verificar resultado
      if (!result)
      {
         m_lastError = (int)m_trade.ResultRetcode();
         m_lastErrorDesc = "Erro na execução da ordem: " + IntegerToString(m_lastError);

         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Erro %d na tentativa %d: %s", m_lastError, retries + 1, m_lastErrorDesc));
         }

         // Verificar se o erro é recuperável
         if (!IsRetryableError(m_lastError))
         {
            if (m_logger != NULL)
            {
               m_logger.Error("Erro não recuperável: " + m_lastErrorDesc);
            }
            break;
         }
      }

      retries++;
   }

   // Verificar resultado final
   if (result)
   {
      ulong orderTicket = m_trade.ResultOrder();
      ulong dealTicket = m_trade.ResultDeal();
      double dealPrice = m_trade.ResultPrice();

      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("✅ ORDEM EXECUTADA COM SUCESSO!", ""));
         m_logger.Info(StringFormat("   Tipo: %s a mercado", request.type == ORDER_TYPE_BUY ? "COMPRA" : "VENDA"));
         m_logger.Info(StringFormat("   Volume: %.2f", request.volume));
         m_logger.Info(StringFormat("   Preço executado: %.5f", dealPrice));
         m_logger.Info(StringFormat("   Stop Loss: %.5f", normalizedSL));
         m_logger.Info(StringFormat("   Take Profit: %.5f", normalizedTP));
         m_logger.Info(StringFormat("   Ticket Ordem: %d", orderTicket));
         m_logger.Info(StringFormat("   Ticket Deal: %d", dealTicket));
      }
      return true;
   }
   else
   {
      if (m_logger != NULL)
      {
         m_logger.Error(StringFormat("❌ FALHA NA EXECUÇÃO após %d tentativas", m_maxRetries));
         m_logger.Error(StringFormat("   Último erro: %d (%s)", m_lastError, m_lastErrorDesc));
         m_logger.Error(StringFormat("   Símbolo: %s", request.symbol));
         m_logger.Error(StringFormat("   Tipo: %s", request.type == ORDER_TYPE_BUY ? "COMPRA" : "VENDA"));
         m_logger.Error(StringFormat("   Volume: %.2f", request.volume));
      }
      return false;
   }
}

bool CTradeExecutor::QuickValidateExecution(OrderRequest &request, MqlTick &tick)
{
   if (m_logger != NULL)
   {
      m_logger.Debug("TradeExecutor: Executando validação rápida...");
   }

   // 1. Verificar se o mercado está aberto
   long tradeMode = SymbolInfoInteger(request.symbol, SYMBOL_TRADE_MODE);
   if (tradeMode != SYMBOL_TRADE_MODE_FULL)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Mercado fechado ou trading restrito para " + request.symbol);
      }
      return false;
   }

   // 2. Verificar se temos preços válidos
   if (tick.ask <= 0 || tick.bid <= 0 || tick.ask <= tick.bid)
   {
      if (m_logger != NULL)
      {
         m_logger.Error(StringFormat("Preços inválidos: Bid=%.5f, Ask=%.5f", tick.bid, tick.ask));
      }
      return false;
   }

   // 3. Verificar spread razoável
   double spread = tick.ask - tick.bid;
   double maxSpread = GetMaxAllowedSpread(request.symbol);

   if (spread > maxSpread)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("Spread muito alto: %.5f > %.5f", spread, maxSpread));
      }
      // Não bloquear, apenas avisar
   }

   // 4. Verificar volumes
   double minVol = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MAX);

   if (request.volume < minVol || request.volume > maxVol)
   {
      if (m_logger != NULL)
      {
         m_logger.Error(StringFormat("Volume fora dos limites: %.2f (permitido: %.2f - %.2f)",
                                     request.volume, minVol, maxVol));
      }
      return false;
   }

   // 5. Verificar margem livre (estimativa rápida)
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double requiredMargin = request.volume * tick.ask * 0.01; // Estimativa grosseira

   if (freeMargin < requiredMargin)
   {
      if (m_logger != NULL)
      {
         m_logger.Error(StringFormat("Margem insuficiente: %.2f < %.2f (estimado)", freeMargin, requiredMargin));
      }
      return false;
   }

   // 6. Verificar stops básicos
   double marketPrice = (request.type == ORDER_TYPE_BUY) ? tick.ask : tick.bid;

   if (request.type == ORDER_TYPE_BUY)
   {
      if (request.stopLoss >= marketPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Error(StringFormat("SL inválido para COMPRA: %.5f >= %.5f", request.stopLoss, marketPrice));
         }
         return false;
      }
   }
   else
   {
      if (request.stopLoss <= marketPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Error(StringFormat("SL inválido para VENDA: %.5f <= %.5f", request.stopLoss, marketPrice));
         }
         return false;
      }
   }

   if (m_logger != NULL)
   {
      m_logger.Debug("✅ Validação rápida: APROVADA");
   }

   return true;
}

// E uma função auxiliar para spread máximo:
double CTradeExecutor::GetMaxAllowedSpread(string symbol)
{
   // Spreads máximos específicos por ativo
   if (StringFind(symbol, "WIN") >= 0)
      return 20.0; // WIN$D: máximo 20 pontos
   if (StringFind(symbol, "WDO") >= 0)
      return 5.0; // WDO$D: máximo 5 pontos
   if (StringFind(symbol, "BIT") >= 0)
      return 100.0; // BIT$D: máximo 100 pontos

   // Para outros símbolos: 5x o spread normal
   long currentSpreadPoints = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double currentSpread = currentSpreadPoints * point;

   return MathMax(currentSpread * 5.0, point * 10.0); // Mínimo de 10 pontos
}

void CTradeExecutor::DebugInvalidStopsError(OrderRequest &request, MqlTick &tick)
{
   if (m_logger == NULL)
      return;

   m_logger.Error("🔍 === DEBUG DETALHADO - ERRO 10016 (INVALID STOPS) ===");

   // Informações básicas
   m_logger.Error(StringFormat("Símbolo: %s", request.symbol));
   m_logger.Error(StringFormat("Tipo de ordem: %s", EnumToString(request.type)));
   m_logger.Error(StringFormat("Volume: %.2f", request.volume));

   // Preços solicitados
   m_logger.Error(StringFormat("Preço entrada: %.5f", request.price));
   m_logger.Error(StringFormat("Stop Loss: %.5f", request.stopLoss));
   m_logger.Error(StringFormat("Take Profit: %.5f", request.takeProfit));

   // Preços de mercado
   m_logger.Error(StringFormat("BID atual: %.5f", tick.bid));
   m_logger.Error(StringFormat("ASK atual: %.5f", tick.ask));
   m_logger.Error(StringFormat("Spread: %.5f", tick.ask - tick.bid));

   // Informações do símbolo
   double point = SymbolInfoDouble(request.symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(request.symbol, SYMBOL_DIGITS);
   long stopsLevel = SymbolInfoInteger(request.symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel = SymbolInfoInteger(request.symbol, SYMBOL_TRADE_FREEZE_LEVEL);

   m_logger.Error(StringFormat("Point: %.10f", point));
   m_logger.Error(StringFormat("Digits: %d", digits));
   m_logger.Error(StringFormat("Stops Level: %d pontos", stopsLevel));
   m_logger.Error(StringFormat("Freeze Level: %d pontos", freezeLevel));

   // Análise detalhada para SELL
   if (request.type == ORDER_TYPE_SELL)
   {
      m_logger.Error("--- ANÁLISE PARA ORDEM DE VENDA ---");

      // Verificar relação SL vs Entrada
      if (request.stopLoss <= request.price)
      {
         m_logger.Error(StringFormat("❌ ERRO: SL (%.5f) <= Entrada (%.5f) para VENDA",
                                     request.stopLoss, request.price));
         m_logger.Error("   Para VENDA: SL deve estar ACIMA da entrada");
      }
      else
      {
         m_logger.Error(StringFormat("✅ SL correto: %.5f > %.5f (%.1f pontos acima)",
                                     request.stopLoss, request.price,
                                     (request.stopLoss - request.price) / point));
      }

      // Verificar relação TP vs Entrada
      if (request.takeProfit >= request.price)
      {
         m_logger.Error(StringFormat("❌ ERRO: TP (%.5f) >= Entrada (%.5f) para VENDA",
                                     request.takeProfit, request.price));
         m_logger.Error("   Para VENDA: TP deve estar ABAIXO da entrada");
      }
      else
      {
         m_logger.Error(StringFormat("✅ TP correto: %.5f < %.5f (%.1f pontos abaixo)",
                                     request.takeProfit, request.price,
                                     (request.price - request.takeProfit) / point));
      }

      // Verificar distância do SL em relação ao BID
      double slDistanceFromBid = request.stopLoss - tick.bid;
      m_logger.Error(StringFormat("Distância SL do BID: %.1f pontos", slDistanceFromBid / point));

      if (stopsLevel > 0 && slDistanceFromBid < stopsLevel * point)
      {
         m_logger.Error(StringFormat("❌ ERRO: SL muito próximo do BID (%.1f < %d pontos)",
                                     slDistanceFromBid / point, stopsLevel));
      }

      // Verificar distância do TP em relação ao BID
      double tpDistanceFromBid = tick.bid - request.takeProfit;
      m_logger.Error(StringFormat("Distância TP do BID: %.1f pontos", tpDistanceFromBid / point));

      if (stopsLevel > 0 && tpDistanceFromBid < stopsLevel * point)
      {
         m_logger.Error(StringFormat("❌ ERRO: TP muito próximo do BID (%.1f < %d pontos)",
                                     tpDistanceFromBid / point, stopsLevel));
      }
   }
   // Análise para BUY (similar)
   else if (request.type == ORDER_TYPE_BUY)
   {
      m_logger.Error("--- ANÁLISE PARA ORDEM DE COMPRA ---");

      if (request.stopLoss >= request.price)
      {
         m_logger.Error(StringFormat("❌ ERRO: SL (%.5f) >= Entrada (%.5f) para COMPRA",
                                     request.stopLoss, request.price));
      }
      else
      {
         m_logger.Error(StringFormat("✅ SL correto: %.5f < %.5f", request.stopLoss, request.price));
      }

      if (request.takeProfit <= request.price)
      {
         m_logger.Error(StringFormat("❌ ERRO: TP (%.5f) <= Entrada (%.5f) para COMPRA",
                                     request.takeProfit, request.price));
      }
      else
      {
         m_logger.Error(StringFormat("✅ TP correto: %.5f > %.5f", request.takeProfit, request.price));
      }
   }

   // Verificar normalização
   double normalizedPrice = NormalizeDouble(request.price, digits);
   double normalizedSL = NormalizeDouble(request.stopLoss, digits);
   double normalizedTP = NormalizeDouble(request.takeProfit, digits);

   m_logger.Error("--- VERIFICAÇÃO DE NORMALIZAÇÃO ---");
   m_logger.Error(StringFormat("Entrada: %.5f -> %.5f", request.price, normalizedPrice));
   m_logger.Error(StringFormat("SL: %.5f -> %.5f", request.stopLoss, normalizedSL));
   m_logger.Error(StringFormat("TP: %.5f -> %.5f", request.takeProfit, normalizedTP));

   // Verificar modo de trading
   long tradeMode = SymbolInfoInteger(request.symbol, SYMBOL_TRADE_MODE);
   m_logger.Error(StringFormat("Modo de trading: %d (%s)", tradeMode,
                               tradeMode == SYMBOL_TRADE_MODE_FULL ? "FULL" : tradeMode == SYMBOL_TRADE_MODE_LONGONLY ? "LONG_ONLY"
                                                                          : tradeMode == SYMBOL_TRADE_MODE_SHORTONLY  ? "SHORT_ONLY"
                                                                                                                      : "DISABLED"));

   // Verificar horário de trading
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);

   m_logger.Error(StringFormat("Horário atual: %02d:%02d:%02d",
                               timeStruct.hour, timeStruct.min, timeStruct.sec));

   // Sugestões de correção
   m_logger.Error("--- POSSÍVEIS SOLUÇÕES ---");

   if (request.type == ORDER_TYPE_SELL)
   {
      double suggestedSL = tick.bid + (stopsLevel > 0 ? (stopsLevel + 10) * point : 50 * point);
      double suggestedTP = tick.bid - (stopsLevel > 0 ? (stopsLevel + 10) * point : 100 * point);

      m_logger.Error(StringFormat("SL sugerido: %.5f (BID + %d pontos)", suggestedSL,
                                  stopsLevel > 0 ? stopsLevel + 10 : 50));
      m_logger.Error(StringFormat("TP sugerido: %.5f (BID - %d pontos)", suggestedTP,
                                  stopsLevel > 0 ? stopsLevel + 10 : 100));
   }

   m_logger.Error("=== FIM DO DEBUG ERRO 10016 ===");
}