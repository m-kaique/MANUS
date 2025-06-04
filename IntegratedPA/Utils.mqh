#ifndef UTILS_MQH_
#define UTILS_MQH_

//+------------------------------------------------------------------+
//|                                                     Utils.mqh ||
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "Structures.mqh"

//+------------------------------------------------------------------+
//| Funções para manipulação de timeframes                           |
//+------------------------------------------------------------------+

/**
 * Obtém o próximo timeframe maior
 * @param timeframe Timeframe atual
 * @return Próximo timeframe maior
 */
ENUM_TIMEFRAMES GetHigherTimeframe(ENUM_TIMEFRAMES timeframe) {
   switch(timeframe) {
      case PERIOD_M1:  return PERIOD_M5;
      case PERIOD_M2:  return PERIOD_M10;
      case PERIOD_M3:  return PERIOD_M15;
      case PERIOD_M4:  return PERIOD_M15;
      case PERIOD_M5:  return PERIOD_M15;
      case PERIOD_M6:  return PERIOD_M30;
      case PERIOD_M10: return PERIOD_M30;
      case PERIOD_M12: return PERIOD_M30;
      case PERIOD_M15: return PERIOD_H1;
      case PERIOD_M20: return PERIOD_H1;
      case PERIOD_M30: return PERIOD_H4;
      case PERIOD_H1:  return PERIOD_H4;
      case PERIOD_H2:  return PERIOD_H6;
      case PERIOD_H3:  return PERIOD_H8;
      case PERIOD_H4:  return PERIOD_D1;
      case PERIOD_H6:  return PERIOD_D1;
      case PERIOD_H8:  return PERIOD_D1;
      case PERIOD_H12: return PERIOD_W1;
      case PERIOD_D1:  return PERIOD_W1;
      case PERIOD_W1:  return PERIOD_MN1;
      case PERIOD_MN1: return PERIOD_MN1;
      default:         return PERIOD_H1;
   }
}

/**
 * Obtém um timeframe intermediário entre o atual e o maior
 * @param timeframe Timeframe atual
 * @return Timeframe intermediário
 */
ENUM_TIMEFRAMES GetIntermediateTimeframe(ENUM_TIMEFRAMES timeframe) {
   switch(timeframe) {
      case PERIOD_M1:  return PERIOD_M3;
      case PERIOD_M2:  return PERIOD_M5;
      case PERIOD_M3:  return PERIOD_M10;
      case PERIOD_M4:  return PERIOD_M10;
      case PERIOD_M5:  return PERIOD_M10;
      case PERIOD_M6:  return PERIOD_M15;
      case PERIOD_M10: return PERIOD_M15;
      case PERIOD_M12: return PERIOD_M20;
      case PERIOD_M15: return PERIOD_M30;
      case PERIOD_M20: return PERIOD_M30;
      case PERIOD_M30: return PERIOD_H1;
      case PERIOD_H1:  return PERIOD_H2;
      case PERIOD_H2:  return PERIOD_H4;
      case PERIOD_H3:  return PERIOD_H6;
      case PERIOD_H4:  return PERIOD_H8;
      case PERIOD_H6:  return PERIOD_H12;
      case PERIOD_H8:  return PERIOD_D1;
      case PERIOD_H12: return PERIOD_D1;
      case PERIOD_D1:  return PERIOD_D1;
      case PERIOD_W1:  return PERIOD_W1;
      case PERIOD_MN1: return PERIOD_MN1;
      default:         return PERIOD_M30;
   }
}

/**
 * Obtém o próximo timeframe menor
 * @param timeframe Timeframe atual
 * @return Próximo timeframe menor
 */
ENUM_TIMEFRAMES GetLowerTimeframe(ENUM_TIMEFRAMES timeframe) {
   switch(timeframe) {
      case PERIOD_M1:  return PERIOD_M1;
      case PERIOD_M2:  return PERIOD_M1;
      case PERIOD_M3:  return PERIOD_M1;
      case PERIOD_M4:  return PERIOD_M1;
      case PERIOD_M5:  return PERIOD_M1;
      case PERIOD_M6:  return PERIOD_M2;
      case PERIOD_M10: return PERIOD_M5;
      case PERIOD_M12: return PERIOD_M5;
      case PERIOD_M15: return PERIOD_M5;
      case PERIOD_M20: return PERIOD_M10;
      case PERIOD_M30: return PERIOD_M15;
      case PERIOD_H1:  return PERIOD_M30;
      case PERIOD_H2:  return PERIOD_H1;
      case PERIOD_H3:  return PERIOD_H1;
      case PERIOD_H4:  return PERIOD_H1;
      case PERIOD_H6:  return PERIOD_H2;
      case PERIOD_H8:  return PERIOD_H4;
      case PERIOD_H12: return PERIOD_H6;
      case PERIOD_D1:  return PERIOD_H4;
      case PERIOD_W1:  return PERIOD_D1;
      case PERIOD_MN1: return PERIOD_W1;
      default:         return PERIOD_M5;
   }
}

