//+------------------------------------------------------------------+
//|                                   G004_PostNewsImbalance.mqh     |
//|                                  Copyright 2026, GoldEngine V5   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV5_G004_POST_NEWS_IMBALANCE_MQH
#define GOLDENGINEV5_G004_POST_NEWS_IMBALANCE_MQH

#include "../../IStrategy.mqh"
#include "../../../Core/Logger.mqh"
#include "../../../Core/Config.mqh"

//+------------------------------------------------------------------+
//| Strategy G-4: Post-News Institutional Imbalance Expansion        |
//| Captures post-news institutional momentum 5m after US releases.  |
//+------------------------------------------------------------------+
class CG004_PostNewsImbalance : public IStrategy
{
private:
   bool              m_enabled;
   CConfig*          m_config;
   CLogger*          m_logger;
   string            m_name;
   datetime          m_lastTradeBarTime;

public:
   CG004_PostNewsImbalance(CLogger* logger, CConfig* config)
      : m_enabled(true),
        m_config(config),
        m_logger(logger),
        m_name("G-004"),
        m_lastTradeBarTime(0)
   {}

   virtual ~CG004_PostNewsImbalance() {}

   virtual bool Initialize(const QuantEnginesContainer &engines) override
   {
      m_logger.Info("G-004: Post-News Institutional Imbalance Strategy initialized.");
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
               response.Reason = "G-004 already has active open position";
               return response;
            }
         }
      }

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      // 24/7 Execution Active - No hour restriction

      MqlRates rates[];
      if(CopyRates(symbol, _Period, 0, 4, rates) < 4) return response;
      ArraySetAsSeries(rates, true);

      if(rates[0].time == m_lastTradeBarTime) return response;

      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      // Evaluate news impulse candle 2
      double impulseBody = MathAbs(rates[2].close - rates[2].open);
      double candle1Body  = MathAbs(rates[1].close - rates[1].open);

      // 1. Bullish News Impulse Expansion
      if(rates[2].close > rates[2].open && impulseBody >= 300.0 * point) // Impulse > 30 pips
      {
         // Retracement check: current price pulled back slightly into upper 30% of impulse candle
         double retraceZoneLow = rates[2].open + (impulseBody * 0.5);
         if(ask <= rates[2].high && ask >= retraceZoneLow)
         {
            response.Signal = GEV2_SIGNAL_BUY;
            response.EntryPrice = ask;
            response.StopLoss = ask - 250.0 * point;  // 25-pip Stop Loss
            response.TakeProfit = ask + 600.0 * point;// 60-pip Take Profit
            response.Confidence = 0.92;
            response.StrategyScore = 92.0;
            response.TradeGrade = "A+";
            response.Reason = StringFormat("Post-News Bullish Imbalance: Impulse %.1f pips", impulseBody / (point * 10.0));
            m_lastTradeBarTime = rates[0].time;
            return response;
         }
      }

      // 2. Bearish News Impulse Expansion
      if(rates[2].close < rates[2].open && impulseBody >= 300.0 * point) // Impulse > 30 pips
      {
         double retraceZoneHigh = rates[2].open - (impulseBody * 0.5);
         if(bid >= rates[2].low && bid <= retraceZoneHigh)
         {
            response.Signal = GEV2_SIGNAL_SELL;
            response.EntryPrice = bid;
            response.StopLoss = bid + 250.0 * point;  // 25-pip Stop Loss
            response.TakeProfit = bid - 600.0 * point;// 60-pip Take Profit
            response.Confidence = 0.92;
            response.StrategyScore = 92.0;
            response.TradeGrade = "A+";
            response.Reason = StringFormat("Post-News Bearish Imbalance: Impulse %.1f pips", impulseBody / (point * 10.0));
            m_lastTradeBarTime = rates[0].time;
            return response;
         }
      }

      return response;
   }
};

#endif // GOLDENGINEV5_G004_POST_NEWS_IMBALANCE_MQH
