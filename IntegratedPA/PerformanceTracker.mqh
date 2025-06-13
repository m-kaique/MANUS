//+------------------------------------------------------------------+
//|                                          PerformanceTracker.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include "Structures.mqh"
#include "Logger.mqh"

//+------------------------------------------------------------------+
//| Estrutura para armazenar estatísticas por qualidade de setup     |
//+------------------------------------------------------------------+
struct SetupQualityStats {
   int               totalSignals;        // Total de sinais gerados
   int               totalTrades;         // Total de trades executados
   int               winTrades;           // Trades vencedores
   int               lossTrades;          // Trades perdedores
   double            totalProfit;         // Lucro total
   double            totalLoss;           // Prejuízo total
   double            avgWin;              // Ganho médio
   double            avgLoss;             // Perda média
   double            winRate;             // Taxa de acerto
   double            profitFactor;        // Fator de lucro
   double            expectancy;          // Expectativa matemática
   double            maxDrawdown;         // Drawdown máximo
   double            avgRiskReward;       // R:R médio realizado
   datetime          lastUpdate;          // Última atualização
   
   // Construtor
   SetupQualityStats() {
      Reset();
   }
   
   // Resetar estatísticas
   void Reset() {
      totalSignals = 0;
      totalTrades = 0;
      winTrades = 0;
      lossTrades = 0;
      totalProfit = 0.0;
      totalLoss = 0.0;
      avgWin = 0.0;
      avgLoss = 0.0;
      winRate = 0.0;
      profitFactor = 0.0;
      expectancy = 0.0;
      maxDrawdown = 0.0;
      avgRiskReward = 0.0;
      lastUpdate = 0;
   }
   
   // Calcular estatísticas derivadas
   void Calculate() {
      if(totalTrades > 0) {
         winRate = (double)winTrades / totalTrades * 100.0;
         
         if(winTrades > 0) {
            avgWin = totalProfit / winTrades;
         }
         
         if(lossTrades > 0) {
            avgLoss = MathAbs(totalLoss / lossTrades);
         }
         
         if(totalLoss != 0) {
            profitFactor = MathAbs(totalProfit / totalLoss);
         }
         
         expectancy = (totalProfit + totalLoss) / totalTrades;
      }
      
      lastUpdate = TimeCurrent();
   }
};

//+------------------------------------------------------------------+
//| Estrutura para armazenar estatísticas por estratégia             |
//+------------------------------------------------------------------+
struct StrategyStats {
   string            strategyName;        // Nome da estratégia
   SetupQualityStats qualityStats[5];    // Stats por qualidade (A+, A, B, C, Invalid)
   int               totalSignals;        // Total de sinais da estratégia
   int               totalTrades;         // Total de trades da estratégia
   double            totalProfit;         // Lucro total da estratégia
   double            winRate;             // Taxa de acerto geral
   
   // Construtor
   StrategyStats() {
      strategyName = "";
      totalSignals = 0;
      totalTrades = 0;
      totalProfit = 0.0;
      winRate = 0.0;
   }
   
   // Agregar estatísticas
   void Aggregate() {
      totalSignals = 0;
      totalTrades = 0;
      totalProfit = 0.0;
      int totalWins = 0;
      
      for(int i = 0; i < 5; i++) {
         totalSignals += qualityStats[i].totalSignals;
         totalTrades += qualityStats[i].totalTrades;
         totalProfit += (qualityStats[i].totalProfit + qualityStats[i].totalLoss);
         totalWins += qualityStats[i].winTrades;
      }
      
      if(totalTrades > 0) {
         winRate = (double)totalWins / totalTrades * 100.0;
      }
   }
};