//+------------------------------------------------------------------+
//| Definições de Constantes                                         |
//+------------------------------------------------------------------+

// Parâmetros de médias móveis
#define EMA_FAST_PERIOD      9
#define EMA_MEDIUM_PERIOD    21
#define EMA_SLOW_PERIOD      50
#define SMA_LONG_PERIOD      200

// Parâmetros de indicadores
#define RSI_PERIOD           14
#define RSI_OVERBOUGHT       70
#define RSI_OVERSOLD         30
#define ATR_PERIOD           14
#define MACD_FAST_PERIOD     12
#define MACD_SLOW_PERIOD     26
#define MACD_SIGNAL_PERIOD   9

// Constantes para cálculos de risco
#define DEFAULT_RISK_PERCENT 1.0
#define MAX_DAILY_RISK       3.0
#define MAX_POSITION_SIZE    5
#define MIN_RISK_REWARD      1.5

// Níveis de Fibonacci
#define FIB_LEVELS_COUNT     9

//+------------------------------------------------------------------+
//| Funções Auxiliares Básicas                                       |
//+------------------------------------------------------------------+

/**
 * Normaliza um preço de acordo com os ticks mínimos do ativo
 * @param symbol Símbolo do ativo
 * @param price Preço a ser normalizado
 * @return Preço normalizado
 */
double NormalizePrice(string symbol, double price) {
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize == 0.0) return price;
   
   return MathRound(price / tickSize) * tickSize;
}

/**
 * Calcula o valor de um pip para um determinado ativo
 * @param symbol Símbolo do ativo
 * @return Valor monetário de um pip
 */
double CalculatePipValue(string symbol) {
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   
   if(tickSize == 0.0 || tickValue == 0.0) return 0.0;
   
   // Para Forex, um pip geralmente é o quarto decimal (0.0001)
   // Para outros instrumentos, pode variar
   double pipSize = 0.0;
   
   if(StringFind(symbol, "USD") >= 0 || StringFind(symbol, "EUR") >= 0 || 
      StringFind(symbol, "GBP") >= 0 || StringFind(symbol, "AUD") >= 0 || 
      StringFind(symbol, "NZD") >= 0) {
      pipSize = 0.0001;
   } else if(StringFind(symbol, "JPY") >= 0) {
      pipSize = 0.01;
   } else if(StringFind(symbol, "BIT") >= 0) {
      pipSize = 1.0;
   } else if(StringFind(symbol, "WIN") >= 0) {
      pipSize = 5.0;
   } else if(StringFind(symbol, "WDO") >= 0) {
      pipSize = 0.5;
   } else {
      pipSize = tickSize;
   }
   
   return (tickValue / tickSize) * pipSize;
}

/**
 * Converte um timeframe em minutos
 * @param timeframe Timeframe a ser convertido
 * @return Número de minutos correspondente ao timeframe
 */
int TimeframeToMinutes(ENUM_TIMEFRAMES timeframe) {
   switch(timeframe) {
      case PERIOD_M1:  return 1;
      case PERIOD_M2:  return 2;
      case PERIOD_M3:  return 3;
      case PERIOD_M4:  return 4;
      case PERIOD_M5:  return 5;
      case PERIOD_M6:  return 6;
      case PERIOD_M10: return 10;
      case PERIOD_M12: return 12;
      case PERIOD_M15: return 15;
      case PERIOD_M20: return 20;
      case PERIOD_M30: return 30;
      case PERIOD_H1:  return 60;
      case PERIOD_H2:  return 120;
      case PERIOD_H3:  return 180;
      case PERIOD_H4:  return 240;
      case PERIOD_H6:  return 360;
      case PERIOD_H8:  return 480;
      case PERIOD_H12: return 720;
      case PERIOD_D1:  return 1440;
      case PERIOD_W1:  return 10080;
      case PERIOD_MN1: return 43200;
      default:         return 0;
   }
}

