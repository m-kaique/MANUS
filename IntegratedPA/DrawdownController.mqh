#ifndef DRAWDOWNCONTROLLER_MQH
#define DRAWDOWNCONTROLLER_MQH


//+------------------------------------------------------------------+
//| Níveis de drawdown                                               |
//+------------------------------------------------------------------+
enum ENUM_DRAWDOWN_LEVEL
{
   DD_NORMAL,     // <5% drawdown
   DD_WARNING,    // 5-10% drawdown
   DD_CRITICAL,   // 10-15% drawdown
   DD_EMERGENCY   // >15% drawdown
};

//+------------------------------------------------------------------+
//| Controlador de drawdown automatizado                             |
//+------------------------------------------------------------------+
class CDrawdownController
{
private:
   double             m_equityPeak;
   double             m_currentDrawdown;
   ENUM_DRAWDOWN_LEVEL m_currentLevel;
   datetime           m_lastDrawdownCheck;
   bool               m_tradingPaused;

public:
   CDrawdownController();
   void     UpdateDrawdownStatus();
   double   GetVolumeAdjustment();
   bool     IsTradingAllowed();
   void     ResetDrawdownTracking();
   ENUM_DRAWDOWN_LEVEL GetCurrentLevel();
   double   GetCurrentDrawdown() { return m_currentDrawdown; }
};

//+------------------------------------------------------------------+
//| Implementação                                                   |
//+------------------------------------------------------------------+
CDrawdownController::CDrawdownController()
{
   m_equityPeak        = AccountInfoDouble(ACCOUNT_EQUITY);
   m_currentDrawdown   = 0.0;
   m_currentLevel      = DD_NORMAL;
   m_lastDrawdownCheck = TimeCurrent();
   m_tradingPaused     = false;
}

void CDrawdownController::UpdateDrawdownStatus()
{
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentEquity > m_equityPeak)
      m_equityPeak = currentEquity;

   if(m_equityPeak > 0)
      m_currentDrawdown = (m_equityPeak - currentEquity) / m_equityPeak * 100.0;
   else
      m_currentDrawdown = 0.0;

   if(m_currentDrawdown >= 15.0)
   {
      m_currentLevel  = DD_EMERGENCY;
      m_tradingPaused = true;
   }
   else if(m_currentDrawdown >= 10.0)
   {
      m_currentLevel = DD_CRITICAL;
   }
   else if(m_currentDrawdown >= 5.0)
   {
      m_currentLevel = DD_WARNING;
   }
   else
   {
      m_currentLevel = DD_NORMAL;
      if(m_currentDrawdown < 3.0)
         m_tradingPaused = false;
   }
}

double CDrawdownController::GetVolumeAdjustment()
{
   switch(m_currentLevel)
   {
      case DD_WARNING:   return 0.8;  // Reduce volume by 20%
      case DD_CRITICAL:  return 0.5;  // Reduce volume by 50%
      case DD_EMERGENCY: return 0.0;  // No trading
      default:           return 1.0;  // Normal
   }
}

bool CDrawdownController::IsTradingAllowed()
{
   return !m_tradingPaused;
}

void CDrawdownController::ResetDrawdownTracking()
{
   if(m_currentDrawdown < 3.0 && m_tradingPaused)
   {
      m_tradingPaused = false;
      Print("Trading resumed - drawdown reduced below 3%");
   }
}

ENUM_DRAWDOWN_LEVEL CDrawdownController::GetCurrentLevel()
{
   return m_currentLevel;
}

#endif // DRAWDOWNCONTROLLER_MQH
