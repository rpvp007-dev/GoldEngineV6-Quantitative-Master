//+------------------------------------------------------------------+
//|                                           IOpportunityEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IOPPORTUNITY_ENGINE_MQH
#define GOLDENGINEV2_IOPPORTUNITY_ENGINE_MQH

#include "OpportunityDefines.mqh"

// Forward declaration to resolve circular dependency
struct QuantEnginesContainer;

//+------------------------------------------------------------------+
//| Interface for Opportunity Engine                                 |
//+------------------------------------------------------------------+
class IOpportunityEngine
{
public:
   virtual ~IOpportunityEngine() {}

   /**
    * @brief Initializes engine with container references to other engines.
    */
   virtual bool      Initialize(const QuantEnginesContainer &engines) = 0;

   /**
    * @brief Updates opportunity calculations for the current closed candle.
    */
   virtual void      UpdateOpportunity(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Retrieves the calculated opportunity context data.
    */
   virtual OpportunityContext GetOpportunityContext() const = 0;
};

#endif // GOLDENGINEV2_IOPPORTUNITY_ENGINE_MQH
