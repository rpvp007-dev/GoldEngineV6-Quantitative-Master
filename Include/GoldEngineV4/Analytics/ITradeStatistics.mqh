//+------------------------------------------------------------------+
//|                                            ITradeStatistics.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_ITRADE_STATISTICS_MQH
#define GOLDENGINEV2_ITRADE_STATISTICS_MQH

#include "../Strategy/StrategyDefines.mqh"

//+------------------------------------------------------------------+
//| Interface for Trade Statistics component                          |
//+------------------------------------------------------------------+
class ITradeStatistics
{
public:
   virtual ~ITradeStatistics() {}

   virtual void      RecordTrade(ulong ticket, const StrategyResponse &signal) = 0;
   virtual int       GetTotalTrades() const = 0;
   virtual int       GetWinTrades() const = 0;
   virtual int       GetLossTrades() const = 0;
   virtual double    GetTotalProfit() const = 0;
   virtual void      Reset() = 0;
};

#endif // GOLDENGINEV2_ITRADE_STATISTICS_MQH
