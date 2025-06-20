//+------------------------------------------------------------------+
//|                                           ModularEA_Classes.mqh |
//|                        Copyright 2025, Expert Advisor Developer |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Expert Advisor Developer"
#property link "https://www.mql5.com"
#property version "2.00"
#include <Trade/Trade.mqh>
#include <Files/File.mqh>

//+------------------------------------------------------------------+
//| Estrutura para dados de Média Móvel                             |
//+------------------------------------------------------------------+
/***
 Armazena valores de médias móveis (MA7, MA21, MA72, MA200), preço atual, timestamp e tendência.
***/
struct SMovingAverageData
{
    double ma7;
    double ma21;
    double ma72;
    double ma200;
    double price;
    datetime timestamp;
    string trend;

    void Reset()  
    {
        ma7 = 0.0;
        ma21 = 0.0;
        ma72 = 0.0;
        ma200 = 0.0;
        price = 0.0;
        timestamp = 0;
        trend = "";
    }
};

//+------------------------------------------------------------------+
//| Estrutura para dados de um símbolo                              |
//+------------------------------------------------------------------+
/***
Gerencia dados de um símbolo em múltiplos timeframes.
***/
struct SSymbolData
{
    string symbol;
    SMovingAverageData timeframeData[];
    ENUM_TIMEFRAMES timeframes[];
    int timeframeCount;

    void Initialize(string sym, ENUM_TIMEFRAMES &tf[])
    {
        symbol = sym;
        timeframeCount = ArraySize(tf);
        ArrayResize(timeframes, timeframeCount);
        ArrayResize(timeframeData, timeframeCount);

        for (int i = 0; i < timeframeCount; i++)
        {
            timeframes[i] = tf[i];
            timeframeData[i].Reset();
        }
    }
};

//+------------------------------------------------------------------+
//| Estrutura para alertas                                          |
//+------------------------------------------------------------------+
/***
Configura regras para disparo de alertas (ex: preço > 1.2000).
***/
struct SAlert
{
    string symbol;
    ENUM_TIMEFRAMES timeframe;
    string indicator; // "PRICE", "MA7", "MA21", etc.
    string condition; // ">", "<", ">=", "<=", "=="
    double value;
    bool triggered;
    datetime lastTrigger;

    void Reset()
    {
        symbol = "";
        timeframe = PERIOD_CURRENT;
        indicator = "";
        condition = "";
        value = 0.0;
        triggered = false;
        lastTrigger = 0;
    }
};

//+------------------------------------------------------------------+
//| Classe para gerenciar dados de um símbolo                       |
//+------------------------------------------------------------------+
/***
Gerencia um único símbolo em múltiplos timeframes (ex: BTCUSD em M15/H1/D1).
***/
class CSymbolManager
{

private:
    SSymbolData m_data;
    int m_ma7Handle[], m_ma21Handle[], m_ma72Handle[], m_ma200Handle[];

public:
    CSymbolManager() {};
    ~CSymbolManager() { Cleanup(); };
    bool Initialize(string symbol, ENUM_TIMEFRAMES &timeframes[]);
    bool UpdateData();
    bool GetMovingAverageData(ENUM_TIMEFRAMES tf, SMovingAverageData &data);
    string GetSymbol() { return m_data.symbol; }
    void Cleanup();
    string ToJSON();

private:

bool CreateIndicatorHandles();
    string DetermineTrend(const SMovingAverageData &data);
    int GetTimeframeIndex(ENUM_TIMEFRAMES tf);
    string TimeframeToString(ENUM_TIMEFRAMES tf);
};

//+------------------------------------------------------------------+
//| Inicializa o gerenciador de símbolo                             |
//+------------------------------------------------------------------+
/***
Cria handles para indicadores de médias móveis.
***/
bool CSymbolManager::Initialize(string symbol, ENUM_TIMEFRAMES &timeframes[])
{
    m_data.Initialize(symbol, timeframes);
    ArrayResize(m_ma7Handle, m_data.timeframeCount);
    ArrayResize(m_ma21Handle, m_data.timeframeCount);
    ArrayResize(m_ma72Handle, m_data.timeframeCount);
    ArrayResize(m_ma200Handle, m_data.timeframeCount);
    return CreateIndicatorHandles();
}

//+------------------------------------------------------------------+
//| Cria os handles dos indicadores                                 |
//+------------------------------------------------------------------+

