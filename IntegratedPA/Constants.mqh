//+------------------------------------------------------------------+
//|                                                   Constants.mqh |
//|                                                   ©2025, MANUS |
//|                         Compatível com MetaEditor Build 4885 – 28 Feb 2025 (≥ 4600) |
//+------------------------------------------------------------------+
#property copyright "©2025, MANUS"
#property link      "https://www.mql5.com"
#property version   "5.00"
#property strict

//+------------------------------------------------------------------+
//| CONFIGURAÇÕES BÁSICAS                                            |
//+------------------------------------------------------------------+
input group "=== CONFIGURAÇÕES BÁSICAS ==="
input int MAGIC_NUMBER = 123456;                      // Número Mágico

//+------------------------------------------------------------------+
//| Constantes Padronizadas - Baseadas no Cap-14 do Guia            |
//+------------------------------------------------------------------+
input group "=== INDICADORES TÉCNICOS ==="
input int    STO_PERIOD = 14;                         // Stochastic lento
input double STO_OVERSOLD = 20;                       // Zona sobrevenda
input double STO_OVERBOUGHT = 80;                     // Zona sobrecompra
input int    VOLUME_PERIOD = 20;                      // Média volume para comparação
input double VOLUME_THRESHOLD = 120;                  // % mínimo volume para MTR

//+------------------------------------------------------------------+
//| SPIKE AND CHANNEL                                                |
//+------------------------------------------------------------------+
input group "=== SPIKE AND CHANNEL ==="
input int    SPIKE_MIN_BARS = 3;                      // Mínimo de barras para spike
input int    SPIKE_MAX_BARS = 5;                      // Máximo de barras para spike
input double SPIKE_MIN_BODY_RATIO = 0.7;              // Razão mínima corpo/total
input double SPIKE_MAX_OVERLAP = 15.0;                // Máxima sobreposição entre barras (%)

input double CHANNEL_MIN_PULLBACK = 0.3;              // Mínimo pullback no canal
input double CHANNEL_MAX_PULLBACK = 0.8;              // Máximo pullback no canal
input int    CHANNEL_MIN_BARS = 5;                    // Mínimo de barras no canal
input int    CHANNEL_MAX_BARS = 30;                   // Máximo de barras no canal

//+------------------------------------------------------------------+
//| Fibonacci Levels                                                 |
//+------------------------------------------------------------------+
input group "=== FIBONACCI LEVELS ==="
input double FIB_LEVEL_236 = 0.236;                   // Fibonacci 23.6%
input double FIB_LEVEL_382 = 0.382;                   // Fibonacci 38.2%
input double FIB_LEVEL_500 = 0.500;                   // Fibonacci 50.0%
input double FIB_LEVEL_618 = 0.618;                   // Fibonacci 61.8% (Golden Zone)
input double FIB_LEVEL_786 = 0.786;                   // Fibonacci 78.6%

//+------------------------------------------------------------------+
//| Setup Quality Thresholds                                         |
//+------------------------------------------------------------------+
input group "=== SETUP QUALITY THRESHOLDS ==="
input int    SETUP_A_PLUS_MIN_FACTORS = 3;            // Mínimo fatores para A+
input double SETUP_A_PLUS_MIN_RR = 3.0;               // R:R mínimo para A+
input int    SETUP_A_PLUS_MIN_SCORE = 80;             // Score mínimo para A+

input int    SETUP_A_MIN_FACTORS = 2;                 // Mínimo fatores para A
input double SETUP_A_MIN_RR = 2.0;                    // R:R mínimo para A
input int    SETUP_A_MIN_SCORE = 60;                  // Score mínimo para A

input int    SETUP_B_MIN_FACTORS = 1;                 // Mínimo fatores para B
input double SETUP_B_MIN_RR = 1.5;                    // R:R mínimo para B
input int    SETUP_B_MIN_SCORE = 40;                  // Score mínimo para B

//+------------------------------------------------------------------+
//| Timeframes para Multi-Timeframe Analysis                         |
//+------------------------------------------------------------------+
input group "=== MULTI-TIMEFRAME ANALYSIS ==="
input ENUM_TIMEFRAMES MTF_HIGHER_TF = PERIOD_D1;      // Timeframe superior
input ENUM_TIMEFRAMES MTF_INTERMEDIATE_TF = PERIOD_H1; // Timeframe intermediário
input ENUM_TIMEFRAMES MTF_LOWER_TF = PERIOD_M15;      // Timeframe inferior

//+------------------------------------------------------------------+
//| Session Times (Horário de Brasília)                              |
//+------------------------------------------------------------------+
input group "=== SESSION TIMES ==="
input int SESSION_START_HOUR = 9;                     // Início do pregão
input int SESSION_END_HOUR = 17;                      // Fim do pregão
input int SESSION_LUNCH_START = 12;                   // Início do almoço
input int SESSION_LUNCH_END = 13;                     // Fim do almoço

