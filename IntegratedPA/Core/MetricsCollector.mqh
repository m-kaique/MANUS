#ifndef METRICSCOLLECTOR_MQH
#define METRICSCOLLECTOR_MQH
#property strict

#include "Structures.mqh"

//+------------------------------------------------------------------+
//| Classe para coleta e relatório de métricas de correção           |
//+------------------------------------------------------------------+
class CMetricsCollector
{
private:
   CorrectionMetrics m_metrics;       // Dados de métricas
   double            m_volumeHistory[]; // Histórico de volumes
   int               m_historySize;     // Tamanho máximo do histórico
   int               m_adjustCount;     // Contagem de ajustes de volume

public:
   CMetricsCollector(int historySize = 1000);

   void     RecordScaling(SETUP_QUALITY quality, double volume);
   void     RecordVolumeAdjustment(double originalVolume, double adjustedVolume, string reason);
   void     RecordOutlierPrevention(double proposedVolume, double limitedVolume);
   void     RecordDrawdownIntervention(double drawdownPercent, double volumeAdjustment);
   void     RecordCircuitBreakerActivation() { m_metrics.circuitBreakerActivations++; }
   datetime GetLastReportTime() { return m_metrics.lastReport; }
   void     GenerateReport();
   void     ResetMetrics();
};

//+------------------------------------------------------------------+
//| Implementação                                                   |
//+------------------------------------------------------------------+
CMetricsCollector::CMetricsCollector(int historySize)
{
   m_historySize  = historySize;
   ArrayResize(m_volumeHistory, 0);
   m_adjustCount  = 0;
   m_metrics      = CorrectionMetrics();
   m_metrics.metricsStartTime = TimeCurrent();
}

void CMetricsCollector::RecordScaling(SETUP_QUALITY quality, double volume)
{
   m_metrics.totalScalings++;

   switch(quality)
   {
      case SETUP_A_PLUS: m_metrics.scalingsA_Plus++; break;
      case SETUP_A:      m_metrics.scalingsA++; break;
      case SETUP_B:      m_metrics.scalingsB++; break;
      case SETUP_C:      m_metrics.scalingsC++; break;
      default:           break;
   }

   int newSize = ArraySize(m_volumeHistory) + 1;
   if(newSize > m_historySize)
   {
      ArrayRemove(m_volumeHistory, 0);
      newSize = m_historySize;
   }
   ArrayResize(m_volumeHistory, newSize);
   m_volumeHistory[newSize-1] = volume;

   if(volume > m_metrics.maxVolumeRecorded)
      m_metrics.maxVolumeRecorded = volume;
}

void CMetricsCollector::RecordVolumeAdjustment(double originalVolume, double adjustedVolume, string reason)
{
   m_adjustCount++;
   m_metrics.avgVolumeBeforeCorrection = ((m_metrics.avgVolumeBeforeCorrection*(m_adjustCount-1)) + originalVolume) / m_adjustCount;
   m_metrics.avgVolumeAfterCorrection  = ((m_metrics.avgVolumeAfterCorrection*(m_adjustCount-1)) + adjustedVolume) / m_adjustCount;

   if(adjustedVolume > m_metrics.maxVolumeRecorded)
      m_metrics.maxVolumeRecorded = adjustedVolume;

   if(StringFind(reason, "Volatility") >= 0)
      m_metrics.volatilityAdjustments++;
}

void CMetricsCollector::RecordOutlierPrevention(double proposedVolume, double limitedVolume)
{
   m_metrics.outliersPrevented++;
   RecordVolumeAdjustment(proposedVolume, limitedVolume, "Outlier Prevention");
}

void CMetricsCollector::RecordDrawdownIntervention(double drawdownPercent, double volumeAdjustment)
{
   m_metrics.drawdownInterventions++;
   // volumeAdjustment assumed to be multiplicative factor, no average update
}

void CMetricsCollector::GenerateReport()
{
   string report = "=== CORRECTION METRICS REPORT ===\n";
   report += StringFormat("Period: %s to %s\n",
                          TimeToString(m_metrics.metricsStartTime),
                          TimeToString(TimeCurrent()));

   report += "\n--- SCALING DISTRIBUTION ---\n";
   report += StringFormat("Total Scalings: %d\n", m_metrics.totalScalings);
   report += StringFormat("Setup A+: %d (%.1f%%)\n",
                          m_metrics.scalingsA_Plus,
                          m_metrics.totalScalings>0 ? (double)m_metrics.scalingsA_Plus/m_metrics.totalScalings*100.0 : 0.0);
   report += StringFormat("Setup A:  %d (%.1f%%)\n",
                          m_metrics.scalingsA,
                          m_metrics.totalScalings>0 ? (double)m_metrics.scalingsA/m_metrics.totalScalings*100.0 : 0.0);
   report += StringFormat("Setup B:  %d (%.1f%%)\n",
                          m_metrics.scalingsB,
                          m_metrics.totalScalings>0 ? (double)m_metrics.scalingsB/m_metrics.totalScalings*100.0 : 0.0);
   report += StringFormat("Setup C:  %d (%.1f%%)\n",
                          m_metrics.scalingsC,
                          m_metrics.totalScalings>0 ? (double)m_metrics.scalingsC/m_metrics.totalScalings*100.0 : 0.0);

   report += "\n--- VOLUME CONTROL ---\n";
   report += StringFormat("Max Volume: %.2f lots\n", m_metrics.maxVolumeRecorded);
   report += StringFormat("Outliers Prevented: %d\n", m_metrics.outliersPrevented);
   if(m_metrics.avgVolumeBeforeCorrection > 0)
      report += StringFormat("Avg Volume Reduction: %.1f%%\n",
                             (1.0 - m_metrics.avgVolumeAfterCorrection/m_metrics.avgVolumeBeforeCorrection)*100.0);
   else
      report += "Avg Volume Reduction: 0\n";

   report += "\n--- RISK INTERVENTIONS ---\n";
   report += StringFormat("Drawdown Interventions: %d\n", m_metrics.drawdownInterventions);
   report += StringFormat("Volatility Adjustments: %d\n", m_metrics.volatilityAdjustments);
   report += StringFormat("Circuit Breaker Activations: %d\n", m_metrics.circuitBreakerActivations);

   Print(report);

   string filename = "CorrectionMetrics_" + TimeToString(TimeCurrent(), TIME_DATE) + ".txt";
   int file = FileOpen(filename, FILE_WRITE|FILE_TXT);
   if(file != INVALID_HANDLE)
   {
      FileWrite(file, report);
      FileClose(file);
   }

   m_metrics.lastReport = TimeCurrent();
}

void CMetricsCollector::ResetMetrics()
{
   m_metrics = CorrectionMetrics();
   ArrayResize(m_volumeHistory, 0);
   m_adjustCount = 0;
   m_metrics.metricsStartTime = TimeCurrent();
   m_metrics.lastReset = TimeCurrent();
}

#endif // METRICSCOLLECTOR_MQH
