#ifndef ORDER_EXECUTION_MQH
#define ORDER_EXECUTION_MQH

// Order execution related methods

bool CTradeExecutor::Execute(OrderRequest &request)
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   if(m_circuitBreaker != NULL && !m_circuitBreaker.CanOperate())
   {
      m_lastError = -5;
      m_lastErrorDesc = "Circuit Breaker ativo";
      if(m_logger != NULL)
         m_logger.Warning("Execução bloqueada pelo Circuit Breaker");
      return false;
   }

   // Verificar parâmetros
   if (request.symbol == "" || request.volume <= 0)
   {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros de ordem inválidos";
      m_logger.Error(m_lastErrorDesc);
      return false;
   }

   // ✅ NOVA VALIDAÇÃO: Ajustar stops ANTES da execução
   double adjustedEntry = request.price;
   double adjustedSL = request.stopLoss;
   double adjustedTP = request.takeProfit;

   if (!ValidateAndAdjustStops(request.symbol, request.type, adjustedEntry, adjustedSL, adjustedTP))
   {
      m_lastError = -4;
      m_lastErrorDesc = "Falha na validação dos stops";
      m_logger.Error(m_lastErrorDesc);
      return false;
   }

   // Atualizar valores no request
   request.price = adjustedEntry;
   request.stopLoss = adjustedSL;
  request.takeProfit = adjustedTP;

   // Verificar slippage em relação ao preço atual
   double point=SymbolInfoDouble(request.symbol,SYMBOL_POINT);
   MqlTick t; SymbolInfoTick(request.symbol,t);
   double marketPrice = (request.type==ORDER_TYPE_SELL || request.type==ORDER_TYPE_SELL_LIMIT || request.type==ORDER_TYPE_SELL_STOP) ? t.bid : t.ask;
   double slipp = MathAbs(marketPrice - request.price)/point;
   if(request.maxSlippage>0 && slipp>request.maxSlippage)
   {
      if(m_logger!=NULL)
         m_logger.LogCategorized(LOG_TRADE_EXECUTION, LOG_LEVEL_WARNING, request.symbol,
                                "SLIPPAGE_TOO_BIG", DoubleToString(slipp,1), "");
      return false;
   }
   else if(request.maxSlippage>0 && slipp>0 && (request.type==ORDER_TYPE_BUY_LIMIT || request.type==ORDER_TYPE_SELL_LIMIT || request.type==ORDER_TYPE_BUY_STOP || request.type==ORDER_TYPE_SELL_STOP))
   {
      request.price = marketPrice;
      if(m_logger!=NULL)
         m_logger.LogCategorized(LOG_TRADE_EXECUTION, LOG_LEVEL_INFO, request.symbol,
                                "PENDING_MISPLACED", DoubleToString(slipp,1), "");
   }

   // Registrar detalhes da ordem
   m_logger.Info(StringFormat("Executando ordem: %s %s %.2f @ %.5f, SL: %.5f, TP: %.5f",
                              request.symbol,
                              request.type == ORDER_TYPE_BUY ? "BUY" : "SELL",
                              request.volume,
                              request.price,
                              request.stopLoss,
                              request.takeProfit));

   // Executar ordem com retry
   bool result = false;
   int retries = 0;

   while (retries < m_maxRetries && !result)
   {
      if (retries > 0)
      {
         m_logger.Warning(StringFormat("Tentativa %d de %d após erro: %d", retries + 1, m_maxRetries, m_lastError));
         Sleep(m_retryDelay);

         // ✅ Re-validar stops a cada tentativa (preços podem ter mudado)
         if (!ValidateAndAdjustStops(request.symbol, request.type, request.price, request.stopLoss, request.takeProfit))
         {
            m_logger.Error("Falha na re-validação dos stops");
            return false;
         }
      }

      // ✅ Para ordens de mercado, usar preço 0 (execução ao melhor preço disponível)
      double executionPrice = request.price;
      if (request.type == ORDER_TYPE_BUY || request.type == ORDER_TYPE_SELL)
      {
         executionPrice = 0; // Deixar o MT5 usar o preço de mercado atual
      }

      // Executar ordem de acordo com o tipo
      switch (request.type)
      {
      case ORDER_TYPE_BUY:
         result = m_trade.Buy(request.volume, request.symbol, executionPrice, request.stopLoss, request.takeProfit, request.comment);
         break;
      case ORDER_TYPE_SELL:
         result = m_trade.Sell(request.volume, request.symbol, executionPrice, request.stopLoss, request.takeProfit, request.comment);
         break;
      case ORDER_TYPE_BUY_LIMIT:
         result = m_trade.BuyLimit(request.volume, request.price, request.symbol, request.stopLoss, request.takeProfit, ORDER_TIME_GTC, 0, request.comment);
         break;
      case ORDER_TYPE_SELL_LIMIT:
         result = m_trade.SellLimit(request.volume, request.price, request.symbol, request.stopLoss, request.takeProfit, ORDER_TIME_GTC, 0, request.comment);
         break;
      case ORDER_TYPE_BUY_STOP:
         result = m_trade.BuyStop(request.volume, request.price, request.symbol, request.stopLoss, request.takeProfit, ORDER_TIME_GTC, 0, request.comment);
         break;
      case ORDER_TYPE_SELL_STOP:
         result = m_trade.SellStop(request.volume, request.price, request.symbol, request.stopLoss, request.takeProfit, ORDER_TIME_GTC, 0, request.comment);
         break;
      default:
         m_lastError = -3;
         m_lastErrorDesc = "Tipo de ordem não suportado";
         m_logger.Error(m_lastErrorDesc);
         return false;
      }

      // Verificar resultado
      if (!result)
      {
         m_lastError = (int)m_trade.ResultRetcode();
         m_lastErrorDesc = "Erro na execução da ordem: " + IntegerToString(m_lastError);

         // ✅ Log detalhado do erro
         if (m_logger != NULL)
         {
            m_logger.Error(StringFormat("%s - Retcode: %d, Comment: %s",
                                        m_lastErrorDesc,
                                        m_lastError,
                                        m_trade.ResultRetcodeDescription()));
         }

         // Verificar se o erro é recuperável
         if (!IsRetryableError(m_lastError))
         {
            m_logger.Error(m_lastErrorDesc);
            return false;
         }
      }

      retries++;
   }

   // Verificar resultado final
   if (result)
   {
      ulong ticket = m_trade.ResultOrder();
      m_logger.Info(StringFormat("Ordem executada com sucesso. Ticket: %d", ticket));

   // ✅ CORREÇÃO CRÍTICA: Configurar APENAS breakeven inicialmente
   // Trailing será configurado automaticamente após breakeven ser acionado
   if (ticket > 0)
   {
      AutoConfigureBreakeven(ticket, request.symbol);

      // ✅ NOVO: Configurar controle inteligente de parciais
      ConfigurePartialControl(ticket, request.symbol, request.price, request.volume);

      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("Breakeven e controle de parciais configurados para #%d. Trailing será ativado após breakeven.", ticket));
      }
   }
      if(m_circuitBreaker != NULL)
         m_circuitBreaker.RegisterSuccess();
      return true;
   }
   else
   {
      if(m_circuitBreaker != NULL)
         m_circuitBreaker.RegisterError();
      m_logger.Error(StringFormat("Falha na execução da ordem após %d tentativas. Último erro: %d", m_maxRetries, m_lastError));
      return false;
   }
}

