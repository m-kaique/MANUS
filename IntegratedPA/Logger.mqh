//+------------------------------------------------------------------+
//|                                                     Logger.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "Structures.mqh"

//+------------------------------------------------------------------+
//| Classe para gerenciamento de logs                                |
//+------------------------------------------------------------------+
class CLogger {
private:
   string         m_logFileName;      // Nome do arquivo de log
   int            m_logFileHandle;    // Handle do arquivo de log
   ENUM_LOG_LEVEL m_logLevel;         // Nível de log atual
   bool           m_consoleOutput;    // Flag para saída no console
   bool           m_fileOutput;       // Flag para saída em arquivo
   string         m_eaName;           // Nome do EA para identificação nos logs
   
   // Método privado para formatar mensagem de log
   string FormatLogMessage(ENUM_LOG_LEVEL level, string message);
   
   // Método privado para escrever no arquivo de log
   bool WriteToLogFile(string message);
   
public:
   // Construtores e destrutores
   CLogger();
   CLogger(string logFileName, string eaName = "IntegratedPA_EA", ENUM_LOG_LEVEL logLevel = LOG_LEVEL_INFO);
   ~CLogger();
   
   // Métodos de inicialização e configuração
   bool Initialize(string logFileName, string eaName = "IntegratedPA_EA", ENUM_LOG_LEVEL logLevel = LOG_LEVEL_INFO);
   void SetLogLevel(ENUM_LOG_LEVEL logLevel);
   void EnableConsoleOutput(bool enable);
   void EnableFileOutput(bool enable);
   
   // Métodos de logging
   void Debug(string message);
   void Info(string message);
   void Warning(string message);
   void Error(string message);
   
   // Métodos específicos para trading
   void LogSignal(const Signal &signal);
   void LogTrade(int ticket, string action, double price, double volume);
   void LogPosition(int ticket, double profit, double drawdown);
   void LogPerformance(int totalTrades, int winTrades, double profitFactor);
   void LogSetupClassification(string symbol, SETUP_QUALITY quality, int factors, double riskReward);
   void LogSpreadWarning(string symbol, double currentSpread, double avgSpread, double multiple);
   
   // Métodos para exportação
   bool ExportToCSV(string fileName, string headers, string data);
   
   // Sistema de alertas
   void SendAlert(string message, bool notifyTerminal = true, bool sendEmail = false, bool pushNotification = false);
};

//+------------------------------------------------------------------+
//| Construtor padrão                                                |
//+------------------------------------------------------------------+
CLogger::CLogger() {
   m_logFileName = "IntegratedPA_EA.log";
   m_logFileHandle = INVALID_HANDLE;
   m_logLevel = LOG_LEVEL_INFO;
   m_consoleOutput = true;
   m_fileOutput = true;
   m_eaName = "IntegratedPA_EA";
}

