//+------------------------------------------------------------------+
//|                                                   Constants.mqh |
//|                                                   ©2025, MANUS |
//|                         Compatível com MetaEditor Build 4885 – 28 Feb 2025 (≥ 4600) |
//+------------------------------------------------------------------+
#property copyright "©2025, MANUS"
#property link      "https://www.mql5.com"
#property version   "5.00"
#property strict


#define MAGIC_NUMBER             123456
//+------------------------------------------------------------------+
//| Constantes Padronizadas - Baseadas no Cap-14 do Guia            |
//+------------------------------------------------------------------+
#define STO_PERIOD              14    // Stochastic lento
#define STO_OVERSOLD            20    // Zona sobrevenda
#define STO_OVERBOUGHT          80    // Zona sobrecompra

#define VOLUME_PERIOD           20    // Média volume para comparação
#define VOLUME_THRESHOLD        120   // % mínimo volume para MTR

//------ Constantes para SPIKE AND CHANNEL ------
#define SPIKE_MIN_BARS          3     // Mínimo de barras para spike
#define SPIKE_MAX_BARS          5     // Máximo de barras para spike
#define SPIKE_MIN_BODY_RATIO    0.7   // Razão mínima corpo/total
#define SPIKE_MAX_OVERLAP       15.0  // Máxima sobreposição entre barras (%)

#define CHANNEL_MIN_PULLBACK    0.3   // Mínimo pullback no canal
#define CHANNEL_MAX_PULLBACK    0.8   // Máximo pullback no canal
#define CHANNEL_MIN_BARS        5     // Mínimo de barras no canal
#define CHANNEL_MAX_BARS        30    // Máximo de barras no canal

//------ Fibonacci Levels ------
#define FIB_LEVEL_236           0.236
#define FIB_LEVEL_382           0.382
#define FIB_LEVEL_500           0.500
#define FIB_LEVEL_618           0.618  // Golden Zone
#define FIB_LEVEL_786           0.786

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


// STOPS - Aumentados para reduzir exits prematuros
#define WIN_SPIKE_MAX_STOP          1200  // Stop máximo durante spike (era 800)
#define WIN_CHANNEL_MAX_STOP        1000  // Stop máximo durante canal (era 800)

// TARGETS - Otimizados para melhor R:R
#define WIN_FIRST_TARGET            800   // Primeiro alvo (era 500) - R:R 2:1 mínimo
#define WIN_SECOND_TARGET           2000  // Segundo alvo (era 1500) - R:R 4:1

// TRAILING - Ajustado para capturar mais movimento
#define WIN_TRAILING_STOP           400   // Trailing stop (era 350)
#define WIN_MIN_STOP_DISTANCE       300   // Distância mínima (era 250)

// NOVOS PARÂMETROS SUGERIDOS
#define WIN_BREAKEVEN_TRIGGER       400   // Move SL para BE após este lucro
#define WIN_PARTIAL_CLOSE_1         400   // Fecha 50% da posição no 1º alvo
#define WIN_MAX_HOLDING_BARS        240   // Máximo 12h em M3 (240 * 3min)


// WDO (Mini Dólar) - Valores em pontos - CORRIGIDO
#define WDO_SPIKE_MAX_STOP          15    // Stop máximo durante spike (era 7)
#define WDO_CHANNEL_MAX_STOP        12    // Stop máximo durante canal (era 5)
#define WDO_FIRST_TARGET            25    // Primeiro alvo (era 15)
#define WDO_SECOND_TARGET           45    // Segundo alvo (era 30)
#define WDO_TRAILING_STOP           18    // Trailing stop (era 12)
#define WDO_MIN_STOP_DISTANCE       10    // NOVO: Distância mínima do stop

// BTC (Bitcoin Futuros) - Valores em USD - CORRIGIDO
#define BTC_SPIKE_MAX_STOP          1200  // Stop máximo durante spike (era 700)
#define BTC_CHANNEL_MAX_STOP        800   // Stop máximo durante canal (era 500)
#define BTC_FIRST_TARGET            2000  // Primeiro alvo (era 1250)
#define BTC_SECOND_TARGET           4000  // Segundo alvo (era 3000)
#define BTC_TRAILING_STOP           1000  // Trailing stop (era 900)
#define BTC_MIN_STOP_DISTANCE       600   // NOVO: Distância mínima do stop

//------ NOVOS PARÂMETROS DE STOP LOSS MAIS CONSERVADORES ------
#define DEFAULT_ATR_MULTIPLIER      3.0   // Multiplicador ATR padrão (era 2.0)
#define MIN_ATR_MULTIPLIER          2.5   // Multiplicador ATR mínimo
#define MAX_ATR_MULTIPLIER          5.0   // Multiplicador ATR máximo

#define STOP_LOSS_BUFFER_PERCENT    0.2   // Buffer adicional de 20% no stop loss
#define MIN_STOP_DISTANCE_PERCENT   1.5   // Mínimo 1.5% de distância do preço atual

//------ PARÂMETROS PARA DIFERENTES FASES DE MERCADO ------
#define TREND_STOP_MULTIPLIER       1.0   // Normal em tendência
#define RANGE_STOP_MULTIPLIER       0.8   // 20% menor em range
#define REVERSAL_STOP_MULTIPLIER    1.3   // 30% maior em reversão

//------ CONFIGURAÇÕES DE TRAILING STOP MELHORADAS ------
#define TRAILING_UPDATE_INTERVAL    30    // Atualizar trailing a cada 30 segundos (não a cada tick)
#define TRAILING_MIN_PROFIT_POINTS  100   // Mínimo lucro antes de ativar trailing
#define TRAILING_ACTIVATION_RR      0.8   // Ativar trailing após 0.8:1 R:R