//+------------------------------------------------------------------+
//|                                       MA_JSON_Exporter_OOP.mq5 |
//|                        Copyright 2025, Expert Advisor Developer |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Expert Advisor Developer"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property description "Exportador de dados de Médias Móveis - Versão Orientada a Objetos"

#include "ModularEA_Classes.mqh" 

//--- Input parameters
input group "=== Configurações de Exportação ==="
input bool EnableExport = true;
input string JsonFileName = "MA_Data_OOP.json";

input group "=== Configurações de Símbolos ==="
input string Symbol1 = "DOL$";
input string Symbol2 = "BIT$D";  
input string Symbol3 = "WIN$";
input bool UseSymbol1 = true;
input bool UseSymbol2 = true;
input bool UseSymbol3 = true;

input group "=== Configurações de Timeframes ==="
input bool UseD1 = true;
input bool UseH1 = true;
input bool UseM15 = true;
input bool UseM3 = true;

input group "=== Configurações Avançadas ==="
input int UpdateIntervalSeconds = 180;
input bool EnableDetailedLog = false;

//--- Variáveis globais
CPortfolioManager* g_portfolio = NULL;
CAlertManager* g_alerts = NULL;
datetime g_lastManualUpdate = 0;

//+------------------------------------------------------------------+
//| Função de inicialização do Expert Advisor                       |
//| Executada uma vez quando o EA é carregado no gráfico            |
//| Retorna: INIT_SUCCEEDED se inicialização bem-sucedida,          |
//|          INIT_FAILED se ocorrer erro                            |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== MA JSON Exporter OOP v2.00 ===");
    Print("Inicializando sistema orientado a objetos...");

    // Cria instâncias dos gerenciadores principais
    g_portfolio = new CPortfolioManager();
    g_alerts = new CAlertManager();

    // Verifica se os objetos foram criados com sucesso
    if(g_portfolio == NULL || g_alerts == NULL)
    {
        Print("ERRO: Falha ao criar componentes principais!");
        return INIT_FAILED;
    }

    // Configura parâmetros do gerenciador de portfolio
    g_portfolio.SetExportEnabled(EnableExport);
    g_portfolio.SetJSONFileName(JsonFileName);
    g_portfolio.SetUpdateInterval(UpdateIntervalSeconds);

    // Prepara listas de símbolos e timeframes baseado nos inputs
    string symbols[];
    ENUM_TIMEFRAMES timeframes[];

    if(!PrepareSymbolsList(symbols) || !PrepareTimeframesList(timeframes))
    {
        Print("ERRO: Configuração inválida de símbolos ou timeframes!");
        delete g_portfolio;
        delete g_alerts;
        return INIT_FAILED;
    }

    // Inicializa o gerenciador de portfolio com símbolos e timeframes
    if(!g_portfolio.Initialize(symbols, timeframes))
    {
        Print("ERRO: Falha ao inicializar Portfolio Manager!");
        delete g_portfolio;
        delete g_alerts;
        return INIT_FAILED;
    }

    // Exemplo de alerta - monitora se preço do DOL$ passa de 5000 no H1
    g_alerts.AddAlert("DOL$", PERIOD_H1, "PRICE", ">", 5000);

    // Realiza primeira exportação
    g_portfolio.ExportToJSON();
    Print("=== Sistema inicializado com sucesso! ===");

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Função de desinicialização do Expert Advisor                    |
//| Executada quando o EA é removido do gráfico ou terminal fechado |
//| Parâmetro: reason - motivo da desinicialização                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Libera memória dos objetos criados
    if(g_portfolio != NULL) delete g_portfolio;
    if(g_alerts != NULL) delete g_alerts;
    Print("Sistema finalizado.");
}

//+------------------------------------------------------------------+
//| Função executada a cada tick (mudança de preço)                 |
//| Responsável por verificar atualizações e alertas                |
//+------------------------------------------------------------------+
void OnTick()
{
    if(g_portfolio == NULL) return;

    // Verifica se é hora de exportar dados (baseado no intervalo configurado)
    if(g_portfolio.CheckAndExport())
    {
        if(EnableDetailedLog)
            Print("Exportação automática realizada.");
    }

    // Verifica se algum alerta foi acionado
    if(g_alerts != NULL)
        g_alerts.CheckAlerts(g_portfolio);
}

//+------------------------------------------------------------------+
//| Prepara array de símbolos baseado nos inputs do usuário         |
//| Parâmetro: symbols[] - array que receberá os símbolos válidos   |
//| Retorna: true se pelo menos um símbolo foi configurado          |
//+------------------------------------------------------------------+
bool PrepareSymbolsList(string &symbols[])
{
    string tempSymbols[10]; // Array temporário para construir lista
    int count = 0;

    // Adiciona símbolos habilitados pelo usuário
    if(UseSymbol1 && Symbol1 != "") 
    {
        tempSymbols[count] = Symbol1;
        count++;
    }
    if(UseSymbol2 && Symbol2 != "") 
    {
        tempSymbols[count] = Symbol2;
        count++;
    }
    if(UseSymbol3 && Symbol3 != "") 
    {
        tempSymbols[count] = Symbol3;
        count++;
    }

    // Se nenhum símbolo foi configurado, usa o símbolo atual do gráfico
    if(count == 0)
    {
        tempSymbols[0] = Symbol();
        count = 1;
    }

    // Redimensiona array final e copia símbolos válidos
    ArrayResize(symbols, count);
    for(int i = 0; i < count; i++) 
    {
        symbols[i] = tempSymbols[i];
    }

    // Log dos símbolos configurados
    Print("Símbolos configurados: ", count);
    for(int i = 0; i < count; i++)
    {
        Print("  [", i, "] ", symbols[i]);
    }

    return count > 0;
}

//+------------------------------------------------------------------+
//| Prepara array de timeframes baseado nos inputs do usuário       |
//| Parâmetro: timeframes[] - array que receberá os timeframes      |
//| Retorna: true se pelo menos um timeframe foi configurado        |
//+------------------------------------------------------------------+
bool PrepareTimeframesList(ENUM_TIMEFRAMES &timeframes[])
{
    ENUM_TIMEFRAMES temp[10]; // Array temporário para construir lista
    int count = 0;

    // Adiciona timeframes habilitados pelo usuário (ordem crescente)
    if(UseM3)   
    {
        temp[count] = PERIOD_M3;
        count++;
    }
    if(UseM15)  
    {
        temp[count] = PERIOD_M15;
        count++;
    }
    if(UseH1)   
    {
        temp[count] = PERIOD_H1;
        count++;
    }
    if(UseD1)   
    {
        temp[count] = PERIOD_D1;
        count++;
    }

    // Se nenhum timeframe foi selecionado, usa configuração padrão
    if(count == 0)
    {
        temp[0] = PERIOD_M3;
        temp[1] = PERIOD_M15;
        temp[2] = PERIOD_H1;
        temp[3] = PERIOD_D1;
        count = 4;
    }

    // Redimensiona array final e copia timeframes válidos
    ArrayResize(timeframes, count);
    for(int i = 0; i < count; i++) 
    {
        timeframes[i] = temp[i];
    }

    // Log dos timeframes configurados
    Print("Timeframes configurados: ", count);
    for(int i = 0; i < count; i++)
    {
        Print("  [", i, "] ", EnumToString(timeframes[i]));
    }

    return count > 0;
}