//+------------------------------------------------------------------+
//| Estrutura para armazenar histórico de trades                     |
//+------------------------------------------------------------------+
struct TradeHistory {
   ulong             ticket;              // Ticket da operação
   string            symbol;              // Símbolo
   string            strategy;            // Estratégia utilizada
   SETUP_QUALITY     quality;             // Qualidade do setup
   ENUM_POSITION_TYPE type;               // Tipo (compra/venda)
   datetime          openTime;            // Hora de abertura
   datetime          closeTime;           // Hora de fechamento
   double            openPrice;           // Preço de abertura
   double            closePrice;          // Preço de fechamento
   double            volume;              // Volume
   double            profit;              // Lucro/prejuízo
   double            commission;          // Comissão
   double            swap;                // Swap
   double            riskReward;          // R:R realizado
   int               confluenceFactors;   // Fatores de confluência
   string            comment;             // Comentário
};

//+------------------------------------------------------------------+
//| Classe para rastreamento de performance                          |
//+------------------------------------------------------------------+
class CPerformanceTracker {
private:
   CLogger*          m_logger;
   
   // Estatísticas globais
   SetupQualityStats m_globalStats[5];    // Stats globais por qualidade
   StrategyStats     m_strategyStats[];   // Stats por estratégia
   TradeHistory      m_tradeHistory[];    // Histórico de trades
   
   // Parâmetros de análise
   double            m_initialBalance;    // Saldo inicial
   double            m_peakBalance;       // Pico de saldo
   double            m_currentDrawdown;   // Drawdown atual
   datetime          m_startDate;         // Data de início
   
   // Métodos privados
   int GetQualityIndex(SETUP_QUALITY quality);
   int FindStrategyIndex(string strategy);
   void UpdateDrawdown();
   bool SaveTradeToHistory(ulong ticket);
   
public:
   // Construtor e destrutor
   CPerformanceTracker();
   ~CPerformanceTracker();
   
   // Inicialização
   bool Initialize(CLogger* logger, double initialBalance);
   
   // Registro de eventos
   void RegisterSignal(string symbol, string strategy, SETUP_QUALITY quality);
   void RegisterTradeOpen(ulong ticket, string symbol, string strategy, SETUP_QUALITY quality, int confluenceFactors);
   void RegisterTradeClose(ulong ticket);
   void UpdateOpenTrades();
   
   // Análise e relatórios
   void GeneratePerformanceReport();
   void GenerateQualityReport();
   void GenerateStrategyReport();
   void ExportToCSV(string filename);
   
   // Métodos de acesso
   double GetWinRate(SETUP_QUALITY quality = SETUP_INVALID);
   double GetProfitFactor(SETUP_QUALITY quality = SETUP_INVALID);
   double GetExpectancy(SETUP_QUALITY quality = SETUP_INVALID);
   double GetMaxDrawdown() { return m_currentDrawdown; }
   SetupQualityStats GetQualityStats(SETUP_QUALITY quality);
   
