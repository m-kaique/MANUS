//+------------------------------------------------------------------+
//| ✅ SISTEMA DE PARCIAIS UNIVERSAL - IMPLEMENTAÇÃO CORRIGIDA      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO: ClassifyAssetType                                    |
//| Classifica automaticamente o tipo de ativo                      |
//+------------------------------------------------------------------+
ASSET_TYPE CRiskManager::ClassifyAssetType(string symbol)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   
   // Validar informações do símbolo
   if (minLot <= 0 || stepLot <= 0 || maxLot <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("Informações de lote inválidas para %s: min=%.3f, step=%.3f, max=%.1f", 
                                     symbol, minLot, stepLot, maxLot));
      }
      return ASSET_UNKNOWN;
   }
   
   // Classificação baseada nas características de lote
   if (minLot <= 0.01 && stepLot <= 0.01)
   {
      // Ativos com lotes fracionários (Forex, Crypto)
      if (m_logger != NULL)
      {
         m_logger.Debug(StringFormat("%s classificado como ASSET_FRACTIONAL (min=%.3f, step=%.3f)", 
                                   symbol, minLot, stepLot));
      }
      return ASSET_FRACTIONAL;
   }
   else if (minLot >= 100.0)
   {
      // Ativos com lotes grandes (Ações em lotes de 100)
      if (m_logger != NULL)
      {
         m_logger.Debug(StringFormat("%s classificado como ASSET_LARGE_LOT (min=%.1f)", 
                                   symbol, minLot));
      }
      return ASSET_LARGE_LOT;
   }
   else if (minLot >= 1.0 && stepLot >= 1.0)
   {
      // Ativos com lotes inteiros (Futuros brasileiros)
      if (m_logger != NULL)
      {
         m_logger.Debug(StringFormat("%s classificado como ASSET_INTEGER (min=%.1f, step=%.1f)", 
                                   symbol, minLot, stepLot));
      }
      return ASSET_INTEGER;
   }
   
   // Caso não se encaixe em nenhuma categoria conhecida
   if (m_logger != NULL)
   {
      m_logger.Warning(StringFormat("%s não se encaixa em nenhuma categoria conhecida (min=%.3f, step=%.3f)", 
                                  symbol, minLot, stepLot));
   }
   return ASSET_UNKNOWN;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO: GetLotCharacteristics                                |
//| Obtém características completas de lote para um símbolo         |
//+------------------------------------------------------------------+
LotCharacteristics CRiskManager::GetLotCharacteristics(string symbol)
{
   LotCharacteristics lotChar;
   
   // Obter informações básicas do símbolo
   lotChar.minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   lotChar.maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   lotChar.stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Classificar tipo de ativo
   lotChar.type = ClassifyAssetType(symbol);
   
   // Determinar suporte a parciais e estratégia recomendada
   switch (lotChar.type)
   {
      case ASSET_FRACTIONAL:
         lotChar.supportsPartials = true;
         lotChar.minVolumeForPartials = 0.03; // 3 parciais de 0.01 cada
         lotChar.recommendedStrategy = PARTIAL_STRATEGY_ORIGINAL;
         break;
         
      case ASSET_INTEGER:
         lotChar.supportsPartials = true;
         lotChar.minVolumeForPartials = 10.0; // 10 lotes para parciais efetivas
         lotChar.recommendedStrategy = PARTIAL_STRATEGY_ADAPTIVE;
         break;
         
      case ASSET_LARGE_LOT:
         lotChar.supportsPartials = false;
         lotChar.minVolumeForPartials = 1000.0; // Muito alto, desencorajar parciais
         lotChar.recommendedStrategy = PARTIAL_STRATEGY_DISABLED;
         break;
         
      default:
         lotChar.supportsPartials = false;
         lotChar.minVolumeForPartials = 0.0;
         lotChar.recommendedStrategy = PARTIAL_STRATEGY_CONDITIONAL;
         break;
   }
   
   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Características de %s: tipo=%s, suporta_parciais=%s, vol_min=%.2f", 
                                symbol, EnumToString(lotChar.type), 
                                lotChar.supportsPartials ? "SIM" : "NÃO", 
                                lotChar.minVolumeForPartials));
   }
   
   return lotChar;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: CalculateUniversalPartials                |
