#ifndef PARTIALMANAGER_MQH
#define PARTIALMANAGER_MQH
#property strict

#include "../Core/Structures.mqh"
#include "../Logging/Logger.mqh"

class CPartialManager
{
private:
   CLogger        *m_logger;

   struct SymbolPartials
   {
      string symbol;
      bool   usePartials;
      double levels[10];
      double volumes[10];

      SymbolPartials()
      {
         symbol = "";
         usePartials = true;
         for(int i=0;i<10;i++)
         {
            levels[i] = 0.0;
            volumes[i] = 0.0;
         }
      }
   };

   SymbolPartials m_symbols[];

   int FindSymbolIndex(string symbol)
   {
      for(int i=0;i<ArraySize(m_symbols);i++)
      {
         if(m_symbols[i].symbol==symbol)
            return i;
      }
      return -1;
   }

public:
   CPartialManager(CLogger *logger=NULL) { m_logger = logger; }

   bool ConfigureSymbolPartials(string symbol,double &levels[],double &volumes[]);
   bool ShouldTakePartial(string symbol,ulong ticket,double currentRR);
   double GetPartialVolume(string symbol,ulong ticket,double currentRR);
};

#endif // PARTIALMANAGER_MQH
