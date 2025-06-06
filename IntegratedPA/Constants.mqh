//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                   Constants.mqh |
//|                                                   ©2025, MANUS |
//|                         Compatível com MetaEditor Build 4885 – 28 Feb 2025 (≥ 4600) |
//+------------------------------------------------------------------+
#property copyright "©2025, MANUS"
#property link      "https://www.mql5.com"
#property version   "5.00"
#property strict

#ifndef CONSTANTS_MQH
#define CONSTANTS_MQH

//+------------------------------------------------------------------+
//| Constantes Padronizadas - Baseadas no Cap-14 do Guia            |
//+------------------------------------------------------------------+

//------ Defaults testados (baseados no Cap-14) ------
#ifndef EMA_FAST_PERIOD
#define EMA_FAST_PERIOD         9     // EMA rápida para tendência
#endif

#ifndef EMA_SLOW_PERIOD
#define EMA_SLOW_PERIOD         21    // EMA lenta para contexto
#endif

#ifndef EMA_CONTEXT_PERIOD
#define EMA_CONTEXT_PERIOD      50    // EMA contexto pullbacks
#endif

#ifndef EMA_LONG_PERIOD
#define EMA_LONG_PERIOD         200   // EMA longa para bias
#endif

#ifndef ATR_PERIOD
#define ATR_PERIOD              14    // Average True Range
#endif

#ifndef MAX_RANGE_ATR
#define MAX_RANGE_ATR           1.2   // Limite de amplitude p/ fase de range
#endif

#ifndef STO_PERIOD
#define STO_PERIOD              14    // Stochastic lento
#endif

#ifndef STO_OVERSOLD
#define STO_OVERSOLD            20    // Zona sobrevenda
#endif

#ifndef STO_OVERBOUGHT
#define STO_OVERBOUGHT          80    // Zona sobrecompra
#endif

#ifndef VOLUME_PERIOD
#define VOLUME_PERIOD           20    // Média volume para comparação
#endif

#ifndef VOLUME_THRESHOLD
#define VOLUME_THRESHOLD        120   // % mínimo volume para MTR
#endif

#ifndef RSI_PERIOD
#define RSI_PERIOD              14    // RSI período padrão
#endif

#ifndef RSI_OVERSOLD
#define RSI_OVERSOLD            30    // RSI sobrevenda
#endif

#ifndef RSI_OVERBOUGHT
#define RSI_OVERBOUGHT          70    // RSI sobrecompra
#endif

#ifndef MACD_FAST_PERIOD
#define MACD_FAST_PERIOD        12    // MACD EMA rápida
#endif

#ifndef MACD_SLOW_PERIOD
#define MACD_SLOW_PERIOD        26    // MACD EMA lenta
#endif

#ifndef MACD_SIGNAL_PERIOD
#define MACD_SIGNAL_PERIOD      9     // MACD linha de sinal
#endif

//------ Constantes para SPIKE AND CHANNEL ------
#ifndef SPIKE_MIN_BARS
#define SPIKE_MIN_BARS          3     // Mínimo de barras para spike
#endif

#ifndef SPIKE_MAX_BARS
#define SPIKE_MAX_BARS          5     // Máximo de barras para spike
#endif

#ifndef SPIKE_MIN_BODY_RATIO
#define SPIKE_MIN_BODY_RATIO    0.7   // Razão mínima corpo/total
#endif

#ifndef SPIKE_MAX_OVERLAP
#define SPIKE_MAX_OVERLAP       15.0  // Máxima sobreposição entre barras (%)
#endif

#ifndef CHANNEL_MIN_PULLBACK
#define CHANNEL_MIN_PULLBACK    0.3   // Mínimo pullback no canal
#endif

#ifndef CHANNEL_MAX_PULLBACK
#define CHANNEL_MAX_PULLBACK    0.8   // Máximo pullback no canal
#endif

#ifndef CHANNEL_MIN_BARS
#define CHANNEL_MIN_BARS        5     // Mínimo de barras no canal
#endif

