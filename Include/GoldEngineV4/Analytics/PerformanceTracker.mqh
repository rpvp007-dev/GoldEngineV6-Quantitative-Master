//+------------------------------------------------------------------+
//|                                             PerformanceTracker.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_PERFORMANCE_TRACKER_MQH
#define GOLDENGINEV2_PERFORMANCE_TRACKER_MQH

#include "IPerformanceTracker.mqh"
#include "../Core/Logger.mqh"

//+------------------------------------------------------------------+
//| Performance Tracker Component Concrete Implementation (Skeleton)  |
//+------------------------------------------------------------------+
class CPerformanceTracker : public IPerformanceTracker
{
private:
   CLogger*          m_logger;
   double            m_sharpe;
   double            m_sortino;
   double            m_profitFactor;
   double            m_drawdown;

public:
   CPerformanceTracker(CLogger* logger)
      : m_logger(logger),
        m_sharpe(0.0),
        m_sortino(0.0),
        m_profitFactor(0.0),
        m_drawdown(0.0)
   {}
   ~CPerformanceTracker() {}

   virtual double    GetSharpeRatio() override { return m_sharpe; }
   virtual double    GetSortinoRatio() override { return m_sortino; }
   virtual double    GetProfitFactor() override { return m_profitFactor; }
   virtual double    GetMaxDrawdownPercent() override { return m_drawdown; }
   virtual void      TrackEquityPoint(double equity) override {}
   virtual void      UpdateMetrics() override
   {
      m_logger.Debug("PerformanceTracker: Recalculating mathematical ratios (Sharpe, Sortino).");
   }
};

#endif // GOLDENGINEV2_PERFORMANCE_TRACKER_MQH