   // Recomendações automáticas
   string GetRecommendations();
   bool ShouldAdjustMinQuality(SETUP_QUALITY &recommendedQuality);
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CPerformanceTracker::CPerformanceTracker() {
   m_logger = NULL;
   m_initialBalance = 0;
   m_peakBalance = 0;
   m_currentDrawdown = 0;
   m_startDate = TimeCurrent();
   
   // Inicializar arrays
   ArrayResize(m_strategyStats, 0);
   ArrayResize(m_tradeHistory, 0);
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CPerformanceTracker::~CPerformanceTracker() {
   // Gerar relatório final
   if(m_logger != NULL) {
      GeneratePerformanceReport();
   }
}

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool CPerformanceTracker::Initialize(CLogger* logger, double initialBalance) {
   if(logger == NULL || initialBalance <= 0) {
      return false;
   }
   
   m_logger = logger;
   m_initialBalance = initialBalance;
   m_peakBalance = initialBalance;
   m_startDate = TimeCurrent();
   
   m_logger.Info("PerformanceTracker inicializado com saldo inicial: " + DoubleToString(initialBalance, 2));
   
   return true;
}

//+------------------------------------------------------------------+
//| Registrar sinal gerado                                           |
//+------------------------------------------------------------------+
void CPerformanceTracker::RegisterSignal(string symbol, string strategy, SETUP_QUALITY quality) {
   // Atualizar estatísticas globais
   int qualityIndex = GetQualityIndex(quality);
   if(qualityIndex >= 0) {
      m_globalStats[qualityIndex].totalSignals++;
   }
   
   // Atualizar estatísticas por estratégia
   int strategyIndex = FindStrategyIndex(strategy);
   if(strategyIndex < 0) {
      // Criar nova entrada para estratégia
      int newSize = ArraySize(m_strategyStats) + 1;
      ArrayResize(m_strategyStats, newSize);
      strategyIndex = newSize - 1;
      m_strategyStats[strategyIndex].strategyName = strategy;
   }
   
   if(qualityIndex >= 0) {
      m_strategyStats[strategyIndex].qualityStats[qualityIndex].totalSignals++;
   }
   
   if(m_logger != NULL) {
      m_logger.Debug(StringFormat("PerformanceTracker: Sinal registrado - %s, %s, Qualidade: %s", 
                                symbol, strategy, EnumToString(quality)));
   }
}

//+------------------------------------------------------------------+
//| Registrar abertura de trade                                      |
//+------------------------------------------------------------------+
void CPerformanceTracker::RegisterTradeOpen(ulong ticket, string symbol, string strategy, SETUP_QUALITY quality, int confluenceFactors) {
   // Adicionar ao histórico
   int size = ArraySize(m_tradeHistory);
   ArrayResize(m_tradeHistory, size + 1);
   
   // Preencher diretamente a nova posição do array
   m_tradeHistory[size].ticket = ticket;
   m_tradeHistory[size].symbol = symbol;
   m_tradeHistory[size].strategy = strategy;
   m_tradeHistory[size].quality = quality;
   m_tradeHistory[size].confluenceFactors = confluenceFactors;
   m_tradeHistory[size].openTime = TimeCurrent();
   
   // Obter informações da posição
   if(PositionSelectByTicket(ticket)) {
      m_tradeHistory[size].type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      m_tradeHistory[size].openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      m_tradeHistory[size].volume = PositionGetDouble(POSITION_VOLUME);
      m_tradeHistory[size].comment = PositionGetString(POSITION_COMMENT);
   }
   
   // Atualizar estatísticas
   int qualityIndex = GetQualityIndex(quality);
   if(qualityIndex >= 0) {
      m_globalStats[qualityIndex].totalTrades++;
   }
   
   int strategyIndex = FindStrategyIndex(strategy);
   if(strategyIndex >= 0 && qualityIndex >= 0) {
      m_strategyStats[strategyIndex].qualityStats[qualityIndex].totalTrades++;
   }
   
   if(m_logger != NULL) {
      m_logger.Info(StringFormat("PerformanceTracker: Trade aberto - Ticket: %d, %s, %s, Qualidade: %s, Fatores: %d", 
                               ticket, symbol, strategy, EnumToString(quality), confluenceFactors));
   }
}

//+------------------------------------------------------------------+
//| Registrar fechamento de trade                                    |
//+------------------------------------------------------------------+
void CPerformanceTracker::RegisterTradeClose(ulong ticket) {
   // Encontrar trade no histórico
   int index = -1;
   for(int i = 0; i < ArraySize(m_tradeHistory); i++) {
      if(m_tradeHistory[i].ticket == ticket && m_tradeHistory[i].closeTime == 0) {
         index = i;
         break;
      }
   }
   
   if(index < 0) {
      if(m_logger != NULL) {
         m_logger.Warning("PerformanceTracker: Trade não encontrado no histórico - Ticket: " + IntegerToString(ticket));
      }
      return;
   }
   
   // Obter informações do histórico de deals
   if(!HistorySelectByPosition(ticket)) {
      if(m_logger != NULL) {
         m_logger.Error("PerformanceTracker: Falha ao selecionar histórico da posição - Ticket: " + IntegerToString(ticket));
      }
      return;
   }
   
   // Calcular resultado
   double totalProfit = 0;
   double totalCommission = 0;
   double totalSwap = 0;
   
   int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; i++) {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0) {
         totalProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         totalCommission += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         totalSwap += HistoryDealGetDouble(dealTicket, DEAL_SWAP);
         
         // Pegar preço de fechamento do último deal
         if(i == deals - 1) {
            m_tradeHistory[index].closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            m_tradeHistory[index].closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         }
      }
   }

