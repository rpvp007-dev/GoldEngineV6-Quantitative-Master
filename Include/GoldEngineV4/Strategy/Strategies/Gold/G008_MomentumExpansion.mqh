//+------------------------------------------------------------------+
//|                                  G008_MomentumExpansion.mqh       |
//|                                  Copyright 2026, GoldEngine V5   |
//|                                       https://github.com/goldv5  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV4_G008_MOMENTUM_EXPANSION_MQH
#define GOLDENGINEV4_G008_MOMENTUM_EXPANSION_MQH

#include "../../IStrategy.mqh"
#include "../../../Core/Logger.mqh"
#include "../../../Core/Config.mqh"

//+------------------------------------------------------------------+
//| G-008: Institutional Momentum & Volatility Expansion Strategy   |
//| Catches 100-300 pip expansion trends & drops instantly!        |
//+------------------------------------------------------------------+
class CG008_MomentumExpansion : public IStrategy
{
private:
   bool           m_enabled;
   datetime       m_lastTradeBarTime;

public:
   CG008_MomentumExpansion()
      : m_enabled(true),
        m_lastTradeBarTime(0)
   {}

   virtual ~CG008_MomentumExpansion() {}

   virtual bool Initialize(const QuantEnginesContainer &engines) override { return true; }
   virtual string GetName() const override { return "G-008"; }
   virtual bool IsEnabled() const override { return m_enabled; }
   virtual void SetEnabled(bool enabled) override { m_enabled = enabled; }

   virtual StrategyResponse Evaluate(const string symbol) override
   {
      StrategyResponse response;
      response.Signal = GEV2_SIGNAL_NONE;
      response.Confidence = 0.0;
      response.StrategyName = GetName();
      response.EntryPrice = 0.0;
      response.StopLoss = 0.0;
      response.TakeProfit = 0.0;
      response.Reason = "No Expansion Pattern";

      if(!m_enabled) return response;

      // 1. Position Guard per strategy
      int totalPos = PositionsTotal();
      for(int i = 0; i < totalPos; i++)
      {
         if(PositionGetSymbol(i) == symbol)
         {
            if(PositionGetString(POSITION_COMMENT) == GetName())
            {
               response.Reason = "Position Active for G-008";
               return response;
            }
         }
      }

      // 2. Bar Time Guard (1 trade per candle max)
      MqlRates rates[];
      if(CopyRates(symbol, _Period, 0, 5, rates) < 5) return response;
      ArraySetAsSeries(rates, true);

      if(rates[0].time == m_lastTradeBarTime)
      {
         response.Reason = "Bar Time Guard Active";
         return response;
      }

      // 3. Check ATR Volatility (Must have active volatility expansion)
      int atrHandle = iATR(symbol, _Period, 14);
      if(atrHandle == INVALID_HANDLE) return response;

      double atrValues[];
      ArraySetAsSeries(atrValues, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atrValues) <= 0)
      {
         IndicatorRelease(atrHandle);
         return response;
      }
      double currentATR = atrValues[0];
      IndicatorRelease(atrHandle);

      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0.0) point = 0.01;

      // Require minimum ATR of 8.0 points (0.8 pips) - Blocks low-volatility chop!
      if(currentATR < 8.0 * point)
      {
         response.Reason = "Low ATR Volatility Chop";
         return response;
      }

      // 4. Candle Body Expansion Detection
      double prevBody = MathAbs(rates[1].close - rates[1].open);
      double prevRange = rates[1].high - rates[1].low;

      // Large expansion candle (> 150 points / 15 pips body)
      if(prevBody >= 150.0 * point && prevBody >= prevRange * 0.65)
      {
         double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

         // BEARISH EXPANSION DROP (Red candle closing near bottom)
         if(rates[1].close < rates[1].open)
         {
            response.Signal = GEV2_SIGNAL_SELL;
            response.Confidence = 0.90;
            response.EntryPrice = bid;
            response.StopLoss = rates[1].high + 50.0 * point; // SL above expansion candle high
            response.TakeProfit = bid - 500.0 * point;         // TP +50 pips (+500 points)
            response.Reason = StringFormat("G-008 Bearish Expansion Drop (Body: %.1f pips)", prevBody / (point * 10.0));
            m_lastTradeBarTime = rates[0].time;
            return response;
         }
         // BULLISH EXPANSION SURGE (Green candle closing near top)
         else if(rates[1].close > rates[1].open)
         {
            response.Signal = GEV2_SIGNAL_BUY;
            response.Confidence = 0.90;
            response.EntryPrice = ask;
            response.StopLoss = rates[1].low - 50.0 * point;  // SL below expansion candle low
            response.TakeProfit = ask + 500.0 * point;        // TP +50 pips (+500 points)
            response.Reason = StringFormat("G-008 Bullish Expansion Surge (Body: %.1f pips)", prevBody / (point * 10.0));
            m_lastTradeBarTime = rates[0].time;
            return response;
         }
      }

      return response;
   }
};

#endif // GOLDENGINEV4_G008_MOMENTUM_EXPANSION_MQH
