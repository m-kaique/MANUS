#ifndef TRADEEXECUTOR_MQH_
#define TRADEEXECUTOR_MQH_

//+------------------------------------------------------------------+
//|                                           TradeExecutor.mqh ||
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

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
   ulong           m_eaMagicNumber; // Armazenar Magic Number do EA
   
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
   bool Initialize(CLogger* logger, ulong magicNumber); // Receber Magic Number
   
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
   ulong GetMagicNumber() const { return m_eaMagicNumber; } // CORRIGIDO: Retornar Magic Number armazenado
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
   m_eaMagicNumber = 0; // Inicializar Magic Number
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
bool CTradeExecutor::Initialize(CLogger* logger, ulong magicNumber) {
   // Verificar parâmetros
   if(logger == NULL) {
      Print("CTradeExecutor::Initialize - Logger não pode ser NULL");
      return false;
   }
   
   // Atribuir logger e magic number
   m_logger = logger;
   m_eaMagicNumber = magicNumber; // Armazenar Magic Number
   m_logger.Info("Inicializando TradeExecutor com Magic Number: " + (string)m_eaMagicNumber);
   
   // Criar objeto de trade
   m_trade = new CTrade();
   if(m_trade == NULL) {
      m_logger.Error("Falha ao criar objeto CTrade");
      return false;
   }
   
   // Configurar objeto de trade
   m_trade.SetExpertMagicNumber(m_eaMagicNumber); // Usar Magic Number recebido
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(Symbol());
   m_trade.SetDeviationInPoints(10); // Desvio máximo de preço em pontos
   
   m_logger.Info("TradeExecutor inicializado com sucesso");
   return true;
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
      m_lastErrorDesc = "Parâmetros de trailing stop inválidos";
      m_logger.Error(m_lastErrorDesc);
      return false;
   }
   
   // Selecionar posição
   if(!PositionSelectByTicket(ticket)) {
      m_lastError = GetLastError();
      m_lastErrorDesc = "Falha ao selecionar posição #" + IntegerToString(ticket);
      m_logger.Error(m_lastErrorDesc);
      return false;
   }
   
   // Verificar se a posição pertence a este EA
   ulong positionMagic = PositionGetInteger(POSITION_MAGIC);
   if(positionMagic != m_eaMagicNumber) {
      m_logger.Warning("Posição #" + IntegerToString(ticket) + " não pertence a este EA");
      return false;
   }
   
   // Obter dados da posição
   string symbol = PositionGetString(POSITION_SYMBOL);
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   // Calcular novo stop loss
   double newSL = CalculateFixedTrailingStop(ticket, points);
   
   // Verificar se o novo SL é válido
   if(newSL <= 0) {
      m_logger.Warning("Trailing stop calculado inválido para posição #" + IntegerToString(ticket));
      return false;
   }
   
   // Verificar se o novo SL é melhor que o atual
   bool shouldModify = false;
   
   if(posType == POSITION_TYPE_BUY) {
      // Para compras, o SL deve ser maior que o atual (mas ainda abaixo do preço)
      if(newSL > currentSL) {
         shouldModify = true;
      }
   } else if(posType == POSITION_TYPE_SELL) {
      // Para vendas, o SL deve ser menor que o atual (mas ainda acima do preço)
      if(newSL < currentSL || currentSL == 0) {
         shouldModify = true;
      }
   }
   
   // Modificar posição se necessário
   if(shouldModify) {
      m_logger.Info(StringFormat("Aplicando trailing stop para posição #%d: SL %.5f -> %.5f", 
                                ticket, currentSL, newSL));
      
      return ModifyPosition(ticket, newSL, currentTP);
   }
   
   return true; // Nenhuma modificação necessária
}

// Implementação de outros métodos...

#endif // TRADEEXECUTOR_MQH_