//| Calcula parciais universais para qualquer tipo de ativo        |
//+------------------------------------------------------------------+
AdaptivePartialConfig CRiskManager::CalculateUniversalPartials(string symbol, double baseVolume,
                                                              double &originalPercentages[],
                                                              double &originalLevels[],
                                                              int numPartials,
                                                              SETUP_QUALITY quality)
{
   AdaptivePartialConfig config;
   
   // Inicializar configuração
   config.originalVolume = baseVolume;
   config.finalVolume = baseVolume;
   config.numPartials = numPartials;
   
   // Copiar percentuais originais
   for (int i = 0; i < numPartials && i < 10; i++)
   {
      config.originalPercentages[i] = originalPercentages[i];
      config.adaptedPercentages[i] = originalPercentages[i];
   }
   
   // Obter características do ativo
   LotCharacteristics lotChar = GetLotCharacteristics(symbol);
   
   // Determinar estratégia baseada no tipo de ativo e volume
   PARTIAL_STRATEGY strategy = DetermineOptimalStrategy(symbol, baseVolume, lotChar, originalPercentages, numPartials);
   config.strategy = strategy;
   
   // Aplicar estratégia escolhida
   switch (strategy)
   {
      case PARTIAL_STRATEGY_ORIGINAL:
         config.enabled = true;
         config.reason = "Ativo suporta lotes fracionários";
         break;
         
      case PARTIAL_STRATEGY_SCALED:
         config = ApplyScaledStrategy(symbol, config, lotChar, originalPercentages, numPartials, quality);
         break;
         
      case PARTIAL_STRATEGY_ADAPTIVE:
         config = ApplyAdaptiveStrategy(symbol, config, lotChar, originalPercentages, numPartials);
         break;
         
      case PARTIAL_STRATEGY_CONDITIONAL:
         config = ApplyConditionalStrategy(symbol, config, lotChar, originalPercentages, numPartials);
         break;
         
      case PARTIAL_STRATEGY_DISABLED:
         config.enabled = false;
         config.reason = "Tipo de ativo não suporta parciais efetivas";
         break;
   }

   // Aplicar correlação qualidade-risco ao fator de escalonamento
   double allowedFactor = CalculateRiskBasedScaling(quality, config.scalingFactor);
   if(!ValidateSetupForScaling(quality, allowedFactor))
   {
      config.enabled = false;
      config.finalVolume = config.originalVolume;
      config.scalingFactor = 1.0;
      config.reason = "Qualidade do setup não permite escalonamento";
   }
   else if(allowedFactor < config.scalingFactor)
   {
      config.finalVolume = config.originalVolume * allowedFactor;
      config.scalingFactor = allowedFactor;
   }

   // Logging detalhado da correlação qualidade-risco
   for(int i=0;i<ArraySize(riskMatrix);i++)
   {
      if(riskMatrix[i].quality==quality && m_logger!=NULL)
      {
         m_logger.Info(StringFormat("Setup Quality: %s | Factors: %d | R:R: %.1f | Max Scaling: %.1fx",
                                   EnumToString(quality),
                                   riskMatrix[i].minFactors,
                                   riskMatrix[i].minRiskReward,
                                   riskMatrix[i].maxScaling));
         break;
      }
   }
   
   // Validar configuração final
   if (config.enabled)
   {
      config.enabled = ValidateUniversalPartials(symbol, config.finalVolume, config.adaptedPercentages, numPartials);
      if (!config.enabled)
      {
         config.reason = "Validação final falhou";
      }
   }
   
   // Log da decisão
   LogPartialDecision(symbol, config);
   
   // ✅ ATUALIZAR MÉTRICAS
   UpdatePartialMetrics(config);
   
   return config;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: DetermineOptimalStrategy                  |
//| Determina a estratégia ótima baseada nas características        |
//+------------------------------------------------------------------+
PARTIAL_STRATEGY CRiskManager::DetermineOptimalStrategy(string symbol, double volume, 
                                                       LotCharacteristics &lotChar, 
                                                       double &percentages[], int numPartials)
{
   // Para ativos fracionários, sempre usar estratégia original
   if (lotChar.type == ASSET_FRACTIONAL)
   {
      return PARTIAL_STRATEGY_ORIGINAL;
   }
   
   // Para ativos com lotes grandes, desabilitar parciais
   if (lotChar.type == ASSET_LARGE_LOT)
   {
      return PARTIAL_STRATEGY_DISABLED;
   }
   
   // Para ativos com lotes inteiros (WIN$, WDO$)
   if (lotChar.type == ASSET_INTEGER)
   {
      // Verificar se volume é suficiente para parciais diretas
      bool canUseDirectPartials = true;
      for (int i = 0; i < numPartials; i++)
      {
         if (percentages[i] > 0)
         {
            double partialVolume = volume * percentages[i];
            if (partialVolume < lotChar.minLot)
            {
               canUseDirectPartials = false;
               break;
            }
         }
      }
      
      if (canUseDirectPartials)
      {
         return PARTIAL_STRATEGY_ADAPTIVE; // Adaptar percentuais
      }
      
      // Verificar se vale a pena escalar volume
      if (volume < lotChar.minVolumeForPartials)
      {
         double scalingFactor = lotChar.minVolumeForPartials / volume;
         if (scalingFactor <= 3.0) // Máximo 3x o volume original
         {
            return PARTIAL_STRATEGY_SCALED;
         }
      }
      
      // Se não for viável escalar, usar estratégia condicional
      return PARTIAL_STRATEGY_CONDITIONAL;
   }
   
   // Para tipos desconhecidos, usar estratégia condicional
   return PARTIAL_STRATEGY_CONDITIONAL;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ApplyScaledStrategy                       |
//| Aplica estratégia de volume escalado com verificações extras    |
//| (limites por símbolo, detecção de outliers e controle por equity)|
//+------------------------------------------------------------------+
AdaptivePartialConfig CRiskManager::ApplyScaledStrategy(string symbol, AdaptivePartialConfig &config,
                                                       LotCharacteristics &lotChar,
                                                       double &percentages[], int numPartials,
                                                       SETUP_QUALITY quality)
{
   // ✅ CORREÇÃO #1: Encontrar menor percentual com validação
   double smallestPercentage = 1.0;
   bool hasValidPercentages = false;
   
   for (int i = 0; i < numPartials; i++)
   {
      if (percentages[i] > 0)
      {
         // ✅ PROTEÇÃO: Percentual mínimo de 0.1% (0.001) para evitar overflow
         if (percentages[i] >= 0.001)
         {
            smallestPercentage = MathMin(smallestPercentage, percentages[i]);
            hasValidPercentages = true;
         }
         else
         {
            if (m_logger != NULL)
            {
               m_logger.Warning(StringFormat("⚠️ PERCENTUAL MUITO PEQUENO ignorado para %s: %.6f (mínimo: 0.1%%)", 
                                           symbol, percentages[i]));
            }
         }
      }
   }
   
   // ✅ CORREÇÃO #2: Validar se há percentuais válidos
   if (!hasValidPercentages || smallestPercentage >= 1.0)
   {
      config.enabled = false;
      config.reason = "Percentuais inválidos ou muito pequenos";
      if (m_logger != NULL)
      {
         m_logger.Error(StringFormat("❌ ESCALONAMENTO FALHOU para %s: percentuais inválidos (menor: %.6f)", 
                                   symbol, smallestPercentage));
      }
      return config;
   }
   
   // ✅ CORREÇÃO #3: Calcular volume mínimo com proteção contra overflow
   double minVolumeNeeded = lotChar.minLot / smallestPercentage;
   
   // ✅ PROTEÇÃO: Limite máximo por símbolo e broker
   double maxAllowedVolume = GetMaxVolumeBySymbol(symbol, config.originalVolume);
   
   if (minVolumeNeeded > maxAllowedVolume)
   {
      config.enabled = false;
      config.reason = StringFormat("Escalonamento excessivo necessário: %.1fx (máximo: 100x)",
                                  minVolumeNeeded / config.originalVolume);
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("⚠️ ESCALONAMENTO LIMITADO para %s: %.2f → %.2f (seria %.2f)",
                                     symbol, config.originalVolume, maxAllowedVolume, minVolumeNeeded));
      }
      return config;
   }
   else if(m_logger != NULL && minVolumeNeeded > maxAllowedVolume*0.9)
   {
      m_logger.Warning(StringFormat("⚠️ Volume proposto para %s próximo ao limite: %.2f / %.2f",
                                   symbol, minVolumeNeeded, maxAllowedVolume));
   }
   
   // ✅ CORREÇÃO #4: Arredondar para cima com validação
   minVolumeNeeded = MathCeil(minVolumeNeeded / lotChar.minLot) * lotChar.minLot;
   
   // ✅ CORREÇÃO #5: Aplicar escalonamento com validações
   double finalCandidate = MathMax(config.originalVolume, minVolumeNeeded);

   // Verificar outliers e limite por patrimônio
   if(IsVolumeOutlier(finalCandidate, symbol))
   {
      if(m_logger != NULL)
         m_logger.Warning(StringFormat("⚠️ Volume %.2f para %s considerado outlier. Reduzindo.",
                                      finalCandidate, symbol));
      if(m_metricsCollector != NULL)
         m_metricsCollector.RecordOutlierPrevention(finalCandidate, config.originalVolume);
      finalCandidate = config.originalVolume;
   }

   if(!ValidateVolumeByEquity(finalCandidate, symbol))
   {
      double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double equityLimit = (price > 0 && contractSize > 0) ? (equity * 0.10) / (price * contractSize) : finalCandidate;

      if(m_logger != NULL)
         m_logger.Warning(StringFormat("⚠️ Volume %.2f para %s excede 10%% da equity. Limitado a %.2f",
                                      finalCandidate, symbol, equityLimit));
      double limited = MathMin(finalCandidate, equityLimit);
      if(m_metricsCollector != NULL && limited < finalCandidate)
         m_metricsCollector.RecordVolumeAdjustment(finalCandidate, limited, "Equity Limit");
      finalCandidate = limited;
   }

   config.finalVolume = finalCandidate;
   if(m_metricsCollector != NULL && config.finalVolume < config.originalVolume)
      m_metricsCollector.RecordVolumeAdjustment(config.originalVolume, config.finalVolume, "Scaled Limit");
   config.volumeWasScaled = (config.finalVolume > config.originalVolume);
   
   // ✅ PROTEÇÃO: Evitar divisão por zero
   if (config.originalVolume > 0)
   {
      config.scalingFactor = config.finalVolume / config.originalVolume;
   }
   else
   {
      config.scalingFactor = 1.0;
   }
   
   config.enabled = true;
   config.reason = StringFormat("Volume escalado %.1fx para permitir parciais", config.scalingFactor);
   
   // ✅ LOG DETALHADO PARA DEBUGGING
   if (m_logger != NULL)
   {
      m_logger.LogVolumeScaling(symbol, quality, config.originalVolume, config.finalVolume,
                               "Partial scaling");
      m_logger.Debug(StringFormat("📊 DETALHES: menor percentual: %.3f%%, volume mínimo calculado: %.2f",
                                smallestPercentage * 100, minVolumeNeeded));
   }
   
   return config;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ApplyAdaptiveStrategy                     |
//| Aplica estratégia de parciais adaptativas                       |
//+------------------------------------------------------------------+
AdaptivePartialConfig CRiskManager::ApplyAdaptiveStrategy(string symbol, AdaptivePartialConfig &config, 
                                                         LotCharacteristics &lotChar, 
                                                         double &percentages[], int numPartials)
{
   double totalAdaptedVolume = 0;
   int adaptedLots[10];
   
   // Calcular lotes inteiros para cada parcial
   for (int i = 0; i < numPartials && i < 10; i++)
   {
      if (percentages[i] > 0)
      {
         double partialVolume = config.finalVolume * percentages[i];
         adaptedLots[i] = (int)MathMax(1, MathRound(partialVolume / lotChar.minLot));
         totalAdaptedVolume += adaptedLots[i] * lotChar.minLot;
      }
      else
      {
         adaptedLots[i] = 0;
      }
   }
   
   // Verificar se adaptação é viável
   if (totalAdaptedVolume > config.originalVolume * 1.5) // Tolerância de 50%
   {
      config.enabled = false;
      config.reason = StringFormat("Adaptação resultaria em volume muito alto (%.1f vs %.1f)", 
                                  totalAdaptedVolume, config.originalVolume);
      return config;
   }
   
   // Atualizar volume final e calcular percentuais adaptados
   config.finalVolume = totalAdaptedVolume;
   for (int i = 0; i < numPartials && i < 10; i++)
   {
      if (adaptedLots[i] > 0)
      {
         config.adaptedPercentages[i] = (adaptedLots[i] * lotChar.minLot) / totalAdaptedVolume;
      }
      else
      {
         config.adaptedPercentages[i] = 0;
      }
   }
   
   config.enabled = true;
   config.reason = StringFormat("Percentuais adaptados para lotes inteiros (volume: %.1f)", totalAdaptedVolume);
   
   if (m_logger != NULL)
   {
      m_logger.Info(StringFormat("Parciais adaptadas para %s: volume %.1f → %.1f", 
                                symbol, config.originalVolume, config.finalVolume));
   }
   
   return config;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ApplyConditionalStrategy                  |
//| Aplica estratégia condicional (desabilita se não viável)        |
//+------------------------------------------------------------------+
AdaptivePartialConfig CRiskManager::ApplyConditionalStrategy(string symbol, AdaptivePartialConfig &config, 
                                                           LotCharacteristics &lotChar, 
                                                           double &percentages[], int numPartials)
{
   // Verificar se cada parcial é viável
   for (int i = 0; i < numPartials; i++)
   {
      if (percentages[i] > 0)
      {
         double partialVolume = config.finalVolume * percentages[i];
         if (partialVolume < lotChar.minLot)
         {
            config.enabled = false;
            config.reason = StringFormat("Parcial %d resultaria em %.3f lotes (< %.1f mínimo)", 
                                        i+1, partialVolume, lotChar.minLot);
            return config;
         }
      }
   }
   
   // Se chegou até aqui, parciais são viáveis
   config.enabled = true;
   config.reason = "Parciais viáveis com volume atual";
   
   return config;
}


//+------------------------------------------------------------------+
//| ✅ FUNÇÕES DE VALIDAÇÃO ESPECÍFICAS - CORRIGIDAS PARA MQL5     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ValidateFractionalPartials                |
//| Valida parciais para ativos com lotes fracionários              |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateFractionalPartials(string symbol, double totalVolume, double &partialPercentages[], int numPartials)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Usar valores padrão se informações inválidas
   if (minLot <= 0) minLot = 0.01;
   if (stepLot <= 0) stepLot = 0.01;
   
   // ✅ CORREÇÃO: Validação robusta de percentuais
   double totalPercentage = 0;
   double minPartialVolume = totalVolume;
   int validPartials = 0;
   
   for (int i = 0; i < numPartials; i++)
   {
      if (partialPercentages[i] > 0)
      {
         // ✅ PROTEÇÃO: Verificar se percentual é válido (não muito pequeno, não muito grande)
         if (partialPercentages[i] < 0.001) // Menor que 0.1%
         {
            if (m_logger != NULL)
            {
               m_logger.Warning(StringFormat("⚠️ PERCENTUAL MUITO PEQUENO para %s parcial %d: %.6f%% (ignorado)", 
                                           symbol, i+1, partialPercentages[i] * 100));
            }
            partialPercentages[i] = 0; // Zerar percentual inválido
            continue;
         }
         
         if (partialPercentages[i] > 1.0) // Maior que 100%
         {
            if (m_logger != NULL)
            {
               m_logger.Warning(StringFormat("⚠️ PERCENTUAL MUITO GRANDE para %s parcial %d: %.1f%% (limitado a 100%%)", 
                                           symbol, i+1, partialPercentages[i] * 100));
            }
            partialPercentages[i] = 1.0; // Limitar a 100%
         }
         
         totalPercentage += partialPercentages[i];
         validPartials++;
         
         double partialVolume = totalVolume * partialPercentages[i];
         minPartialVolume = MathMin(minPartialVolume, partialVolume);
         
         // Verificar se parcial é maior que lote mínimo
         if (partialVolume < minLot)
         {
            if (m_logger != NULL)
            {
               m_logger.Warning(StringFormat("Parcial %d para %s muito pequena: %.3f < %.3f (mínimo)", 
                                           i+1, symbol, partialVolume, minLot));
            }
            return false;
         }
         
         // Verificar se parcial é múltiplo do step
         double remainder = fmod(partialVolume, stepLot);
         if (remainder > stepLot * 0.01) // Tolerância de 1%
         {
            if (m_logger != NULL)
            {
               m_logger.Debug(StringFormat("Parcial %d para %s será ajustada para step: %.3f → %.3f", 
                                         i+1, symbol, partialVolume, 
                                         MathFloor(partialVolume / stepLot) * stepLot));
            }
         }
      }
   }
   
   // ✅ CORREÇÃO: Verificar se há parciais válidas
   if (validPartials == 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error(StringFormat("❌ NENHUMA PARCIAL VÁLIDA para %s", symbol));
      }
      return false;
   }
   
   // ✅ CORREÇÃO: Verificar soma dos percentuais com tolerância maior
   if (MathAbs(totalPercentage - 1.0) > 0.05) // Tolerância de 5%
   {
      if (m_logger != NULL)
      {
         m_logger.Error(StringFormat("❌ SOMA DOS PERCENTUAIS INVÁLIDA para %s: %.3f%% (deveria ser 100%% ± 5%%)", 
                                   symbol, totalPercentage * 100));
      }
      return false;
   }
   
   // ✅ LOG DE SUCESSO
   if (m_logger != NULL && totalPercentage != 1.0)
   {
      m_logger.Info(StringFormat("✅ PERCENTUAIS AJUSTADOS para %s: %.1f%% (diferença: %.1f%%)", 
                                symbol, totalPercentage * 100, (totalPercentage - 1.0) * 100));
   }
   
   // Verificar volume mínimo total
   if (totalVolume < minLot)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("Volume total muito pequeno para %s: %.3f < %.3f", 
                                     symbol, totalVolume, minLot));
      }
      return false;
   }
   
   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Validação de parciais fracionárias para %s: APROVADA (volume: %.3f, menor parcial: %.3f)", 
                                symbol, totalVolume, minPartialVolume));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ValidateIntegerPartials                   |
