#ifndef __TRADING_CONTROL_MQH__
#define __TRADING_CONTROL_MQH__
#pragma  once

namespace TradingControl
{
   // flags globais (visíveis em todo o EA)
   bool g_allowEntry = true;
   bool g_allowExit  = true;

   // getters -----------------------------------------------------
   inline bool AllowEntry() { return g_allowEntry; }
   inline bool AllowExit()  { return g_allowExit;  }

   // setters -----------------------------------------------------
   inline void EnableEntry()  { g_allowEntry = true;  }
   inline void EnableExit()   { g_allowExit  = true;  }
   inline void DisableEntry() { g_allowEntry = false; }
   inline void DisableExit()  { g_allowExit  = false; }
}

#endif // __TRADING_CONTROL_MQH__
