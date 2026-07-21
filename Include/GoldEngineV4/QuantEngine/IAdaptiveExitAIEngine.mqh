//+------------------------------------------------------------------+
//|                                         IAdaptiveExitAIEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IADAPTIVE_EXIT_AI_ENGINE_MQH
#define GOLDENGINEV2_IADAPTIVE_EXIT_AI_ENGINE_MQH

#include "AdaptiveExitDefines.mqh"
#include "../Strategy/IStrategy.mqh"

//--- Abstract Interface for Adaptive Exit AI Engine (Chief Trader)
class IAdaptiveExitAIEngine
{
public:
   virtual ~IAdaptiveExitAIEngine() {}

   /**
    * @brief Initializes references, thresholds, and weights for the AI exit model.
    */
   virtual bool Initialize(const QuantEnginesContainer &engines,
                           bool     enable,
                           double   holdThreshold,
                           double   exitThreshold,
                           double   runnerThreshold,
                           double   trailThreshold,
                           double   confidenceThreshold) = 0;

   /**
    * @brief Evaluates active positions and compiles the consolidated recommendations on tick.
    */
   virtual void Update(const string symbol) = 0;

   /**
    * @brief Retrieves the compiled AI evaluation context.
    */
   virtual AdaptiveExitContext GetExitContext() const = 0;
};

#endif // GOLDENGINEV2_IADAPTIVE_EXIT_AI_ENGINE_MQH
