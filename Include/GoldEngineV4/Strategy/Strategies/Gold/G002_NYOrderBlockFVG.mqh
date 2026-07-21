//+------------------------------------------------------------------+
//|                                     G002_NYOrderBlockFVG.mqh    |
//|                                  Copyright 2026, GoldEngine V5   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV5_G002_NY_ORDER_BLOCK_FVG_MQH
#define GOLDENGINEV5_G002_NY_ORDER_BLOCK_FVG_MQH

#include "../../IStrategy.mqh"
#include "../../../Core/Logger.mqh"
#include "../../../Core/Config.mqh"

//+------------------------------------------------------------------+
//| Strategy G-2: New York Session Order Block & FVG Retracement      |
//| Capitalizes on NY Session liquidity retests of London FVG/OB.   |
//+------------------------------------------------------------------+
class CG002_NYOrderBlockFVG : public IStrategy
{
private:
   bool              m_enabled;
   CConfig*          m_config;
   CLogger*          m_logger;
   string            m_name;
   datetime          m_lastTradeBarTime;

public:
   CG002_NYOrderBlockFVG(CLogger* logger, CConfig* config)
      : m_enabled(true),
        m_config(config),
        m_logger(logger),
        m_name("G-002"),
        m_lastTradeBarTime(0)
   {}

   virtual ~CG002_NYOrderBlockFVG() {}

   virtual bool Initialize(const QuantEnginesContainer &engines) override
   {
      m_logger.Info("G-002: NY Order Block & Fair Value Gap Strategy initialized.");
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
               response.Reason = "G-002 already has active open position";
               return response;
            }
         }
      }

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      // 24/7 Execution Active - No hour restriction

      MqlRates rates[];
      if(CopyRates(symbol, _Period, 0, 5, rates) < 5) return response;
      ArraySetAsSeries(rates, true);

      if(rates[0].time == m_lastTradeBarTime) return response;

      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      // 1. Detect Bullish Fair Value Gap (FVG) in the last 4 candles
      // FVG occurs when rates[3].high < rates[1].low
      if(rates[3].high < rates[1].low)
      {
         double fvgLow = rates[3].high;
         double fvgHigh = rates[1].low;
         double fvgSize = (fvgHigh - fvgLow) / (point * 10.0);

         // If current live price retraces into the Bullish FVG zone
         if(ask >= fvgLow && ask <= fvgHigh + 50.0 * point)
         {
            double sl = fvgLow - 200.0 * point; // SL 20 pips below FVG low
            double slDist = ask - sl;
            double tp = ask + (slDist * 2.5);   // 1:2.5 Risk to Reward

            response.Signal = GEV2_SIGNAL_BUY;
            response.EntryPrice = ask;
            response.StopLoss = sl;
            response.TakeProfit = tp;
            response.Confidence = 0.88;
            response.StrategyScore = 88.0;
            response.TradeGrade = "A+";
            response.Reason = StringFormat("NY Bullish FVG Retracement: FVG size %.1f pips", fvgSize);
            m_lastTradeBarTime = rates[0].time;
            return response;
         }
      }

      // 2. Detect Bearish Fair Value Gap (FVG) in the last 4 candles
      // Bearish FVG occurs when rates[3].low > rates[1].high
      if(rates[3].low > rates[1].high)
      {
         double fvgHigh = rates[3].low;
         double fvgLow = rates[1].high;
         double fvgSize = (fvgHigh - fvgLow) / (point * 10.0);

         // If current live price retraces up into the Bearish FVG zone
         if(bid <= fvgHigh && bid >= fvgLow - 50.0 * point)
         {
            double sl = fvgHigh + 200.0 * point; // SL 20 pips above FVG high
            double slDist = sl - bid;
            double tp = bid - (slDist * 2.5);   // 1:2.5 Risk to Reward

            response.Signal = GEV2_SIGNAL_SELL;
            response.EntryPrice = bid;
            response.StopLoss = sl;
            response.TakeProfit = tp;
            response.Confidence = 0.88;
            response.StrategyScore = 88.0;
            response.TradeGrade = "A+";
            response.Reason = StringFormat("NY Bearish FVG Retracement: FVG size %.1f pips", fvgSize);
            m_lastTradeBarTime = rates[0].time;
            return response;
         }
      }

      return response;
   }
};

#endif // GOLDENGINEV5_G002_NY_ORDER_BLOCK_FVG_MQH