/**
 * Verifica se uma nova barra foi formada em um determinado timeframe
 * @param symbol Símbolo do ativo
 * @param timeframe Timeframe para verificação
 * @return true se uma nova barra foi formada
 */
bool IsNewBar(string symbol, ENUM_TIMEFRAMES timeframe) {
   static datetime last_time = 0;
   datetime current_time = iTime(symbol, timeframe, 0);
   
   if(current_time != last_time) {
      last_time = current_time;
      return true;
   }
   
   return false;
}

/**
 * Calcula o tamanho da posição baseado no risco percentual
 * @param symbol Símbolo do ativo
 * @param riskPercent Percentual do capital a ser arriscado
 * @param entryPrice Preço de entrada
 * @param stopLoss Preço de stop loss
 * @return Tamanho da posição
 */
double CalculatePositionSize(string symbol, double riskPercent, double entryPrice, double stopLoss) {
   if(entryPrice == 0.0 || stopLoss == 0.0 || riskPercent <= 0.0) return 0.0;
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (riskPercent / 100.0);
   double stopDistance = MathAbs(entryPrice - stopLoss);
   
   if(stopDistance == 0.0) return 0.0;
   
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   
   if(tickSize == 0.0 || tickValue == 0.0 || contractSize == 0.0) return 0.0;
   
   double ticksInStopDistance = stopDistance / tickSize;
   double valuePerTick = tickValue / tickSize;
   
   double positionSize = riskAmount / (ticksInStopDistance * valuePerTick);
   
   // Arredondar para o tamanho de lote mínimo
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   if(stepLot > 0.0) {
      positionSize = MathFloor(positionSize / stepLot) * stepLot;
   }
   
   // Garantir que o tamanho está dentro dos limites
   positionSize = MathMax(minLot, MathMin(maxLot, positionSize));
   
   return positionSize;
}

//+------------------------------------------------------------------+
//| Funções Complexas                                                |
//+------------------------------------------------------------------+

/**
 * Verifica se há reversão à média entre as EMAs de 50 e 200 períodos
 * @param symbol Símbolo do ativo
 * @param timeframe Timeframe para análise
 * @param lookbackBars Número de barras para análise retroativa
 * @return true se o preço estiver retornando à média após um desvio significativo
 */