//+------------------------------------------------------------------+
//| Construtor com parâmetros                                        |
//+------------------------------------------------------------------+
CLogger::CLogger(string logFileName, string eaName = "IntegratedPA_EA", ENUM_LOG_LEVEL logLevel = LOG_LEVEL_INFO) {
   m_logFileName = logFileName;
   m_logFileHandle = INVALID_HANDLE;
   m_logLevel = logLevel;
   m_consoleOutput = true;
   m_fileOutput = true;
   m_eaName = eaName;
   
   Initialize(logFileName, eaName, logLevel);
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CLogger::~CLogger() {
   // Fechar o arquivo de log se estiver aberto
   if(m_logFileHandle != INVALID_HANDLE) {
      FileClose(m_logFileHandle);
      m_logFileHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Inicializa o logger                                              |
//+------------------------------------------------------------------+
bool CLogger::Initialize(string logFileName, string eaName = "IntegratedPA_EA", ENUM_LOG_LEVEL logLevel = LOG_LEVEL_INFO) {
   m_logFileName = logFileName;
   m_logLevel = logLevel;
   m_eaName = eaName;
   
   // Fechar o arquivo se já estiver aberto
   if(m_logFileHandle != INVALID_HANDLE) {
      FileClose(m_logFileHandle);
      m_logFileHandle = INVALID_HANDLE;
   }
   
   // Abrir o arquivo de log
   if(m_fileOutput) {
      m_logFileHandle = FileOpen(m_logFileName, FILE_WRITE | FILE_TXT | FILE_ANSI);
      
      if(m_logFileHandle == INVALID_HANDLE) {
         Print("Erro ao abrir arquivo de log: ", GetLastError());
         return false;
      }
      
      // Escrever cabeçalho do log
      string header = "=== " + m_eaName + " Log iniciado em " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + " ===";
      FileWrite(m_logFileHandle, header);
      FileFlush(m_logFileHandle);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Define o nível de log                                            |
//+------------------------------------------------------------------+
void CLogger::SetLogLevel(ENUM_LOG_LEVEL logLevel) {
   m_logLevel = logLevel;
}

//+------------------------------------------------------------------+
//| Habilita/desabilita saída no console                             |
//+------------------------------------------------------------------+
void CLogger::EnableConsoleOutput(bool enable) {
   m_consoleOutput = enable;
}

//+------------------------------------------------------------------+
//| Habilita/desabilita saída em arquivo                             |
//+------------------------------------------------------------------+
void CLogger::EnableFileOutput(bool enable) {
   m_fileOutput = enable;
   
   // Se estiver habilitando e o arquivo não estiver aberto, abrir
   if(enable && m_logFileHandle == INVALID_HANDLE) {
      Initialize(m_logFileName, m_eaName, m_logLevel);
   }
   
   // Se estiver desabilitando e o arquivo estiver aberto, fechar
   if(!enable && m_logFileHandle != INVALID_HANDLE) {
      FileClose(m_logFileHandle);
      m_logFileHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Formata mensagem de log                                          |
//+------------------------------------------------------------------+
string CLogger::FormatLogMessage(ENUM_LOG_LEVEL level, string message) {
   string levelStr = "";
   
   switch(level) {
      case LOG_LEVEL_DEBUG:   levelStr = "DEBUG"; break;
      case LOG_LEVEL_INFO:    levelStr = "INFO"; break;
      case LOG_LEVEL_WARNING: levelStr = "WARNING"; break;
      case LOG_LEVEL_ERROR:   levelStr = "ERROR"; break;
      default:                levelStr = "UNKNOWN";
   }
   
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
   return "[" + timestamp + "] [" + levelStr + "] " + message;
}

//+------------------------------------------------------------------+
//| Escreve no arquivo de log                                        |
//+------------------------------------------------------------------+
bool CLogger::WriteToLogFile(string message) {
   if(!m_fileOutput || m_logFileHandle == INVALID_HANDLE) {
      return false;
   }
   
   FileWrite(m_logFileHandle, message);
   FileFlush(m_logFileHandle);
   
   return true;
}

//+------------------------------------------------------------------+
//| Log de nível DEBUG                                               |
//+------------------------------------------------------------------+
void CLogger::Debug(string message) {
   if(m_logLevel > LOG_LEVEL_DEBUG) {
      return;
   }
   
   string formattedMessage = FormatLogMessage(LOG_LEVEL_DEBUG, message);
   
   if(m_consoleOutput) {
      Print(formattedMessage);
   }
   
   WriteToLogFile(formattedMessage);
}

//+------------------------------------------------------------------+
//| Log de nível INFO                                                |
//+------------------------------------------------------------------+
void CLogger::Info(string message) {
   if(m_logLevel > LOG_LEVEL_INFO) {
      return;
   }
   
   string formattedMessage = FormatLogMessage(LOG_LEVEL_INFO, message);
   
   if(m_consoleOutput) {
      Print(formattedMessage);
   }
   
   WriteToLogFile(formattedMessage);
}

//+------------------------------------------------------------------+
//| Log de nível WARNING                                             |
//+------------------------------------------------------------------+
void CLogger::Warning(string message) {
   if(m_logLevel > LOG_LEVEL_WARNING) {
      return;
   }
   
   string formattedMessage = FormatLogMessage(LOG_LEVEL_WARNING, message);
   
   if(m_consoleOutput) {
      Print(formattedMessage);
   }
   
   WriteToLogFile(formattedMessage);
}

//+------------------------------------------------------------------+
//| Log de nível ERROR                                               |
//+------------------------------------------------------------------+
void CLogger::Error(string message) {
   if(m_logLevel > LOG_LEVEL_ERROR) {
      return;
   }
   
   string formattedMessage = FormatLogMessage(LOG_LEVEL_ERROR, message);
   
   if(m_consoleOutput) {
      Print(formattedMessage);
   }
   
   WriteToLogFile(formattedMessage);
}

//+------------------------------------------------------------------+
//| Log de sinal de trading                                          |
//+------------------------------------------------------------------+
void CLogger::LogSignal(const Signal &signal) {
   string direction = (signal.direction == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   string phase = "";
   
   switch(signal.marketPhase) {
      case PHASE_TREND:    phase = "TREND"; break;
      case PHASE_RANGE:    phase = "RANGE"; break;
      case PHASE_REVERSAL: phase = "REVERSAL"; break;
      default:             phase = "UNDEFINED";
   }
   
   string quality = "";
   
   switch(signal.quality) {
      case SETUP_A_PLUS: quality = "A+"; break;
      case SETUP_A:      quality = "A"; break;
      case SETUP_B:      quality = "B"; break;
      case SETUP_C:      quality = "C"; break;
      default:           quality = "UNKNOWN";
   }
   
   string message = StringFormat(
      "SIGNAL [%d] %s %s (Quality: %s) - Entry: %.5f, SL: %.5f, TP1: %.5f, R:R: %.2f, Strategy: %s, Desc: %s",
      signal.id,
      direction,
      phase,
      quality,
      signal.entryPrice,
      signal.stopLoss,
      signal.takeProfits[0],
      signal.riskRewardRatio,
      signal.strategy,
      signal.description
   );
   
   Info(message);
}

//+------------------------------------------------------------------+
//| Log de operação                                                  |
//+------------------------------------------------------------------+
void CLogger::LogTrade(int ticket, string action, double price, double volume) {
   string message = StringFormat(
      "TRADE [%d] %s - Price: %.5f, Volume: %.2f",
      ticket,
      action,
      price,
      volume
   );
   
   Info(message);
}

//+------------------------------------------------------------------+
//| Log de posição                                                   |
//+------------------------------------------------------------------+
void CLogger::LogPosition(int ticket, double profit, double drawdown) {
   string message = StringFormat(
      "POSITION [%d] - Profit: %.2f, Max Drawdown: %.2f",
      ticket,
      profit,
      drawdown
   );
   
   Info(message);
}

//+------------------------------------------------------------------+
//| Log de desempenho                                                |
//+------------------------------------------------------------------+
void CLogger::LogPerformance(int totalTrades, int winTrades, double profitFactor) {
   double winRate = (totalTrades > 0) ? (double)winTrades / totalTrades * 100.0 : 0.0;
   
   string message = StringFormat(
      "PERFORMANCE - Total Trades: %d, Win Trades: %d, Win Rate: %.2f%%, Profit Factor: %.2f",
      totalTrades,
      winTrades,
      winRate,
      profitFactor
   );
   
   Info(message);
}

//+------------------------------------------------------------------+
//| Exporta dados para CSV                                           |
//+------------------------------------------------------------------+
bool CLogger::ExportToCSV(string fileName, string headers, string data) {
   // Abrir arquivo CSV
   int fileHandle = FileOpen(fileName, FILE_WRITE | FILE_CSV | FILE_ANSI);
   
   if(fileHandle == INVALID_HANDLE) {
      Error(StringFormat("Erro ao abrir arquivo CSV %s: %d", fileName, GetLastError()));
      return false;
   }
   
   // Escrever cabeçalhos
   FileWrite(fileHandle, headers);
   
   // Escrever dados
   FileWrite(fileHandle, data);
   
   // Fechar arquivo
   FileClose(fileHandle);
   
   Info(StringFormat("Dados exportados para %s", fileName));
   
   return true;
}

//+------------------------------------------------------------------+
//| Envia alertas                                                    |
//+------------------------------------------------------------------+
void CLogger::SendAlert(string message, bool notifyTerminal = true, bool sendEmail = false, bool pushNotification = false) {
   // Formatar mensagem
   string formattedMessage = m_eaName + ": " + message;
   
   // Notificação no terminal
   if(notifyTerminal) {
      Alert(formattedMessage);
   }
   
   // Email
   if(sendEmail) {
      if(!SendMail(m_eaName + " Alert", formattedMessage)) {
         Error(StringFormat("Erro ao enviar email: %d", GetLastError()));
      }
   }
   
   // Notificação push
   if(pushNotification) {
      if(!SendNotification(formattedMessage)) {
         Error(StringFormat("Erro ao enviar notificação push: %d", GetLastError()));
      }
   }
   
   // Registrar alerta no log
   Info("ALERT: " + message);
}
