//+------------------------------------------------------------------+
//|                                         G007_FibonacciOTE.mqh   |
//|                                  Copyright 2026, GoldEngine V5   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV5_G007_FIBONACCI_OTE_MQH
#define GOLDENGINEV5_G007_FIBONACCI_OTE_MQH

#include "../../IStrategy.mqh"
#include "../../../Core/Logger.mqh"
#include "../../../Core/Config.mqh"

//+------------------------------------------------------------------+
//| Strategy G-7: 61.8% / 78.6% Fibonacci Optimal Trade Entry (OTE)   |
//| Enters institutional session pullbacks at Golden Ratio Fib levels|
//+------------------------------------------------------------------+
class CG007_FibonacciOTE : public IStrategy
{
private:
   bool              m_enabled;
   CConfig*          m_config;
   CLogger*          m_logger;
   string            m_name;
   datetime          m_lastTradeBarTime;
   int               m_ema50Handle;
   int               m_ema200Handle;

public:
   CG007_FibonacciOTE(CLogger* logger, CConfig* config)
      : m_enabled(true),
        m_config(config),
        m_logger(logger),
        m_name("G-007"),
        m_lastTradeBarTime(0),
        m_ema50Handle(INVALID_HANDLE),
        m_ema200Handle(INVALID_HANDLE)
   {}

   virtual ~CG007_FibonacciOTE()
   {
      if(m_ema50Handle != INVALID_HANDLE) IndicatorRelease(m_ema50Handle);
      if(m_ema200Handle != INVALID_HANDLE) IndicatorRelease(m_ema200Handle);
   }

   virtual bool Initialize(const QuantEnginesContainer &engines) override
   {
      m_ema50Handle = iMA(_Symbol, _Period, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_ema200Handle = iMA(_Symbol, _Period, 200, 0, MODE_EMA, PRICE_CLOSE);

      m_logger.Info("G-007: 61.8%/78.6% Fibonacci OTE Strategy initialized.");
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
               response.Reason = "G-007 already has active open position";
               return response;
            }
         }
      }

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      // 24/7 Execution Active - No hour restriction

      MqlRates rates[];
      if(CopyRates(symbol, _Period, 0, 50, rates) < 50) return response;
      ArraySetAsSeries(rates, true);

      if(rates[0].time == m_lastTradeBarTime) return response;

      if(m_ema50Handle == INVALID_HANDLE) m_ema50Handle = iMA(symbol, _Period, 50, 0, MODE_EMA, PRICE_CLOSE);
      if(m_ema200Handle == INVALID_HANDLE) m_ema200Handle = iMA(symbol, _Period, 200, 0, MODE_EMA, PRICE_CLOSE);

      double ema50Val[], ema200Val[];
      ArraySetAsSeries(ema50Val, true);
      ArraySetAsSeries(ema200Val, true);

      if(CopyBuffer(m_ema50Handle, 0, 0, 2, ema50Val) < 2 || CopyBuffer(m_ema200Handle, 0, 0, 2, ema200Val) < 2)
         return response;

      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      // Calculate recent 50-bar swing High and Low
      double swingHigh = rates[0].high;
      double swingLow  = rates[0].low;
      for(int i = 1; i < 50; i++)
      {
         if(rates[i].high > swingHigh) swingHigh = rates[i].high;
         if(rates[i].low < swingLow)   swingLow  = rates[i].low;
      }

      double range = swingHigh - swingLow;
      if(range < 300.0 * point) return response; // Minimum 30 pips swing required

      // 1. Bullish Fib 61.8%-78.6% Retracement (BUY)
      if(ema50Val[1] > ema200Val[1]) // Uptrend
      {
         double fib618 = swingHigh - (0.618 * range);
         double fib786 = swingHigh - (0.786 * range);

         // If price pulled back into Fib OTE zone
         if(bid <= fib618 && bid >= (fib786 - 50.0 * point))
         {
            double bottomWick = MathMin(rates[1].open, rates[1].close) - rates[1].low;
            double body = MathAbs(rates[1].close - rates[1].open);

            if(bottomWick >= body * 0.8 || rates[1].close > rates[1].open)
            {
               response.Signal = GEV2_SIGNAL_BUY;
               response.EntryPrice = ask;
               response.StopLoss = ask - 180.0 * point;  // 18-pip SL
               response.TakeProfit = ask + 500.0 * point;// 50-pip TP (1:2.8 R:R)
               response.Confidence = 0.90;
               response.StrategyScore = 90.0;
               response.TradeGrade = "A+";
               response.Reason = StringFormat("61.8%% Fib OTE Retracement Buy: Fib618=%.2f, Fib786=%.2f", fib618, fib786);
               m_lastTradeBarTime = rates[0].time;
               return response;
            }
         }
      }

      // 2. Bearish Fib 61.8%-78.6% Retracement (SELL)
      if(ema50Val[1] < ema200Val[1]) // Downtrend
      {
         double fib618 = swingLow + (0.618 * range);
         double fib786 = swingLow + (0.786 * range);

         // If price pulled back up into Fib OTE zone
         if(ask >= fib618 && ask <= (fib786 + 50.0 * point))
         {
            double topWick = rates[1].high - MathMax(rates[1].open, rates[1].close);
            double body = MathAbs(rates[1].close - rates[1].open);

            if(topWick >= body * 0.8 || rates[1].close < rates[1].open)
            {
               response.Signal = GEV2_SIGNAL_SELL;
               response.EntryPrice = bid;
               response.StopLoss = bid + 180.0 * point;  // 18-pip SL
               response.TakeProfit = bid - 500.0 * point;// 50-pip TP (1:2.8 R:R)
               response.Confidence = 0.90;
               response.StrategyScore = 90.0;
               response.TradeGrade = "A+";
               response.Reason = StringFormat("61.8%% Fib OTE Retracement Sell: Fib618=%.2f, Fib786=%.2f", fib618, fib786);
               m_lastTradeBarTime = rates[0].time;
               return response;
            }
         }
      }

      return response;
   }
};

#endif // GOLDENGINEV5_G007_FIBONACCI_OTE_MQH
