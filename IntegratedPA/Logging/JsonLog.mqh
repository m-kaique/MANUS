//+------------------------------------------------------------------+
//|                                              JsonLog.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#include "Logger.mqh"
//+------------------------------------------------------------------+
//| Estruturas para logging JSON                                      |
//+------------------------------------------------------------------+

// Estrutura para dados da ordem
struct OrderLogData
{
   ulong ticket;          // Ticket da ordem
   datetime openTime;     // Hora de abertura
   string symbol;         // Símbolo
   string strategy;       // Estratégia usada
   string setupQuality;   // Qualidade do setup
   string marketPhase;    // Fase do mercado
   string direction;      // BUY/SELL
   double volume;         // Volume
   double entryPrice;     // Preço de entrada
   double stopLoss;       // Stop loss
   double takeProfit;     // Take profit
   double riskPercent;    // Risco em %
   double riskReward;     // Relação R:R
   int confluenceFactors; // Fatores de confluência
   string comment;        // Comentário

   // Dados de acompanhamento
   double currentPrice; // Preço atual
   double profit;       // Lucro/prejuízo atual
   double maxProfit;    // Lucro máximo
   double maxDrawdown;  // Drawdown máximo
   string status;       // OPEN/CLOSED/PARTIAL

   // Trailing e modificações
   double trailingDistance; // Distância do trailing
   string trailingType;     // Tipo de trailing
   double breakevenLevel;   // Nível de breakeven
   bool breakevenActive;    // Breakeven ativo

   // Parciais
   int partialsExecuted;   // Quantas parciais executadas
   double volumeRemaining; // Volume restante
   double partialProfit;   // Lucro das parciais

   // Fechamento
   datetime closeTime; // Hora de fechamento
   double closePrice;  // Preço de fechamento
   double finalProfit; // Lucro final
   string closeReason; // Motivo do fechamento
};

// Estrutura para dados da sessão
struct SessionLogData
{
   string sessionId;      // ID único da sessão
   datetime startTime;    // Início da sessão
   datetime endTime;      // Fim da sessão
   string eaVersion;      // Versão do EA
   double initialBalance; // Saldo inicial
   double finalBalance;   // Saldo final
   int totalOrders;       // Total de ordens
   int winningOrders;     // Ordens vencedoras
   int losingOrders;      // Ordens perdedoras
   double totalProfit;    // Lucro total
   double totalLoss;      // Perda total
   double maxDrawdown;    // Drawdown máximo
   double profitFactor;   // Fator de lucro
   double winRate;        // Taxa de acerto

   OrderLogData orders[]; // Array de ordens
};

//+------------------------------------------------------------------+
//| Classe para gerenciamento de logs JSON                           |
//+------------------------------------------------------------------+
class CJSONLogger
{
private:
   SessionLogData m_session;
   string m_logPath;
   CLogger *m_logger;

