//+------------------------------------------------------------------+
//|                                           SpikeAndChannel.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#ifndef SPIKEANDCHANNEL_MQH
#define SPIKEANDCHANNEL_MQH

#include "../Structures.mqh"
#include "../Utils.mqh"
#include "../Logger.mqh"
#include "../MarketContext.mqh"

//+------------------------------------------------------------------+
//| Enumeração para Tipos de Entrada no Padrão Spike & Channel       |
//+------------------------------------------------------------------+
enum SPIKE_CHANNEL_ENTRY_TYPE {
   ENTRY_PULLBACK_MINIMO,           // Entrada em pullback mínimo
   ENTRY_FECHAMENTO_FORTE,          // Entrada em fechamento forte
   ENTRY_PULLBACK_LINHA_TENDENCIA,  // Pullback para linha de tendência
   ENTRY_FALHA_PULLBACK             // Falha de pullback
};

//+------------------------------------------------------------------+
//| Estrutura para armazenar dados do padrão Spike & Channel         |
//+------------------------------------------------------------------+
struct SpikeChannelPattern {
   bool              isValid;           // Indica se o padrão é válido
   bool              isUptrend;         // Indica se é tendência de alta
   int               spikeStartBar;     // Barra de início do spike
   int               spikeEndBar;       // Barra de fim do spike
   int               channelStartBar;   // Barra de início do canal
   int               channelEndBar;     // Barra de fim do canal
   double            spikeHeight;       // Altura do spike em pontos
   double            channelHeight;     // Altura do canal em pontos
   double            trendLineSlope;    // Inclinação da linha de tendência
   double            trendLineValues[]; // Valores da linha de tendência
   
   // Construtor com valores padrão
   SpikeChannelPattern() {
      isValid = false;
      isUptrend = false;
      spikeStartBar = -1;
      spikeEndBar = -1;
      channelStartBar = -1;
      channelEndBar = -1;
      spikeHeight = 0.0;
      channelHeight = 0.0;
      trendLineSlope = 0.0;
      ArrayResize(trendLineValues, 0);
   }
};

//+------------------------------------------------------------------+
//| Classe para detecção e análise do padrão Spike & Channel         |
//+------------------------------------------------------------------+
class CSpikeAndChannel {
private:
   CLogger*          m_logger;           // Ponteiro para o logger
   CMarketContext*   m_marketContext;    // Ponteiro para o contexto de mercado
   
   // Configurações do padrão
   int               m_spikeMinBars;     // Mínimo de barras para spike
   int               m_spikeMaxBars;     // Máximo de barras para spike
   double            m_minSpikeBodyRatio; // Razão mínima corpo/sombra para spike
   double            m_minChannelPullbackRatio; // Razão mínima de pullback no canal
   int               m_lookbackBars;     // Número de barras para análise retroativa
   
   // Métodos privados para detecção do padrão
   bool DetectSpikePhase(string symbol, ENUM_TIMEFRAMES timeframe, int &startBar, int &endBar, bool &isUptrend);
   bool DetectChannelPhase(string symbol, ENUM_TIMEFRAMES timeframe, int spikeStartBar, int spikeEndBar, bool isUptrend, int &channelEndBar, double &trendLineSlope, double &trendLineValues[]);
   bool CalculateTrendLine(string symbol, ENUM_TIMEFRAMES timeframe, int startBar, int endBar, bool isUptrend, double &slope, double &values[]);

   bool CalculateLinearRegression(double &x[], double &y[], int n, double &a, double &b);

   // Métodos privados para detecção de entradas
   bool DetectPullbackMinimo(string symbol, ENUM_TIMEFRAMES timeframe, SpikeChannelPattern &pattern, int &entryBar, double &entryPrice, double &stopLoss);
   bool DetectFechamentoForte(string symbol, ENUM_TIMEFRAMES timeframe, SpikeChannelPattern &pattern, int &entryBar, double &entryPrice, double &stopLoss);
   bool DetectPullbackLinhaTendencia(string symbol, ENUM_TIMEFRAMES timeframe, SpikeChannelPattern &pattern, int &entryBar, double &entryPrice, double &stopLoss);
   bool DetectFalhaPullback(string symbol, ENUM_TIMEFRAMES timeframe, SpikeChannelPattern &pattern, int &entryBar, double &entryPrice, double &stopLoss);
   
   // Métodos auxiliares
   double CalculateBarBodyRatio(string symbol, ENUM_TIMEFRAMES timeframe, int bar);
   bool IsConsecutiveBar(string symbol, ENUM_TIMEFRAMES timeframe, int bar1, int bar2, bool isUptrend);
   double CalculateBarOverlap(string symbol, ENUM_TIMEFRAMES timeframe, int bar1, int bar2);
   
public:
   // Construtores e destrutor
   CSpikeAndChannel();
   CSpikeAndChannel(CLogger* logger, CMarketContext* marketContext);
   ~CSpikeAndChannel();
   
   // Método de inicialização
   bool Initialize(CLogger* logger, CMarketContext* marketContext);
   
   // Métodos de configuração
   void SetSpikeParameters(int minBars, int maxBars, double bodyRatio);
   void SetChannelParameters(double pullbackRatio);
   void SetLookbackBars(int bars) { m_lookbackBars = bars; }
   
   // Métodos principais
   bool DetectPattern(string symbol, ENUM_TIMEFRAMES timeframe, SpikeChannelPattern &pattern);
   bool FindEntrySetup(string symbol, ENUM_TIMEFRAMES timeframe, SpikeChannelPattern &pattern, SPIKE_CHANNEL_ENTRY_TYPE entryType, int &entryBar, double &entryPrice, double &stopLoss);
   
