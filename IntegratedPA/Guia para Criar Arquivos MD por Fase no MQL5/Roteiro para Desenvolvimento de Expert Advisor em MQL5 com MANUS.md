# Roteiro para Desenvolvimento de Expert Advisor em MQL5 com MANUS

## Introdução

Este roteiro apresenta uma metodologia estruturada para desenvolver um Expert Advisor (EA) complexo em MQL5 utilizando a IA MANUS, respeitando as capacidades e limitações das IAs atuais, sem comprometer a qualidade da entrega final. O processo é dividido em fases iterativas, com pontos de validação e integração manual, garantindo um desenvolvimento eficiente e um produto final robusto.

O EA a ser desenvolvido implementará a metodologia descrita no Capítulo 14 do Guia Completo de Trading, com arquitetura modular, suporte a múltiplos ativos (BTC, WDO, WIN), estratégias ativáveis individualmente e sistema de gestão de risco adaptativo.

## Fase 1: Preparação e Planejamento

### 1.1. Configuração do Ambiente de Desenvolvimento

1. **Instalar MetaTrader 5** (versão compatível com Build 4885 ou superior)
2. **Configurar MetaEditor** para desenvolvimento em MQL5
3. **Criar estrutura de diretórios** para o projeto:
   ```
   /IntegratedPA_EA/
   ├── MQL5/
   │   ├── Experts/
   │   │   └── IntegratedPA_EA.mq5
   │   ├── Include/
   │   │   ├── IntegratedPA/
   │   │   │   ├── MarketContext.mqh
   │   │   │   ├── SignalEngine.mqh
   │   │   │   ├── RiskManager.mqh
   │   │   │   ├── TradeExecutor.mqh
   │   │   │   ├── Logger.mqh
   │   │   │   ├── Utils.mqh
   │   │   │   └── strategies/
   │   │   │       ├── TrendRangeDay.mqh
   │   │   │       └── WedgeReversal.mqh
   │   │   └── ...
   │   └── ...
   └── ...
   ```

### 1.2. Análise e Decomposição do Projeto

1. **Revisar detalhadamente** o Capítulo 14 do Guia Completo de Trading
2. **Identificar componentes principais** do EA:
   - Estrutura modular e interfaces entre módulos
   - Fases de mercado (tendência, range, reversão)
   - Setups por fase de mercado
   - Sistema de gestão de risco
   - Fluxo operacional multi-símbolo
3. **Criar diagrama de fluxo** do EA para visualizar a interação entre componentes
4. **Definir interfaces** entre os módulos para garantir integração coesa

### 1.3. Preparação dos Prompts para MANUS

1. **Dividir o projeto em componentes menores** que respeitem as limitações de contexto da IA
2. **Preparar prompts específicos** para cada componente, incluindo:
   - Descrição clara da funcionalidade
   - Interfaces com outros módulos
   - Exemplos de implementação quando disponíveis
   - Requisitos específicos de compatibilidade

## Fase 2: Desenvolvimento Iterativo dos Componentes Básicos

### 2.1. Desenvolvimento das Estruturas de Dados

1. **Solicitar à MANUS a criação das estruturas de dados fundamentais**:
   ```
   Prompt: "Crie as estruturas de dados fundamentais para o EA, incluindo:
   - Enumerações para fases de mercado (TREND, RANGE, REVERSAL)
   - Estrutura para parâmetros de ativos (AssetParams)
   - Estrutura para sinais de trading (Signal)
   - Estrutura para requisições de ordem (OrderRequest)
   - Estrutura para classificação de qualidade de setup (SETUP_A_PLUS, SETUP_B, SETUP_C)
   Garanta que as estruturas sejam compatíveis com MQL5 Build 4885 ou superior."
   ```

2. **Validar manualmente as estruturas geradas**:
   - Verificar compatibilidade com MQL5
   - Garantir que todas as propriedades necessárias estejam presentes
   - Corrigir possíveis erros ou inconsistências

3. **Refinar iterativamente** com feedback para a MANUS até obter estruturas robustas