   // Gerar ID único para sessão
   string GenerateSessionId()
   {
      return StringFormat("%s_%d", TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), MathRand());
   }

   // Converter OrderLogData para string JSON
   string OrderToJSON(const OrderLogData &order)
   {
      string json = "{";
      json += "\"ticket\":" + IntegerToString(order.ticket) + ",";
      json += "\"openTime\":\"" + TimeToString(order.openTime, TIME_DATE | TIME_SECONDS) + "\",";
      json += "\"symbol\":\"" + order.symbol + "\",";
      json += "\"strategy\":\"" + order.strategy + "\",";
      json += "\"setupQuality\":\"" + order.setupQuality + "\",";
      json += "\"marketPhase\":\"" + order.marketPhase + "\",";
      json += "\"direction\":\"" + order.direction + "\",";
      json += "\"volume\":" + DoubleToString(order.volume, 2) + ",";
      json += "\"entryPrice\":" + DoubleToString(order.entryPrice, 5) + ",";
      json += "\"stopLoss\":" + DoubleToString(order.stopLoss, 5) + ",";
      json += "\"takeProfit\":" + DoubleToString(order.takeProfit, 5) + ",";
      json += "\"riskPercent\":" + DoubleToString(order.riskPercent, 2) + ",";
      json += "\"riskReward\":" + DoubleToString(order.riskReward, 2) + ",";
      json += "\"confluenceFactors\":" + IntegerToString(order.confluenceFactors) + ",";
      json += "\"comment\":\"" + order.comment + "\",";
      json += "\"currentPrice\":" + DoubleToString(order.currentPrice, 5) + ",";
      json += "\"profit\":" + DoubleToString(order.profit, 2) + ",";
      json += "\"maxProfit\":" + DoubleToString(order.maxProfit, 2) + ",";
      json += "\"maxDrawdown\":" + DoubleToString(order.maxDrawdown, 2) + ",";
      json += "\"status\":\"" + order.status + "\",";
      json += "\"trailingDistance\":" + DoubleToString(order.trailingDistance, 1) + ",";
      json += "\"trailingType\":\"" + order.trailingType + "\",";
      json += "\"breakevenLevel\":" + DoubleToString(order.breakevenLevel, 5) + ",";
      json += "\"breakevenActive\":" + (order.breakevenActive ? "true" : "false") + ",";
      json += "\"partialsExecuted\":" + IntegerToString(order.partialsExecuted) + ",";
      json += "\"volumeRemaining\":" + DoubleToString(order.volumeRemaining, 2) + ",";
      json += "\"partialProfit\":" + DoubleToString(order.partialProfit, 2) + ",";
      json += "\"closeTime\":\"" + TimeToString(order.closeTime, TIME_DATE | TIME_SECONDS) + "\",";
      json += "\"closePrice\":" + DoubleToString(order.closePrice, 5) + ",";
      json += "\"finalProfit\":" + DoubleToString(order.finalProfit, 2) + ",";
      json += "\"closeReason\":\"" + order.closeReason + "\"";
      json += "}";
      return json;
   }