//+------------------------------------------------------------------+
//| Market Phase Detection                                            |
//+------------------------------------------------------------------+
input group "=== MARKET PHASE DETECTION ==="
input double TREND_MIN_EMA_SEPARATION = 0.1;          // Separação mínima entre EMAs para tendência
input double RANGE_MAX_EMA_SEPARATION = 0.05;         // Separação máxima entre EMAs para range
input int    REVERSAL_MIN_DIVERGENCE = 5;             // Divergência mínima para reversão

//+------------------------------------------------------------------+
//| Volume Analysis                                                  |
//+------------------------------------------------------------------+
input group "=== VOLUME ANALYSIS ==="
input double VOLUME_SPIKE_THRESHOLD = 150;            // % para considerar spike de volume
input double VOLUME_DECLINE_THRESHOLD = 80;           // % para considerar declínio de volume

//+------------------------------------------------------------------+
//| Spread Control                                                   |
//+------------------------------------------------------------------+
input group "=== SPREAD CONTROL ==="
input double MAX_SPREAD_MULTIPLIER = 2.0;             // Máximo spread em relação à média
input int    SPREAD_CHECK_PERIOD = 100;               // Período para calcular spread médio

//+------------------------------------------------------------------+
//| Error Handling                                                   |
//+------------------------------------------------------------------+
input group "=== ERROR HANDLING ==="
input int MAX_RETRIES = 3;                            // Máximo de tentativas
input int RETRY_DELAY_MS = 1000;                      // Delay entre tentativas (ms)
input int SUSPENSION_TIME_SEC = 300;                  // Tempo de suspensão após falhas (sec)

//+------------------------------------------------------------------+
//| Cache and Performance                                             |
//+------------------------------------------------------------------+
input group "=== CACHE AND PERFORMANCE ==="
input int INDICATOR_CACHE_SIZE = 1000;                // Tamanho do cache de indicadores
input int HISTORY_CHECK_INTERVAL = 300;               // Intervalo para recheck de histórico (sec)
input int LOG_BUFFER_SIZE = 1000;                     // Tamanho do buffer de logs
input int LOG_FLUSH_INTERVAL = 60;                    // Intervalo para flush de logs (sec)

//+------------------------------------------------------------------+
//| Alert and Notification                                           |
//+------------------------------------------------------------------+
input group "=== ALERT AND NOTIFICATION ==="
input bool   ENABLE_SOUND_ALERTS = true;              // Habilitar alertas sonoros
input bool   ENABLE_EMAIL_ALERTS = false;             // Habilitar alertas por email
input bool   ENABLE_PUSH_NOTIFICATIONS = false;       // Habilitar push notifications
input string ALERT_SOUND_FILE = "alert.wav";          // Arquivo de som
input string EMAIL_SUBJECT_PREFIX = "[INTEGRATED PA EA]"; // Prefixo do email
input int    ALERT_HISTORY_SIZE = 1000;               // Tamanho histórico alertas

//+------------------------------------------------------------------+
//| Additional Strategy Constants                                     |
//+------------------------------------------------------------------+
input group "=== TTRD STRATEGY ==="
input int    TTRD_MIN_RANGE_DURATION = 6;             // Duração mínima do range (barras)
input int    TTRD_MAX_RANGE_DURATION = 12;            // Duração máxima do range (barras)
input int    TTRD_MIN_RANGES = 3;                     // Mínimo de ranges para TTRD
input double TTRD_BREAKOUT_THRESHOLD = 0.1;           // Threshold para breakout (ATR)

input group "=== WEDGE REVERSAL ==="
input int    WEDGE_MIN_TOUCH_POINTS = 4;              // Mínimo de toques nas linhas
input int    WEDGE_MAX_DURATION = 20;                 // Duração máxima da cunha (barras)
input double WEDGE_CONVERGENCE_THRESHOLD = 0.05;      // Threshold de convergência
input double WEDGE_VOLUME_DECLINE = 0.8;              // Volume deve declinar (fator)

//+------------------------------------------------------------------+
//| Memory Management                                                 |
//+------------------------------------------------------------------+
input group "=== MEMORY MANAGEMENT ==="
input int MAX_SYMBOLS = 10;                           // Máximo de símbolos simultâneos
input int MAX_STRATEGIES = 5;                         // Máximo de estratégias por símbolo
input int MAX_SIGNALS_HISTORY = 100;                  // Máximo de sinais no histórico
input int MAX_TRADES_HISTORY = 1000;                  // Máximo de trades no histórico

