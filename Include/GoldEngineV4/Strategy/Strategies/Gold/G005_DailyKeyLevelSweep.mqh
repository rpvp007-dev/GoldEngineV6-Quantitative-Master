//+------------------------------------------------------------------+
//|                                   G005_DailyKeyLevelSweep.mqh    |
//|                                  Copyright 2026, GoldEngine V5   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV5_G005_DAILY_KEY_LEVEL_SWEEP_MQH
#define GOLDENGINEV5_G005_DAILY_KEY_LEVEL_SWEEP_MQH

#include "../../IStrategy.mqh"
#include "../../../Core/Logger.mqh"
#include "../../../Core/Config.mqh"

//+------------------------------------------------------------------+
//| Strategy G-5: Daily Key Level (PDH/PDL) Sweep & Reversal         |
//| Reversal trades at Previous Day High and Previous Day Low.       |
//+------------------------------------------------------------------+
class CG005_DailyKeyLevelSweep : public IStrategy
{
private:
   bool              m_enabled;
   CConfig*          m_config;
   CLogger*          m_logger;
   string            m_name;
   datetime          m_lastTradeBarTime;
   
   double            m_pdh;
   double            m_pdl;
   datetime          m_lastDailyCheckDate;

   void FetchDailyKeyLevels(const string symbol)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      datetime todayDate = StructToTime(dt) - (dt.hour * 3600 + dt.min * 60 + dt.sec);
      
      if(todayDate != m_lastDailyCheckDate)
      {
         m_lastDailyCheckDate = todayDate;
         MqlRates dailyRates[];
         if(CopyRates(symbol, PERIOD_D1, 1, 1, dailyRates) > 0)
         {
            m_pdh = dailyRates[0].high;
            m_pdl = dailyRates[0].low;
         }
      }
   }

public:
   CG005_DailyKeyLevelSweep(CLogger* logger, CConfig* config)
      : m_enabled(true),
        m_config(config),
        m_logger(logger),
        m_name("G-005"),
        m_lastTradeBarTime(0),
        m_pdh(0.0),
        m_pdl(0.0),
        m_lastDailyCheckDate(0)
   {}

   virtual ~CG005_DailyKeyLevelSweep() {}

   virtual bool Initialize(const QuantEnginesContainer &engines) override
   {
      m_logger.Info("G-005: Daily Key Level (PDH/PDL) Sweep Strategy initialized.");
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
               response.Reason = "G-005 already has active open position";
               return response;
            }
         }
      }

      FetchDailyKeyLevels(symbol);
      if(m_pdh <= 0.0 || m_pdl <= 0.0)
      {
         response.Reason = "Daily Key Levels (PDH/PDL) not available";
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

      double dailyMid = (m_pdh + m_pdl) / 2.0;

      // 1. PDH Sweep Reversal (SELL)
      if(ask >= (m_pdh + 150.0 * point))
      {
         double topWick = rates[1].high - MathMax(rates[1].open, rates[1].close);
         double body = MathAbs(rates[1].close - rates[1].open);

         if(topWick >= body * 1.0 || rates[1].close < rates[1].open)
         {
            response.Signal = GEV2_SIGNAL_SELL;
            response.EntryPrice = bid;
            response.StopLoss = m_pdh + 400.0 * point; // 40 pips above PDH
            response.TakeProfit = dailyMid; // Target Daily Midpoint
            response.Confidence = 0.89;
            response.StrategyScore = 89.0;
            response.TradeGrade = "A+";
            response.Reason = StringFormat("PDH Liquidity Sweep Reversal: PDH=%.2f, Top Wick=%.1f pips", m_pdh, topWick / (point * 10.0));
            m_lastTradeBarTime = rates[0].time;
            return response;
         }
      }

      // 2. PDL Sweep Reversal (BUY)
      if(bid <= (m_pdl - 150.0 * point))
      {
         double bottomWick = MathMin(rates[1].open, rates[1].close) - rates[1].low;
         double body = MathAbs(rates[1].close - rates[1].open);

         if(bottomWick >= body * 1.0 || rates[1].close > rates[1].open)
         {
            response.Signal = GEV2_SIGNAL_BUY;
            response.EntryPrice = ask;
            response.StopLoss = m_pdl - 400.0 * point; // 40 pips below PDL
            response.TakeProfit = dailyMid; // Target Daily Midpoint
            response.Confidence = 0.89;
            response.StrategyScore = 89.0;
            response.TradeGrade = "A+";
            response.Reason = StringFormat("PDL Liquidity Sweep Reversal: PDL=%.2f, Bottom Wick=%.1f pips", m_pdl, bottomWick / (point * 10.0));
            m_lastTradeBarTime = rates[0].time;
            return response;
         }
      }

      return response;
   }
};

#endif // GOLDENGINEV5_G005_DAILY_KEY_LEVEL_SWEEP_MQH