public:
   // Construtor
   CJSONLogger(CLogger *logger)
   {
      m_logger = logger;
      m_logPath = "Logs/Sessions/";
   }

   // Iniciar nova sessão
   bool StartSession(string eaVersion)
   {
      // Limpar dados anteriores
      ArrayResize(m_session.orders, 0);

      // Configurar nova sessão
      m_session.sessionId = GenerateSessionId();
      m_session.startTime = TimeCurrent();
      m_session.eaVersion = eaVersion;
      m_session.initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_session.totalOrders = 0;
      m_session.winningOrders = 0;
      m_session.losingOrders = 0;
      m_session.totalProfit = 0;
      m_session.totalLoss = 0;
      m_session.maxDrawdown = 0;

      // Criar arquivo JSON inicial
      string filename = "cavalo.json";
      // string filename = "cavalo.json";
      int handle = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_ANSI);

      if (handle == INVALID_HANDLE)
      {
         if (m_logger != NULL)
         {
            m_logger.Error("Falha ao criar arquivo de sessão JSON: " + filename);
         }
         return false;
      }

      // Escrever cabeçalho inicial
      FileWrite(handle, GetSessionJSON());
      FileClose(handle);

      if (m_logger != NULL)
      {
         m_logger.Info("Nova sessão JSON iniciada: " + m_session.sessionId);
      }

      return true;
   }

   // Adicionar nova ordem
   // Adicionar nova ordem
   void AddOrder(ulong ticket, const Signal &signal, const OrderRequest &request)
   {
      int index = ArraySize(m_session.orders);
      ArrayResize(m_session.orders, index + 1);

      // CORREÇÃO: Atribuir diretamente ao array, não a uma cópia
      m_session.orders[index].ticket = ticket;
      m_session.orders[index].openTime = TimeCurrent();
      m_session.orders[index].symbol = request.symbol;
      m_session.orders[index].strategy = signal.strategy;
      m_session.orders[index].setupQuality = EnumToString(signal.quality);
      m_session.orders[index].marketPhase = EnumToString(signal.marketPhase);
      m_session.orders[index].direction = (request.type == ORDER_TYPE_BUY ? "BUY" : "SELL");
      m_session.orders[index].volume = request.volume;
      m_session.orders[index].entryPrice = request.price;
      m_session.orders[index].stopLoss = request.stopLoss;
      m_session.orders[index].takeProfit = request.takeProfit;
      m_session.orders[index].riskPercent = 1.0; // Usar valor padrão por enquanto
      m_session.orders[index].riskReward = signal.riskRewardRatio;
      m_session.orders[index].confluenceFactors = 0; // Usar valor padrão por enquanto
      m_session.orders[index].comment = request.comment;
      m_session.orders[index].status = "OPEN";
      m_session.orders[index].breakevenActive = false;
      m_session.orders[index].partialsExecuted = 0;
      m_session.orders[index].volumeRemaining = request.volume;
      m_session.orders[index].partialProfit = 0;
      m_session.orders[index].closeTime = 0;
      m_session.orders[index].closePrice = 0;
      m_session.orders[index].finalProfit = 0;
      m_session.orders[index].closeReason = "";
      m_session.orders[index].currentPrice = request.price;
      m_session.orders[index].profit = 0;
      m_session.orders[index].maxProfit = 0;
      m_session.orders[index].maxDrawdown = 0;
      m_session.orders[index].trailingDistance = 0;
      m_session.orders[index].trailingType = "";
      m_session.orders[index].breakevenLevel = 0;

      m_session.totalOrders++;

      UpdateSessionFile();
   }

   // Atualizar ordem existente
   void UpdateOrder(ulong ticket)
   {
      for (int i = 0; i < ArraySize(m_session.orders); i++)
      {
         if (m_session.orders[i].ticket == ticket)
         {
            if (PositionSelectByTicket(ticket))
            {
               m_session.orders[i].currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
               m_session.orders[i].profit = PositionGetDouble(POSITION_PROFIT);
               m_session.orders[i].volumeRemaining = PositionGetDouble(POSITION_VOLUME);

               // Atualizar máximos
               if (m_session.orders[i].profit > m_session.orders[i].maxProfit)
               {
                  m_session.orders[i].maxProfit = m_session.orders[i].profit;
               }
               if (m_session.orders[i].profit < -m_session.orders[i].maxDrawdown)
               {
                  m_session.orders[i].maxDrawdown = -m_session.orders[i].profit;
               }
            }
            break;
         }
      }

      UpdateSessionFile();
   }

   // Registrar modificação de trailing stop
   void UpdateTrailing(ulong ticket, double distance, string type)
   {
      for (int i = 0; i < ArraySize(m_session.orders); i++)
      {
         if (m_session.orders[i].ticket == ticket)
         {
            m_session.orders[i].trailingDistance = distance;
            m_session.orders[i].trailingType = type;
            break;
         }
      }
      UpdateSessionFile();
   }

   // Registrar ativação de breakeven
   void UpdateBreakeven(ulong ticket, double level)
   {
      for (int i = 0; i < ArraySize(m_session.orders); i++)
      {
         if (m_session.orders[i].ticket == ticket)
         {
            m_session.orders[i].breakevenLevel = level;
            m_session.orders[i].breakevenActive = true;
            break;
         }
      }
      UpdateSessionFile();
   }

   // Registrar execução de parcial
   void UpdatePartial(ulong ticket, double volumeClosed, double profit)
   {
      for (int i = 0; i < ArraySize(m_session.orders); i++)
      {
         if (m_session.orders[i].ticket == ticket)
         {
            m_session.orders[i].partialsExecuted++;
            m_session.orders[i].volumeRemaining -= volumeClosed;
            m_session.orders[i].partialProfit += profit;
            break;
         }
      }
      UpdateSessionFile();
   }

   // Registrar fechamento de ordem
   void CloseOrder(ulong ticket, double closePrice, double finalProfit, string reason)
   {
      for (int i = 0; i < ArraySize(m_session.orders); i++)
      {
         if (m_session.orders[i].ticket == ticket)
         {
            m_session.orders[i].closeTime = TimeCurrent();
            m_session.orders[i].closePrice = closePrice;
            m_session.orders[i].finalProfit = finalProfit + m_session.orders[i].partialProfit;
            m_session.orders[i].closeReason = reason;
            m_session.orders[i].status = "CLOSED";

            // Atualizar estatísticas da sessão
            if (m_session.orders[i].finalProfit > 0)
            {
               m_session.winningOrders++;
               m_session.totalProfit += m_session.orders[i].finalProfit;
            }
            else
            {
               m_session.losingOrders++;
               m_session.totalLoss += MathAbs(m_session.orders[i].finalProfit);
            }

            break;
         }
      }

      UpdateSessionFile();
   }

   // Finalizar sessão
   void EndSession()
   {
      m_session.endTime = TimeCurrent();
      m_session.finalBalance = AccountInfoDouble(ACCOUNT_BALANCE);

      // Calcular métricas finais
      if (m_session.totalOrders > 0)
      {
         m_session.winRate = (double)m_session.winningOrders / m_session.totalOrders * 100;
      }

      if (m_session.totalLoss > 0)
      {
         m_session.profitFactor = m_session.totalProfit / m_session.totalLoss;
      }

      // Calcular drawdown máximo da sessão
      double minBalance = m_session.initialBalance;
      double runningBalance = m_session.initialBalance;

      for (int i = 0; i < ArraySize(m_session.orders); i++)
      {
         if (m_session.orders[i].status == "CLOSED")
         {
            runningBalance += m_session.orders[i].finalProfit;
            if (runningBalance < minBalance)
            {
               minBalance = runningBalance;
            }
         }
      }

      m_session.maxDrawdown = m_session.initialBalance - minBalance;

      UpdateSessionFile();

      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("Sessão finalizada: %d trades, Win Rate: %.1f%%, PF: %.2f",
                                    m_session.totalOrders, m_session.winRate, m_session.profitFactor));
      }
   }

