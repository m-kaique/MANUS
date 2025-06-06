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
//| Classe CLogger modificada com buffer para exportação CSV          |
//+------------------------------------------------------------------+
class CLogger
{
private:
   // Propriedades existentes
   string          m_logFileName;
   int             m_logFileHandle;
   ENUM_LOG_LEVEL  m_logLevel;
   bool            m_consoleOutput;
   bool            m_fileOutput;
   string          m_eaName;
   
   // ADICIONAR: Buffer para armazenar logs
   string          m_logBuffer[];  // Buffer para armazenar logs
   int             m_bufferSize;   // Tamanho atual do buffer
   int             m_maxBufferSize; // Tamanho máximo do buffer
   
   // Método para formatar mensagem de log
   string FormatLogMessage(ENUM_LOG_LEVEL level, string message);
   
   // Método para escrever no arquivo de log
   void WriteToLogFile(string message);
   
   // ADICIONAR: Método para adicionar ao buffer
   void AddToBuffer(string message) {
      if(m_bufferSize >= m_maxBufferSize) {
         // Rotacionar buffer se necessário
         for(int i = 0; i < m_maxBufferSize - 1; i++) {
            m_logBuffer[i] = m_logBuffer[i + 1];
         }
         m_logBuffer[m_maxBufferSize - 1] = message;
      } else {
         ArrayResize(m_logBuffer, m_bufferSize + 1);
         m_logBuffer[m_bufferSize] = message;
         m_bufferSize++;
      }
   }

public:
   // Construtores e destrutor
   CLogger(string logFileName = "EA_Log.txt", ENUM_LOG_LEVEL logLevel = LOG_LEVEL_INFO);
   ~CLogger();
   
   // Métodos de inicialização
   bool Initialize(string eaName = "EA");
   
   // Métodos de configuração
   void SetLogLevel(ENUM_LOG_LEVEL level) { m_logLevel = level; }
   void EnableConsoleOutput(bool enable) { m_consoleOutput = enable; }
   void EnableFileOutput(bool enable) { m_fileOutput = enable; }
   
   // Métodos de log
   void Debug(string message);
   void Info(string message);
   void Warning(string message);
   void Error(string message);
   
