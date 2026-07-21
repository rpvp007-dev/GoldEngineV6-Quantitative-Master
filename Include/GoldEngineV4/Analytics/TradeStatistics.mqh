//+------------------------------------------------------------------+
//|                                             TradeStatistics.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_TRADE_STATISTICS_MQH
#define GOLDENGINEV2_TRADE_STATISTICS_MQH

#include "ITradeStatistics.mqh"
#include "../Core/Logger.mqh"

//+------------------------------------------------------------------+
//| Trade Statistics Component Concrete Implementation (Skeleton)     |
//+------------------------------------------------------------------+
class CTradeStatistics : public ITradeStatistics
{
private:
   CLogger*          m_logger;
   int               m_totalTrades;
   int               m_wins;
   int               m_losses;
   double            m_profit;

public:
   CTradeStatistics(CLogger* logger)
      : m_logger(logger),
        m_totalTrades(0),
        m_wins(0),
        m_losses(0),
        m_profit(0.0)
   {}
   ~CTradeStatistics() {}

   virtual void RecordTrade(ulong ticket, const StrategyResponse &signal) override
   {
      // CRITICAL ISSUE 6 Validation: Verify signal is BUY or SELL, do not record NO_TRADE
      if(signal.Signal != GEV2_SIGNAL_BUY && signal.Signal != GEV2_SIGNAL_SELL)
      {
         m_logger.Warning("TradeStatistics: Ignored trade record with invalid signal type " + (string)signal.Signal);
         return;
      }
      m_totalTrades++;
      m_logger.Info(StringFormat("TradeStatistics: Recorded trade #%d from strategy '%s'", ticket, signal.StrategyName));
   }
   
   virtual int       GetTotalTrades() const override { return m_totalTrades; }
   virtual int       GetWinTrades() const override { return m_wins; }
   virtual int       GetLossTrades() const override { return m_losses; }
   virtual double    GetTotalProfit() const override { return m_profit; }
   virtual void      Reset() override
   {
      m_totalTrades = 0;
      m_wins = 0;
      m_losses = 0;
      m_profit = 0.0;
   }
};

#endif // GOLDENGINEV2_TRADE_STATISTICS_MQH
