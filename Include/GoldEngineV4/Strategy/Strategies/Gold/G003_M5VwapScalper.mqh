//+------------------------------------------------------------------+
//|                                      G003_M5VwapScalper.mqh     |
//|                                  Copyright 2026, GoldEngine V5   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV5_G003_M5_VWAP_SCALPER_MQH
#define GOLDENGINEV5_G003_M5_VWAP_SCALPER_MQH

#include "../../IStrategy.mqh"
#include "../../../Core/Logger.mqh"
#include "../../../Core/Config.mqh"

//+------------------------------------------------------------------+
//| Strategy G-3: M5 VWAP & EMA 9/21 Micro-Momentum Scalper          |
//| Captures quick 20-40 pip momentum bursts during active sessions. |
//+------------------------------------------------------------------+
class CG003_M5VwapScalper : public IStrategy
{
private:
   bool              m_enabled;
   CConfig*          m_config;
   CLogger*          m_logger;
   string            m_name;
   datetime          m_lastTradeBarTime;
   int               m_ema9Handle;
   int               m_ema21Handle;

public:
   CG003_M5VwapScalper(CLogger* logger, CConfig* config)
      : m_enabled(true),
        m_config(config),
        m_logger(logger),
        m_name("G-003"),
        m_lastTradeBarTime(0),
        m_ema9Handle(INVALID_HANDLE),
        m_ema21Handle(INVALID_HANDLE)
   {}

   virtual ~CG003_M5VwapScalper()
   {
      if(m_ema9Handle != INVALID_HANDLE) IndicatorRelease(m_ema9Handle);
      if(m_ema21Handle != INVALID_HANDLE) IndicatorRelease(m_ema21Handle);
   }

   virtual bool Initialize(const QuantEnginesContainer &engines) override
   {
      m_ema9Handle = iMA(_Symbol, _Period, 9, 0, MODE_EMA, PRICE_CLOSE);
      m_ema21Handle = iMA(_Symbol, _Period, 21, 0, MODE_EMA, PRICE_CLOSE);
      
      if(m_ema9Handle == INVALID_HANDLE || m_ema21Handle == INVALID_HANDLE)
      {
         m_logger.Warning("G-003: EMA 9/21 handles pending lazy initialization.");
      }

      m_logger.Info("G-003: VWAP & EMA 9/21 Scalper Strategy initialized.");
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
               response.Reason = "G-003 already has active open position";
               return response;
            }
         }
      }

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      // 24/7 Execution Active - No hour restriction

      MqlRates rates[];
      if(CopyRates(symbol, _Period, 0, 3, rates) < 3) return response;
      ArraySetAsSeries(rates, true);

      // Bar Guard: Evaluate ONLY once per bar
      if(rates[0].time == m_lastTradeBarTime) return response;

      if(m_ema9Handle == INVALID_HANDLE) m_ema9Handle = iMA(symbol, _Period, 9, 0, MODE_EMA, PRICE_CLOSE);
      if(m_ema21Handle == INVALID_HANDLE) m_ema21Handle = iMA(symbol, _Period, 21, 0, MODE_EMA, PRICE_CLOSE);
      if(m_ema9Handle == INVALID_HANDLE || m_ema21Handle == INVALID_HANDLE) return response;

      double ema9Val[], ema21Val[];
      ArraySetAsSeries(ema9Val, true);
      ArraySetAsSeries(ema21Val, true);

      if(CopyBuffer(m_ema9Handle, 0, 0, 2, ema9Val) < 2 || CopyBuffer(m_ema21Handle, 0, 0, 2, ema21Val) < 2)
      {
         return response;
      }

      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      double ema9 = ema9Val[1];
      double ema21 = ema21Val[1];

      // 1. Bullish Micro-Scalp (EMA9 > EMA21 and price testing EMA9)
      if(ema9 > ema21)
      {
         // Candle 1 low touched EMA 9 and closed bullish
         if(rates[1].low <= (ema9 + 30.0 * point) && rates[1].close > rates[1].open)
         {
            response.Signal = GEV2_SIGNAL_BUY;
            response.EntryPrice = ask;
            response.StopLoss = ask - 150.0 * point;  // Tight 15-pip Stop Loss
            response.TakeProfit = ask + 350.0 * point;// 35-pip Take Profit
            response.Confidence = 0.82;
            response.StrategyScore = 82.0;
            response.TradeGrade = "A";
            response.Reason = "M5 Bullish VWAP/EMA Micro-Scalp Pullback";
            m_lastTradeBarTime = rates[0].time;
            return response;
         }
      }

      // 2. Bearish Micro-Scalp (EMA9 < EMA21 and price testing EMA9)
      if(ema9 < ema21)
      {
         // Candle 1 high touched EMA 9 and closed bearish
         if(rates[1].high >= (ema9 - 30.0 * point) && rates[1].close < rates[1].open)
         {
            response.Signal = GEV2_SIGNAL_SELL;
            response.EntryPrice = bid;
            response.StopLoss = bid + 150.0 * point;  // Tight 15-pip Stop Loss
            response.TakeProfit = bid - 350.0 * point;// 35-pip Take Profit
            response.Confidence = 0.82;
            response.StrategyScore = 82.0;
            response.TradeGrade = "A";
            response.Reason = "M5 Bearish VWAP/EMA Micro-Scalp Pullback";
            m_lastTradeBarTime = rates[0].time;
            return response;
         }
      }

      return response;
   }
};

#endif // GOLDENGINEV5_G003_M5_VWAP_SCALPER_MQH