bool CSymbolManager::CreateIndicatorHandles()
{
    for (int i = 0; i < m_data.timeframeCount; i++)
    {
        m_ma7Handle[i] = iMA(m_data.symbol, m_data.timeframes[i], 7, 0, MODE_EMA, PRICE_CLOSE);
        m_ma21Handle[i] = iMA(m_data.symbol, m_data.timeframes[i], 21, 0, MODE_EMA, PRICE_CLOSE);
        m_ma72Handle[i] = iMA(m_data.symbol, m_data.timeframes[i], 72, 0, MODE_EMA, PRICE_CLOSE);
        m_ma200Handle[i] = iMA(m_data.symbol, m_data.timeframes[i], 200, 0, MODE_SMA, PRICE_CLOSE);

        if (m_ma7Handle[i] == INVALID_HANDLE || m_ma21Handle[i] == INVALID_HANDLE ||
            m_ma72Handle[i] == INVALID_HANDLE || m_ma200Handle[i] == INVALID_HANDLE)
        {
            Print("ERRO: Falha ao criar handles para ", m_data.symbol, " TF:", EnumToString(m_data.timeframes[i]));
            return false;
        }
    }
    return true;
}

//+------------------------------------------------------------------+
//| Atualiza os dados do símbolo                                    |
//+------------------------------------------------------------------+
/***
Copia valores dos indicadores para as estruturas.
***/
bool CSymbolManager::UpdateData()
{
    double ma7[], ma21[], ma72[], ma200[];

    for (int i = 0; i < m_data.timeframeCount; i++)
    {
        if (CopyBuffer(m_ma7Handle[i], 0, 0, 1, ma7) <= 0 ||
            CopyBuffer(m_ma21Handle[i], 0, 0, 1, ma21) <= 0 ||
            CopyBuffer(m_ma72Handle[i], 0, 0, 1, ma72) <= 0 ||
            CopyBuffer(m_ma200Handle[i], 0, 0, 1, ma200) <= 0)
        {
            Print("ERRO: Falha ao copiar dados das MAs para ", m_data.symbol);
            continue;
        }

        m_data.timeframeData[i].ma7 = ma7[0];
        m_data.timeframeData[i].ma21 = ma21[0];
        m_data.timeframeData[i].ma72 = ma72[0];
        m_data.timeframeData[i].ma200 = ma200[0];
        m_data.timeframeData[i].price = SymbolInfoDouble(m_data.symbol, SYMBOL_BID);
        m_data.timeframeData[i].timestamp = TimeCurrent();
        m_data.timeframeData[i].trend = DetermineTrend(m_data.timeframeData[i]);
    }
    return true;
}

//+------------------------------------------------------------------+
//| Obtém dados de MA para um timeframe específico                  |
//+------------------------------------------------------------------+

bool CSymbolManager::GetMovingAverageData(ENUM_TIMEFRAMES tf, SMovingAverageData &data)
{
    int index = GetTimeframeIndex(tf);

    if (index < 0)
        return false;
    data = m_data.timeframeData[index];

    return true;
}

//+------------------------------------------------------------------+
//| Determina a tendência baseada nas MAs                           |
//+------------------------------------------------------------------+
/***
Classifica o mercado com base no alinhamento das MAs.
***/

string CSymbolManager::DetermineTrend(const SMovingAverageData &data)
{
    if (data.ma7 > data.ma21 && data.ma21 > data.ma72 && data.price > data.ma7)
        return "STRONG_BULL";
    else if (data.ma7 > data.ma21 && data.price > data.ma7)
        return "BULL";
    else if (data.ma7 < data.ma21 && data.ma21 < data.ma72 && data.price < data.ma7)
        return "STRONG_BEAR";
    else if (data.ma7 < data.ma21 && data.price < data.ma7)
        return "BEAR";
    else
        return "SIDEWAYS";
}

//+------------------------------------------------------------------+
//| Obtém índice do timeframe                                       |
//+------------------------------------------------------------------+

