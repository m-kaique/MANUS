# Fluxo Lógico do Expert Advisor IntegratedPA_EA

Este documento descreve de forma resumida o fluxo de execução do EA `IntegratedPA_EA`, destacando os principais componentes e a ordem de chamadas.

## Componentes Principais

- **Logger (`CLogger`)** – responsável por registrar mensagens e exportar logs.
- **CircuitBreaker (`CCircuitBreaker`)** – bloqueia operações em caso de erros consecutivos.
- **HandlePool (`CHandlePool`)** – gerencia handles de indicadores.
- **MarketContext (`CMarketContext`)** – analisa o contexto do mercado e determina a fase de mercado.
- **SetupClassifier (`CSetupClassifier`)** – classifica a qualidade dos setups.
- **SignalEngine (`CSignalEngine`)** – gera sinais de entrada conforme a fase de mercado.
- **RiskManager (`CRiskManager`)** – calcula tamanhos de posição, stop loss e take profit.
- **TradeExecutor (`CTradeExecutor`)** – executa ordens, gerencia trailing stop, breakeven e parciais.
- **TradingHoursManager (`CTradingHoursManager`)** – controla os horários em que o EA pode operar.
- **JSONLogger (`CJSONLogger`)** – registra ordens e eventos em JSON.

## Fluxo de Inicialização (OnInit)

1. Criação do `CLogger` e `CCircuitBreaker`.
2. Criação do `CJSONLogger` e início de sessão.
3. Configuração dos ativos via `SetupAssets`.
4. Inicialização do `CHandlePool`.
5. Criação e inicialização de `CMarketContext`, `CSetupClassifier` e `CSignalEngine`.
6. Criação de `CRiskManager` e configuração de parâmetros específicos (`ConfigureRiskParameters`).
7. Criação e inicialização do `CTradeExecutor`.
8. Criação e configuração do `CTradingHoursManager`.
9. Ajuste do controle de tempo (`EventSetTimer`) e preparação de estruturas auxiliares.

Trecho de código referente ao início da função `OnInit`:

```mql
int OnInit()
{
   // Inicializar o logger primeiro para registrar todo o processo
   g_logger = new CLogger();
   ...
```

## Loop Principal (OnTick)

A cada tick o EA executa os seguintes passos:

1. Atualiza ordens no JSON a cada 10 ticks.
2. Verifica se todos os componentes estão inicializados.
3. Atualiza horários de negociação via `TradingHoursManager`.
4. Chama `ManageOpenPositions` no `TradeExecutor` e atualiza informações de conta.
5. Processa sinais pendentes.
6. Para cada ativo habilitado:
   - Garante que o histórico está carregado e identifica nova barra.
   - Atualiza o contexto de mercado (`UpdateSymbol`) e determina a fase do mercado.
   - Gera um sinal com `GenerateSignalByPhase`.
   - Caso válido, tenta execução imediata (`TryImmediateExecution`) ou armazena como pendente.

Trecho representativo da função `OnTick`:

```mql
void OnTick()
{
   tickCounter++;

   if (tickCounter >= 10)
   {
      UpdateJSONOrders();
      tickCounter = 0;
   }
   ...
   g_tradeExecutor.ManageOpenPositions();
   g_riskManager.UpdateAccountInfo();
   ProcessPendingSignals();
   ...
   Signal signal = GenerateSignalByPhase(symbol, phase);
   if (signal.id > 0 && signal.quality != SETUP_INVALID)
   {
      if (!TryImmediateExecution(symbol, signal, phase))
         StorePendingSignal(signal, phase);
   }
}
```

## Rotina de Timer (OnTimer)

A cada 60 segundos são executadas tarefas de manutenção:

- Atualização do `TradingHoursManager`.
- Exportação periódica de logs.
- Relatório de breakeven e limpeza de sinais pendentes.

Trecho de código:

```mql
void OnTimer()
{
   if (g_logger == NULL)
      return;

   if (g_hoursManager != NULL)
      g_hoursManager.Update();

   datetime currentTime = TimeCurrent();
   if (currentTime - g_lastExportTime > 60)
      g_lastExportTime = currentTime;

   CleanupExpiredSignals();
}
```

## Tratamento de Eventos

- **OnTrade** – registra eventos de trade e atualiza informações de conta.
- **OnBookEvent** – atualiza profundidade de mercado quando há alteração no book.

Trecho do código `OnTrade`:

```mql
void OnTrade()
{
   if (g_logger == NULL)
      return;

   g_logger.Debug("Evento de trade detectado");

   if (g_riskManager != NULL)
      g_riskManager.UpdateAccountInfo();
}
```

## Finalização (OnDeinit)

Durante o encerramento do EA são executados:

1. Exportação final dos logs.
2. Liberação dos objetos na ordem inversa da criação (TradeExecutor, RiskManager, MarketContext etc.).
3. Encerramento do `CJSONLogger`.

Trecho de código:

```mql
void OnDeinit(const int reason)
{
   ...
   EventKillTimer();
   g_logger.ExportToCSV("IntegratedPA_EA_log.csv", "Timestamp,Level,Message", "");
   delete g_tradeExecutor;
   delete g_hoursManager;
   delete g_riskManager;
   ...
   if (g_jsonLogger != NULL)
   {
      g_jsonLogger.EndSession();
      delete g_jsonLogger;
      g_jsonLogger = NULL;
   }
}
```

## Funções Auxiliares de Destaque

- **SetupAssets** – prepara a lista de ativos e seus parâmetros (tamanhos de lote, risco, níveis de parcial etc.).
- **ConfigureRiskParameters** – registra cada ativo no `RiskManager` e define stops específicos.
- **ProcessPendingSignals / TryImmediateExecution** – controlam a fila de sinais e executam ordens quando possível.

Trecho de `SetupAssets`:

```mql
bool SetupAssets()
{
   int assetsCount = 0;
   if (EnableBTC)
      assetsCount++;
   ...
   g_logger.Info(StringFormat("Configurados %d ativos para operação com parâmetros CONSERVADORES", assetsCount));
   return true;
}
```

## Conclusão

O EA `IntegratedPA_EA` segue um fluxo estruturado:

1. **OnInit** cria e configura todos os componentes.
2. **OnTick** realiza gerenciamento contínuo de posições e geração/executação de sinais.
3. **OnTimer** executa manutenções periódicas.
4. **OnTrade** e **OnBookEvent** respondem a eventos do terminal.
5. **OnDeinit** finaliza recursos e registra os dados finais.

Com essa visão geral, é possível compreender como cada módulo interage e em que ponto do ciclo de vida do EA cada ação ocorre.

