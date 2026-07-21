//+------------------------------------------------------------------+
//|                                            IDecisionEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IDECISION_ENGINE_MQH
#define GOLDENGINEV2_IDECISION_ENGINE_MQH

#include "DecisionEngineDefines.mqh"
#include "../MarketContext/IMarketContextEngine.mqh"

//+------------------------------------------------------------------+
//| Institutional Decision Engine Interface                          |
//+------------------------------------------------------------------+
class IDecisionEngine
{
public:
   virtual ~IDecisionEngine() {}

   /**
    * @brief Initializes engine with reference to Market Context Engine.
    */
   virtual bool Initialize(IMarketContextEngine* contextEngine) = 0;

   /**
    * @brief Processes current context to calculate probability metrics and decisions.
    */
   virtual void EvaluateDecision(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Retrieves calculated decision context data.
    */
   virtual DecisionContext GetDecisionContext() const = 0;
};

#endif // GOLDENGINEV2_IDECISION_ENGINE_MQH