//| Valida parciais para ativos com lotes inteiros (WIN$, WDO$)     |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateIntegerPartials(string symbol, double totalVolume, double &partialPercentages[], int numPartials)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Usar valores padrão se informações inválidas
   if (minLot <= 0) minLot = 1.0;
   if (stepLot <= 0) stepLot = 1.0;
   
   double totalPercentage = 0;
   double totalCalculatedVolume = 0;
   int validPartials = 0;
   
   for (int i = 0; i < numPartials; i++)
   {
      if (partialPercentages[i] > 0)
      {
         totalPercentage += partialPercentages[i];
         
         double partialVolume = totalVolume * partialPercentages[i];
         
         // Para lotes inteiros, verificar se resulta em pelo menos 1 lote
         if (partialVolume < minLot)
         {
            if (m_logger != NULL)
            {
               m_logger.Warning(StringFormat("Parcial %d para %s insuficiente: %.2f < %.0f lote(s)", 
                                           i+1, symbol, partialVolume, minLot));
            }
            return false;
         }
         
         // Calcular lotes inteiros
         int lots = (int)MathRound(partialVolume / minLot);
         double adjustedVolume = lots * minLot;
         totalCalculatedVolume += adjustedVolume;
         validPartials++;
         
         if (m_logger != NULL)
         {
            m_logger.Debug(StringFormat("Parcial %d para %s: %.2f → %d lote(s) (%.2f)", 
                                      i+1, symbol, partialVolume, lots, adjustedVolume));
         }
      }
   }
   
   // Verificar soma dos percentuais
   if (MathAbs(totalPercentage - 1.0) > 0.01)
   {
      if (m_logger != NULL)
      {
         m_logger.Error(StringFormat("Soma dos percentuais inválida para %s: %.3f (deveria ser 1.0)", 
                                   symbol, totalPercentage));
      }
      return false;
   }
   
   // Verificar se há pelo menos 2 parciais válidas
   if (validPartials < 2)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("Parciais insuficientes para %s: apenas %d válida(s)", 
                                     symbol, validPartials));
      }
      return false;
   }
   
   // Verificar se volume total ajustado não excede muito o original
   double volumeIncrease = ((totalCalculatedVolume - totalVolume) / totalVolume) * 100;
   if (volumeIncrease > 50.0) // Tolerância de 50%
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("Volume ajustado muito alto para %s: %.1f → %.1f (+%.1f%%)", 
                                     symbol, totalVolume, totalCalculatedVolume, volumeIncrease));
      }
      return false;
   }
   
   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Validação de parciais inteiras para %s: APROVADA (volume: %.1f → %.1f, parciais: %d)", 
                                symbol, totalVolume, totalCalculatedVolume, validPartials));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ValidateLargeLotPartials                  |
