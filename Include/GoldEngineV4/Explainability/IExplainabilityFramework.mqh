//+------------------------------------------------------------------+
//|                                   IExplainabilityFramework.mqh   |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IEXPLAINABILITY_FRAMEWORK_MQH
#define GOLDENGINEV2_IEXPLAINABILITY_FRAMEWORK_MQH

#include "../Core/Config.mqh"
#include "../Strategy/IStrategy.mqh"
#include "../QuantEngine/MarketQuality.mqh"
#include "../Risk/RiskGuardian.mqh"

//+------------------------------------------------------------------+
//| Interface for Strategy Validation & Explainability Framework      |
//+------------------------------------------------------------------+
class IExplainabilityFramework
{
public:
   virtual ~IExplainabilityFramework() {}

   /**
    * @brief Initializes the framework with configs and engine pointers.
    */
   virtual bool Initialize(
      CConfig*                config,
      const QuantEnginesContainer &engines,
      CMarketQuality*         mq) = 0;

   /**
    * @brief Logs evaluations and reasons to CSV and counters.
    */
   virtual void LogDecision(
      const StrategyResponse  &response,
      const RiskAuditResponse &riskResponse,
      bool                    riskPassed) = 0;

   /**
    * @brief Generates backtest summary (Research Dashboard) to the journal.
    */
   virtual void GenerateDashboardSummary() = 0;
};

#endif // GOLDENGINEV2_IEXPLAINABILITY_FRAMEWORK_MQH
