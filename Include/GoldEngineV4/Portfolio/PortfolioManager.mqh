//+------------------------------------------------------------------+
//|                                             PortfolioManager.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_PORTFOLIO_MANAGER_MQH
#define GOLDENGINEV2_PORTFOLIO_MANAGER_MQH

#include "IPortfolioManager.mqh"
#include "../Core/Logger.mqh"
#include "../Core/Config.mqh"

//+------------------------------------------------------------------+
//| Concrete Portfolio Manager Class implementation (skeleton)       |
//+------------------------------------------------------------------+
class CPortfolioManager : public IPortfolioManager
{
private:
   CLogger*          m_logger;
   CConfig*          m_config;

   //--- Skeletons for future portfolio optimization algorithms
   void              RankStrategies(const StrategyResponse &inSignals[], StrategyResponse &sortedSignals[])
   {
      // Mock copy and simple check
      int total = ArraySize(inSignals);
      ArrayResize(sortedSignals, total);
      for(int i = 0; i < total; i++)
      {
         sortedSignals[i] = inSignals[i];
      }
      // Future implementation: Sort sortedSignals based on historical Win Rate or Confidence score
   }

   void              ResolveConflicts(StrategyResponse &signals[])
   {
      // Future implementation: Loop signals and remove opposing signals (e.g. BUY vs SELL on same symbol)
      // or filter based on priority weights.
   }

public:
   /**
    * @brief Constructor.
    */
   CPortfolioManager(CLogger* logger, CConfig* config)
      : m_logger(logger),
        m_config(config)
   {}

   /**
    * @brief Destructor.
    */
   ~CPortfolioManager() {}

   virtual int FilterAndRankSignals(const StrategyResponse &inSignals[], StrategyResponse &outSelectedSignals[]) override
   {
      int totalInput = ArraySize(inSignals);
      ArrayResize(outSelectedSignals, 0);
      if(totalInput == 0) return 0;
 
      m_logger.Info(StringFormat("Portfolio Manager: Auditing %d candidate signal(s)...", totalInput));
 
      StrategyResponse sortedSignals[];
      RankStrategies(inSignals, sortedSignals);
      ResolveConflicts(sortedSignals);
 
      // Copy finalized signals to output array, rejecting invalid/none signals (CRITICAL ISSUE 2)
      int approvedCount = 0;
      for(int i = 0; i < ArraySize(sortedSignals); i++)
      {
         if(sortedSignals[i].Signal != GEV2_SIGNAL_BUY && sortedSignals[i].Signal != GEV2_SIGNAL_SELL)
         {
            m_logger.Info(StringFormat("Portfolio Manager: Rejected signal from '%s' (Reason: Non-tradable Signal %d)", 
               sortedSignals[i].StrategyName, sortedSignals[i].Signal));
            continue;
         }
 
         approvedCount++;
         ArrayResize(outSelectedSignals, approvedCount);
         outSelectedSignals[approvedCount - 1] = sortedSignals[i];
         m_logger.Info(StringFormat("Portfolio Manager: Signal from '%s' (%s) approved for risk check (Rank Priority: %d)", 
            sortedSignals[i].StrategyName, 
            (sortedSignals[i].Signal == GEV2_SIGNAL_BUY) ? "BUY" : "SELL", 
            approvedCount));
      }
 
      return approvedCount;
   }

   /**
    * @brief Skeletons for adjusting asset allocation weights dynamically.
    */
   virtual void UpdatePortfolioAllocation() override
   {
      // No calculations needed yet
   }
};

#endif // GOLDENGINEV2_PORTFOLIO_MANAGER_MQH
