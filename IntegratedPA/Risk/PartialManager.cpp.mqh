#include "PartialManager.mqh"

bool CPartialManager::ConfigureSymbolPartials(string symbol,double &levels[],double &volumes[])
{
   int index = FindSymbolIndex(symbol);

   if(index < 0)
   {
      int newSize = ArraySize(m_symbols) + 1;
      if(ArrayResize(m_symbols,newSize) != newSize)
      {
         if(m_logger != NULL)
            m_logger.Error("PartialManager: Falha ao redimensionar array de simbolos");
         return false;
      }
      index = newSize - 1;
      m_symbols[index] = SymbolPartials();
      m_symbols[index].symbol = symbol;
   }

   int levelsSize = ArraySize(levels);
   int volumesSize = ArraySize(volumes);

   if(levelsSize != volumesSize || levelsSize == 0)
   {
      if(m_logger != NULL)
         m_logger.Error("PartialManager: Arrays de niveis e volumes devem ter o mesmo tamanho e nao podem ser vazios");
      return false;
   }

   for(int i=1;i<levelsSize;i++)
   {
      if(levels[i] <= levels[i-1])
      {
         if(m_logger != NULL)
         {
            m_logger.Warning(StringFormat("PartialManager: Niveis devem estar em ordem crescente. Nivel %d (%.2f) <= Nivel %d (%.2f)",
                                        i, levels[i], i-1, levels[i-1]));
         }
         return false;
      }
   }

   double totalVolume = 0.0;
   for(int i=0;i<volumesSize;i++)
      totalVolume += volumes[i];

   if(MathAbs(totalVolume - 1.0) > 0.01 && m_logger != NULL)
      m_logger.Warning(StringFormat("PartialManager: Soma dos volumes (%.2f) nao eh igual a 1.0", totalVolume));

   m_symbols[index].usePartials = true;

   int maxSize = MathMin(levelsSize,10);
   for(int i=0;i<maxSize;i++)
   {
      m_symbols[index].levels[i] = levels[i];
      m_symbols[index].volumes[i] = volumes[i];
   }

   if(m_logger != NULL)
   {
      string levelsStr = "";
      string volumesStr = "";
      for(int i=0;i<maxSize;i++)
      {
         levelsStr  += DoubleToString(levels[i],1) + " ";
         volumesStr += DoubleToString(volumes[i]*100,0) + "% ";
      }
      m_logger.Info(StringFormat("PartialManager: Parciais configuradas para %s: Niveis: %s, Volumes: %s",
                                 symbol, levelsStr, volumesStr));
   }

   return true;
}

bool CPartialManager::ShouldTakePartial(string symbol,ulong ticket,double currentRR)
{
   int index = FindSymbolIndex(symbol);
   if(index < 0 || !m_symbols[index].usePartials)
      return false;

   for(int i=0;i<10;i++)
   {
      if(m_symbols[index].levels[i] > 0 && currentRR >= m_symbols[index].levels[i])
         return true;
   }

   return false;
}

double CPartialManager::GetPartialVolume(string symbol,ulong ticket,double currentRR)
{
   int index = FindSymbolIndex(symbol);
   if(index < 0)
      return 0.0;

   for(int i=0;i<10;i++)
   {
      if(m_symbols[index].levels[i] > 0 && currentRR >= m_symbols[index].levels[i])
         return m_symbols[index].volumes[i];
   }

   return 0.0;
}
