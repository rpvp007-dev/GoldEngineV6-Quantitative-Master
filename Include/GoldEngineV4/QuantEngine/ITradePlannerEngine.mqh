//+------------------------------------------------------------------+
//|                                        ITradePlannerEngine.mqh   |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_ITRADE_PLANNER_ENGINE_MQH
#define GOLDENGINEV2_ITRADE_PLANNER_ENGINE_MQH

#include "TradePlannerDefines.mqh"

// Forward declaration to resolve circular dependency
struct QuantEnginesContainer;

//+------------------------------------------------------------------+
//| Interface for Trade Planner Engine                               |
//+------------------------------------------------------------------+
class ITradePlannerEngine
{
public:
   virtual ~ITradePlannerEngine() {}

   /**
    * @brief Initializes engine with container references to other engines.
    */
   virtual bool      Initialize(const QuantEnginesContainer &engines) = 0;

   /**
    * @brief Updates trade planning context for the closed candle.
    */
   virtual void      UpdatePlan(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Retrieves the calculated trade plan context data.
    */
   virtual TradePlanContext GetTradePlanContext() const = 0;
};

#endif // GOLDENGINEV2_ITRADE_PLANNER_ENGINE_MQH