int CSymbolManager::GetTimeframeIndex(ENUM_TIMEFRAMES tf)
{
    for (int i = 0; i < m_data.timeframeCount; i++)
    {
        if (m_data.timeframes[i] == tf)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Converte timeframe para string                                  |
//+------------------------------------------------------------------+

string CSymbolManager::TimeframeToString(ENUM_TIMEFRAMES tf)
{
    switch (tf)
    {
    case PERIOD_M3:
        return "M3";
    case PERIOD_M15:
        return "M15";
    case PERIOD_H1:
        return "H1";
    case PERIOD_D1:
        return "D1";
    default:
        return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Converte dados para JSON                                        |
//+------------------------------------------------------------------+

string CSymbolManager::ToJSON()
{
    string json = "{\n";
    json += "    \"symbol\": \"" + m_data.symbol + "\",\n";
    json += "    \"timeframes\": {\n";
    for (int i = 0; i < m_data.timeframeCount; i++)
    {
        json += "      \"" + TimeframeToString(m_data.timeframes[i]) + "\": {\n";
        json += "        \"ma7\": " + DoubleToString(m_data.timeframeData[i].ma7, 5) + ",\n";
        json += "        \"ma21\": " + DoubleToString(m_data.timeframeData[i].ma21, 5) + ",\n";
        json += "        \"ma72\": " + DoubleToString(m_data.timeframeData[i].ma72, 5) + ",\n";
        json += "        \"ma200\": " + DoubleToString(m_data.timeframeData[i].ma200, 5) + ",\n";
        json += "        \"price\": " + DoubleToString(m_data.timeframeData[i].price, 5) + ",\n";
        json += "        \"trend\": \"" + m_data.timeframeData[i].trend + "\",\n";
        json += "        \"timestamp\": \"" + TimeToString(m_data.timeframeData[i].timestamp) + "\"\n";
        json += "      }";

        if (i < m_data.timeframeCount - 1)
            json += ",";
        json += "\n";
    }

    json += "    }\n";
    json += "  }";
    return json;
}

//+------------------------------------------------------------------+
//| Limpa recursos                                                  |
//+------------------------------------------------------------------+

void CSymbolManager::Cleanup()
{
    for (int i = 0; i < ArraySize(m_ma7Handle); i++)
    {
        if (m_ma7Handle[i] != INVALID_HANDLE)
            IndicatorRelease(m_ma7Handle[i]);
        if (m_ma21Handle[i] != INVALID_HANDLE)
            IndicatorRelease(m_ma21Handle[i]);
        if (m_ma72Handle[i] != INVALID_HANDLE)
            IndicatorRelease(m_ma72Handle[i]);
        if (m_ma200Handle[i] != INVALID_HANDLE)
            IndicatorRelease(m_ma200Handle[i]);
    }
}

//+------------------------------------------------------------------+
//| Classe principal para gerenciar portfolio                       |
//+------------------------------------------------------------------+

class CPortfolioManager
{

private:
    CSymbolManager *m_symbols[];
    int m_symbolCount;
    string m_jsonFileName;
    bool m_exportEnabled;
    datetime m_lastExport;
    int m_updateInterval;

public:
    CPortfolioManager();
    ~CPortfolioManager();
    bool Initialize(string &symbols[], ENUM_TIMEFRAMES &timeframes[]);
    bool CheckAndExport();
    bool ExportToJSON();
    bool GetSymbolData(string symbol, ENUM_TIMEFRAMES tf, SMovingAverageData &data);
    void SetJSONFileName(string filename) { m_jsonFileName = filename; }
    void SetExportEnabled(bool enabled) { m_exportEnabled = enabled; }
    void SetUpdateInterval(int seconds) { m_updateInterval = seconds; }
    int GetSymbolCount() { return m_symbolCount; }
    string GetSymbolName(int index);

private:
    bool UpdateAllData();
    string GenerateCompleteJSON();
};

//+------------------------------------------------------------------+
//| Construtor                                                      |
//+------------------------------------------------------------------+

CPortfolioManager::CPortfolioManager()

{
    m_symbolCount = 0;
    m_jsonFileName = "MA_Data.json";
    m_exportEnabled = true;
    m_lastExport = 0;
    m_updateInterval = 30;
}

//+------------------------------------------------------------------+
//| Destrutor                                                       |
//+------------------------------------------------------------------+

CPortfolioManager::~CPortfolioManager()
{
    for (int i = 0; i < m_symbolCount; i++)
    {
        if (m_symbols[i] != NULL)
            delete m_symbols[i];
    }
}

//+------------------------------------------------------------------+
//| Inicializa o gerenciador de portfolio                          |
//+------------------------------------------------------------------+

bool CPortfolioManager::Initialize(string &symbols[], ENUM_TIMEFRAMES &timeframes[])
{
    m_symbolCount = ArraySize(symbols);
    ArrayResize(m_symbols, m_symbolCount);

    for (int i = 0; i < m_symbolCount; i++)
    {
        m_symbols[i] = new CSymbolManager();
        if (m_symbols[i] == NULL)
        {
            Print("ERRO: Falha ao criar CSymbolManager para ", symbols[i]);
            return false;
        }

        if (!m_symbols[i].Initialize(symbols[i], timeframes))
        {
            Print("ERRO: Falha ao inicializar símbolo ", symbols[i]);
            return false;
        }
    }

    return UpdateAllData();
}

//+------------------------------------------------------------------+
//| Verifica e exporta se necessário                               |
//+------------------------------------------------------------------+

bool CPortfolioManager::CheckAndExport()

{
    if (!m_exportEnabled)
        return false;

    datetime current = TimeCurrent();
    if (current - m_lastExport >= m_updateInterval)
    {
        UpdateAllData();
        return ExportToJSON();
    }

    return false;
}

//+------------------------------------------------------------------+
//| Atualiza dados de todos os símbolos                            |
//+------------------------------------------------------------------+

bool CPortfolioManager::UpdateAllData()
{

    bool success = true;

    for (int i = 0; i < m_symbolCount; i++)
    {
        if (m_symbols[i] != NULL)
        {
            if (!m_symbols[i].UpdateData())
                success = false;
        }
    }
    return success;
}

//+------------------------------------------------------------------+
//| Exporta dados para JSON                                        |
//+------------------------------------------------------------------+

bool CPortfolioManager::ExportToJSON()
{

    if (!m_exportEnabled)
        return false;
    string jsonContent = GenerateCompleteJSON();
    int fileHandle = FileOpen(m_jsonFileName, FILE_WRITE | FILE_TXT);
    if (fileHandle == INVALID_HANDLE)
    {
        Print("ERRO: Não foi possível criar o arquivo JSON: ", m_jsonFileName);
        return false;
    }

    FileWrite(fileHandle, jsonContent);
    FileClose(fileHandle);
    m_lastExport = TimeCurrent();
    Print("JSON exportado com sucesso: ", m_jsonFileName);
    return true;
}

//+------------------------------------------------------------------+
//| Gera JSON completo                                             |
//+------------------------------------------------------------------+

string CPortfolioManager::GenerateCompleteJSON()
{

    string json = "{\n";
    json += "  \"export_info\": {\n";
    json += "    \"timestamp\": \"" + TimeToString(TimeCurrent()) + "\",\n";
    json += "    \"symbol_count\": " + IntegerToString(m_symbolCount) + "\n";
    json += "  },\n";
    json += "  \"symbols\": [\n";
    for (int i = 0; i < m_symbolCount; i++)
    {
        if (m_symbols[i] != NULL)
        {
            json += "    " + m_symbols[i].ToJSON();
            if (i < m_symbolCount - 1)
                json += ",";

            json += "\n";
        }
    }

    json += "  ]\n";
    json += "}";
    return json;
}

//+------------------------------------------------------------------+
//| Obtém dados de um símbolo específico                           |
//+------------------------------------------------------------------+

bool CPortfolioManager::GetSymbolData(string symbol, ENUM_TIMEFRAMES tf, SMovingAverageData &data)

{
    for (int i = 0; i < m_symbolCount; i++)
    {
        if (m_symbols[i] != NULL && m_symbols[i].GetSymbol() == symbol)
        {
            return m_symbols[i].GetMovingAverageData(tf, data);
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Obtém nome do símbolo por índice                               |
//+------------------------------------------------------------------+

string CPortfolioManager::GetSymbolName(int index)
{
    if (index >= 0 && index < m_symbolCount && m_symbols[index] != NULL)
        return m_symbols[index].GetSymbol();
    return "";
}

//+------------------------------------------------------------------+
//| Classe para gerenciar alertas                                  |
//+------------------------------------------------------------------+

class CAlertManager
{

private:
    SAlert m_alerts[];
    int m_alertCount;

public:
    CAlertManager() { m_alertCount = 0; };
    ~CAlertManager() {};
    bool AddAlert(string symbol, ENUM_TIMEFRAMES tf, string indicator, string condition, double value);
    bool RemoveAlert(int index);
    void CheckAlerts(CPortfolioManager *portfolio);
    int GetAlertCount() { return m_alertCount; }

private:
    bool EvaluateCondition(double currentValue, string condition, double targetValue);
    void TriggerAlert(int alertIndex, double currentValue);
};

//+------------------------------------------------------------------+
//| Adiciona um novo alerta                                        |
//+------------------------------------------------------------------+

bool CAlertManager::AddAlert(string symbol, ENUM_TIMEFRAMES tf, string indicator, string condition, double value)

{
    ArrayResize(m_alerts, m_alertCount + 1);
    m_alerts[m_alertCount].symbol = symbol;
    m_alerts[m_alertCount].timeframe = tf;
    m_alerts[m_alertCount].indicator = indicator;
    m_alerts[m_alertCount].condition = condition;
    m_alerts[m_alertCount].value = value;
    m_alerts[m_alertCount].triggered = false;
    m_alerts[m_alertCount].lastTrigger = 0;
    m_alertCount++;

    Print("Alerta adicionado: ", symbol, " ", EnumToString(tf), " ", indicator, " ", condition, " ", DoubleToString(value));
    return true;
}

//+------------------------------------------------------------------+
//| Remove um alerta                                               |
//+------------------------------------------------------------------+

bool CAlertManager::RemoveAlert(int index)

{
    if (index < 0 || index >= m_alertCount)
        return false;
    for (int i = index; i < m_alertCount - 1; i++)

    {
        m_alerts[i] = m_alerts[i + 1];
    }

    m_alertCount--;
    ArrayResize(m_alerts, m_alertCount);
    return true;
}

//+------------------------------------------------------------------+
//| Verifica todos os alertas                                      |
//+------------------------------------------------------------------+

void CAlertManager::CheckAlerts(CPortfolioManager *portfolio)

{

    if (portfolio == NULL)
        return;

    for (int i = 0; i < m_alertCount; i++)

    {

        SMovingAverageData data;

        if (!portfolio.GetSymbolData(m_alerts[i].symbol, m_alerts[i].timeframe, data))

            continue;

        double currentValue = 0.0;

        if (m_alerts[i].indicator == "PRICE")

            currentValue = data.price;

        else if (m_alerts[i].indicator == "MA7")

            currentValue = data.ma7;

        else if (m_alerts[i].indicator == "MA21")

            currentValue = data.ma21;

        else if (m_alerts[i].indicator == "MA72")

            currentValue = data.ma72;

        else if (m_alerts[i].indicator == "MA200")

            currentValue = data.ma200;

        else

            continue;

        if (EvaluateCondition(currentValue, m_alerts[i].condition, m_alerts[i].value))

        {

            TriggerAlert(i, currentValue);
        }
    }
}

//+------------------------------------------------------------------+

//| Avalia condição do alerta                                      |

//+------------------------------------------------------------------+

bool CAlertManager::EvaluateCondition(double currentValue, string condition, double targetValue)

{

    if (condition == ">")
        return currentValue > targetValue;

    if (condition == "<")
        return currentValue < targetValue;

    if (condition == ">=")
        return currentValue >= targetValue;

    if (condition == "<=")
        return currentValue <= targetValue;

    if (condition == "==")
        return MathAbs(currentValue - targetValue) < 0.00001;

    return false;
}

//+------------------------------------------------------------------+

//| Dispara alerta                                                 |

//+------------------------------------------------------------------+

void CAlertManager::TriggerAlert(int alertIndex, double currentValue)

{

    datetime current = TimeCurrent();

    // Evita spam de alertas (mínimo 60 segundos entre alertas do mesmo tipo)

    if (current - m_alerts[alertIndex].lastTrigger < 60)

        return;

    string message = StringFormat("ALERTA: %s %s %s %s %.5f (Atual: %.5f)",

                                  m_alerts[alertIndex].symbol,

                                  EnumToString(m_alerts[alertIndex].timeframe),

                                  m_alerts[alertIndex].indicator,

                                  m_alerts[alertIndex].condition,

                                  m_alerts[alertIndex].value,

                                  currentValue);

    Print(message);

    Alert(message);

    m_alerts[alertIndex].triggered = true;

    m_alerts[alertIndex].lastTrigger = current;
}