//| Valida parciais para ativos com lotes grandes (ações)           |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateLargeLotPartials(string symbol, double totalVolume, double &partialPercentages[], int numPartials)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   
   // Usar valor padrão se informação inválida
   if (minLot <= 0) minLot = 100.0; // Padrão para ações
   
   // Para ativos com lotes grandes, geralmente não recomendamos parciais
   if (minLot >= 100.0)
   {
      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("Parciais não recomendadas para %s (lote mínimo: %.0f)", 
                                  symbol, minLot));
      }
      return false;
   }
   
   // Se mesmo assim quiser validar, verificar viabilidade
   double totalPercentage = 0;
   int viablePartials = 0;
   
   for (int i = 0; i < numPartials; i++)
   {
      if (partialPercentages[i] > 0)
      {
         totalPercentage += partialPercentages[i];
         
         double partialVolume = totalVolume * partialPercentages[i];
         
         if (partialVolume >= minLot)
         {
            viablePartials++;
         }
         else
         {
            if (m_logger != NULL)
            {
               m_logger.Warning(StringFormat("Parcial %d para %s inviável: %.0f < %.0f (lote mínimo)", 
                                           i+1, symbol, partialVolume, minLot));
            }
         }
      }
   }
   
   // Verificar soma dos percentuais
   if (MathAbs(totalPercentage - 1.0) > 0.01)
   {
      if (m_logger != NULL)
      {
         m_logger.Error(StringFormat("Soma dos percentuais inválida para %s: %.3f (deveria ser 1.0)", 
                                   symbol, totalPercentage));
      }
      return false;
   }
   
   // Para lotes grandes, exigir volume muito alto para parciais
   double minVolumeForPartials = minLot * numPartials * 2; // Pelo menos 2x o mínimo por parcial
   if (totalVolume < minVolumeForPartials)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("Volume insuficiente para parciais em %s: %.0f < %.0f", 
                                     symbol, totalVolume, minVolumeForPartials));
      }
      return false;
   }
   
   // Verificar se há parciais viáveis suficientes
   if (viablePartials < 2)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("Parciais viáveis insuficientes para %s: apenas %d", 
                                     symbol, viablePartials));
      }
      return false;
   }
   
   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Validação de parciais para lotes grandes %s: APROVADA (volume: %.0f, parciais viáveis: %d)", 
                                symbol, totalVolume, viablePartials));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ValidateUniversalPartials                 |
