# Fase 2: Desenvolvimento Iterativo dos Componentes Básicos

## Resumo da Fase

A Fase 2 marca o início do desenvolvimento prático do Expert Advisor (EA), focando nos componentes fundamentais que servirão como base para todo o sistema. Nesta fase, você irá desenvolver as estruturas de dados essenciais e os módulos básicos que sustentarão as funcionalidades mais complexas nas fases posteriores.

O desenvolvimento iterativo permite que cada componente seja criado, testado e refinado individualmente, garantindo uma base sólida antes de avançar para implementações mais complexas. Esta abordagem minimiza erros e facilita a identificação e correção de problemas.

Os principais objetivos desta fase são:
1. Desenvolver as estruturas de dados fundamentais
2. Criar o módulo Utils.mqh com funções auxiliares
3. Implementar o módulo MarketContext.mqh para detecção de fases de mercado
4. Desenvolver o módulo Logger.mqh para registro de operações e métricas

## Informações Requeridas pela Fase

Para completar esta fase com sucesso, você precisará das seguintes informações:

1. **Estruturas de Dados**:
   - Enumerações para fases de mercado (TREND, RANGE, REVERSAL)
   - Estrutura para parâmetros de ativos (AssetParams)
   - Estrutura para sinais de trading (Signal)
   - Estrutura para requisições de ordem (OrderRequest)
   - Estrutura para classificação de qualidade de setup (SETUP_A_PLUS, SETUP_B, SETUP_C)

2. **Funções Auxiliares e Indicadores**:
   - Definições de constantes para parâmetros de indicadores
   - Implementação da função CheckMeanReversion50to200()
   - Implementação da função GetFibLevels()
   - Outras funções auxiliares para cálculos e conversões

3. **Critérios de Detecção de Fases de Mercado**:
   - Indicadores e parâmetros para identificação de tendência
   - Indicadores e parâmetros para identificação de range
   - Indicadores e parâmetros para identificação de reversão
   - Lógica de análise multi-timeframe

4. **Requisitos de Logging**:
   - Formato e conteúdo dos logs de operações
   - Métricas de desempenho a serem registradas
   - Formato para exportação de dados em CSV
   - Sistema de alertas para eventos importantes

## Arquivos Necessários

Para esta fase, você precisará criar os seguintes arquivos:

1. **Estruturas de Dados**:
   - Podem ser definidas em um arquivo separado ou incluídas nos módulos relevantes

2. **Utils.mqh**:
   - Contém funções auxiliares e definições de indicadores

3. **MarketContext.mqh**:
   - Implementa a detecção de fases de mercado

4. **Logger.mqh**:
   - Implementa o sistema de registro e métricas

## Prompt Completo para MANUS

Abaixo está um prompt completo que você pode enviar à MANUS para auxiliar no desenvolvimento dos componentes básicos:

