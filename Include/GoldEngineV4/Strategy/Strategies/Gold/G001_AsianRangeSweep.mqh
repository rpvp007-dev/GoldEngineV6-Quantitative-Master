//+------------------------------------------------------------------+
//|                                       G001_AsianRangeSweep.mqh   |
//|                                  Copyright 2026, GoldEngine V5   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV5_G001_ASIAN_RANGE_SWEEP_MQH
#define GOLDENGINEV5_G001_ASIAN_RANGE_SWEEP_MQH

#include "../../IStrategy.mqh"
#include "../../../Core/Logger.mqh"
#include "../../../Core/Config.mqh"

//+------------------------------------------------------------------+
//| Strategy G-1: Asian Range Liquidity Sweep & London Expansion     |
//| Designed specifically for XAUUSD Gold institutional sessions.   |
//+------------------------------------------------------------------+
class CG001_AsianRangeSweep : public IStrategy
{
private:
   bool              m_enabled;
   CConfig*          m_config;
   CLogger*          m_logger;
   string            m_name;
   
   datetime          m_lastTradeBarTime;
   double            m_asianHigh;
   double            m_asianLow;
   datetime          m_asianDate;

   void CalculateAsianRange(const string symbol)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      // Reset daily range at Asian Session start (00:00)
      datetime todayDate = StructToTime(dt) - (dt.hour * 3600 + dt.min * 60 + dt.sec);
      if(todayDate != m_asianDate)
      {
         m_asianDate = todayDate;
         m_asianHigh = 0.0;
         m_asianLow = 999999.0;
         
         // Fetch Asian session bars (00:00 to 06:00)
         datetime asianStart = m_asianDate;
         datetime asianEnd = m_asianDate + (6 * 3600);
         
         MqlRates rates[];
         int copied = CopyRates(symbol, _Period, asianStart, asianEnd, rates);
         if(copied > 0)
         {
            for(int i = 0; i < copied; i++)
            {
               if(rates[i].high > m_asianHigh) m_asianHigh = rates[i].high;
               if(rates[i].low < m_asianLow)   m_asianLow = rates[i].low;
            }
         }
      }
   }

public:
   CG001_AsianRangeSweep(CLogger* logger, CConfig* config)
      : m_enabled(true),
        m_config(config),
        m_logger(logger),
        m_name("G-001"),
        m_lastTradeBarTime(0),
        m_asianHigh(0.0),
        m_asianLow(0.0),
        m_asianDate(0)
   {}

   virtual ~CG001_AsianRangeSweep() {}

   virtual bool Initialize(const QuantEnginesContainer &engines) override
   {
      m_logger.Info("G-001: Asian Range Sweep & London Expansion Strategy initialized.");
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
               response.Reason = "G-001 already has active open position";
               return response;
            }
         }
      }

      // Calculate Asian Session High & Low
      CalculateAsianRange(symbol);
      if(m_asianHigh <= 0.0 || m_asianLow >= 999998.0)
      {
         response.Reason = "Asian Range not yet established";
         return response;
      }

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      // 24/7 Execution Active - No hour restriction

      // One trade per bar guard
      MqlRates rates[];
      if(CopyRates(symbol, _Period, 0, 2, rates) < 2) return response;
      ArraySetAsSeries(rates, true);
      if(rates[0].time == m_lastTradeBarTime) return response;

      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      double asianRangePips = (m_asianHigh - m_asianLow) / (point * 10.0);

      // 1. Asian High Liquidity Sweep Reversal (SELL)
      if(ask >= (m_asianHigh + 100.0 * point))
      {
         // Wick Reversal Confirmation on last candle
         MqlRates m5_rates[];
         if(CopyRates(symbol, _Period, 0, 2, m5_rates) >= 2)
         {
            ArraySetAsSeries(m5_rates, true);
            double topWick = m5_rates[1].high - MathMax(m5_rates[1].open, m5_rates[1].close);
            double body = MathAbs(m5_rates[1].close - m5_rates[1].open);
            
            if(topWick >= body * 1.2 || m5_rates[1].close < m5_rates[1].open)
            {
               response.Signal = GEV2_SIGNAL_SELL;
               response.EntryPrice = bid;
               response.StopLoss = m_asianHigh + 250.0 * point; // 25 pips above Asian High
               response.TakeProfit = m_asianLow; // Target Asian Low
               response.Confidence = 0.85;
               response.StrategyScore = 85.0;
               response.TradeGrade = "A";
               response.Reason = StringFormat("Asian High Sweep Reversal: Swept %.1f, M5 Rejection Wick detected", m_asianHigh);
               m_lastTradeBarTime = rates[0].time;
               return response;
            }
         }
      }

      // 2. Asian Low Liquidity Sweep Reversal (BUY)
      if(bid <= (m_asianLow - 100.0 * point))
      {
         MqlRates m5_rates[];
         if(CopyRates(symbol, _Period, 0, 2, m5_rates) >= 2)
         {
            ArraySetAsSeries(m5_rates, true);
            double bottomWick = MathMin(m5_rates[1].open, m5_rates[1].close) - m5_rates[1].low;
            double body = MathAbs(m5_rates[1].close - m5_rates[1].open);

            if(bottomWick >= body * 1.2 || m5_rates[1].close > m5_rates[1].open)
            {
               response.Signal = GEV2_SIGNAL_BUY;
               response.EntryPrice = ask;
               response.StopLoss = m_asianLow - 250.0 * point; // 25 pips below Asian Low
               response.TakeProfit = m_asianHigh; // Target Asian High
               response.Confidence = 0.85;
               response.StrategyScore = 85.0;
               response.TradeGrade = "A";
               response.Reason = StringFormat("Asian Low Sweep Reversal: Swept %.1f, M5 Rejection Wick detected", m_asianLow);
               m_lastTradeBarTime = rates[0].time;
               return response;
            }
         }
      }

      // 3. London Momentum Expansion (Bullish Breakout)
      if(rates[1].close > (m_asianHigh + 150.0 * point) && rates[1].open < m_asianHigh)
      {
         response.Signal = GEV2_SIGNAL_BUY;
         response.EntryPrice = ask;
         response.StopLoss = m_asianHigh - 150.0 * point;
         response.TakeProfit = ask + 300.0 * point; // +30 pips expansion target
         response.Confidence = 0.90;
         response.StrategyScore = 90.0;
         response.TradeGrade = "A+";
         response.Reason = "London Momentum Expansion: Closed strongly above Asian High";
         m_lastTradeBarTime = rates[0].time;
         return response;
      }

      // 4. London Momentum Expansion (Bearish Breakout)
      if(rates[1].close < (m_asianLow - 150.0 * point) && rates[1].open > m_asianLow)
      {
         response.Signal = GEV2_SIGNAL_SELL;
         response.EntryPrice = bid;
         response.StopLoss = m_asianLow + 150.0 * point;
         response.TakeProfit = bid - 300.0 * point; // +30 pips expansion target
         response.Confidence = 0.90;
         response.StrategyScore = 90.0;
         response.TradeGrade = "A+";
         response.Reason = "London Momentum Expansion: Closed strongly below Asian Low";
         m_lastTradeBarTime = rates[0].time;
         return response;
      }

      return response;
   }
};

#endif // GOLDENGINEV5_G001_ASIAN_RANGE_SWEEP_MQH