//| Valida parciais usando a função específica do tipo de ativo     |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateUniversalPartials(string symbol, double totalVolume, double &partialPercentages[], int numPartials)
{
   // Obter tipo de ativo
   ASSET_TYPE assetType = ClassifyAssetType(symbol);
   
   // Chamar função de validação específica
   switch (assetType)
   {
      case ASSET_FRACTIONAL:
         return ValidateFractionalPartials(symbol, totalVolume, partialPercentages, numPartials);
         
      case ASSET_INTEGER:
         return ValidateIntegerPartials(symbol, totalVolume, partialPercentages, numPartials);
         
      case ASSET_LARGE_LOT:
         return ValidateLargeLotPartials(symbol, totalVolume, partialPercentages, numPartials);
         
      default:
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Tipo de ativo desconhecido para %s, usando validação condicional", symbol));
         }
         return ValidateIntegerPartials(symbol, totalVolume, partialPercentages, numPartials);
   }
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÕES AUXILIARES                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO: LogPartialDecision                                   |
//| Registra logs detalhados da decisão de parciais                 |
//+------------------------------------------------------------------+
void CRiskManager::LogPartialDecision(string symbol, AdaptivePartialConfig &config)
{
   if (m_logger == NULL) return;
   
   m_logger.Info(StringFormat("=== DECISÃO DE PARCIAIS PARA %s ===", symbol));
   m_logger.Info(StringFormat("Estratégia: %s", EnumToString(config.strategy)));
   m_logger.Info(StringFormat("Habilitado: %s", config.enabled ? "SIM" : "NÃO"));
   m_logger.Info(StringFormat("Razão: %s", config.reason));
   m_logger.Info(StringFormat("Volume: %.3f → %.3f", config.originalVolume, config.finalVolume));
   
   if (config.volumeWasScaled)
   {
      m_logger.Info(StringFormat("Volume escalado: %.1fx", config.scalingFactor));
   }
   
   if (config.enabled)
   {
      for (int i = 0; i < config.numPartials; i++)
      {
         if (config.originalPercentages[i] > 0)
         {
            double originalLots = config.originalVolume * config.originalPercentages[i];
            double finalLots = config.finalVolume * config.adaptedPercentages[i];
            
            m_logger.Info(StringFormat("Parcial %d: %.1f%% (%.2f lotes) → %.1f%% (%.2f lotes)", 
                                     i+1, 
                                     config.originalPercentages[i] * 100, originalLots,
                                     config.adaptedPercentages[i] * 100, finalLots));
         }
      }
   }
   
   m_logger.Info("=== FIM DA DECISÃO DE PARCIAIS ===");
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO: UpdatePartialMetrics                                |
//| Atualiza métricas de performance das parciais                   |
//+------------------------------------------------------------------+
void CRiskManager::UpdatePartialMetrics(AdaptivePartialConfig &config)
{
   m_partialMetrics.totalOperations++;
   m_partialMetrics.totalVolumeOriginal += config.originalVolume;
   m_partialMetrics.totalVolumeFinal += config.finalVolume;
   
   if (config.enabled)
   {
      m_partialMetrics.operationsWithPartials++;
      
      if (config.volumeWasScaled)
      {
         m_partialMetrics.operationsScaled++;
      }
      
      if (config.strategy == PARTIAL_STRATEGY_ADAPTIVE)
      {
         m_partialMetrics.operationsAdapted++;
      }
   }
   else
   {
      m_partialMetrics.operationsDisabled++;
   }
   
   // Calcular médias
   if (m_partialMetrics.totalOperations > 0)
   {
      m_partialMetrics.avgVolumeIncrease = 
         ((m_partialMetrics.totalVolumeFinal - m_partialMetrics.totalVolumeOriginal) / 
          m_partialMetrics.totalVolumeOriginal) * 100.0;
          
      m_partialMetrics.avgPartialEfficiency = 
         (double)m_partialMetrics.operationsWithPartials / m_partialMetrics.totalOperations * 100.0;
   }
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO: ResetPartialMetrics                                 |
//| Reinicializa métricas de parciais                               |
//+------------------------------------------------------------------+
void CRiskManager::ResetPartialMetrics()
{
   m_partialMetrics.totalOperations = 0;
   m_partialMetrics.operationsWithPartials = 0;
   m_partialMetrics.operationsScaled = 0;
   m_partialMetrics.operationsAdapted = 0;
   m_partialMetrics.operationsDisabled = 0;
   m_partialMetrics.totalVolumeOriginal = 0.0;
   m_partialMetrics.totalVolumeFinal = 0.0;
   m_partialMetrics.avgVolumeIncrease = 0.0;
   m_partialMetrics.avgPartialEfficiency = 0.0;
   m_partialMetrics.lastReset = TimeCurrent();
   
   if (m_logger != NULL)
   {
      m_logger.Info("Métricas de parciais universais reinicializadas");
   }
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO AUXILIAR: GetScalingTier                              |
//| Retorna o menor tier permitido que atenda ao fator requerido    |
//+------------------------------------------------------------------+
double CRiskManager::GetScalingTier(SETUP_QUALITY quality, double requiredFactor, double maxFactor)
{
   int qIndex = (int)quality;
   if(qIndex < 0 || qIndex >= ArraySize(m_qualityScaling))
      qIndex = 0; // SETUP_INVALID

   // Limites baseados na qualidade do setup
   double qualityLimit = 1.0;
   switch(quality)
   {
      case SETUP_A_PLUS: qualityLimit = 5.0; break;
      case SETUP_A:      qualityLimit = 3.0; break;
      case SETUP_B:      qualityLimit = 2.0; break;
      case SETUP_C:      qualityLimit = 1.0; break;
      default:           qualityLimit = 1.0; break;
   }

   // Aplicar limite efetivo
   double effectiveMax = MathMin(maxFactor, qualityLimit);

   for(int i = 0; i < m_qualityScaling[qIndex].count; i++)
   {
      double tier = m_qualityScaling[qIndex].tiers[i];
      if(tier <= effectiveMax && tier >= requiredFactor)
         return tier;
   }

   return (effectiveMax >= requiredFactor) ? effectiveMax : 0.0;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO AUXILIAR: CalculateRiskBasedScaling                   |
//| Limita o escalonamento baseado na qualidade do setup            |
//+------------------------------------------------------------------+
double CRiskManager::CalculateRiskBasedScaling(SETUP_QUALITY quality, double baseScaling)
{
   for(int i=0;i<ArraySize(riskMatrix);i++)
   {
      if(riskMatrix[i].quality==quality)
         return(MathMin(baseScaling, riskMatrix[i].maxScaling));
   }
   return(1.0);
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO AUXILIAR: ValidateSetupForScaling                     |
//| Impede escalonamento inadequado para setups fracos              |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateSetupForScaling(SETUP_QUALITY quality, double requestedScaling)
{
   if(quality==SETUP_C && requestedScaling>1.0)
   {
      if(m_logger!=NULL)
         m_logger.Warning("Setup C cannot be scaled beyond 1x");
      return(false);
   }
   return(true);
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO: GetPartialReport                                    |
//| Gera relatório de parciais para um símbolo                      |
//+------------------------------------------------------------------+
string CRiskManager::GetPartialReport(string symbol)
{
   int index = FindSymbolIndex(symbol);
   
   if (index < 0)
   {
      return StringFormat("Símbolo %s não encontrado", symbol);
   }
   
   string report = StringFormat("=== RELATÓRIO DE PARCIAIS: %s ===\n", symbol);
   report += StringFormat("Tipo de Ativo: %s\n", EnumToString(m_symbolParams[index].assetType));
   report += StringFormat("Estratégia: %s\n", EnumToString(m_symbolParams[index].partialStrategy));
   report += StringFormat("Volume Mínimo: %.2f\n", m_symbolParams[index].minVolumeForPartials);
   report += StringFormat("Permite Escalonamento: %s\n", m_symbolParams[index].allowVolumeScaling ? "SIM" : "NÃO");
   report += StringFormat("Fator Máximo: %.1fx\n", m_symbolParams[index].maxScalingFactor);
   
   // Características de lote
   report += StringFormat("Lote Mínimo: %.3f\n", m_symbolParams[index].lotChar.minLot);
   report += StringFormat("Lote Máximo: %.1f\n", m_symbolParams[index].lotChar.maxLot);
   report += StringFormat("Step: %.3f\n", m_symbolParams[index].lotChar.stepLot);
   
   // Última configuração
   if (m_symbolParams[index].lastPartialConfig.enabled)
   {
      report += "\n--- ÚLTIMA CONFIGURAÇÃO ---\n";
      report += StringFormat("Volume: %.3f → %.3f\n", 
                           m_symbolParams[index].lastPartialConfig.originalVolume,
                           m_symbolParams[index].lastPartialConfig.finalVolume);
      report += StringFormat("Escalado: %s\n", 
                           m_symbolParams[index].lastPartialConfig.volumeWasScaled ? "SIM" : "NÃO");
      report += StringFormat("Razão: %s\n", m_symbolParams[index].lastPartialConfig.reason);
   }
   
   return report;
bool CRiskManager::ShouldTakePartial(string symbol, ulong ticket, double currentPrice, double entryPrice, double stopLoss) {
   // Implementação original mantida
   int index = FindSymbolIndex(symbol);
   if(index < 0 || !m_symbolParams[index].usePartials) return false;
   
   double riskPoints = MathAbs(entryPrice - stopLoss);
   double profitPoints = MathAbs(currentPrice - entryPrice);
   double currentRR = profitPoints / riskPoints;
   
   // Verificar se atingiu algum nível de parcial
   for(int i = 0; i < 10; i++) {
      if(m_symbolParams[index].partialLevels[i] > 0 && 
         currentRR >= m_symbolParams[index].partialLevels[i]) {
         return true;
      }
   }
   
   return false;
}

double CRiskManager::GetPartialVolume(string symbol, ulong ticket, double currentRR) {
   // Implementação original mantida
   int index = FindSymbolIndex(symbol);
   if(index < 0) return 0;
   
   for(int i = 0; i < 10; i++) {
      if(m_symbolParams[index].partialLevels[i] > 0 && 
         currentRR >= m_symbolParams[index].partialLevels[i]) {
         return m_symbolParams[index].partialVolumes[i];
      }
   }
   
   return 0;
}