private:
   // Gerar JSON completo da sessão
   string GetSessionJSON()
   {
      string json = "{\n";
      json += "  \"sessionId\": \"" + m_session.sessionId + "\",\n";
      json += "  \"startTime\": \"" + TimeToString(m_session.startTime, TIME_DATE | TIME_SECONDS) + "\",\n";
      json += "  \"endTime\": \"" + TimeToString(m_session.endTime, TIME_DATE | TIME_SECONDS) + "\",\n";
      json += "  \"eaVersion\": \"" + m_session.eaVersion + "\",\n";
      json += "  \"initialBalance\": " + DoubleToString(m_session.initialBalance, 2) + ",\n";
      json += "  \"finalBalance\": " + DoubleToString(m_session.finalBalance, 2) + ",\n";
      json += "  \"totalOrders\": " + IntegerToString(m_session.totalOrders) + ",\n";
      json += "  \"winningOrders\": " + IntegerToString(m_session.winningOrders) + ",\n";
      json += "  \"losingOrders\": " + IntegerToString(m_session.losingOrders) + ",\n";
      json += "  \"totalProfit\": " + DoubleToString(m_session.totalProfit, 2) + ",\n";
      json += "  \"totalLoss\": " + DoubleToString(m_session.totalLoss, 2) + ",\n";
      json += "  \"maxDrawdown\": " + DoubleToString(m_session.maxDrawdown, 2) + ",\n";
      json += "  \"profitFactor\": " + DoubleToString(m_session.profitFactor, 2) + ",\n";
      json += "  \"winRate\": " + DoubleToString(m_session.winRate, 2) + ",\n";
      json += "  \"orders\": [\n";

      // Adicionar ordens
      for (int i = 0; i < ArraySize(m_session.orders); i++)
      {
         json += "    " + OrderToJSON(m_session.orders[i]);
         if (i < ArraySize(m_session.orders) - 1)
         {
            json += ",";
         }
         json += "\n";
      }

      json += "  ]\n";
      json += "}";

      return json;
   }

   // Atualizar arquivo JSON
   void UpdateSessionFile()
   {
      string filename = "cavalo.json";
      int handle = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_ANSI);

      if (handle != INVALID_HANDLE)
      {
         FileWrite(handle, GetSessionJSON());
         FileClose(handle);
      }
   }
};
