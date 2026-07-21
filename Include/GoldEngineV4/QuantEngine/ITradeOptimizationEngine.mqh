//+------------------------------------------------------------------+
//|                                    ITradeOptimizationEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_ITRADE_OPTIMIZATION_ENGINE_MQH
#define GOLDENGINEV2_ITRADE_OPTIMIZATION_ENGINE_MQH

#include "TradeOptimizationDefines.mqh"
#include "../Strategy/IStrategy.mqh"
#include "../Core/Config.mqh"

//--- Abstract Interface for Self Learning & Trade Optimization Engine
class ITradeOptimizationEngine
{
public:
   virtual ~ITradeOptimizationEngine() {}

   /**
    * @brief Initializes indicators/settings and holds references to config and other engines.
    */
   virtual bool Initialize(const QuantEnginesContainer &engines, CConfig* config) = 0;

   /**
    * @brief Runs on every tick to track open position entry conditions and process closures.
    */
   virtual void Update(const string symbol) = 0;

   /**
    * @brief Retrieves computed aggregate performance metrics.
    */
   virtual GITSPerformanceStats GetPerformanceStats() const = 0;

   /**
    * @brief Gets total dynamically discovered edge patterns.
    */
   virtual int GetObservationsCount() const = 0;

   /**
    * @brief Gets description of a discovered pattern by index.
    */
   virtual string GetObservation(int index) const = 0;

   /**
    * @brief Exports the entire optimization database to CSV.
    */
   virtual void ExportToCSV() = 0;
};

#endif // GOLDENGINEV2_ITRADE_OPTIMIZATION_ENGINE_MQH