   // MODIFICAR: Método ExportToCSV
   bool ExportToCSV(string fileName) {
      int fileHandle = FileOpen(fileName, FILE_WRITE | FILE_CSV | FILE_ANSI);
      
      if(fileHandle == INVALID_HANDLE) {
         Error("Falha ao abrir arquivo CSV para exportação: " + IntegerToString(GetLastError()));
         return false;
      }
      
      // Escrever cabeçalho
      FileWrite(fileHandle, "Timestamp,Level,Message");
      
      // Escrever todos os logs do buffer
      for(int i = 0; i < m_bufferSize; i++) {
         FileWrite(fileHandle, m_logBuffer[i]);
      }
      
      FileClose(fileHandle);
      
      Info(StringFormat("Logs exportados para %s: %d entradas", fileName, m_bufferSize));
      
      return true;
   }
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CLogger::CLogger(string logFileName = "EA_Log.txt", ENUM_LOG_LEVEL logLevel = LOG_LEVEL_INFO)
{
   m_logFileName = logFileName;
   m_logLevel = logLevel;
   m_logFileHandle = INVALID_HANDLE;
   m_consoleOutput = true;
   m_fileOutput = true;
   m_eaName = "EA";
   
   // ADICIONAR: Inicializar buffer
   m_bufferSize = 0;
   m_maxBufferSize = 1000; // Armazenar até 1000 logs
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CLogger::~CLogger()
{
   if(m_logFileHandle != INVALID_HANDLE) {
      FileClose(m_logFileHandle);
      m_logFileHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool CLogger::Initialize(string eaName = "EA")
{
   m_eaName = eaName;
   
   if(m_fileOutput) {
      m_logFileHandle = FileOpen(m_logFileName, FILE_WRITE | FILE_TXT | FILE_ANSI);
      
      if(m_logFileHandle == INVALID_HANDLE) {
         Print("Erro ao abrir arquivo de log: ", GetLastError());
         return false;
      }
   }
   
   Info("Logger inicializado");
   return true;
}

//+------------------------------------------------------------------+
//| Formatar mensagem de log                                         |
//+------------------------------------------------------------------+
string CLogger::FormatLogMessage(ENUM_LOG_LEVEL level, string message)
{
   string levelStr;
   
   switch(level) {
      case LOG_LEVEL_DEBUG:
         levelStr = "DEBUG";
         break;
      case LOG_LEVEL_INFO:
         levelStr = "INFO";
         break;
      case LOG_LEVEL_WARNING:
         levelStr = "WARNING";
         break;
      case LOG_LEVEL_ERROR:
         levelStr = "ERROR";
         break;
      default:
         levelStr = "UNKNOWN";
   }
   
   return StringFormat("[%s] [%s] [%s] %s", 
                      TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                      m_eaName,
                      levelStr,
                      message);
}

//+------------------------------------------------------------------+
//| Escrever no arquivo de log                                       |
//+------------------------------------------------------------------+
void CLogger::WriteToLogFile(string message)
{
   if(!m_fileOutput || m_logFileHandle == INVALID_HANDLE) {
      return;
   }
   
   FileWrite(m_logFileHandle, message);
   FileFlush(m_logFileHandle);
}

//+------------------------------------------------------------------+
//| Log de nível DEBUG                                               |
//+------------------------------------------------------------------+
void CLogger::Debug(string message)
{
   if(m_logLevel > LOG_LEVEL_DEBUG) {
      return;
   }
   
   string formattedMessage = FormatLogMessage(LOG_LEVEL_DEBUG, message);
   
   if(m_consoleOutput) {
      Print(formattedMessage);
   }
   
   WriteToLogFile(formattedMessage);
   
   // ADICIONAR: Salvar no buffer para CSV
   string csvLine = StringFormat("%s,DEBUG,\"%s\"", 
                               TimeToString(TimeCurrent()), 
                               message);
   AddToBuffer(csvLine);
}

//+------------------------------------------------------------------+
//| Log de nível INFO                                                |
//+------------------------------------------------------------------+
void CLogger::Info(string message)
{
   if(m_logLevel > LOG_LEVEL_INFO) {
      return;
   }
   
   string formattedMessage = FormatLogMessage(LOG_LEVEL_INFO, message);
   
   if(m_consoleOutput) {
      Print(formattedMessage);
   }
   
   WriteToLogFile(formattedMessage);
   
   // ADICIONAR: Salvar no buffer para CSV
   string csvLine = StringFormat("%s,INFO,\"%s\"", 
                               TimeToString(TimeCurrent()), 
                               message);
   AddToBuffer(csvLine);
}

//+------------------------------------------------------------------+
//| Log de nível WARNING                                             |
//+------------------------------------------------------------------+
void CLogger::Warning(string message)
{
   if(m_logLevel > LOG_LEVEL_WARNING) {
      return;
   }
   
   string formattedMessage = FormatLogMessage(LOG_LEVEL_WARNING, message);
   
   if(m_consoleOutput) {
      Print(formattedMessage);
   }
   
   WriteToLogFile(formattedMessage);
   
   // ADICIONAR: Salvar no buffer para CSV
   string csvLine = StringFormat("%s,WARNING,\"%s\"", 
                               TimeToString(TimeCurrent()), 
                               message);
   AddToBuffer(csvLine);
}

//+------------------------------------------------------------------+
//| Log de nível ERROR                                               |
//+------------------------------------------------------------------+
void CLogger::Error(string message)
{
   if(m_logLevel > LOG_LEVEL_ERROR) {
      return;
   }
   
   string formattedMessage = FormatLogMessage(LOG_LEVEL_ERROR, message);
   
   if(m_consoleOutput) {
      Print(formattedMessage);
   }
   
   WriteToLogFile(formattedMessage);
   
   // ADICIONAR: Salvar no buffer para CSV
   string csvLine = StringFormat("%s,ERROR,\"%s\"", 
                               TimeToString(TimeCurrent()), 
                               message);
   AddToBuffer(csvLine);
}

