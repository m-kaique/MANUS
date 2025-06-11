#ifndef PARTIALMANAGER_MQH
#define PARTIALMANAGER_MQH
#property strict

#include "../Core/Structures.mqh"
#include "../Logging/Logger.mqh"

class CPartialManager
{
private:
   CLogger        *m_logger;
public:
   CPartialManager(CLogger *logger=NULL) { m_logger = logger; }

   bool ConfigureSymbolPartials(string symbol,double &levels[],double &volumes[]);
   bool ShouldTakePartial(string symbol,ulong ticket,double currentRR);
   double GetPartialVolume(string symbol,ulong ticket,double currentRR);
};

#endif // PARTIALMANAGER_MQH
