# Fase 3: Desenvolvimento dos Módulos de Estratégia

## Resumo da Fase

A Fase 3 é dedicada ao desenvolvimento dos módulos de estratégia do Expert Advisor (EA), que são responsáveis pela geração de sinais de trading baseados em price action. Esta fase é crucial pois implementa o "cérebro" do EA, onde as decisões de trading são tomadas com base na análise do contexto de mercado.

Nesta fase, você irá desenvolver o módulo SignalEngine.mqh, que serve como o framework principal para todas as estratégias, e implementar módulos específicos para diferentes padrões de mercado, como o TrendRangeDay.mqh e o WedgeReversal.mqh.

Os principais objetivos desta fase são:
1. Desenvolver o esqueleto do módulo SignalEngine.mqh
2. Implementar estratégias específicas para cada fase de mercado (tendência, range, reversão)
3. Criar módulos dedicados para padrões complexos
4. Integrar o sistema de classificação de qualidade de setup

## Informações Requeridas pela Fase

Para completar esta fase com sucesso, você precisará das seguintes informações:

1. **Estrutura do SignalEngine**:
   - Interface principal para geração de sinais
   - Sistema de classificação de qualidade de setup
   - Mecanismo de integração com diferentes estratégias

2. **Estratégias para Mercados em Tendência**:
   - Spike & Channel
   - Pullback para EMAs
   - Breakout Pullback
   - Critérios de entrada e saída para cada estratégia

3. **Estratégias para Mercados em Range**:
   - Rejeição de extremos
   - Falha de rompimento
   - Critérios de entrada e saída para cada estratégia

4. **Estratégias para Mercados em Reversão**:
   - Padrões de reversão (double top/bottom, head and shoulders)
   - Divergências em indicadores
   - Critérios de entrada e saída para cada estratégia

5. **Padrões Específicos**:
   - Trending Trading Range Day (TrendRangeDay)
   - Cunha de alta/baixa (WedgeReversal)
   - Critérios de identificação e confirmação

## Arquivos Necessários

Para esta fase, você precisará criar os seguintes arquivos:

1. **SignalEngine.mqh**:
   - Framework principal para todas as estratégias

2. **strategies/TrendRangeDay.mqh**:
   - Implementação da estratégia Trending Trading Range Day

3. **strategies/WedgeReversal.mqh**:
   - Implementação da estratégia de Cunha de alta/baixa

## Prompt Completo para MANUS

Abaixo está um prompt completo que você pode enviar à MANUS para auxiliar no desenvolvimento dos módulos de estratégia:

