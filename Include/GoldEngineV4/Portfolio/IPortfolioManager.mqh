//+------------------------------------------------------------------+
//|                                           IPortfolioManager.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IPORTFOLIO_MANAGER_MQH
#define GOLDENGINEV2_IPORTFOLIO_MANAGER_MQH

#include "../Strategy/StrategyDefines.mqh"

//+------------------------------------------------------------------+
//| Interface for Portfolio Manager                                 |
//+------------------------------------------------------------------+
class IPortfolioManager
{
public:
   virtual ~IPortfolioManager() {}

   /**
    * @brief Receives candidate strategy responses, ranks them, resolves conflicts, and returns selected candidates.
    * @param inSignals Raw strategy candidate responses collected by Strategy Manager.
    * @param outSelectedSignals Prioritized/filtered signals ready for risk auditing.
    * @return Number of signals approved for execution.
    */
   virtual int       FilterAndRankSignals(const StrategyResponse &inSignals[], StrategyResponse &outSelectedSignals[]) = 0;

   /**
    * @brief Updates internal portfolio allocation sizes and strategy weights.
    */
   virtual void      UpdatePortfolioAllocation() = 0;
};

#endif // GOLDENGINEV2_IPORTFOLIO_MANAGER_MQH
