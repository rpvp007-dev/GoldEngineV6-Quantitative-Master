//+------------------------------------------------------------------+
//|                                           IPerformanceTracker.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IPERFORMANCE_TRACKER_MQH
#define GOLDENGINEV2_IPERFORMANCE_TRACKER_MQH

//+------------------------------------------------------------------+
//| Interface for Performance Tracker component                       |
//+------------------------------------------------------------------+
class IPerformanceTracker
{
public:
   virtual ~IPerformanceTracker() {}

   virtual double    GetSharpeRatio() = 0;
   virtual double    GetSortinoRatio() = 0;
   virtual double    GetProfitFactor() = 0;
   virtual double    GetMaxDrawdownPercent() = 0;
   virtual void      TrackEquityPoint(double equity) = 0;
   virtual void      UpdateMetrics() = 0;
};

#endif // GOLDENGINEV2_IPERFORMANCE_TRACKER_MQH