bool CheckMeanReversion50to200(string symbol, ENUM_TIMEFRAMES timeframe, int lookbackBars = 10) {
   // Verificar parâmetros de entrada
   if(lookbackBars < 5) lookbackBars = 5;
   
   // Obter handles para as médias móveis
   int ema50Handle = iMA(symbol, timeframe, EMA_SLOW_PERIOD, 0, MODE_EMA, PRICE_CLOSE);
   int sma200Handle = iMA(symbol, timeframe, SMA_LONG_PERIOD, 0, MODE_SMA, PRICE_CLOSE);
   
   if(ema50Handle == INVALID_HANDLE || sma200Handle == INVALID_HANDLE) {
      Print("Erro ao obter handles dos indicadores: ", GetLastError());
      return false;
   }
   
   // Arrays para armazenar os valores das médias
   double ema50Values[];
   double sma200Values[];
   double closeValues[];
   
   // Redimensionar arrays
   ArraySetAsSeries(ema50Values, true);
   ArraySetAsSeries(sma200Values, true);
   ArraySetAsSeries(closeValues, true);
   
   // Copiar dados para os arrays
   if(CopyBuffer(ema50Handle, 0, 0, lookbackBars, ema50Values) <= 0 ||
      CopyBuffer(sma200Handle, 0, 0, lookbackBars, sma200Values) <= 0 ||
      CopyClose(symbol, timeframe, 0, lookbackBars, closeValues) <= 0) {
      Print("Erro ao copiar dados dos indicadores: ", GetLastError());
      
      // Liberar handles
      IndicatorRelease(ema50Handle);
      IndicatorRelease(sma200Handle);
      
      return false;
   }
   
   // Liberar handles
   IndicatorRelease(ema50Handle);
   IndicatorRelease(sma200Handle);
   
   // Verificar se temos dados suficientes
   if(ArraySize(ema50Values) < lookbackBars || ArraySize(sma200Values) < lookbackBars || ArraySize(closeValues) < lookbackBars) {
      Print("Dados insuficientes para análise de reversão à média");
      return false;
   }
   
   // Verificar condições de reversão à média
   
   // 1. Verificar se o preço estava significativamente afastado da média de 200
   double maxDeviation = 0.0;
   int maxDeviationIndex = -1;
   
   for(int i = lookbackBars - 1; i >= 0; i--) {
      double deviation = MathAbs(closeValues[i] - sma200Values[i]) / sma200Values[i] * 100.0;
      
      if(deviation > maxDeviation) {
         maxDeviation = deviation;
         maxDeviationIndex = i;
      }
   }
   
   // Se não houve desvio significativo, não há reversão à média
   if(maxDeviation < 2.0 || maxDeviationIndex == -1) {
      return false;
   }
   
   // 2. Verificar se o preço está se aproximando da média de 200 após o desvio
   bool isReturningToMean = false;
   
   if(maxDeviationIndex > 0) {
      double initialDeviation = MathAbs(closeValues[maxDeviationIndex] - sma200Values[maxDeviationIndex]);
      double currentDeviation = MathAbs(closeValues[0] - sma200Values[0]);
      
      // Preço está mais próximo da média agora do que no ponto de desvio máximo
      if(currentDeviation < initialDeviation) {
         isReturningToMean = true;
      }
   }
   
   // 3. Verificar se a EMA 50 está entre o preço e a SMA 200 (sinal de reversão)
   bool ema50Between = false;
   
   if(closeValues[0] > sma200Values[0] && closeValues[0] > ema50Values[0] && ema50Values[0] > sma200Values[0]) {
      ema50Between = true; // Preço acima da EMA 50, que está acima da SMA 200
   } else if(closeValues[0] < sma200Values[0] && closeValues[0] < ema50Values[0] && ema50Values[0] < sma200Values[0]) {
      ema50Between = true; // Preço abaixo da EMA 50, que está abaixo da SMA 200
   }
   
   // Retornar true se ambas as condições forem atendidas
   return isReturningToMean && ema50Between;
}

/**
 * Calcula níveis de Fibonacci com base em um swing high e swing low
 * @param highPrice Preço mais alto do swing
 * @param lowPrice Preço mais baixo do swing
 * @param isUptrend true se a tendência for de alta, false se for de baixa
 * @param levels Array para armazenar os níveis calculados
 * @return Número de níveis calculados
 */
int GetFibLevels(double highPrice, double lowPrice, bool isUptrend, double &levels[]) {
   if(highPrice <= lowPrice) {
      Print("Erro: highPrice deve ser maior que lowPrice");
      return 0;
   }
   
   // Redimensionar o array para armazenar todos os níveis
   ArrayResize(levels, FIB_LEVELS_COUNT);
   
   // Definir os ratios de Fibonacci
   double fibRatios[FIB_LEVELS_COUNT] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0, 1.272, 1.618};
   
   // Calcular a amplitude do movimento
   double range = highPrice - lowPrice;
   
   // Calcular os níveis de Fibonacci
   if(isUptrend) {
      // Em tendência de alta, os níveis são calculados de baixo para cima
      for(int i = 0; i < FIB_LEVELS_COUNT; i++) {
         levels[i] = lowPrice + range * fibRatios[i];
      }
   } else {
      // Em tendência de baixa, os níveis são calculados de cima para baixo
      for(int i = 0; i < FIB_LEVELS_COUNT; i++) {
         levels[i] = highPrice - range * fibRatios[i];
      }
   }
   
   return FIB_LEVELS_COUNT;
}

/**
 * Identifica swing highs e lows em um determinado período
 * @param symbol Símbolo do ativo
 * @param timeframe Timeframe para análise
 * @param lookbackBars Número de barras para análise retroativa
 * @param swingHighs Array para armazenar os swing highs encontrados
 * @param swingLows Array para armazenar os swing lows encontrados
 * @param strength Número de barras para cada lado que define a força do swing
 * @return Número de swings encontrados (soma de highs e lows)
 */