### 2.2. Desenvolvimento do Módulo Utils.mqh

1. **Solicitar à MANUS a criação do módulo Utils.mqh**:
   ```
   Prompt: "Desenvolva o módulo Utils.mqh que conterá funções auxiliares e definições de indicadores, incluindo:
   - Definições de constantes para parâmetros de indicadores
   - Função CheckMeanReversion50to200() para filtro de média 50→200
   - Função GetFibLevels() para cálculo de níveis de Fibonacci
   - Funções auxiliares para cálculos e conversões
   Use os valores padrão especificados no prompt original."
   ```

2. **Validar e testar o módulo**:
   - Compilar no MetaEditor para verificar erros
   - Testar cada função individualmente
   - Corrigir problemas identificados

3. **Documentar funções e parâmetros** para facilitar integração posterior

### 2.3. Desenvolvimento do Módulo MarketContext.mqh

1. **Solicitar à MANUS a criação do módulo MarketContext.mqh**:
   ```
   Prompt: "Desenvolva o módulo MarketContext.mqh responsável pela detecção de fases de mercado (tendência, range, reversão), incluindo:
   - Função DetectPhase() que analisa múltiplos timeframes
   - Implementação dos critérios de identificação para cada fase
   - Integração com o módulo Utils.mqh
   Siga os critérios detalhados no Capítulo 14 para identificação de cada fase."
   ```

2. **Validar e refinar o módulo**:
   - Verificar implementação dos critérios de cada fase
   - Testar com dados históricos de diferentes ativos
   - Ajustar parâmetros conforme necessário

### 2.4. Desenvolvimento do Módulo Logger.mqh

1. **Solicitar à MANUS a criação do módulo Logger.mqh**:
   ```
   Prompt: "Desenvolva o módulo Logger.mqh para registro de operações, KPIs e exportação de dados, incluindo:
   - Funções para log de operações
   - Funções para cálculo e registro de métricas de desempenho
   - Funções para exportação de dados em formato CSV
   - Sistema de alertas para eventos importantes"
   ```

2. **Validar e testar o módulo**:
   - Verificar funcionalidade de registro
   - Testar exportação de dados
   - Garantir que não haja vazamento de memória

## Fase 3: Desenvolvimento dos Módulos de Estratégia

### 3.1. Desenvolvimento do Módulo SignalEngine.mqh

1. **Solicitar à MANUS a criação do esqueleto do módulo SignalEngine.mqh**:
   ```
   Prompt: "Crie a estrutura básica do módulo SignalEngine.mqh, responsável pela geração de sinais por fase de mercado, incluindo:
   - Interface principal Generate() que recebe parâmetros do ativo e fase de mercado
   - Estrutura para implementação de diferentes estratégias
   - Sistema de classificação de qualidade de setup (A+, B, C)
   Não implemente as estratégias específicas ainda, apenas a estrutura."
   ```

2. **Validar a estrutura** e refinar conforme necessário

3. **Solicitar à MANUS a implementação das estratégias de tendência**:
   ```
   Prompt: "Implemente as estratégias para mercados em tendência no módulo SignalEngine.mqh, incluindo:
   - Spike & Channel
   - Pullback para EMAs
   - Breakout Pullback
   Siga os critérios e exemplos detalhados no Capítulo 14."
   ```

4. **Validar e testar as estratégias de tendência**:
   - Verificar implementação dos critérios
   - Testar com dados históricos
   - Ajustar parâmetros conforme necessário

5. **Repetir o processo para estratégias de range e reversão**, solicitando à MANUS e validando cada conjunto

### 3.2. Desenvolvimento dos Módulos de Estratégias Específicas

1. **Solicitar à MANUS a criação do módulo TrendRangeDay.mqh**:
   ```
   Prompt: "Desenvolva o módulo TrendRangeDay.mqh para implementação da estratégia Trending Trading Range Day, incluindo:
   - Função para identificação do padrão
   - Função para geração de sinais
   - Integração com o sistema de classificação de qualidade
   Siga os critérios e exemplos detalhados no Capítulo 14."
   ```