   m_tradeHistory[index].profit = totalProfit;
   m_tradeHistory[index].commission = totalCommission;
   m_tradeHistory[index].swap = totalSwap;
   
   // Calcular R:R realizado
   double risk = 0;
   double reward = 0;
   
   if(m_tradeHistory[index].type == POSITION_TYPE_BUY) {
      risk = m_tradeHistory[index].openPrice - PositionGetDouble(POSITION_SL);
      reward = m_tradeHistory[index].closePrice - m_tradeHistory[index].openPrice;
   } else {
      risk = PositionGetDouble(POSITION_SL) - m_tradeHistory[index].openPrice;
      reward = m_tradeHistory[index].openPrice - m_tradeHistory[index].closePrice;
   }

   if(risk > 0) {
      m_tradeHistory[index].riskReward = reward / risk;
   }

   // Atualizar estatísticas
   int qualityIndex = GetQualityIndex(m_tradeHistory[index].quality);
   if(qualityIndex >= 0) {
      if(totalProfit > 0) {
         m_globalStats[qualityIndex].winTrades++;
         m_globalStats[qualityIndex].totalProfit += totalProfit;
      } else {
         m_globalStats[qualityIndex].lossTrades++;
         m_globalStats[qualityIndex].totalLoss += totalProfit;
      }
      
      m_globalStats[qualityIndex].avgRiskReward = 
         (m_globalStats[qualityIndex].avgRiskReward * (m_globalStats[qualityIndex].totalTrades - 1) + m_tradeHistory[index].riskReward) /
         m_globalStats[qualityIndex].totalTrades;
      
      m_globalStats[qualityIndex].Calculate();
   }
   
   // Atualizar estatísticas por estratégia
   int strategyIndex = FindStrategyIndex(m_tradeHistory[index].strategy);
   if(strategyIndex >= 0 && qualityIndex >= 0) {
      if(totalProfit > 0) {
         m_strategyStats[strategyIndex].qualityStats[qualityIndex].winTrades++;
         m_strategyStats[strategyIndex].qualityStats[qualityIndex].totalProfit += totalProfit;
      } else {
         m_strategyStats[strategyIndex].qualityStats[qualityIndex].lossTrades++;
         m_strategyStats[strategyIndex].qualityStats[qualityIndex].totalLoss += totalProfit;
      }
      
      m_strategyStats[strategyIndex].qualityStats[qualityIndex].Calculate();
      m_strategyStats[strategyIndex].Aggregate();
   }
   
   // Atualizar drawdown
   UpdateDrawdown();
   
   if(m_logger != NULL) {
      m_logger.Info(StringFormat("PerformanceTracker: Trade fechado - Ticket: %d, Lucro: %.2f, R:R: %.2f",
                               ticket, totalProfit, m_tradeHistory[index].riskReward));
   }
}

