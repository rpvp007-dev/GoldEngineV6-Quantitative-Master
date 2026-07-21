//+------------------------------------------------------------------+
//|                                    IPullbackReversalEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IPULLBACK_REVERSAL_ENGINE_MQH
#define GOLDENGINEV2_IPULLBACK_REVERSAL_ENGINE_MQH

#include "PullbackReversalDefines.mqh"
#include "../Strategy/IStrategy.mqh"

//--- Abstract Interface for Pullback vs Reversal Intelligence Engine
class IPullbackReversalEngine
{
public:
   virtual ~IPullbackReversalEngine() {}

   /**
    * @brief Initializes indicators/settings and holds references to config and other engines.
    */
   virtual bool Initialize(const QuantEnginesContainer &engines,
                           bool     enable,
                           double   minContinuationProb,
                           double   minReversalProb,
                           double   breakoutThreshold,
                           double   fakeBreakoutThreshold,
                           int      emaPeriod,
                           int      atrPeriod,
                           double   weightVolume,
                           double   weightMovement,
                           double   weightIntent,
                           double   weightTradeHealth,
                           bool     enableNarratives) = 0;

   /**
    * @brief Runs on every tick to evaluate the pullback vs reversal state of active positions.
    */
   virtual void Update(const string symbol) = 0;

   /**
    * @brief Retrieves the pullback vs reversal context evaluation for the first open trade.
    */
   virtual PullbackReversalContext GetEvaluationContext() const = 0;
};

#endif // GOLDENGINEV2_IPULLBACK_REVERSAL_ENGINE_MQH