2. **Validar e testar o módulo**

3. **Solicitar à MANUS a criação do módulo WedgeReversal.mqh**:
   ```
   Prompt: "Desenvolva o módulo WedgeReversal.mqh para implementação da estratégia de Cunha de alta/baixa, incluindo:
   - Função para identificação do padrão
   - Função para geração de sinais
   - Integração com o sistema de classificação de qualidade
   Siga os critérios e exemplos detalhados no Capítulo 14."
   ```

4. **Validar e testar o módulo**

## Fase 4: Desenvolvimento dos Módulos de Execução e Gestão de Risco

### 4.1. Desenvolvimento do Módulo RiskManager.mqh

1. **Solicitar à MANUS a criação do módulo RiskManager.mqh**:
   ```
   Prompt: "Desenvolva o módulo RiskManager.mqh para gestão de risco, incluindo:
   - Função BuildRequest() para criação de requisições de ordem
   - Sistema de parciais estruturado por ativo
   - Ajuste de tamanho de posição baseado na fase de mercado
   - Implementação de stops adaptativos
   Siga os critérios e exemplos detalhados no Capítulo 14."
   ```

2. **Validar e testar o módulo**:
   - Verificar cálculos de tamanho de posição
   - Testar sistema de parciais
   - Validar ajustes adaptativos

### 4.2. Desenvolvimento do Módulo TradeExecutor.mqh

1. **Solicitar à MANUS a criação do módulo TradeExecutor.mqh**:
   ```
   Prompt: "Desenvolva o módulo TradeExecutor.mqh para execução e gestão de ordens multi-símbolo, incluindo:
   - Função Execute() para envio de ordens
   - Função ManageOpenPositions() para gestão de posições abertas
   - Tratamento de erros e exceções
   - Implementação de trailing stops
   Garanta compatibilidade com MQL5 Build 4885 ou superior."
   ```

2. **Validar e testar o módulo**:
   - Verificar execução de ordens
   - Testar gestão de posições
   - Validar tratamento de erros

## Fase 5: Integração e Desenvolvimento do Arquivo Principal

### 5.1. Desenvolvimento do Arquivo Principal IntegratedPA_EA.mq5

1. **Solicitar à MANUS a criação do esqueleto do arquivo principal**:
   ```
   Prompt: "Crie a estrutura básica do arquivo IntegratedPA_EA.mq5, incluindo:
   - Declarações de propriedades (#property)
   - Inclusão dos módulos necessários
   - Declaração de variáveis globais
   - Estrutura das funções principais (OnInit, OnDeinit, OnTick, OnTimer)
   Não implemente a lógica completa ainda, apenas a estrutura."
   ```

2. **Validar a estrutura** e refinar conforme necessário

3. **Solicitar à MANUS a implementação da função OnInit()**:
   ```
   Prompt: "Implemente a função OnInit() no arquivo IntegratedPA_EA.mq5, incluindo:
   - Inicialização de variáveis
   - Configuração de parâmetros
   - Verificações de compatibilidade
   - Chamada à função SetAssets() para configuração dos ativos
   Garanta que todos os módulos sejam inicializados corretamente."
   ```

4. **Validar e testar a função**

5. **Solicitar à MANUS a implementação das demais funções principais**:
   - OnTick()
   - OnTimer()
   - OnDeinit()

6. **Validar e testar cada função** individualmente

### 5.2. Integração e Testes Iniciais

1. **Compilar o EA completo** no MetaEditor
2. **Corrigir erros de compilação** que possam surgir
3. **Realizar testes iniciais** em modo de visualização (sem execução real)
4. **Ajustar parâmetros e corrigir problemas** identificados

## Fase 6: Validação, Otimização e Documentação

### 6.1. Testes Abrangentes

1. **Realizar backtesting** em diferentes períodos e ativos
2. **Analisar resultados** e identificar pontos de melhoria
3. **Ajustar parâmetros** para otimizar desempenho
4. **Testar em diferentes condições de mercado** para validar robustez

### 6.2. Otimização de Código