//+------------------------------------------------------------------+
//| Modificação de posição                                           |
//+------------------------------------------------------------------+
bool CTradeExecutor::ModifyPosition(ulong ticket, double stopLoss, double takeProfit)
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   // Registrar detalhes da modificação
   m_logger.Info(StringFormat("Modificando posição #%d: SL: %.5f, TP: %.5f", ticket, stopLoss, takeProfit));

   // Executar modificação com retry
   bool result = false;
   int retries = 0;

   while (retries < m_maxRetries && !result)
   {
      if (retries > 0)
      {
         m_logger.Warning(StringFormat("Tentativa %d de %d após erro: %d", retries + 1, m_maxRetries, m_lastError));
         Sleep(m_retryDelay);
      }

      result = m_trade.PositionModify(ticket, stopLoss, takeProfit);

      // Verificar resultado
      if (!result)
      {
         m_lastError = (int)m_trade.ResultRetcode();
         m_lastErrorDesc = "Erro na modificação da posição: " + IntegerToString(m_lastError);

         // Verificar se o erro é recuperável
         if (!IsRetryableError(m_lastError))
         {
            m_logger.Error(m_lastErrorDesc);
            return false;
         }
      }

      retries++;
   }

   // Verificar resultado final
   if (result)
   {
      m_logger.Info(StringFormat("Posição #%d modificada com sucesso", ticket));
      return true;
   }
   else
   {
      m_logger.Error(StringFormat("Falha na modificação da posição #%d após %d tentativas. Último erro: %d", ticket, m_maxRetries, m_lastError));
      return false;
   }
}

