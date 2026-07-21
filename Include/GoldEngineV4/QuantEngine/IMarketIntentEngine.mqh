//+------------------------------------------------------------------+
//|                                          IMarketIntentEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IMARKET_INTENT_ENGINE_MQH
#define GOLDENGINEV2_IMARKET_INTENT_ENGINE_MQH

#include "MarketIntentDefines.mqh"

// Forward declaration to resolve circular dependency
struct QuantEnginesContainer;

//+------------------------------------------------------------------+
//| Interface for Market Intent Engine                               |
//+------------------------------------------------------------------+
class IMarketIntentEngine
{
public:
   virtual ~IMarketIntentEngine() {}

   /**
    * @brief Initializes engine with container references to other engines.
    */
   virtual bool      Initialize(const QuantEnginesContainer &engines) = 0;

   /**
    * @brief Updates market intent calculations for the closed candle.
    */
   virtual void      UpdateIntent(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Retrieves the calculated market intent context data.
    */
   virtual MarketIntentContext GetMarketIntentContext() const = 0;
};

#endif // GOLDENGINEV2_IMARKET_INTENT_ENGINE_MQH