1. **Revisar todo o código** em busca de:
   - Ineficiências
   - Vazamentos de memória
   - Possíveis bugs
   - Warnings de compilação
2. **Otimizar seções críticas** para melhor desempenho
3. **Garantir compatibilidade** com MetaEditor 5 Build 4885 ou superior

### 6.3. Criação de Presets

1. **Criar arquivo de preset BTC_Only.set**:
   ```
   Prompt: "Crie um arquivo de preset BTC_Only.set para o EA, configurando apenas o Bitcoin Futuros para operação, com parâmetros otimizados conforme os testes realizados."
   ```

2. **Criar arquivos de preset** para os demais cenários:
   - WDO_Only.set
   - WIN_Only.set
   - All_Assets.set

### 6.4. Documentação Técnica

1. **Solicitar à MANUS a criação do manual técnico**:
   ```
   Prompt: "Crie um manual técnico em formato Markdown para o EA, incluindo:
   - Visão geral da arquitetura
   - Descrição detalhada de cada módulo
   - Guia de configuração e parâmetros
   - Exemplos de uso
   - Guia de troubleshooting
   - Recomendações para backtesting
   Utilize uma linguagem clara e didática."
   ```

2. **Revisar e complementar o manual** conforme necessário

## Fase 7: Finalização e Entrega

1. **Realizar revisão final** de todos os componentes
2. **Compilar versão final** do EA
3. **Organizar todos os arquivos** para entrega:
   - Código-fonte (.mq5 e .mqh)
   - Presets (.set)
   - Manual técnico (Markdown e PDF)
   - Relatórios de backtesting
4. **Entregar o pacote completo** ao cliente

## Considerações Importantes para Trabalhar com a MANUS

### Maximizando a Eficiência da IA

1. **Dividir tarefas em componentes menores** que respeitem as limitações de contexto
2. **Fornecer exemplos claros** sempre que possível
3. **Especificar interfaces precisas** entre módulos
4. **Utilizar linguagem técnica precisa** nos prompts
5. **Revisar e validar cada componente** antes de avançar

### Pontos de Validação Manual Críticos

1. **Compilação no MetaEditor** para verificar compatibilidade e warnings
2. **Lógica de detecção de fases de mercado** (MarketContext.mqh)
3. **Implementação dos setups específicos** (SignalEngine.mqh)
4. **Cálculos de gestão de risco** (RiskManager.mqh)
5. **Execução de ordens e tratamento de erros** (TradeExecutor.mqh)
6. **Integração entre módulos** no arquivo principal

### Iteração e Refinamento

1. **Adotar abordagem iterativa** para cada componente
2. **Começar com versões simplificadas** e adicionar complexidade gradualmente
3. **Testar cada função individualmente** antes da integração
4. **Documentar ajustes manuais** para manter consistência

## Cronograma Estimado

| Fase | Descrição | Tempo Estimado |
|------|-----------|----------------|
| 1 | Preparação e Planejamento | 1-2 dias |
| 2 | Desenvolvimento dos Componentes Básicos | 3-4 dias |
| 3 | Desenvolvimento dos Módulos de Estratégia | 4-5 dias |
| 4 | Desenvolvimento dos Módulos de Execução e Gestão de Risco | 3-4 dias |
| 5 | Integração e Desenvolvimento do Arquivo Principal | 2-3 dias |
| 6 | Validação, Otimização e Documentação | 4-5 dias |
| 7 | Finalização e Entrega | 1-2 dias |
| **Total** | | **18-25 dias** |

## Conclusão

Este roteiro apresenta uma abordagem estruturada e iterativa para o desenvolvimento de um Expert Advisor complexo em MQL5 utilizando a IA MANUS. Ao dividir o projeto em componentes menores, com pontos de validação manual e integração gradual, é possível aproveitar as capacidades da IA enquanto se contorna suas limitações, garantindo um produto final robusto e profissional.

A chave para o sucesso está na combinação inteligente entre automação via IA e supervisão humana nos pontos críticos, resultando em um desenvolvimento mais eficiente sem comprometer a qualidade da entrega final.