#ifndef CHANNEL_MAX_BARS
#define CHANNEL_MAX_BARS        30    // Máximo de barras no canal
#endif

//------ Fibonacci Levels ------
#ifndef FIB_LEVEL_236
#define FIB_LEVEL_236           0.236
#endif

#ifndef FIB_LEVEL_382
#define FIB_LEVEL_382           0.382
#endif

#ifndef FIB_LEVEL_500
#define FIB_LEVEL_500           0.500
#endif

#ifndef FIB_LEVEL_618
#define FIB_LEVEL_618           0.618  // Golden Zone
#endif

#ifndef FIB_LEVEL_786
#define FIB_LEVEL_786           0.786
#endif

//------ Risk Management Constants ------
#ifndef DEFAULT_RISK_PERCENT
#define DEFAULT_RISK_PERCENT    1.0   // Risco padrão por trade
#endif

#ifndef MAX_DAILY_RISK
#define MAX_DAILY_RISK          3.0   // Risco máximo diário
#endif

#ifndef MAX_POSITION_SIZE
#define MAX_POSITION_SIZE       5     // Tamanho máximo de posição
#endif

#ifndef MIN_RISK_REWARD
#define MIN_RISK_REWARD         1.5   // R:R mínimo
#endif

//------ Setup Quality Thresholds ------
#define SETUP_A_PLUS_MIN_FACTORS    3     // Mínimo fatores para A+
#define SETUP_A_PLUS_MIN_RR         3.0   // R:R mínimo para A+
#define SETUP_A_PLUS_MIN_SCORE      80    // Score mínimo para A+

#define SETUP_A_MIN_FACTORS         2     // Mínimo fatores para A
#define SETUP_A_MIN_RR              2.0   // R:R mínimo para A
#define SETUP_A_MIN_SCORE           60    // Score mínimo para A

#define SETUP_B_MIN_FACTORS         1     // Mínimo fatores para B
#define SETUP_B_MIN_RR              1.5   // R:R mínimo para B
#define SETUP_B_MIN_SCORE           40    // Score mínimo para B

//------ Timeframes para Multi-Timeframe Analysis ------
#define MTF_HIGHER_TF          PERIOD_D1   // Timeframe superior
#define MTF_INTERMEDIATE_TF    PERIOD_H1   // Timeframe intermediário
#define MTF_LOWER_TF           PERIOD_M15  // Timeframe inferior

//------ Session Times (Horário de Brasília) ------
#define SESSION_START_HOUR     9      // Início do pregão
#define SESSION_END_HOUR       17     // Fim do pregão
#define SESSION_LUNCH_START    12     // Início do almoço
#define SESSION_LUNCH_END      13     // Fim do almoço

//------ Market Phase Detection ------
#define TREND_MIN_EMA_SEPARATION    0.1   // Separação mínima entre EMAs para tendência
#define RANGE_MAX_EMA_SEPARATION    0.05  // Separação máxima entre EMAs para range
#define REVERSAL_MIN_DIVERGENCE     5     // Divergência mínima para reversão

//------ Volume Analysis ------
#define VOLUME_SPIKE_THRESHOLD      150   // % para considerar spike de volume
#define VOLUME_DECLINE_THRESHOLD    80    // % para considerar declínio de volume

//------ Spread Control ------
#define MAX_SPREAD_MULTIPLIER       2.0   // Máximo spread em relação à média
#define SPREAD_CHECK_PERIOD         100   // Período para calcular spread médio

//------ Error Handling ------
#define MAX_RETRIES                 3     // Máximo de tentativas
#define RETRY_DELAY_MS              1000  // Delay entre tentativas (ms)
#define SUSPENSION_TIME_SEC         300   // Tempo de suspensão após falhas (sec)

//------ Cache and Performance ------
#define INDICATOR_CACHE_SIZE        1000  // Tamanho do cache de indicadores
#define HISTORY_CHECK_INTERVAL      300   // Intervalo para recheck de histórico (sec)
#define LOG_BUFFER_SIZE             1000  // Tamanho do buffer de logs
#define LOG_FLUSH_INTERVAL          60    // Intervalo para flush de logs (sec)

