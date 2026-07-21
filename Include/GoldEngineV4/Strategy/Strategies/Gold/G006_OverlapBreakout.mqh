//+------------------------------------------------------------------+
//|                                     G006_OverlapBreakout.mqh    |
//|                                  Copyright 2026, GoldEngine V5   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV5_G006_OVERLAP_BREAKOUT_MQH
#define GOLDENGINEV5_G006_OVERLAP_BREAKOUT_MQH

#include "../../IStrategy.mqh"
#include "../../../Core/Logger.mqh"
#include "../../../Core/Config.mqh"

//+------------------------------------------------------------------+
//| Strategy G-6: London/NY Overlap 15:00 UTC Power Hour Expansion   |
//| Captures US Stock Market open volatility breakout on Gold.        |
//+------------------------------------------------------------------+
class CG006_OverlapBreakout : public IStrategy
{
private:
   bool              m_enabled;
   CConfig*          m_config;
   CLogger*          m_logger;
   string            m_name;
   datetime          m_lastTradeBarTime;
   
   double            m_rangeHigh;
   double            m_rangeLow;
   datetime          m_rangeDate;

   void CalculateOverlapRange(const string symbol)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      datetime todayDate = StructToTime(dt) - (dt.hour * 3600 + dt.min * 60 + dt.sec);

      if(todayDate != m_rangeDate)
      {
         m_rangeDate = todayDate;
         m_rangeHigh = 0.0;
         m_rangeLow = 999999.0;

         // Pre-open range: 13:00 to 14:45 UTC
         datetime rangeStart = m_rangeDate + (13 * 3600);
         datetime rangeEnd   = m_rangeDate + (14 * 3600 + 45 * 60);

         MqlRates rates[];
         int copied = CopyRates(symbol, _Period, rangeStart, rangeEnd, rates);
         if(copied > 0)
         {
            for(int i = 0; i < copied; i++)
            {
               if(rates[i].high > m_rangeHigh) m_rangeHigh = rates[i].high;
               if(rates[i].low < m_rangeLow)   m_rangeLow  = rates[i].low;
            }
         }
      }
   }

public:
   CG006_OverlapBreakout(CLogger* logger, CConfig* config)
      : m_enabled(true),
        m_config(config),
        m_logger(logger),
        m_name("G-006"),
        m_lastTradeBarTime(0),
        m_rangeHigh(0.0),
        m_rangeLow(0.0),
        m_rangeDate(0)
   {}

   virtual ~CG006_OverlapBreakout() {}

   virtual bool Initialize(const QuantEnginesContainer &engines) override
   {
      m_logger.Info("G-006: London/NY Overlap 15:00 UTC Power Hour Strategy initialized.");
      return true;
   }

   virtual string GetName() const override { return m_name; }
   virtual void SetEnabled(bool enabled) override { m_enabled = enabled; }
   virtual bool IsEnabled() const override { return m_enabled; }

   virtual StrategyResponse Evaluate(const string symbol) override
   {
      StrategyResponse response;
      response.Signal         = GEV2_SIGNAL_NONE;
      response.EntryPrice     = 0.0;
      response.StopLoss       = 0.0;
      response.TakeProfit     = 0.0;
      response.Confidence     = 0.0;
      response.StrategyScore  = 0.0;
      response.TradeGrade     = "D";
      response.Reason         = "No Setup";
      response.StrategyName   = GetName();
      response.RawStrategyScore = 0.0;
      response.CompositeScore   = 0.0;
      response.PenaltyScore     = 0.0;

      if(!m_enabled) return response;

      // Do not open another trade if this strategy already has an active position
      for(int p = PositionsTotal() - 1; p >= 0; p--)
      {
         if(PositionGetSymbol(p) == symbol)
         {
            if(PositionGetString(POSITION_COMMENT) == GetName())
            {
               response.Reason = "G-006 already has active open position";
               return response;
            }
         }
      }

      CalculateOverlapRange(symbol);
      if(m_rangeHigh <= 0.0 || m_rangeLow >= 999998.0)
      {
         response.Reason = "Overlap Range not yet established";
         return response;
      }

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      // 24/7 Execution Active - No hour restriction

      MqlRates rates[];
      if(CopyRates(symbol, _Period, 0, 3, rates) < 3) return response;
      ArraySetAsSeries(rates, true);

      if(rates[0].time == m_lastTradeBarTime) return response;

      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      // 1. Bullish Power Hour Breakout
      if(ask >= (m_rangeHigh + 50.0 * point) && rates[1].close > rates[1].open)
      {
         response.Signal = GEV2_SIGNAL_BUY;
         response.EntryPrice = ask;
         response.StopLoss = ask - 200.0 * point;  // 20-pip Stop Loss
         response.TakeProfit = ask + 400.0 * point;// 40-pip Take Profit
         response.Confidence = 0.91;
         response.StrategyScore = 91.0;
         response.TradeGrade = "A+";
         response.Reason = StringFormat("Overlap 15:00 UTC Bullish Breakout: Range High=%.2f", m_rangeHigh);
         m_lastTradeBarTime = rates[0].time;
         return response;
      }

      // 2. Bearish Power Hour Breakout
      if(bid <= (m_rangeLow - 50.0 * point) && rates[1].close < rates[1].open)
      {
         response.Signal = GEV2_SIGNAL_SELL;
         response.EntryPrice = bid;
         response.StopLoss = bid + 200.0 * point;  // 20-pip Stop Loss
         response.TakeProfit = bid - 400.0 * point;// 40-pip Take Profit
         response.Confidence = 0.91;
         response.StrategyScore = 91.0;
         response.TradeGrade = "A+";
         response.Reason = StringFormat("Overlap 15:00 UTC Bearish Breakout: Range Low=%.2f", m_rangeLow);
         m_lastTradeBarTime = rates[0].time;
         return response;
      }

      return response;
   }
};

#endif // GOLDENGINEV5_G006_OVERLAP_BREAKOUT_MQH