//+------------------------------------------------------------------+
//| Atualizar trades abertos                                         |
//+------------------------------------------------------------------+
void CPerformanceTracker::UpdateOpenTrades() {
   // Atualizar informações de trades ainda abertos
   for(int i = 0; i < ArraySize(m_tradeHistory); i++) {
      if(m_tradeHistory[i].closeTime == 0) {
         if(PositionSelectByTicket(m_tradeHistory[i].ticket)) {
            // Trade ainda aberto, atualizar lucro flutuante
            double currentProfit = PositionGetDouble(POSITION_PROFIT);
            
            // Atualizar drawdown se necessário
            UpdateDrawdown();
         } else {
            // Trade foi fechado, registrar
            RegisterTradeClose(m_tradeHistory[i].ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gerar relatório de performance                                   |
//+------------------------------------------------------------------+
void CPerformanceTracker::GeneratePerformanceReport() {
   if(m_logger == NULL) return;
   
   m_logger.Info("=== RELATÓRIO DE PERFORMANCE ===");
   
   // Informações gerais
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double totalReturn = (currentBalance - m_initialBalance) / m_initialBalance * 100;
   int totalDays = (int)((TimeCurrent() - m_startDate) / 86400);
   
   m_logger.Info(StringFormat("Período: %s a %s (%d dias)", 
                            TimeToString(m_startDate, TIME_DATE),
                            TimeToString(TimeCurrent(), TIME_DATE),
                            totalDays));
   
   m_logger.Info(StringFormat("Saldo Inicial: %.2f | Saldo Atual: %.2f | Retorno: %.2f%%", 
                            m_initialBalance, currentBalance, totalReturn));
   
   m_logger.Info(StringFormat("Drawdown Máximo: %.2f%%", m_currentDrawdown));
   
   // Estatísticas por qualidade
   m_logger.Info("--- Estatísticas por Qualidade de Setup ---");
   
   string qualities[] = {"A+", "A", "B", "C"};
   for(int i = 0; i < 4; i++) {
      if(m_globalStats[i].totalTrades > 0) {
         m_logger.Info(StringFormat("Setup %s: Sinais: %d, Trades: %d, Win Rate: %.1f%%, PF: %.2f, Exp: %.2f, R:R Médio: %.2f",
                                  qualities[i],
                                  m_globalStats[i].totalSignals,
                                  m_globalStats[i].totalTrades,
                                  m_globalStats[i].winRate,
                                  m_globalStats[i].profitFactor,
                                  m_globalStats[i].expectancy,
                                  m_globalStats[i].avgRiskReward));
      }
   }
   
   // Recomendações
   m_logger.Info("--- Recomendações ---");
   m_logger.Info(GetRecommendations());
}

//+------------------------------------------------------------------+
//| Gerar relatório por qualidade                                    |
//+------------------------------------------------------------------+
void CPerformanceTracker::GenerateQualityReport() {
   if(m_logger == NULL) return;
   
   m_logger.Info("=== RELATÓRIO DETALHADO POR QUALIDADE ===");
   
   string qualities[] = {"A+", "A", "B", "C"};
   
   for(int i = 0; i < 4; i++) {
      if(m_globalStats[i].totalSignals > 0) {
         m_logger.Info(StringFormat("--- Setup %s ---", qualities[i]));
         m_logger.Info(StringFormat("Sinais Gerados: %d", m_globalStats[i].totalSignals));
         m_logger.Info(StringFormat("Trades Executados: %d (%.1f%% dos sinais)", 
                                  m_globalStats[i].totalTrades,
                                  (double)m_globalStats[i].totalTrades / m_globalStats[i].totalSignals * 100));
         
         if(m_globalStats[i].totalTrades > 0) {
            m_logger.Info(StringFormat("Vencedores: %d | Perdedores: %d", 
                                     m_globalStats[i].winTrades,
                                     m_globalStats[i].lossTrades));
            m_logger.Info(StringFormat("Taxa de Acerto: %.1f%%", m_globalStats[i].winRate));
            m_logger.Info(StringFormat("Lucro Total: %.2f | Prejuízo Total: %.2f", 
                                     m_globalStats[i].totalProfit,
                                     m_globalStats[i].totalLoss));
            m_logger.Info(StringFormat("Ganho Médio: %.2f | Perda Média: %.2f", 
                                     m_globalStats[i].avgWin,
                                     m_globalStats[i].avgLoss));
            m_logger.Info(StringFormat("Fator de Lucro: %.2f", m_globalStats[i].profitFactor));
            m_logger.Info(StringFormat("Expectativa: %.2f", m_globalStats[i].expectancy));
            m_logger.Info(StringFormat("R:R Médio Realizado: %.2f", m_globalStats[i].avgRiskReward));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gerar relatório por estratégia                                   |
//+------------------------------------------------------------------+
void CPerformanceTracker::GenerateStrategyReport() {
   if(m_logger == NULL) return;
   
   m_logger.Info("=== RELATÓRIO POR ESTRATÉGIA ===");
   
   for(int i = 0; i < ArraySize(m_strategyStats); i++) {
      m_logger.Info(StringFormat("--- %s ---", m_strategyStats[i].strategyName));
      m_logger.Info(StringFormat("Total de Sinais: %d | Total de Trades: %d", 
                               m_strategyStats[i].totalSignals,
                               m_strategyStats[i].totalTrades));
      
      if(m_strategyStats[i].totalTrades > 0) {
         m_logger.Info(StringFormat("Taxa de Acerto: %.1f%% | Lucro Total: %.2f", 
                                  m_strategyStats[i].winRate,
                                  m_strategyStats[i].totalProfit));
         
         // Detalhar por qualidade
         string qualities[] = {"A+", "A", "B", "C"};
         for(int j = 0; j < 4; j++) {
            if(m_strategyStats[i].qualityStats[j].totalTrades > 0) {
               m_logger.Info(StringFormat("  %s: Trades: %d, Win Rate: %.1f%%, PF: %.2f",
                                        qualities[j],
                                        m_strategyStats[i].qualityStats[j].totalTrades,
                                        m_strategyStats[i].qualityStats[j].winRate,
                                        m_strategyStats[i].qualityStats[j].profitFactor));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Exportar dados para CSV                                          |
//+------------------------------------------------------------------+
void CPerformanceTracker::ExportToCSV(string filename) {
   int handle = FileOpen(filename, FILE_WRITE | FILE_CSV);
   if(handle == INVALID_HANDLE) {
      if(m_logger != NULL) {
         m_logger.Error("PerformanceTracker: Falha ao criar arquivo CSV");
      }
      return;
   }
   
   // Cabeçalho
   FileWrite(handle, "Ticket,Symbol,Strategy,Quality,Type,OpenTime,CloseTime,OpenPrice,ClosePrice,Volume,Profit,Commission,Swap,RiskReward,ConfluenceFactors");
   
   // Dados
   for(int i = 0; i < ArraySize(m_tradeHistory); i++) {
      if(m_tradeHistory[i].closeTime > 0) { // Apenas trades fechados
         FileWrite(handle,
                  m_tradeHistory[i].ticket,
                  m_tradeHistory[i].symbol,
                  m_tradeHistory[i].strategy,
                  EnumToString(m_tradeHistory[i].quality),
                  (m_tradeHistory[i].type == POSITION_TYPE_BUY) ? "BUY" : "SELL",
                  TimeToString(m_tradeHistory[i].openTime),
                  TimeToString(m_tradeHistory[i].closeTime),
                  m_tradeHistory[i].openPrice,
                  m_tradeHistory[i].closePrice,
                  m_tradeHistory[i].volume,
                  m_tradeHistory[i].profit,
                  m_tradeHistory[i].commission,
                  m_tradeHistory[i].swap,
                  m_tradeHistory[i].riskReward,
                  m_tradeHistory[i].confluenceFactors);
      }
   }
   
   FileClose(handle);
   
   if(m_logger != NULL) {
      m_logger.Info("PerformanceTracker: Dados exportados para " + filename);
   }
}

//+------------------------------------------------------------------+
//| Obter índice da qualidade                                        |
//+------------------------------------------------------------------+
int CPerformanceTracker::GetQualityIndex(SETUP_QUALITY quality) {
   switch(quality) {
      case SETUP_A_PLUS: return 0;
      case SETUP_A:      return 1;
      case SETUP_B:      return 2;
      case SETUP_C:      return 3;
      case SETUP_INVALID: return 4;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Encontrar índice da estratégia                                   |
//+------------------------------------------------------------------+
int CPerformanceTracker::FindStrategyIndex(string strategy) {
   for(int i = 0; i < ArraySize(m_strategyStats); i++) {
      if(m_strategyStats[i].strategyName == strategy) {
         return i;
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Atualizar drawdown                                               |
//+------------------------------------------------------------------+
void CPerformanceTracker::UpdateDrawdown() {
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Atualizar pico se necessário
   if(currentBalance > m_peakBalance) {
      m_peakBalance = currentBalance;
   }
   
   // Calcular drawdown
   if(m_peakBalance > 0) {
      double drawdown = (m_peakBalance - currentBalance) / m_peakBalance * 100;
      if(drawdown > m_currentDrawdown) {
         m_currentDrawdown = drawdown;
      }
   }
}

//+------------------------------------------------------------------+
//| Obter taxa de acerto                                             |
//+------------------------------------------------------------------+
double CPerformanceTracker::GetWinRate(SETUP_QUALITY quality = SETUP_INVALID) {
   if(quality == SETUP_INVALID) {
      // Retornar taxa geral
      int totalWins = 0;
      int totalTrades = 0;
      
      for(int i = 0; i < 4; i++) {
         totalWins += m_globalStats[i].winTrades;
         totalTrades += m_globalStats[i].totalTrades;
      }
      
      if(totalTrades > 0) {
         return (double)totalWins / totalTrades * 100;
      }
   } else {
      int index = GetQualityIndex(quality);
      if(index >= 0) {
         return m_globalStats[index].winRate;
      }
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Obter fator de lucro                                             |
//+------------------------------------------------------------------+
double CPerformanceTracker::GetProfitFactor(SETUP_QUALITY quality = SETUP_INVALID) {
   if(quality == SETUP_INVALID) {
      // Retornar fator geral
      double totalProfit = 0;
      double totalLoss = 0;
      
      for(int i = 0; i < 4; i++) {
         totalProfit += m_globalStats[i].totalProfit;
         totalLoss += m_globalStats[i].totalLoss;
      }
      
      if(totalLoss != 0) {
         return MathAbs(totalProfit / totalLoss);
      }
   } else {
      int index = GetQualityIndex(quality);
      if(index >= 0) {
         return m_globalStats[index].profitFactor;
      }
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Obter expectativa matemática                                     |
//+------------------------------------------------------------------+
double CPerformanceTracker::GetExpectancy(SETUP_QUALITY quality = SETUP_INVALID) {
   if(quality == SETUP_INVALID) {
      // Retornar expectativa geral
      double totalExpectancy = 0;
      int totalTrades = 0;
      
      for(int i = 0; i < 4; i++) {
         if(m_globalStats[i].totalTrades > 0) {
            totalExpectancy += m_globalStats[i].expectancy * m_globalStats[i].totalTrades;
            totalTrades += m_globalStats[i].totalTrades;
         }
      }
      
      if(totalTrades > 0) {
         return totalExpectancy / totalTrades;
      }
   } else {
      int index = GetQualityIndex(quality);
      if(index >= 0) {
         return m_globalStats[index].expectancy;
      }
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Obter estatísticas de qualidade                                  |
//+------------------------------------------------------------------+
SetupQualityStats CPerformanceTracker::GetQualityStats(SETUP_QUALITY quality) {
   SetupQualityStats emptyStats;
   
   int index = GetQualityIndex(quality);
   if(index >= 0 && index < 5) {
      return m_globalStats[index];
   }
   
   return emptyStats;
}

//+------------------------------------------------------------------+
//| Obter recomendações automáticas                                  |
//+------------------------------------------------------------------+
string CPerformanceTracker::GetRecommendations() {
   string recommendations = "";
   
   // Analisar performance por qualidade
   double bestWinRate = 0;
   SETUP_QUALITY bestQuality = SETUP_B;
   
   for(int i = 0; i < 4; i++) {
      if(m_globalStats[i].totalTrades >= 10 && m_globalStats[i].winRate > bestWinRate) {
         bestWinRate = m_globalStats[i].winRate;
         bestQuality = (SETUP_QUALITY)i;
      }
   }
   
   // Recomendação 1: Qualidade mínima
   if(bestWinRate > 60) {
      recommendations += "1. Qualidade mínima recomendada: " + EnumToString(bestQuality) + 
                        " (Win Rate: " + DoubleToString(bestWinRate, 1) + "%)\n";
   }
   
   // Recomendação 2: Estratégias
   double bestStrategyProfit = -999999;
   string bestStrategy = "";
   
   for(int i = 0; i < ArraySize(m_strategyStats); i++) {
      if(m_strategyStats[i].totalTrades >= 5 && m_strategyStats[i].totalProfit > bestStrategyProfit) {
         bestStrategyProfit = m_strategyStats[i].totalProfit;
         bestStrategy = m_strategyStats[i].strategyName;
      }
   }
   
   if(bestStrategy != "") {
      recommendations += "2. Melhor estratégia: " + bestStrategy + 
                        " (Lucro: " + DoubleToString(bestStrategyProfit, 2) + ")\n";
   }
   
   // Recomendação 3: Gestão de risco
   if(m_currentDrawdown > 10) {
      recommendations += "3. ATENÇÃO: Drawdown elevado (" + DoubleToString(m_currentDrawdown, 1) + 
                        "%). Considere reduzir o risco por operação.\n";
   }
   
   // Recomendação 4: Setups de baixa qualidade
   if(m_globalStats[3].totalTrades > 0 && m_globalStats[3].winRate < 40) {
      recommendations += "4. Setups C com baixa performance. Considere desabilitar ou revisar critérios.\n";
   }
   
   // Recomendação 5: R:R realizado
   double avgRR = 0;
   int count = 0;
   
   for(int i = 0; i < 4; i++) {
      if(m_globalStats[i].totalTrades > 0) {
         avgRR += m_globalStats[i].avgRiskReward * m_globalStats[i].totalTrades;
         count += m_globalStats[i].totalTrades;
      }
   }
   
   if(count > 0) {
      avgRR /= count;
      if(avgRR < 1.5) {
         recommendations += "5. R:R médio baixo (" + DoubleToString(avgRR, 2) + 
                           "). Revise níveis de entrada/saída.\n";
      }
   }
   
   return recommendations;
}

//+------------------------------------------------------------------+
//| Verificar se deve ajustar qualidade mínima                       |
//+------------------------------------------------------------------+
bool CPerformanceTracker::ShouldAdjustMinQuality(SETUP_QUALITY &recommendedQuality) {
   // Precisamos de pelo menos 50 trades para fazer recomendações
   int totalTrades = 0;
   for(int i = 0; i < 4; i++) {
      totalTrades += m_globalStats[i].totalTrades;
   }
   
   if(totalTrades < 50) {
      return false;
   }
   
   // Analisar expectativa por qualidade
   double expectations[4];
   for(int i = 0; i < 4; i++) {
      expectations[i] = m_globalStats[i].expectancy;
   }
   
   // Se setups A+ têm expectativa positiva e pelo menos 10 trades
   if(m_globalStats[0].totalTrades >= 10 && expectations[0] > 0) {
      // Se setups A têm expectativa negativa
      if(expectations[1] < 0) {
         recommendedQuality = SETUP_A_PLUS;
         return true;
      }
   }
   
   // Se setups A têm boa performance
   if(m_globalStats[1].totalTrades >= 10 && expectations[1] > 0) {
      // Se setups B têm expectativa negativa
      if(expectations[2] < 0) {
         recommendedQuality = SETUP_A;
         return true;
      }
   }
   
   // Se setups B têm boa performance
   if(m_globalStats[2].totalTrades >= 10 && expectations[2] > 0) {
      // Se setups C têm expectativa muito negativa
      if(expectations[3] < -10) {
         recommendedQuality = SETUP_B;
         return true;
      }
   }
   
   return false;
}