//------ Alert and Notification ------
#define ALERT_SOUND_FILE            "alert.wav"
#define EMAIL_SUBJECT_PREFIX        "[INTEGRATED PA EA]"
#define ALERT_HISTORY_SIZE          1000

//------ Asset Specific Constants ------

// WIN (Mini Índice Bovespa) - Valores em pontos
#define WIN_SPIKE_MAX_STOP          500   // Stop máximo durante spike
#define WIN_CHANNEL_MAX_STOP        500   // Stop máximo durante canal
#define WIN_FIRST_TARGET            100   // Primeiro alvo
#define WIN_SECOND_TARGET           200  // Segundo alvo
#define WIN_TRAILING_STOP           300   // Trailing stop

// WDO (Mini Dólar) - Valores em pontos
#define WDO_SPIKE_MAX_STOP          7     // Stop máximo durante spike
#define WDO_CHANNEL_MAX_STOP        5     // Stop máximo durante canal
#define WDO_FIRST_TARGET            15    // Primeiro alvo
#define WDO_SECOND_TARGET           30    // Segundo alvo
#define WDO_TRAILING_STOP           8    // Trailing stop

// BTC (Bitcoin Futuros) - Valores em USD
#define BTC_SPIKE_MAX_STOP          700   // Stop máximo durante spike
#define BTC_CHANNEL_MAX_STOP        500   // Stop máximo durante canal
#define BTC_FIRST_TARGET            1250  // Primeiro alvo
#define BTC_SECOND_TARGET           3000  // Segundo alvo
#define BTC_TRAILING_STOP           500   // Trailing stop

//------ Additional Strategy Constants ------

// TTRD (Trending Trading Range Day)
#define TTRD_MIN_RANGE_DURATION     6     // Duração mínima do range (barras)
#define TTRD_MAX_RANGE_DURATION     12    // Duração máxima do range (barras)
#define TTRD_MIN_RANGES             3     // Mínimo de ranges para TTRD
#define TTRD_BREAKOUT_THRESHOLD     0.1   // Threshold para breakout (ATR)

// Wedge Reversal
#define WEDGE_MIN_TOUCH_POINTS      4     // Mínimo de toques nas linhas
#define WEDGE_MAX_DURATION          20    // Duração máxima da cunha (barras)
#define WEDGE_CONVERGENCE_THRESHOLD 0.05  // Threshold de convergência
#define WEDGE_VOLUME_DECLINE        0.8   // Volume deve declinar (fator)

//------ Memory Management ------
#define MAX_SYMBOLS                 10    // Máximo de símbolos simultâneos
#define MAX_STRATEGIES              5     // Máximo de estratégias por símbolo
#define MAX_SIGNALS_HISTORY         100   // Máximo de sinais no histórico
#define MAX_TRADES_HISTORY          1000  // Máximo de trades no histórico

//------ Mathematical Constants ------
#define GOLDEN_RATIO                1.618
#define PI                          3.14159265359
#define E                           2.71828182846

//------ String Constants ------
#define STRATEGY_SPIKE_CHANNEL      "Spike and Channel"
#define STRATEGY_TTRD               "TTRD"
#define STRATEGY_WEDGE_REVERSAL     "Wedge Reversal"
#define STRATEGY_PULLBACK_EMA       "Pullback to EMA"
#define STRATEGY_BREAKOUT_PULLBACK  "Breakout Pullback"

//------ Color Constants for Visual Panel ------
#define COLOR_BACKGROUND            C'20,20,20'
#define COLOR_TEXT                  clrWhite
#define COLOR_HEADER                clrGold
#define COLOR_PROFIT                clrLime
#define COLOR_LOSS                  clrRed
#define COLOR_WARNING               clrOrange
#define COLOR_INFO                  clrCyan

#endif // CONSTANTS_MQH

