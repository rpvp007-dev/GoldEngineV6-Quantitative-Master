//+------------------------------------------------------------------+
//|                                           ITradeHealthEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_ITRADE_HEALTH_ENGINE_MQH
#define GOLDENGINEV2_ITRADE_HEALTH_ENGINE_MQH

#include "TradeHealthDefines.mqh"
#include "../Strategy/IStrategy.mqh"

//--- Abstract Interface for Trade Health Evaluation Engine
class ITradeHealthEngine
{
public:
   virtual ~ITradeHealthEngine() {}

   /**
    * @brief Initializes references to other engines in the container.
    */
   virtual bool Initialize(const QuantEnginesContainer &engines) = 0;

   /**
    * @brief Dynamically calculates the trade health context metrics for a given position.
    * @param ticket Position ticket number
    * @param currentProfitPoints Current PnL in points
    * @param mfe Maximum Favorable Excursion in points
    * @param mae Maximum Adverse Excursion in points
    * @param durationSec Position duration in seconds
    * @return TradeHealthContext struct containing score, state, and narrative
    */
   virtual TradeHealthContext EvaluateTradeHealth(
      ulong ticket, 
      double currentProfitPoints, 
      double mfe, 
      double mae, 
      int durationSec
   ) = 0;
};

#endif // GOLDENGINEV2_ITRADE_HEALTH_ENGINE_MQH
