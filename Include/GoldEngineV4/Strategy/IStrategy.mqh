//+------------------------------------------------------------------+
//|                                                     IStrategy.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_ISTRATEGY_MQH
#define GOLDENGINEV2_ISTRATEGY_MQH

#include "StrategyDefines.mqh"
#include "../QuantEngine/ITrendEngine.mqh"
#include "../QuantEngine/IMomentumEngine.mqh"
#include "../QuantEngine/IVolatilityEngine.mqh"
#include "../QuantEngine/IVolumeEngine.mqh"
#include "../QuantEngine/IVwapEngine.mqh"
#include "../QuantEngine/ILiquidityEngine.mqh"
#include "../QuantEngine/IPatternEngine.mqh"
#include "../QuantEngine/ISessionEngine.mqh"
#include "../QuantEngine/IMarketStructureEngine.mqh"

class IMarketContextEngine;
class IDecisionEngine;
class IOpportunityEngine;
class IMovementEngine;
class IMarketIntentEngine;
class ITradePlannerEngine;
class ITradeManager;
class ITradeHealthEngine;
class ITradeOptimizationEngine;
class IPullbackReversalEngine;
class IAdaptiveExitAIEngine;
class IInstitutionalExecutionManager;

//+------------------------------------------------------------------+
//| Container structure holding references to the 9 Quant Engines    |
//| to avoid passing many parameters into Strategy initialization.   |
//| Extended in GITS V3.0 to include IMarketContextEngine.            |
//+------------------------------------------------------------------+
struct QuantEnginesContainer
{
   ITrendEngine*              Trend;
   IMomentumEngine*           Momentum;
   IVolatilityEngine*         Volatility;
   IVolumeEngine*             Volume;
   IVwapEngine*               Vwap;
   ILiquidityEngine*          Liquidity;
   IPatternEngine*            Pattern;
   ISessionEngine*            Session;
   IMarketStructureEngine*    MarketStructure;
   IMarketContextEngine*      MarketContext; // Added in V3.0
   IDecisionEngine*           Decision;      // Added in V3.1
   IOpportunityEngine*        Opportunity;   // Added in V3.4
   IMovementEngine*           Movement;      // Added in V3.5
   IMarketIntentEngine*       Intent;        // Added in V3.6
   ITradePlannerEngine*       Planner;       // Added in V3.7
   ITradeManager*             TradeManager;  // Added in V4.6
   ITradeHealthEngine*        TradeHealth;   // Added in V4.7
   ITradeOptimizationEngine*  TradeOptimization; // Added in V4.8
   IPullbackReversalEngine*   PullbackReversal; // Added in V4.9
   IAdaptiveExitAIEngine*     AdaptiveExit;    // Added in V4.10
   IInstitutionalExecutionManager* InstitutionalExecution; // Added in V5.0
};

//+------------------------------------------------------------------+
//| Base Strategy Interface                                          |
//| All GITS production strategies MUST inherit from this.           |
//+------------------------------------------------------------------+
class IStrategy
{
public:
   virtual ~IStrategy() {}

   /**
    * @brief Initializes strategy settings and indicator bindings using the Quant Engines container.
    * @param engines Structure containing pointers to the 9 independent quant engines.
    * @return true if initialization completes successfully, false otherwise.
    */
   virtual bool      Initialize(const QuantEnginesContainer &engines) = 0;

   /**
    * @brief Evaluates the strategy logic for entry/exit setup.
    * @param symbol Trading symbol (e.g. "XAUUSD")
    * @return StrategyResponse containing the raw signal and levels.
    */
   virtual StrategyResponse Evaluate(const string symbol) = 0;

   /**
    * @brief Gets the unique strategy name identifier.
    */
   virtual string    GetName() const = 0;

   /**
    * @brief Sets enabled state of this strategy.
    */
   virtual void      SetEnabled(bool enabled) = 0;

   /**
    * @brief Checks if strategy is active.
    */
   virtual bool      IsEnabled() const = 0;

   // --- Control Center Research Getters (V4.4.1)
   virtual int       GetTotalOpportunities() const { return 0; }
   virtual int       GetTotalTradesTaken() const { return 0; }
   virtual int       GetOpportunitiesRejected() const { return 0; }
   virtual double    GetAverageEntryScore() const { return 0.0; }
};

#endif // GOLDENGINEV2_ISTRATEGY_MQH