```
Preciso de sua ajuda para desenvolver os módulos de estratégia de um Expert Advisor (EA) em MQL5. Este EA implementará estratégias de trading baseadas em price action, conforme detalhado no Capítulo 14 do Guia Completo de Trading.

## Tarefa 1: Desenvolvimento do Esqueleto do SignalEngine.mqh

Por favor, crie a estrutura básica do módulo SignalEngine.mqh com as seguintes características:

1. **Classe SignalEngine**:
   - Deve ter uma interface principal Generate() que recebe parâmetros do ativo e fase de mercado
   - Deve implementar um sistema de classificação de qualidade de setup (A+, B, C)
   - Deve ter uma estrutura para implementação de diferentes estratégias por fase de mercado

2. **Estrutura Básica**:
   ```mql5
   class SignalEngine {
   private:
      // Variáveis privadas para armazenar estado e configurações
      
   public:
      // Construtor e destrutor
      SignalEngine();
      ~SignalEngine();
      
      // Método principal para geração de sinais
      Signal Generate(string symbol, MARKET_PHASE phase, ENUM_TIMEFRAMES timeframe);
      
      // Métodos para estratégias específicas por fase de mercado
      Signal GenerateTrendSignals(string symbol, ENUM_TIMEFRAMES timeframe);
      Signal GenerateRangeSignals(string symbol, ENUM_TIMEFRAMES timeframe);
      Signal GenerateReversalSignals(string symbol, ENUM_TIMEFRAMES timeframe);
      
      // Método para classificação de qualidade de setup
      SETUP_QUALITY ClassifySetupQuality(string symbol, Signal &signal);
   };
   ```

3. **Implementação Básica dos Métodos**:
   - Implemente versões iniciais dos métodos que retornam sinais vazios ou nulos
   - Adicione comentários explicativos para cada método

## Tarefa 2: Implementação das Estratégias para Mercados em Tendência

Agora, implemente as estratégias para mercados em tendência no módulo SignalEngine.mqh:

1. **Spike & Channel**:
   - Identifica um movimento forte (spike) seguido por um canal de continuação
   - Entrada na quebra do canal na direção da tendência
   - Stop loss abaixo/acima do último swing low/high
   - Take profit baseado em extensão de Fibonacci

2. **Pullback para EMAs**:
   - Identifica pullbacks para EMAs importantes (20, 50) em tendência estabelecida
   - Entrada quando o preço toca a EMA e mostra rejeição (pin bar, engulfing)
   - Stop loss abaixo/acima do swing low/high recente
   - Take profit no próximo nível de resistência/suporte

3. **Breakout Pullback**:
   - Identifica breakouts de níveis importantes seguidos de pullback
   - Entrada no pullback quando mostra sinais de continuação
   - Stop loss abaixo/acima do nível de breakout
   - Take profit baseado em projeção do movimento anterior

Implemente cada estratégia como um método separado dentro da classe SignalEngine, e integre-os ao método GenerateTrendSignals().

## Tarefa 3: Implementação das Estratégias para Mercados em Range

Implemente as estratégias para mercados em range no módulo SignalEngine.mqh:

1. **Rejeição de Extremos**:
   - Identifica rejeições nos extremos do range (suporte/resistência)
   - Entrada após confirmação de rejeição (pin bar, engulfing)
   - Stop loss além do extremo testado
   - Take profit no extremo oposto do range

2. **Falha de Rompimento**:
   - Identifica tentativas fracassadas de romper os extremos do range
   - Entrada após confirmação da falha (padrão de reversão)
   - Stop loss além do ponto de falha
   - Take profit no extremo oposto do range

Implemente cada estratégia como um método separado dentro da classe SignalEngine, e integre-os ao método GenerateRangeSignals().

## Tarefa 4: Implementação das Estratégias para Mercados em Reversão

Implemente as estratégias para mercados em reversão no módulo SignalEngine.mqh:

1. **Padrões de Reversão**:
   - Identifica padrões como double top/bottom, head and shoulders
   - Entrada na quebra da neckline ou após confirmação
   - Stop loss acima/abaixo do último swing high/low
   - Take profit baseado na projeção do padrão

2. **Divergências**:
   - Identifica divergências entre preço e indicadores (RSI, MACD)
   - Entrada após confirmação de reversão
   - Stop loss acima/abaixo do último swing high/low
   - Take profit no próximo suporte/resistência importante

Implemente cada estratégia como um método separado dentro da classe SignalEngine, e integre-os ao método GenerateReversalSignals().

## Tarefa 5: Desenvolvimento do Módulo TrendRangeDay.mqh

Crie o módulo TrendRangeDay.mqh para implementar a estratégia Trending Trading Range Day:

1. **Classe TrendRangeDay**:
   ```mql5
   class TrendRangeDay {
   private:
      // Variáveis privadas para armazenar estado e configurações
      
   public:
      // Construtor e destrutor
      TrendRangeDay();
      ~TrendRangeDay();
      
      // Método para identificação do padrão
      bool Identify(string symbol, ENUM_TIMEFRAMES timeframe);
      
      // Método para geração de sinais
      Signal GenerateSignal(string symbol, ENUM_TIMEFRAMES timeframe);
      
      // Método para classificação de qualidade
      SETUP_QUALITY ClassifyQuality(string symbol, ENUM_TIMEFRAMES timeframe);
   };
   ```

2. **Implementação da Identificação do Padrão**:
   - Verifique se o mercado está em tendência no timeframe superior
   - Verifique se há formação de range no timeframe atual
   - Confirme que o range está alinhado com a direção da tendência

3. **Implementação da Geração de Sinais**:
   - Gere sinais de compra na quebra do topo do range em tendência de alta
   - Gere sinais de venda na quebra do fundo do range em tendência de baixa
   - Defina stop loss e take profit apropriados

## Tarefa 6: Desenvolvimento do Módulo WedgeReversal.mqh

Crie o módulo WedgeReversal.mqh para implementar a estratégia de Cunha de alta/baixa:

1. **Classe WedgeReversal**:
   ```mql5
   class WedgeReversal {
   private:
      // Variáveis privadas para armazenar estado e configurações
      
   public:
      // Construtor e destrutor
      WedgeReversal();
      ~WedgeReversal();
      
      // Método para identificação do padrão
      bool Identify(string symbol, ENUM_TIMEFRAMES timeframe, bool &isRising);
      
      // Método para geração de sinais
      Signal GenerateSignal(string symbol, ENUM_TIMEFRAMES timeframe);
      
      // Método para classificação de qualidade
      SETUP_QUALITY ClassifyQuality(string symbol, ENUM_TIMEFRAMES timeframe);
   };
   ```

2. **Implementação da Identificação do Padrão**:
   - Identifique sequências de topos e fundos convergentes
   - Verifique se a cunha é de alta (rising wedge) ou de baixa (falling wedge)
   - Confirme volume decrescente dentro da formação

3. **Implementação da Geração de Sinais**:
   - Gere sinais de venda na quebra do suporte em cunha de alta
   - Gere sinais de compra na quebra da resistência em cunha de baixa
   - Defina stop loss e take profit apropriados

## Requisitos Técnicos:
- Todo o código deve ser compatível com MQL5 Build 4885 ou superior
- Utilize programação orientada a objetos
- Implemente tratamento de erros adequado
- Documente todas as funções e classes com comentários explicativos
- Siga as convenções de nomenclatura padrão do MQL5
- Garanta que os módulos se integrem corretamente com os componentes desenvolvidos anteriormente (MarketContext, Utils)

Por favor, desenvolva cada componente separadamente e forneça o código completo com comentários explicativos. Após cada componente, farei uma revisão e solicitarei ajustes se necessário.
```