```
Preciso de sua ajuda para desenvolver os componentes básicos de um Expert Advisor (EA) em MQL5. Este EA implementará estratégias de trading baseadas em price action, conforme detalhado no Capítulo 14 do Guia Completo de Trading.

## Tarefa 1: Criação das Estruturas de Dados Fundamentais

Por favor, crie as seguintes estruturas de dados em MQL5:

1. **Enumeração para Fases de Mercado**:
   ```mql5
   enum MARKET_PHASE {
      PHASE_TREND,    // Mercado em tendência
      PHASE_RANGE,    // Mercado em range
      PHASE_REVERSAL, // Mercado em reversão
      PHASE_UNDEFINED // Fase não definida
   };
   ```

2. **Estrutura para Parâmetros de Ativos**:
   - Deve incluir campos para:
     - Símbolo do ativo
     - Timeframe principal
     - Timeframes adicionais para análise
     - Parâmetros específicos do ativo (tamanho de tick, valor do pip, etc.)
     - Parâmetros de risco (tamanho máximo de posição, stop loss padrão, etc.)

3. **Estrutura para Sinais de Trading**:
   - Deve incluir campos para:
     - Direção do sinal (compra/venda)
     - Fase de mercado associada
     - Qualidade do setup (A+, B, C)
     - Níveis de entrada, stop loss e take profit
     - Timestamp de geração do sinal
     - Estratégia que gerou o sinal

4. **Estrutura para Requisições de Ordem**:
   - Deve incluir campos para:
     - Tipo de ordem (mercado, limite, stop)
     - Símbolo
     - Volume
     - Preço
     - Stop Loss
     - Take Profit
     - Comentário
     - Identificador único

5. **Estrutura para Classificação de Qualidade de Setup**:
   ```mql5
   enum SETUP_QUALITY {
      SETUP_A_PLUS, // Setup de alta qualidade
      SETUP_A,      // Setup de boa qualidade
      SETUP_B,      // Setup de qualidade média
      SETUP_C       // Setup de baixa qualidade
   };
   ```

## Tarefa 2: Desenvolvimento do Módulo Utils.mqh

Crie o módulo Utils.mqh com as seguintes funcionalidades:

1. **Definições de Constantes**:
   - Parâmetros padrão para indicadores (períodos de médias móveis, etc.)
   - Constantes para cálculos de risco
   - Outras constantes úteis para o EA

2. **Função CheckMeanReversion50to200**:
   - Implementar função que verifica se há reversão à média entre as EMAs de 50 e 200 períodos
   - A função deve retornar true se o preço estiver retornando à média após um desvio significativo

3. **Função GetFibLevels**:
   - Implementar função que calcula níveis de Fibonacci com base em um swing high e swing low
   - Deve retornar um array com os níveis 0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0, 1.272, 1.618

4. **Funções Auxiliares**:
   - NormalizePrice: Normaliza um preço de acordo com os ticks mínimos do ativo
   - CalculatePipValue: Calcula o valor de um pip para um determinado ativo
   - TimeframeToMinutes: Converte um timeframe em minutos
   - IsNewBar: Verifica se uma nova barra foi formada em um determinado timeframe

## Tarefa 3: Desenvolvimento do Módulo MarketContext.mqh

Crie o módulo MarketContext.mqh com as seguintes funcionalidades:

1. **Classe MarketContext**:
   - Deve ter métodos para inicialização e atualização do contexto de mercado
   - Deve implementar a função DetectPhase() que analisa múltiplos timeframes
   - Deve armazenar o estado atual e histórico recente das fases de mercado

2. **Implementação da Detecção de Tendência**:
   - Utilize médias móveis (EMA 20, 50, 200)
   - Verifique inclinação das médias
   - Analise padrões de preço (higher highs, higher lows para tendência de alta)
   - Considere indicadores de momentum (RSI, MACD)

3. **Implementação da Detecção de Range**:
   - Verifique se o preço está oscilando dentro de um canal horizontal
   - Analise a compressão de volatilidade (ATR em queda)
   - Verifique se as médias móveis estão planas

4. **Implementação da Detecção de Reversão**:
   - Identifique divergências em indicadores de momentum
   - Verifique padrões de reversão (double top/bottom, head and shoulders)
   - Analise quebras de suporte/resistência importantes

## Tarefa 4: Desenvolvimento do Módulo Logger.mqh

Crie o módulo Logger.mqh com as seguintes funcionalidades:

1. **Classe Logger**:
   - Deve ter métodos para inicialização e configuração do sistema de log
   - Deve implementar diferentes níveis de log (INFO, WARNING, ERROR, DEBUG)
   - Deve permitir logging em arquivo e console

2. **Funções para Log de Operações**:
   - LogSignal: Registra sinais gerados
   - LogTrade: Registra operações executadas
   - LogPosition: Registra status de posições abertas
   - LogPerformance: Registra métricas de desempenho

3. **Funções para Exportação de Dados**:
   - ExportToCSV: Exporta logs e métricas para arquivo CSV
   - Deve incluir cabeçalhos apropriados e formatação correta

4. **Sistema de Alertas**:
   - Implementar função SendAlert que pode enviar alertas via:
     - Notificação no terminal
     - Email (se configurado)
     - Notificação push (se configurado)

## Requisitos Técnicos:
- Todo o código deve ser compatível com MQL5 Build 4885 ou superior
- Utilize programação orientada a objetos quando apropriado
- Implemente tratamento de erros adequado
- Documente todas as funções e classes com comentários explicativos
- Siga as convenções de nomenclatura padrão do MQL5

Por favor, desenvolva cada componente separadamente e forneça o código completo com comentários explicativos. Após cada componente, farei uma revisão e solicitarei ajustes se necessário.
```

## Dicas e Melhores Práticas

1. **Desenvolvimento Iterativo**:
   - Desenvolva e teste cada componente individualmente antes de integrá-los
   - Comece com versões simplificadas e adicione complexidade gradualmente
   - Valide cada função antes de avançar

2. **Estruturas de Dados**:
   - Projete estruturas que sejam flexíveis e extensíveis
   - Documente claramente o propósito de cada campo
   - Utilize enumerações para valores que têm um conjunto finito de possibilidades

3. **Módulo Utils**:
   - Mantenha funções relacionadas agrupadas
   - Implemente funções genéricas que possam ser reutilizadas
   - Documente parâmetros e valores de retorno

4. **Detecção de Fases de Mercado**:
   - Implemente filtros para reduzir falsos positivos
   - Considere a análise multi-timeframe para confirmação
   - Adicione histerese para evitar mudanças frequentes de fase

5. **Sistema de Logging**:
   - Implemente diferentes níveis de verbosidade
   - Garanta que o logging não afete significativamente o desempenho
   - Inclua timestamps precisos em todos os logs

6. **Testes e Validação**:
   - Teste cada função com diferentes inputs
   - Verifique casos extremos e condições de erro
   - Valide os resultados com dados históricos conhecidos

Ao seguir estas diretrizes, você estará construindo uma base sólida para o seu Expert Advisor, facilitando o desenvolvimento das funcionalidades mais complexas nas próximas fases.