//+------------------------------------------------------------------+
//| WIN (Mini Índice) - Valores em pontos                           |
//+------------------------------------------------------------------+
input group "=== WIN (Mini Índice) ==="
input int WIN_SPIKE_MAX_STOP = 1200;                  // Stop máximo durante spike
input int WIN_CHANNEL_MAX_STOP = 1000;                // Stop máximo durante canal
input int WIN_FIRST_TARGET = 800;                     // Primeiro alvo
input int WIN_SECOND_TARGET = 2000;                   // Segundo alvo
input int WIN_TRAILING_STOP = 400;                    // Trailing stop
input int WIN_MIN_STOP_DISTANCE = 100;                // Distância mínima do stop
input int WIN_BREAKEVEN_TRIGGER = 400;                // Move SL para BE após este lucro
input int WIN_PARTIAL_CLOSE_1 = 400;                  // Fecha 50% da posição no 1º alvo
input int WIN_MAX_HOLDING_BARS = 240;                 // Máximo 12h em M3 (240 * 3min)

//+------------------------------------------------------------------+
//| WDO (Mini Dólar) - Valores em pontos                            |
//+------------------------------------------------------------------+
input group "=== WDO (Mini Dólar) ==="
input int WDO_SPIKE_MAX_STOP = 15;                    // Stop máximo durante spike
input int WDO_CHANNEL_MAX_STOP = 12;                  // Stop máximo durante canal
input int WDO_FIRST_TARGET = 25;                      // Primeiro alvo
input int WDO_SECOND_TARGET = 45;                     // Segundo alvo
input int WDO_TRAILING_STOP = 18;                     // Trailing stop
input int WDO_MIN_STOP_DISTANCE = 10;                 // Distância mínima do stop

//+------------------------------------------------------------------+
//| BTC (Bitcoin Futuros) - Valores em USD                          |
//+------------------------------------------------------------------+
input group "=== BTC (Bitcoin Futuros) ==="
input int BTC_SPIKE_MAX_STOP = 1200;                  // Stop máximo durante spike
input int BTC_CHANNEL_MAX_STOP = 800;                 // Stop máximo durante canal
input int BTC_FIRST_TARGET = 2000;                    // Primeiro alvo
input int BTC_SECOND_TARGET = 4000;                   // Segundo alvo
input int BTC_TRAILING_STOP = 1000;                   // Trailing stop
input int BTC_MIN_STOP_DISTANCE = 600;                // Distância mínima do stop

//+------------------------------------------------------------------+
//| STOP LOSS MAIS CONSERVADORES                                     |
//+------------------------------------------------------------------+
input group "=== STOP LOSS AVANÇADO ==="
input double DEFAULT_ATR_MULTIPLIER = 3.0;            // Multiplicador ATR padrão
input double MIN_ATR_MULTIPLIER = 2.5;                // Multiplicador ATR mínimo
input double MAX_ATR_MULTIPLIER = 5.0;                // Multiplicador ATR máximo
input double STOP_LOSS_BUFFER_PERCENT = 0.2;          // Buffer adicional de 20% no stop loss
input double MIN_STOP_DISTANCE_PERCENT = 1.5;         // Mínimo 1.5% de distância do preço atual

//+------------------------------------------------------------------+
//| PARÂMETROS PARA DIFERENTES FASES DE MERCADO                      |
//+------------------------------------------------------------------+
input group "=== MULTIPLICADORES POR FASE ==="
input double TREND_STOP_MULTIPLIER = 1.0;             // Normal em tendência
input double RANGE_STOP_MULTIPLIER = 0.8;             // 20% menor em range
input double REVERSAL_STOP_MULTIPLIER = 1.3;          // 30% maior em reversão

//+------------------------------------------------------------------+
//| CONFIGURAÇÕES DE TRAILING STOP MELHORADAS                        |
//+------------------------------------------------------------------+
input group "=== TRAILING STOP MELHORADO ==="
input int    TRAILING_MIN_PROFIT_POINTS = 50;         // Mínimo lucro antes de ativar trailing
input double TRAILING_ACTIVATION_RR = 0.3;            // Ativar trailing após 0.3:1 R:R

//+------------------------------------------------------------------+
//| CONSTANTES NÃO CONFIGURÁVEIS                                     |
//+------------------------------------------------------------------+
// Constantes matemáticas - permanecem como #define
#define GOLDEN_RATIO                1.618
#define PI                          3.14159265359
#define E                           2.71828182846

// String Constants - permanecem como #define
#define STRATEGY_SPIKE_CHANNEL      "Spike and Channel"
#define STRATEGY_TTRD               "TTRD"
#define STRATEGY_WEDGE_REVERSAL     "Wedge Reversal"
#define STRATEGY_PULLBACK_EMA       "Pullback to EMA"
#define STRATEGY_BREAKOUT_PULLBACK  "Breakout Pullback"

// Color Constants for Visual Panel - permanecem como #define
#define COLOR_BACKGROUND            C'20,20,20'
#define COLOR_TEXT                  clrWhite
#define COLOR_HEADER                clrGold
#define COLOR_PROFIT                clrLime
#define COLOR_LOSS                  clrRed
#define COLOR_WARNING               clrOrange
#define COLOR_INFO                  clrCyan