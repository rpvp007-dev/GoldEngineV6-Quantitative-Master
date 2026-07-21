//+------------------------------------------------------------------+
//|                                                   IDashboard.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IDASHBOARD_MQH
#define GOLDENGINEV2_IDASHBOARD_MQH

#include "../Analytics/ITradeStatistics.mqh"
#include "../Analytics/IPerformanceTracker.mqh"

//+------------------------------------------------------------------+
//| Dashboard graphical interface (GITS V2.1)                        |
//+------------------------------------------------------------------+
class IDashboard
{
public:
   virtual ~IDashboard() {}

   /**
    * @brief Draws/Renders graphical dashboard elements on the chart.
    */
   virtual void      Render() = 0;

   /**
    * @brief Updates metrics in the dashboard from the Analytics components.
    */
   virtual void      UpdateMetrics(ITradeStatistics* stats, IPerformanceTracker* perf) = 0;

   /**
    * @brief Removes/Deletes all graphical objects from the chart.
    */
   virtual void      DestroyHUD() = 0;

   /**
    * @brief Handles chart events for user interactions (clicks, drags).
    */
   virtual void      OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {}
};

#endif // GOLDENGINEV2_IDASHBOARD_MQH