//+------------------------------------------------------------------+
//| Fechamento de posição                                            |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ClosePosition                              |
//| Usa implementação oficial para fechamento total e parcial       |
//+------------------------------------------------------------------+
bool CTradeExecutor::ClosePosition(ulong ticket, double volume)
{
   // Validar e selecionar posição
   if(!PositionSelectByTicket(ticket))
   {
      m_lastError = ERR_TRADE_POSITION_NOT_FOUND;
      m_lastErrorDesc = "Posição não encontrada: " + IntegerToString(ticket);
      m_logger.Error(m_lastErrorDesc);
      return false;
   }
   
   // Obter volume atual da posição
   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   
   // Determinar tipo de fechamento
   bool isFullClose = (volume <= 0 || volume >= currentVolume);
   
   if(isFullClose)
   {
      // ✅ FECHAMENTO TOTAL USANDO CTrade
      m_logger.Info(StringFormat("Fechando posição #%d completamente (%.2f lotes)", ticket, currentVolume));
      
      bool result = false;
      int retries = 0;
      
      while(retries < m_maxRetries && !result)
      {
         if(retries > 0)
         {
            m_logger.Warning(StringFormat("Tentativa %d de %d após erro: %d", retries + 1, m_maxRetries, m_lastError));
            Sleep(m_retryDelay);
         }
         
         result = m_trade.PositionClose(ticket);
         
         if(!result)
         {
            m_lastError = (int)m_trade.ResultRetcode();
            m_lastErrorDesc = "Erro no fechamento da posição: " + IntegerToString(m_lastError);
            
            if(!IsRetryableError(m_lastError))
            {
               m_logger.Error(StringFormat("Erro não recuperável: %d", m_lastError));
               break;
            }
         }
         
         retries++;
      }
      
      if(result)
      {
         m_logger.Info(StringFormat("✅ POSIÇÃO #%d FECHADA COMPLETAMENTE", ticket));
      }
      else
      {
         m_logger.Error(StringFormat("❌ FALHA NO FECHAMENTO da posição #%d: %s", ticket, m_lastErrorDesc));
      }
      
      return result;
   }
   else
   {
      // ✅ FECHAMENTO PARCIAL USANDO OrderSend OFICIAL
      m_logger.Info(StringFormat("Fechando posição #%d parcialmente: %.2f de %.2f lotes", 
                                ticket, volume, currentVolume));
      
      return ClosePartialPosition(ticket, volume);
   }
}
//+------------------------------------------------------------------+
//| Fechamento de todas as posições                                  |
//+------------------------------------------------------------------+
bool CTradeExecutor::CloseAllPositions(string symbol = "")
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   // Registrar detalhes do fechamento
   if (symbol == "")
   {
      m_logger.Info("Fechando todas as posições");
   }
   else
   {
      m_logger.Info(StringFormat("Fechando todas as posições de %s", symbol));
   }

   // Contar posições abertas
   int totalPositions = PositionsTotal();
   int closedPositions = 0;

   // Fechar cada posição
   for (int i = totalPositions - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if (ticket <= 0)
      {
         m_logger.Warning(StringFormat("Falha ao obter ticket da posição %d", i));
         continue;
      }

      // Verificar símbolo se especificado
      if (symbol != "")
      {
         if (!PositionSelectByTicket(ticket))
         {
            m_logger.Warning(StringFormat("Falha ao selecionar posição #%d", ticket));
            continue;
         }

         string posSymbol = PositionGetString(POSITION_SYMBOL);
         if (posSymbol != symbol)
         {
            continue; // Pular posições de outros símbolos
         }
      }

      // Fechar posição
      if (ClosePosition(ticket))
      {
         closedPositions++;
      }
   }

   // Verificar resultado
   if (closedPositions > 0)
   {
      m_logger.Info(StringFormat("%d posições fechadas com sucesso", closedPositions));
      return true;
   }
   else if (totalPositions == 0)
   {
      m_logger.Info("Nenhuma posição aberta para fechar");
      return true;
   }
   else
   {
      m_logger.Warning(StringFormat("Nenhuma posição fechada de %d posições abertas", totalPositions));
      return false;
   }
}
#endif // ORDER_EXECUTION_MQH