   // Método para gerar sinal
   Signal GenerateSignal(string symbol, ENUM_TIMEFRAMES timeframe, SpikeChannelPattern &pattern, SPIKE_CHANNEL_ENTRY_TYPE preferredEntryType);
};

//+------------------------------------------------------------------+
//| Construtor padrão                                                |
//+------------------------------------------------------------------+
CSpikeAndChannel::CSpikeAndChannel() {
   m_logger = NULL;
   m_marketContext = NULL;
   m_spikeMinBars = 2;
   m_spikeMaxBars = 5;
   m_minSpikeBodyRatio = 0.7;
   m_minChannelPullbackRatio = 0.3;
   m_lookbackBars = 100;
}

//+------------------------------------------------------------------+
//| Construtor com parâmetros                                        |
//+------------------------------------------------------------------+
CSpikeAndChannel::CSpikeAndChannel(CLogger* logger, CMarketContext* marketContext) {
   m_logger = logger;
   m_marketContext = marketContext;
   m_spikeMinBars = 2;
   m_spikeMaxBars = 5;
   m_minSpikeBodyRatio = 0.7;
   m_minChannelPullbackRatio = 0.3;
   m_lookbackBars = 100;
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CSpikeAndChannel::~CSpikeAndChannel() {
   // Não liberamos m_logger e m_marketContext aqui pois são apenas referências
}

//+------------------------------------------------------------------+
//| Inicializa o detector de padrão                                  |
//+------------------------------------------------------------------+
bool CSpikeAndChannel::Initialize(CLogger* logger, CMarketContext* marketContext) {
   if(logger == NULL || marketContext == NULL) {
      if(m_logger != NULL) {
         m_logger.Error("SpikeAndChannel: Falha na inicialização - parâmetros inválidos");
      }
      return false;
   }
   
   m_logger = logger;
   m_marketContext = marketContext;
   
   m_logger.Info("SpikeAndChannel inicializado com sucesso");
   return true;
}

//+------------------------------------------------------------------+
//| Configura parâmetros do spike                                    |
//+------------------------------------------------------------------+
void CSpikeAndChannel::SetSpikeParameters(int minBars, int maxBars, double bodyRatio) {
   m_spikeMinBars = minBars;
   m_spikeMaxBars = maxBars;
   m_minSpikeBodyRatio = bodyRatio;
   
   if(m_logger != NULL) {
      m_logger.Info(StringFormat("SpikeAndChannel: Parâmetros de Spike configurados - MinBars: %d, MaxBars: %d, BodyRatio: %.2f", 
                                minBars, maxBars, bodyRatio));
   }
}

//+------------------------------------------------------------------+
//| Configura parâmetros do canal                                    |
//+------------------------------------------------------------------+
void CSpikeAndChannel::SetChannelParameters(double pullbackRatio) {
   m_minChannelPullbackRatio = pullbackRatio;
   
   if(m_logger != NULL) {
      m_logger.Info(StringFormat("SpikeAndChannel: Parâmetros de Canal configurados - PullbackRatio: %.2f", pullbackRatio));
   }
}

//+------------------------------------------------------------------+
//| Detecta o padrão Spike & Channel                                 |
//+------------------------------------------------------------------+
bool CSpikeAndChannel::DetectPattern(string symbol, ENUM_TIMEFRAMES timeframe, SpikeChannelPattern &pattern) {
   // Inicializar a estrutura do padrão
   pattern.isValid = false;
   
   // Verificar se há barras suficientes
   int bars = Bars(symbol, timeframe);
   if(bars < m_lookbackBars) {
      if(m_logger != NULL) {
         m_logger.Warning(StringFormat("SpikeAndChannel: Barras insuficientes para %s em %s. Necessário: %d, Disponível: %d", 
                                     symbol, EnumToString(timeframe), m_lookbackBars, bars));
      }
      return false;
   }
   
   // Detectar fase de spike
   if(!DetectSpikePhase(symbol, timeframe, pattern.spikeStartBar, pattern.spikeEndBar, pattern.isUptrend)) {
      if(m_logger != NULL) {
         m_logger.Debug(StringFormat("SpikeAndChannel: Fase de Spike não detectada para %s", symbol));
      }
      return false;
   }
   
   // Calcular altura do spike
   double spikeHigh = 0, spikeLow = 0;
   for(int i = pattern.spikeStartBar; i >= pattern.spikeEndBar; i--) {
      double high = iHigh(symbol, timeframe, i);
      double low = iLow(symbol, timeframe, i);
      
      if(i == pattern.spikeStartBar || high > spikeHigh) spikeHigh = high;
      if(i == pattern.spikeStartBar || low < spikeLow) spikeLow = low;
   }
   pattern.spikeHeight = spikeHigh - spikeLow;
   
   // Detectar fase de canal
   pattern.channelStartBar = pattern.spikeEndBar;
   if(!DetectChannelPhase(symbol, timeframe, pattern.spikeStartBar, pattern.spikeEndBar, pattern.isUptrend, 
                         pattern.channelEndBar, pattern.trendLineSlope, pattern.trendLineValues)) {
      if(m_logger != NULL) {
         m_logger.Debug(StringFormat("SpikeAndChannel: Fase de Canal não detectada para %s após Spike", symbol));
      }
      return false;
   }
   
   // Calcular altura do canal
   double channelHigh = 0, channelLow = 0;
   for(int i = pattern.channelStartBar; i >= pattern.channelEndBar; i--) {
      double high = iHigh(symbol, timeframe, i);
      double low = iLow(symbol, timeframe, i);
      
      if(i == pattern.channelStartBar || high > channelHigh) channelHigh = high;
      if(i == pattern.channelStartBar || low < channelLow) channelLow = low;
   }
   pattern.channelHeight = channelHigh - channelLow;
   
   // Padrão válido
   pattern.isValid = true;
   
   if(m_logger != NULL) {
      m_logger.Info(StringFormat("SpikeAndChannel: Padrão detectado para %s - %s, Spike: %d-%d, Canal: %d-%d", 
                                symbol, pattern.isUptrend ? "Alta" : "Baixa", 
                                pattern.spikeStartBar, pattern.spikeEndBar, 
                                pattern.channelStartBar, pattern.channelEndBar));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Detecta a fase de Spike                                          |
//+------------------------------------------------------------------+
bool CSpikeAndChannel::DetectSpikePhase(string symbol, ENUM_TIMEFRAMES timeframe, int &startBar, int &endBar, bool &isUptrend) {
   // Verificar tendência atual
   if(m_marketContext != NULL) {
      isUptrend = m_marketContext.IsTrendUp();
      bool isDowntrend = m_marketContext.IsTrendDown();
      
      if(!isUptrend && !isDowntrend) {
         if(m_logger != NULL) {
            m_logger.Debug(StringFormat("SpikeAndChannel: Sem tendência definida para %s", symbol));
         }
         return false;
      }
   } else {
      // Determinar tendência com base nos preços recentes
      double ma20 = iMA(symbol, timeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
      double ma50 = iMA(symbol, timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
      
      isUptrend = (ma20 > ma50);
   }
   
   // Procurar por sequência de barras consecutivas na direção da tendência
   int consecutiveBars = 0;
   int maxConsecutive = 0;
   int tempStartBar = -1;
   int tempEndBar = -1;
   
   // Analisar as últimas m_lookbackBars barras
   for(int i = m_lookbackBars - 1; i >= 1; i--) {
      bool isDirectionalBar = false;
      
      if(isUptrend) {
         // Em tendência de alta, procurar por barras de alta consecutivas
         if(iClose(symbol, timeframe, i) > iOpen(symbol, timeframe, i) && 
            CalculateBarBodyRatio(symbol, timeframe, i) >= m_minSpikeBodyRatio) {
            isDirectionalBar = true;
         }
      } else {
         // Em tendência de baixa, procurar por barras de baixa consecutivas
         if(iClose(symbol, timeframe, i) < iOpen(symbol, timeframe, i) && 
            CalculateBarBodyRatio(symbol, timeframe, i) >= m_minSpikeBodyRatio) {
            isDirectionalBar = true;
         }
      }
      
      if(isDirectionalBar) {
         // Verificar se é uma barra consecutiva
         if(consecutiveBars == 0 || IsConsecutiveBar(symbol, timeframe, i+1, i, isUptrend)) {
            if(consecutiveBars == 0) tempStartBar = i;
            consecutiveBars++;
            tempEndBar = i;
         } else {
            // Reiniciar contagem se não for consecutiva
            if(consecutiveBars >= m_spikeMinBars && consecutiveBars <= m_spikeMaxBars && 
               consecutiveBars > maxConsecutive) {
               maxConsecutive = consecutiveBars;
               startBar = tempStartBar;
               endBar = tempEndBar;
            }
            consecutiveBars = 1;
            tempStartBar = i;
            tempEndBar = i;
         }
      } else {
         // Verificar se temos um spike válido antes de reiniciar
         if(consecutiveBars >= m_spikeMinBars && consecutiveBars <= m_spikeMaxBars && 
            consecutiveBars > maxConsecutive) {
            maxConsecutive = consecutiveBars;
            startBar = tempStartBar;
            endBar = tempEndBar;
         }
         consecutiveBars = 0;
      }
   }
   
   // Verificar última sequência
   if(consecutiveBars >= m_spikeMinBars && consecutiveBars <= m_spikeMaxBars && 
      consecutiveBars > maxConsecutive) {
      maxConsecutive = consecutiveBars;
      startBar = tempStartBar;
      endBar = tempEndBar;
   }
   
   // Verificar se encontramos um spike válido
   if(maxConsecutive >= m_spikeMinBars && maxConsecutive <= m_spikeMaxBars) {
      if(m_logger != NULL) {
         m_logger.Debug(StringFormat("SpikeAndChannel: Spike detectado para %s - %s, Barras: %d, Índices: %d-%d", 
                                   symbol, isUptrend ? "Alta" : "Baixa", maxConsecutive, startBar, endBar));
      }
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Detecta a fase de Canal - VERSÃO CORRIGIDA                       |
//+------------------------------------------------------------------+
bool CSpikeAndChannel::DetectChannelPhase(string symbol, ENUM_TIMEFRAMES timeframe, int spikeStartBar, int spikeEndBar, bool isUptrend, int &channelEndBar, double &trendLineSlope, double &trendLineValues[]) {
   // O canal começa onde o spike termina
   int channelStartBar = spikeEndBar;
   
   // Calcular altura do spike para referência
   double spikeHigh = 0, spikeLow = 0;
   for(int i = spikeStartBar; i >= spikeEndBar; i--) {
      double high = iHigh(symbol, timeframe, i);
      double low = iLow(symbol, timeframe, i);
      
      if(i == spikeStartBar || high > spikeHigh) spikeHigh = high;
      if(i == spikeStartBar || low < spikeLow) spikeLow = low;
   }
   double spikeHeight = spikeHigh - spikeLow;
   
   // Procurar pelo fim do canal (limitar a um máximo razoável)
   int maxChannelBars = 30; // Máximo de 30 barras para o canal
   int pullbackCount = 0;
   int consecutiveCounter = 0;
   channelEndBar = MathMax(0, channelStartBar - maxChannelBars); // Padrão: máximo de 30 barras
   
   // Calcular linha de tendência inicial com tamanho fixo
   int initialChannelSize = MathMin(10, channelStartBar + 1); // Máximo 10 barras ou até barra 0
   if(!CalculateTrendLine(symbol, timeframe, channelStartBar, MathMax(0, channelStartBar - initialChannelSize + 1), isUptrend, trendLineSlope, trendLineValues)) {
      return false;
   }
   
   // *** CORREÇÃO PRINCIPAL: Calcular índice corretamente ***
   // O array trendLineValues tem índices de 0 até (channelStartBar - channelEndUsedForTrendLine)
   int trendLineStartBar = channelStartBar;
   int trendLineEndBar = MathMax(0, channelStartBar - initialChannelSize + 1);
   int arraySize = ArraySize(trendLineValues);
   
   // Analisar as barras após o spike
   for(int i = channelStartBar - 1; i >= MathMax(0, channelStartBar - maxChannelBars); i--) {
      
      // *** CORREÇÃO: Calcular índice baseado na posição relativa na linha de tendência ***
      int relativeIndex = trendLineStartBar - i;
      
      // *** PROTEÇÃO ROBUSTA: Verificar se o índice está dentro dos limites ***
      if(relativeIndex < 0 || relativeIndex >= arraySize) {
         if(m_logger != NULL) {
            m_logger.Debug(StringFormat("SpikeAndChannel: Índice %d fora dos limites válidos (0-%d) para barra %d", 
                                       relativeIndex, arraySize-1, i));
         }
         continue; // Pular esta barra
      }
      
      double trendLineValue = trendLineValues[relativeIndex];
      
      if(isUptrend) {
         // Em tendência de alta, verificar se o preço respeita o suporte
         if(iLow(symbol, timeframe, i) < trendLineValue - m_minChannelPullbackRatio * spikeHeight) {
            // Pullback muito profundo, possível fim do canal
            pullbackCount++;
            
            if(pullbackCount >= 2) {
               channelEndBar = i + 1; // Barra anterior ao pullback profundo
               break;
            }
         } else if(iHigh(symbol, timeframe, i) > iHigh(symbol, timeframe, i+1) + spikeHeight * 0.5) {
            // Movimento muito forte para cima, possível novo spike
            consecutiveCounter++;
            
            if(consecutiveCounter >= 3) {
               channelEndBar = i + 3; // Algumas barras antes do novo spike
               break;
            }
         } else {
            consecutiveCounter = 0;
         }
      } else {
         // Em tendência de baixa, verificar se o preço respeita a resistência
         if(iHigh(symbol, timeframe, i) > trendLineValue + m_minChannelPullbackRatio * spikeHeight) {
            // Pullback muito alto, possível fim do canal
            pullbackCount++;
            
            if(pullbackCount >= 2) {
               channelEndBar = i + 1; // Barra anterior ao pullback alto
               break;
            }
         } else if(iLow(symbol, timeframe, i) < iLow(symbol, timeframe, i+1) - spikeHeight * 0.5) {
            // Movimento muito forte para baixo, possível novo spike
            consecutiveCounter++;
            
            if(consecutiveCounter >= 3) {
               channelEndBar = i + 3; // Algumas barras antes do novo spike
               break;
            }
         } else {
            consecutiveCounter = 0;
         }
      }
   }
   
   // Verificar se o canal é longo o suficiente
   if(channelStartBar - channelEndBar < 5) {
      if(m_logger != NULL) {
         m_logger.Debug(StringFormat("SpikeAndChannel: Canal muito curto para %s: %d barras", 
                                   symbol, channelStartBar - channelEndBar));
      }
      return false;
   }
   
   // *** RECALCULAR linha de tendência com o canal final completo ***
   if(!CalculateTrendLine(symbol, timeframe, channelStartBar, channelEndBar, isUptrend, trendLineSlope, trendLineValues)) {
      if(m_logger != NULL) {
         m_logger.Warning(StringFormat("SpikeAndChannel: Falha ao recalcular linha de tendência para canal final de %s", symbol));
      }
      return false;
   }
   
   if(m_logger != NULL) {
      m_logger.Debug(StringFormat("SpikeAndChannel: Canal detectado para %s - %s, Barras: %d, Índices: %d-%d, Array size: %d", 
                                symbol, isUptrend ? "Alta" : "Baixa", 
                                channelStartBar - channelEndBar, channelStartBar, channelEndBar, ArraySize(trendLineValues)));
   }
   
   return true;
}
//+------------------------------------------------------------------+
//| Calcula a linha de tendência                                     |
//+------------------------------------------------------------------+
bool CSpikeAndChannel::CalculateTrendLine(string symbol, ENUM_TIMEFRAMES timeframe, int startBar, int endBar, bool isUptrend, double &slope, double &values[]) {
   // Verificar parâmetros
   if(startBar <= endBar) {
      if(m_logger != NULL) {
         m_logger.Error("SpikeAndChannel: Parâmetros inválidos para cálculo de linha de tendência");
      }
      return false;
   }
   
   int numBars = startBar - endBar + 1;
   
   // Redimensionar array de valores
   if(ArraySize(values) < numBars) {
      if(!ArrayResize(values, numBars)) {
         if(m_logger != NULL) {
            m_logger.Error("SpikeAndChannel: Falha ao redimensionar array para linha de tendência");
         }
         return false;
      }
   }
   
   // Coletar pontos para regressão linear
   double xValues[], yValues[];
   ArrayResize(xValues, numBars);
   ArrayResize(yValues, numBars);
   
   int index = 0;
   for(int i = startBar; i >= endBar; i--) {
      xValues[index] = index;
      
      if(isUptrend) {
         // Em tendência de alta, usar mínimas para a linha de suporte
         yValues[index] = iLow(symbol, timeframe, i);
      } else {
         // Em tendência de baixa, usar máximas para a linha de resistência
         yValues[index] = iHigh(symbol, timeframe, i);
      }
      
      index++;
   }
   
   // Calcular regressão linear
   double a, b;
   if(!CalculateLinearRegression(xValues, yValues, numBars, a, b)) {
      if(m_logger != NULL) {
         m_logger.Error("SpikeAndChannel: Falha ao calcular regressão linear");
      }
      return false;
   }
   
   // Armazenar inclinação
   slope = b;
   
   // Calcular valores da linha de tendência
   for(int i = 0; i < numBars; i++) {
      values[i] = a + b * i;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calcula regressão linear (y = a + b*x)                           |
//+------------------------------------------------------------------+
bool CSpikeAndChannel::CalculateLinearRegression(double &x[], double &y[], int n, double &a, double &b) {
   if(n < 2) return false;
   
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
   
   for(int i = 0; i < n; i++) {
      sumX += x[i];
      sumY += y[i];
      sumXY += x[i] * y[i];
      sumX2 += x[i] * x[i];
   }
   
   double denominator = n * sumX2 - sumX * sumX;
   
   if(MathAbs(denominator) < 1e-10) return false;
   
   b = (n * sumXY - sumX * sumY) / denominator;
   a = (sumY - b * sumX) / n;
   
   return true;
}

//+------------------------------------------------------------------+
//| Calcula a razão corpo/total da barra                             |
//+------------------------------------------------------------------+
double CSpikeAndChannel::CalculateBarBodyRatio(string symbol, ENUM_TIMEFRAMES timeframe, int bar) {
   double open = iOpen(symbol, timeframe, bar);
   double close = iClose(symbol, timeframe, bar);
   double high = iHigh(symbol, timeframe, bar);
   double low = iLow(symbol, timeframe, bar);
   
   double bodySize = MathAbs(close - open);
   double totalSize = high - low;
   
   if(totalSize < 1e-10) return 0;
   
   return bodySize / totalSize;
}

//+------------------------------------------------------------------+
//| Verifica se duas barras são consecutivas na direção da tendência |
//+------------------------------------------------------------------+
bool CSpikeAndChannel::IsConsecutiveBar(string symbol, ENUM_TIMEFRAMES timeframe, int bar1, int bar2, bool isUptrend) {
   if(isUptrend) {
      // Em tendência de alta, verificar se a segunda barra continua o movimento
      return iLow(symbol, timeframe, bar2) >= iLow(symbol, timeframe, bar1) - 
             (iHigh(symbol, timeframe, bar1) - iLow(symbol, timeframe, bar1)) * 0.3;
   } else {
      // Em tendência de baixa, verificar se a segunda barra continua o movimento
      return iHigh(symbol, timeframe, bar2) <= iHigh(symbol, timeframe, bar1) + 
             (iHigh(symbol, timeframe, bar1) - iLow(symbol, timeframe, bar1)) * 0.3;
   }
}

//+------------------------------------------------------------------+
//| Calcula a sobreposição entre duas barras                         |
//+------------------------------------------------------------------+
double CSpikeAndChannel::CalculateBarOverlap(string symbol, ENUM_TIMEFRAMES timeframe, int bar1, int bar2) {
   double high1 = iHigh(symbol, timeframe, bar1);
   double low1 = iLow(symbol, timeframe, bar1);
   double high2 = iHigh(symbol, timeframe, bar2);
   double low2 = iLow(symbol, timeframe, bar2);
   
   double overlapHigh = MathMin(high1, high2);
   double overlapLow = MathMax(low1, low2);
   double overlap = overlapHigh - overlapLow;
   
   if(overlap < 0) return 0;
   
   double range1 = high1 - low1;
   double range2 = high2 - low2;
   
   if(range1 < 1e-10 || range2 < 1e-10) return 0;
   
   return overlap / MathMin(range1, range2);
}

//+------------------------------------------------------------------+
//| Encontra setup de entrada com base no tipo preferido             |
//+------------------------------------------------------------------+
bool CSpikeAndChannel::FindEntrySetup(string symbol, ENUM_TIMEFRAMES timeframe, SpikeChannelPattern &pattern, SPIKE_CHANNEL_ENTRY_TYPE entryType, int &entryBar, double &entryPrice, double &stopLoss) {
   // Verificar se o padrão é válido
   if(!pattern.isValid) {
      if(m_logger != NULL) {
         m_logger.Warning("SpikeAndChannel: Tentativa de encontrar entrada em padrão inválido");
      }
      return false;
   }
   
   // Tentar encontrar entrada com base no tipo preferido
   switch(entryType) {
      case ENTRY_PULLBACK_MINIMO:
         return DetectPullbackMinimo(symbol, timeframe, pattern, entryBar, entryPrice, stopLoss);
         
      case ENTRY_FECHAMENTO_FORTE:
         return DetectFechamentoForte(symbol, timeframe, pattern, entryBar, entryPrice, stopLoss);
         
      case ENTRY_PULLBACK_LINHA_TENDENCIA:
         return DetectPullbackLinhaTendencia(symbol, timeframe, pattern, entryBar, entryPrice, stopLoss);
         
      case ENTRY_FALHA_PULLBACK:
         return DetectFalhaPullback(symbol, timeframe, pattern, entryBar, entryPrice, stopLoss);
         
      default:
         // Tentar todos os tipos em ordem de preferência
         if(DetectPullbackLinhaTendencia(symbol, timeframe, pattern, entryBar, entryPrice, stopLoss))
            return true;
            
         if(DetectFalhaPullback(symbol, timeframe, pattern, entryBar, entryPrice, stopLoss))
            return true;
            
         if(DetectPullbackMinimo(symbol, timeframe, pattern, entryBar, entryPrice, stopLoss))
            return true;
            
         if(DetectFechamentoForte(symbol, timeframe, pattern, entryBar, entryPrice, stopLoss))
            return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Detecta entrada em pullback mínimo                               |
//+------------------------------------------------------------------+
bool CSpikeAndChannel::DetectPullbackMinimo(string symbol, ENUM_TIMEFRAMES timeframe, SpikeChannelPattern &pattern, int &entryBar, double &entryPrice, double &stopLoss) {
   // Esta entrada é mais comum durante a fase de spike
   
   // Procurar por uma pequena hesitação (1-2 barras menores)
   for(int i = pattern.spikeEndBar - 1; i >= MathMax(pattern.channelEndBar, 0); i--) {
      bool isHesitation = false;
      
      if(pattern.isUptrend) {
         // Em tendência de alta, procurar por barra menor ou doji
         if(CalculateBarBodyRatio(symbol, timeframe, i) < 0.5 || 
            iHigh(symbol, timeframe, i) < iHigh(symbol, timeframe, i+1)) {
            isHesitation = true;
         }
      } else {
         // Em tendência de baixa, procurar por barra menor ou doji
         if(CalculateBarBodyRatio(symbol, timeframe, i) < 0.5 || 
            iLow(symbol, timeframe, i) > iLow(symbol, timeframe, i+1)) {
            isHesitation = true;
         }
      }
      
      if(isHesitation) {
         // Verificar se a próxima barra retoma o movimento
         if(i > 0) {
            if(pattern.isUptrend) {
               if(iClose(symbol, timeframe, i-1) > iOpen(symbol, timeframe, i-1) && 
                  iClose(symbol, timeframe, i-1) > iClose(symbol, timeframe, i)) {
                  // Entrada na próxima barra após confirmação
                  entryBar = i-1;
                  entryPrice = iClose(symbol, timeframe, i-1);
                  stopLoss = iLow(symbol, timeframe, i) - (iHigh(symbol, timeframe, i) - iLow(symbol, timeframe, i)) * 0.1;
                  
                  if(m_logger != NULL) {
                     m_logger.Info(StringFormat("SpikeAndChannel: Entrada Pullback Mínimo detectada para %s em barra %d", 
                                             symbol, entryBar));
                  }
                  
                  return true;
               }
            } else {
               if(iClose(symbol, timeframe, i-1) < iOpen(symbol, timeframe, i-1) && 
                  iClose(symbol, timeframe, i-1) < iClose(symbol, timeframe, i)) {
                  // Entrada na próxima barra após confirmação
                  entryBar = i-1;
                  entryPrice = iClose(symbol, timeframe, i-1);
                  stopLoss = iHigh(symbol, timeframe, i) + (iHigh(symbol, timeframe, i) - iLow(symbol, timeframe, i)) * 0.1;
                  
                  if(m_logger != NULL) {
                     m_logger.Info(StringFormat("SpikeAndChannel: Entrada Pullback Mínimo detectada para %s em barra %d", 
                                             symbol, entryBar));
                  }
                  
                  return true;
               }
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Detecta entrada em fechamento forte                              |
//+------------------------------------------------------------------+
bool CSpikeAndChannel::DetectFechamentoForte(string symbol, ENUM_TIMEFRAMES timeframe, SpikeChannelPattern &pattern, int &entryBar, double &entryPrice, double &stopLoss) {
   // Esta entrada é mais comum durante a fase de spike
   
   // Procurar por uma barra com fechamento forte na direção do impulso
   for(int i = pattern.spikeEndBar - 1; i >= MathMax(pattern.channelEndBar, 0); i--) {
      bool isStrongClose = false;
      
      if(pattern.isUptrend) {
         // Em tendência de alta, procurar por barra de alta com fechamento forte
         if(iClose(symbol, timeframe, i) > iOpen(symbol, timeframe, i) && 
            CalculateBarBodyRatio(symbol, timeframe, i) > 0.7 && 
            iClose(symbol, timeframe, i) > iClose(symbol, timeframe, i+1)) {
            isStrongClose = true;
         }
      } else {
         // Em tendência de baixa, procurar por barra de baixa com fechamento forte
         if(iClose(symbol, timeframe, i) < iOpen(symbol, timeframe, i) && 
            CalculateBarBodyRatio(symbol, timeframe, i) > 0.7 && 
            iClose(symbol, timeframe, i) < iClose(symbol, timeframe, i+1)) {
            isStrongClose = true;
         }
      }
      
      if(isStrongClose) {
         // Entrada na próxima barra
         entryBar = i;
         
         if(pattern.isUptrend) {
            entryPrice = iHigh(symbol, timeframe, i) + (iHigh(symbol, timeframe, i) - iLow(symbol, timeframe, i)) * 0.1;
            stopLoss = iLow(symbol, timeframe, i) - (iHigh(symbol, timeframe, i) - iLow(symbol, timeframe, i)) * 0.1;
         } else {
            entryPrice = iLow(symbol, timeframe, i) - (iHigh(symbol, timeframe, i) - iLow(symbol, timeframe, i)) * 0.1;
            stopLoss = iHigh(symbol, timeframe, i) + (iHigh(symbol, timeframe, i) - iLow(symbol, timeframe, i)) * 0.1;
         }
         
         if(m_logger != NULL) {
            m_logger.Info(StringFormat("SpikeAndChannel: Entrada Fechamento Forte detectada para %s em barra %d", 
                                     symbol, entryBar));
         }
         
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Detecta entrada em pullback para linha de tendência - CORRIGIDO  |
//+------------------------------------------------------------------+
bool CSpikeAndChannel::DetectPullbackLinhaTendencia(string symbol, ENUM_TIMEFRAMES timeframe, SpikeChannelPattern &pattern, int &entryBar, double &entryPrice, double &stopLoss) {
   // Verificar se temos valores de linha de tendência
   if(ArraySize(pattern.trendLineValues) == 0) {
      if(m_logger != NULL) {
         m_logger.Warning("SpikeAndChannel: Array trendLineValues vazio em DetectPullbackLinhaTendencia");
      }
      return false;
   }
   
   int arraySize = ArraySize(pattern.trendLineValues);
   
   // Procurar por pullback que teste a linha de tendência
   for(int i = pattern.channelStartBar - 1; i >= MathMax(pattern.channelEndBar, 0); i--) {
      
      // *** CORREÇÃO: Calcular índice relativo baseado no início do canal ***
      int relativeIndex = pattern.channelStartBar - i;
      
      // *** PROTEÇÃO: Verificar limites do array ***
      if(relativeIndex < 0 || relativeIndex >= arraySize) {
         if(m_logger != NULL) {
            m_logger.Debug(StringFormat("SpikeAndChannel: Índice %d fora dos limites em DetectPullbackLinhaTendencia (array size: %d)", 
                                       relativeIndex, arraySize));
         }
         continue;
      }
      
      double trendLineValue = pattern.trendLineValues[relativeIndex];
      bool isTouchingTrendLine = false;
      
      if(pattern.isUptrend) {
         // Em tendência de alta, verificar se o preço testa o suporte
         if(iLow(symbol, timeframe, i) <= trendLineValue + pattern.spikeHeight * 0.05 && 
            iLow(symbol, timeframe, i) >= trendLineValue - pattern.spikeHeight * 0.05) {
            isTouchingTrendLine = true;
         }
      } else {
         // Em tendência de baixa, verificar se o preço testa a resistência
         if(iHigh(symbol, timeframe, i) >= trendLineValue - pattern.spikeHeight * 0.05 && 
            iHigh(symbol, timeframe, i) <= trendLineValue + pattern.spikeHeight * 0.05) {
            isTouchingTrendLine = true;
         }
      }
      
      if(isTouchingTrendLine) {
         // Verificar se há confirmação de reversão
         if(i > 0) {
            bool isReversal = false;
            
            if(pattern.isUptrend) {
               // Em tendência de alta, procurar por barra de alta após teste do suporte
               if(iClose(symbol, timeframe, i-1) > iOpen(symbol, timeframe, i-1) && 
                  iLow(symbol, timeframe, i-1) > iLow(symbol, timeframe, i)) {
                  isReversal = true;
               }
            } else {
               // Em tendência de baixa, procurar por barra de baixa após teste da resistência
               if(iClose(symbol, timeframe, i-1) < iOpen(symbol, timeframe, i-1) && 
                  iHigh(symbol, timeframe, i-1) < iHigh(symbol, timeframe, i)) {
                  isReversal = true;
               }
            }
            
            if(isReversal) {
               // Entrada na confirmação da reversão
               entryBar = i-1;
               
               if(pattern.isUptrend) {
                  entryPrice = iHigh(symbol, timeframe, i-1) + (iHigh(symbol, timeframe, i-1) - iLow(symbol, timeframe, i-1)) * 0.1;
                  stopLoss = iLow(symbol, timeframe, i) - (iHigh(symbol, timeframe, i) - iLow(symbol, timeframe, i)) * 0.1;
               } else {
                  entryPrice = iLow(symbol, timeframe, i-1) - (iHigh(symbol, timeframe, i-1) - iLow(symbol, timeframe, i-1)) * 0.1;
                  stopLoss = iHigh(symbol, timeframe, i) + (iHigh(symbol, timeframe, i) - iLow(symbol, timeframe, i)) * 0.1;
               }
               
               if(m_logger != NULL) {
                  m_logger.Info(StringFormat("SpikeAndChannel: Entrada Pullback Linha Tendência detectada para %s em barra %d", 
                                          symbol, entryBar));
               }
               
               return true;
            }
         }
      }
   }
   
   return false;
}
//+------------------------------------------------------------------+
//| Detecta entrada em falha de pullback                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Detecta entrada em falha de pullback - CORRIGIDO                 |
//+------------------------------------------------------------------+
bool CSpikeAndChannel::DetectFalhaPullback(string symbol, ENUM_TIMEFRAMES timeframe, SpikeChannelPattern &pattern, int &entryBar, double &entryPrice, double &stopLoss) {
   // Verificar se temos valores de linha de tendência
   if(ArraySize(pattern.trendLineValues) == 0) {
      if(m_logger != NULL) {
         m_logger.Warning("SpikeAndChannel: Array trendLineValues vazio em DetectFalhaPullback");
      }
      return false;
   }
   
   int arraySize = ArraySize(pattern.trendLineValues);
   
   // Procurar por pullback que falha em atingir a linha de tendência
   for(int i = pattern.channelStartBar - 3; i >= MathMax(pattern.channelEndBar, 0); i--) {
      
      // *** CORREÇÃO: Calcular índice relativo baseado no início do canal ***
      int relativeIndex = pattern.channelStartBar - i;
      
      // *** PROTEÇÃO: Verificar limites do array ***
      if(relativeIndex < 0 || relativeIndex >= arraySize) {
         if(m_logger != NULL) {
            m_logger.Debug(StringFormat("SpikeAndChannel: Índice %d fora dos limites em DetectFalhaPullback (array size: %d)", 
                                       relativeIndex, arraySize));
         }
         continue;
      }
      
      double trendLineValue = pattern.trendLineValues[relativeIndex];
      bool isFailedPullback = false;
      int pullbackBar = -1;
      
      if(pattern.isUptrend) {
         // Em tendência de alta, procurar por pullback que falha em atingir o suporte
         for(int j = i + 2; j > i; j--) {
            if(iLow(symbol, timeframe, j) < iLow(symbol, timeframe, j+1) && 
               iLow(symbol, timeframe, j) > trendLineValue + pattern.spikeHeight * 0.1) {
               isFailedPullback = true;
               pullbackBar = j;
               break;
            }
         }
      } else {
         // Em tendência de baixa, procurar por pullback que falha em atingir a resistência
         for(int j = i + 2; j > i; j--) {
            if(iHigh(symbol, timeframe, j) > iHigh(symbol, timeframe, j+1) && 
               iHigh(symbol, timeframe, j) < trendLineValue - pattern.spikeHeight * 0.1) {
               isFailedPullback = true;
               pullbackBar = j;
               break;
            }
         }
      }
      
      if(isFailedPullback && pullbackBar > 0) {
         // Verificar se há confirmação da falha
         bool isConfirmed = false;
         
         if(pattern.isUptrend) {
            // Em tendência de alta, procurar por barra de alta após falha do pullback
            if(iClose(symbol, timeframe, i) > iOpen(symbol, timeframe, i) && 
               iLow(symbol, timeframe, i) > iLow(symbol, timeframe, pullbackBar)) {
               isConfirmed = true;
            }
         } else {
            // Em tendência de baixa, procurar por barra de baixa após falha do pullback
            if(iClose(symbol, timeframe, i) < iOpen(symbol, timeframe, i) && 
               iHigh(symbol, timeframe, i) < iHigh(symbol, timeframe, pullbackBar)) {
               isConfirmed = true;
            }
         }
         
         if(isConfirmed) {
            // Entrada na confirmação da falha
            entryBar = i;
            
            if(pattern.isUptrend) {
               entryPrice = iHigh(symbol, timeframe, i) + (iHigh(symbol, timeframe, i) - iLow(symbol, timeframe, i)) * 0.1;
               stopLoss = iLow(symbol, timeframe, pullbackBar) - (iHigh(symbol, timeframe, pullbackBar) - iLow(symbol, timeframe, pullbackBar)) * 0.1;
            } else {
               entryPrice = iLow(symbol, timeframe, i) - (iHigh(symbol, timeframe, i) - iLow(symbol, timeframe, i)) * 0.1;
               stopLoss = iHigh(symbol, timeframe, pullbackBar) + (iHigh(symbol, timeframe, pullbackBar) - iLow(symbol, timeframe, pullbackBar)) * 0.1;
            }
            
            if(m_logger != NULL) {
               m_logger.Info(StringFormat("SpikeAndChannel: Entrada Falha Pullback detectada para %s em barra %d", 
                                       symbol, entryBar));
            }
            
            return true;
         }
      }
   }
   
   return false;
}
//+------------------------------------------------------------------+
//| Gera sinal com base no padrão detectado                          |
//+------------------------------------------------------------------+
Signal CSpikeAndChannel::GenerateSignal(string symbol, ENUM_TIMEFRAMES timeframe, SpikeChannelPattern &pattern, SPIKE_CHANNEL_ENTRY_TYPE preferredEntryType) {
   Signal signal;
   
   // Verificar se o padrão é válido
   if(!pattern.isValid) {
      if(m_logger != NULL) {
         m_logger.Warning("SpikeAndChannel: Tentativa de gerar sinal com padrão inválido");
      }
      return signal;
   }
   
   // Encontrar setup de entrada
   int entryBar;
   double entryPrice, stopLoss;
   
   if(!FindEntrySetup(symbol, timeframe, pattern, preferredEntryType, entryBar, entryPrice, stopLoss)) {
      if(m_logger != NULL) {
         m_logger.Debug("SpikeAndChannel: Nenhum setup de entrada encontrado");
      }
      return signal;
   }
   
   // Preencher dados do sinal
   signal.id = (int)GetTickCount(); // ID único baseado no tempo atual
   signal.symbol = symbol;
   signal.direction = pattern.isUptrend ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   signal.marketPhase = PHASE_TREND;
   signal.quality = SETUP_B; // Qualidade padrão, será reclassificada depois
   signal.entryPrice = entryPrice;
   signal.stopLoss = stopLoss;
   signal.generatedTime = TimeCurrent();
   signal.strategy = "Spike and Channel";
   signal.isActive = true;
   
   // Calcular take profits - REMOVIDO: Delegado para RiskManager
   // Os take profits serão calculados pelo RiskManager baseado nas constantes específicas do ativo
   // Inicializar array vazio
   for(int i = 0; i < 3; i++) {
      signal.takeProfits[i] = 0.0;
   }
   
   // Calcular relação risco/retorno
   signal.CalculateRiskRewardRatio();
   
   // Descrição detalhada do sinal
   signal.description = StringFormat("Spike and Channel (%s) - %s, R:R %.2f, Entrada: %s", 
                                   pattern.isUptrend ? "Alta" : "Baixa", 
                                   EnumToString(preferredEntryType),
                                   signal.riskRewardRatio,
                                   TimeToString(signal.generatedTime));
   
   if(m_logger != NULL) {
      m_logger.Info(StringFormat("SpikeAndChannel: Sinal gerado para %s - %s, Entrada: %.5f, Stop: %.5f, R:R: %.2f", 
                               symbol, pattern.isUptrend ? "Compra" : "Venda", 
                               signal.entryPrice, signal.stopLoss, signal.riskRewardRatio));
   }
   
   return signal;
}

#endif // SPIKEANDCHANNEL_MQH

