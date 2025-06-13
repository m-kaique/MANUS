# Fase 1: Preparação e Planejamento

## Resumo da Fase

A Fase 1 é o alicerce para o desenvolvimento bem-sucedido do Expert Advisor (EA) em MQL5. Nesta etapa inicial, você irá configurar o ambiente de desenvolvimento, analisar detalhadamente o projeto, e preparar a estrutura necessária para as fases subsequentes. Esta fase é crucial para garantir que o desenvolvimento ocorra de forma organizada e eficiente, minimizando retrabalhos e problemas futuros.

Os principais objetivos desta fase são:
1. Configurar corretamente o ambiente de desenvolvimento MetaTrader 5
2. Criar a estrutura de diretórios do projeto
3. Analisar e decompor o projeto em componentes gerenciáveis
4. Preparar prompts específicos para a MANUS desenvolver cada componente

## Informações Requeridas pela Fase

Para completar esta fase com sucesso, você precisará das seguintes informações:

1. **Requisitos do Sistema**:
   - Versão do MetaTrader 5 (Build 4885 ou superior)
   - Configurações recomendadas para o MetaEditor

2. **Estrutura do Projeto**:
   - Hierarquia de diretórios completa
   - Nomenclatura padronizada para arquivos e módulos

3. **Detalhes da Metodologia**:
   - Capítulo 14 do Guia Completo de Trading (referência principal)
   - Componentes principais do EA
   - Fases de mercado a serem identificadas
   - Setups por fase de mercado
   - Sistema de gestão de risco
   - Fluxo operacional multi-símbolo

4. **Interfaces entre Módulos**:
   - Definição clara de como os módulos se comunicarão
   - Estruturas de dados compartilhadas
   - Fluxo de informações entre componentes

## Arquivos Necessários

Para esta fase, você precisará criar os seguintes arquivos:

1. **Diagrama de Fluxo do EA** (opcional, mas recomendado):
   - Pode ser criado em formato de imagem (.png, .jpg)
   - Ou em formato de texto descritivo (.md)

2. **Estrutura de Diretórios**:
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

3. **Documento de Análise do Projeto**:
   - Descrição detalhada dos componentes
   - Interfaces entre módulos
   - Requisitos específicos de cada componente

## Prompt Completo para MANUS

Abaixo está um prompt completo que você pode enviar à MANUS para auxiliar na fase de preparação e planejamento:

```
Preciso de sua ajuda para a fase de preparação e planejamento do desenvolvimento de um Expert Advisor (EA) em MQL5. Este EA implementará estratégias de trading baseadas em price action, conforme detalhado no Capítulo 14 do Guia Completo de Trading.

## Tarefas específicas:

1. **Análise da estrutura do projeto**:
   - Revise a seguinte estrutura de diretórios e sugira melhorias se necessário:
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

2. **Criação de um diagrama de fluxo**:
   - Desenvolva um diagrama de fluxo textual ou visual que mostre como os diferentes módulos do EA interagem entre si.
   - Destaque o fluxo de dados desde a análise de mercado até a execução de ordens.

3. **Definição de interfaces entre módulos**:
   - Para cada par de módulos que interagem diretamente, defina as interfaces de comunicação.
   - Especifique quais dados são passados entre os módulos e em que formato.

4. **Análise dos componentes principais**:
   - Detalhe as responsabilidades de cada componente:
     - MarketContext: Detecção de fases de mercado (tendência, range, reversão)
     - SignalEngine: Geração de sinais por fase de mercado
     - RiskManager: Gestão de risco e dimensionamento de posições
     - TradeExecutor: Execução e gestão de ordens
     - Logger: Registro de operações e métricas
     - Utils: Funções auxiliares e definições de indicadores

5. **Preparação para desenvolvimento iterativo**:
   - Sugira uma ordem de desenvolvimento dos componentes que minimize dependências.
   - Identifique quais componentes podem ser desenvolvidos em paralelo.

## Requisitos técnicos:
- O EA deve ser compatível com MetaTrader 5 Build 4885 ou superior.
- O EA deve suportar múltiplos ativos (BTC, WDO, WIN).
- As estratégias devem ser ativáveis individualmente.
- O sistema de gestão de risco deve ser adaptativo conforme a fase de mercado.

Por favor, forneça sua análise e recomendações em formato detalhado, incluindo justificativas para suas sugestões. Se possível, inclua exemplos de código para ilustrar como as interfaces entre módulos podem ser implementadas.
```

## Dicas e Melhores Práticas

1. **Planejamento Detalhado**:
   - Invista tempo suficiente nesta fase para evitar retrabalho nas fases posteriores
   - Documente todas as decisões de design e arquitetura

2. **Modularização Eficiente**:
   - Garanta que cada módulo tenha uma responsabilidade clara e bem definida
   - Minimize o acoplamento entre módulos para facilitar testes e manutenção

3. **Interfaces Claras**:
   - Defina com precisão como os módulos se comunicarão
   - Documente todas as estruturas de dados compartilhadas

4. **Preparação para Iterações**:
   - Planeje o desenvolvimento em incrementos testáveis
   - Identifique pontos de validação para cada componente

5. **Consulta ao Material de Referência**:
   - Mantenha o Capítulo 14 do Guia Completo de Trading sempre à mão
   - Extraia todos os detalhes relevantes para cada componente

Ao seguir estas diretrizes, você estará estabelecendo uma base sólida para o desenvolvimento bem-sucedido do seu Expert Advisor em MQL5.