## Dicas e Melhores Práticas

1. **Estrutura Modular**:
   - Mantenha cada estratégia em um módulo separado para facilitar manutenção
   - Crie interfaces claras entre os módulos de estratégia e o SignalEngine

2. **Identificação de Padrões**:
   - Implemente algoritmos robustos para identificação de padrões
   - Utilize filtros para reduzir falsos positivos
   - Considere a análise multi-timeframe para confirmação

3. **Geração de Sinais**:
   - Defina claramente os critérios de entrada e saída
   - Implemente lógica para determinar a qualidade do setup
   - Garanta que os sinais incluam todas as informações necessárias para execução

4. **Classificação de Qualidade**:
   - Desenvolva critérios objetivos para classificação
   - Considere múltiplos fatores (contexto de mercado, confirmações, etc.)
   - Documente claramente o que constitui cada nível de qualidade

5. **Testes e Validação**:
   - Teste cada estratégia com dados históricos
   - Verifique a precisão da identificação de padrões
   - Valide a qualidade dos sinais gerados

6. **Integração**:
   - Garanta que os módulos de estratégia se integrem corretamente com o SignalEngine
   - Verifique a compatibilidade com os módulos desenvolvidos anteriormente
   - Teste o fluxo completo desde a detecção da fase até a geração do sinal

Ao seguir estas diretrizes, você estará desenvolvendo módulos de estratégia robustos e eficazes, que formarão o núcleo do seu Expert Advisor.