int FindSwingPoints(string symbol, ENUM_TIMEFRAMES timeframe, int lookbackBars, 
                    double &swingHighs[], datetime &swingHighTimes[],
                    double &swingLows[], datetime &swingLowTimes[],
                    int strength = 2) {
   // Validar parâmetros de entrada
   if(strength < 1) strength = 1;
   if(lookbackBars <= 2 * strength) lookbackBars = 2 * strength + 10; // Garantir barras suficientes
   
   // Arrays para armazenar os dados de preço
   double highValues[];
   double lowValues[];
   datetime times[];
   
   // Redimensionar arrays
   ArraySetAsSeries(highValues, true);
   ArraySetAsSeries(lowValues, true);
   ArraySetAsSeries(times, true);
   
   // Copiar dados para os arrays
   int copiedHigh = CopyHigh(symbol, timeframe, 0, lookbackBars, highValues);
   int copiedLow = CopyLow(symbol, timeframe, 0, lookbackBars, lowValues);
   int copiedTime = CopyTime(symbol, timeframe, 0, lookbackBars, times);
   
   if(copiedHigh <= 0 || copiedLow <= 0 || copiedTime <= 0) {
      Print("Erro ao copiar dados de preço: ", GetLastError());
      return 0;
   }
   
   // Verificar se temos dados suficientes
   int actualBars = MathMin(MathMin(copiedHigh, copiedLow), copiedTime);
   if(actualBars <= 2 * strength) {
      Print("Dados históricos insuficientes para análise de swing points");
      return 0;
   }
   
   // Limpar arrays de saída
   ArrayResize(swingHighs, 0);
   ArrayResize(swingHighTimes, 0);
   ArrayResize(swingLows, 0);
   ArrayResize(swingLowTimes, 0);
   
   // Encontrar swing highs
   for(int i = strength; i < actualBars - strength; i++) {
      bool isSwingHigh = true;
      
      for(int j = 1; j <= strength; j++) {
         // Verificar se temos índices válidos
         if(i-j < 0 || i+j >= actualBars) {
            isSwingHigh = false;
            break;
         }
         
         if(highValues[i] <= highValues[i-j] || highValues[i] <= highValues[i+j]) {
            isSwingHigh = false;
            break;
         }
      }
      
      if(isSwingHigh) {
         int newSize = ArraySize(swingHighs) + 1;
         ArrayResize(swingHighs, newSize);
         ArrayResize(swingHighTimes, newSize);
         swingHighs[newSize - 1] = highValues[i];
         swingHighTimes[newSize - 1] = times[i];
      }
   }
   
   // Encontrar swing lows
   for(int i = strength; i < actualBars - strength; i++) {
      bool isSwingLow = true;
      
      for(int j = 1; j <= strength; j++) {
         // Verificar se temos índices válidos
         if(i-j < 0 || i+j >= actualBars) {
            isSwingLow = false;
            break;
         }
         
         if(lowValues[i] >= lowValues[i-j] || lowValues[i] >= lowValues[i+j]) {
            isSwingLow = false;
            break;
         }
      }
      
      if(isSwingLow) {
         int newSize = ArraySize(swingLows) + 1;
         ArrayResize(swingLows, newSize);
         ArrayResize(swingLowTimes, newSize);
         swingLows[newSize - 1] = lowValues[i];
         swingLowTimes[newSize - 1] = times[i];
      }
   }
   
   return ArraySize(swingHighs) + ArraySize(swingLows);
}

/**
 * Verifica se há divergência entre preço e RSI
 * @param symbol Símbolo do ativo
 * @param timeframe Timeframe para análise
 * @param lookbackBars Número de barras para análise retroativa
 * @param bullish true para verificar divergência de baixa, false para alta
 * @return true se houver divergência
 */
bool CheckRSIDivergence(string symbol, ENUM_TIMEFRAMES timeframe, int lookbackBars, bool bullish) {
   // Verificar se temos barras suficientes para análise
   if(lookbackBars < 10) lookbackBars = 10;
   
   // Obter handle para o RSI
   int rsiHandle = iRSI(symbol, timeframe, RSI_PERIOD, PRICE_CLOSE);
   
   if(rsiHandle == INVALID_HANDLE) {
      Print("Erro ao obter handle do RSI: ", GetLastError());
      return false;
   }
   
   // Arrays para armazenar os valores
   double rsiValues[];
   double highValues[];
   double lowValues[];
   
   // Redimensionar arrays
   ArraySetAsSeries(rsiValues, true);
   ArraySetAsSeries(highValues, true);
   ArraySetAsSeries(lowValues, true);
   
   // Copiar dados para os arrays
   if(CopyBuffer(rsiHandle, 0, 0, lookbackBars, rsiValues) <= 0 ||
      CopyHigh(symbol, timeframe, 0, lookbackBars, highValues) <= 0 ||
      CopyLow(symbol, timeframe, 0, lookbackBars, lowValues) <= 0) {
      Print("Erro ao copiar dados: ", GetLastError());
      
      // Liberar handle
      IndicatorRelease(rsiHandle);
      
      return false;
   }
   
   // Liberar handle
   IndicatorRelease(rsiHandle);
   
   // Verificar se temos dados suficientes
   if(ArraySize(rsiValues) < lookbackBars || ArraySize(highValues) < lookbackBars || ArraySize(lowValues) < lookbackBars) {
      Print("Dados insuficientes para análise de divergência");
      return false;
   }
   
   // Encontrar swing points no preço e no RSI
   int priceSwingIndex1 = -1;
   int priceSwingIndex2 = -1;
   int rsiSwingIndex1 = -1;
   int rsiSwingIndex2 = -1;
   
   // Para divergência de baixa (bearish)
   if(bullish) {
      // Encontrar dois swing highs no preço
      for(int i = 1; i < lookbackBars - 1; i++) {
         if(highValues[i] > highValues[i-1] && highValues[i] > highValues[i+1]) {
            if(priceSwingIndex1 == -1) {
               priceSwingIndex1 = i;
            } else if(priceSwingIndex2 == -1 && i > priceSwingIndex1 + 3) {
               priceSwingIndex2 = i;
               break;
            }
         }
      }
      
      // Encontrar dois swing highs no RSI
      for(int i = 1; i < lookbackBars - 1; i++) {
         if(rsiValues[i] > rsiValues[i-1] && rsiValues[i] > rsiValues[i+1]) {
            if(rsiSwingIndex1 == -1) {
               rsiSwingIndex1 = i;
            } else if(rsiSwingIndex2 == -1 && i > rsiSwingIndex1 + 3) {
               rsiSwingIndex2 = i;
               break;
            }
         }
      }
      
      // Verificar se encontramos swing points suficientes
      if(priceSwingIndex1 == -1 || priceSwingIndex2 == -1 || rsiSwingIndex1 == -1 || rsiSwingIndex2 == -1) {
         return false;
      }
      
      // Verificar divergência de baixa: preço faz máximos mais altos, RSI faz máximos mais baixos
      if(highValues[priceSwingIndex2] > highValues[priceSwingIndex1] && 
         rsiValues[rsiSwingIndex2] < rsiValues[rsiSwingIndex1]) {
         return true;
      }
   }
   // Para divergência de alta (bullish)
   else {
      // Encontrar dois swing lows no preço
      for(int i = 1; i < lookbackBars - 1; i++) {
         if(lowValues[i] < lowValues[i-1] && lowValues[i] < lowValues[i+1]) {
            if(priceSwingIndex1 == -1) {
               priceSwingIndex1 = i;
            } else if(priceSwingIndex2 == -1 && i > priceSwingIndex1 + 3) {
               priceSwingIndex2 = i;
               break;
            }
         }
      }
      
      // Encontrar dois swing lows no RSI
      for(int i = 1; i < lookbackBars - 1; i++) {
         if(rsiValues[i] < rsiValues[i-1] && rsiValues[i] < rsiValues[i+1]) {
            if(rsiSwingIndex1 == -1) {
               rsiSwingIndex1 = i;
            } else if(rsiSwingIndex2 == -1 && i > rsiSwingIndex1 + 3) {
               rsiSwingIndex2 = i;
               break;
            }
         }
      }
      
      // Verificar se encontramos swing points suficientes
      if(priceSwingIndex1 == -1 || priceSwingIndex2 == -1 || rsiSwingIndex1 == -1 || rsiSwingIndex2 == -1) {
         return false;
      }
      
      // Verificar divergência de alta: preço faz mínimos mais baixos, RSI faz mínimos mais altos
      if(lowValues[priceSwingIndex2] < lowValues[priceSwingIndex1] && 
         rsiValues[rsiSwingIndex2] > rsiValues[rsiSwingIndex1]) {
         return true;
      }
   }
   
   return false;
}


#endif // UTILS_MQH_
