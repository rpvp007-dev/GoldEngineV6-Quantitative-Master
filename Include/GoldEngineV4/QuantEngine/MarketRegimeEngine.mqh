//+------------------------------------------------------------------+
//|                                           MarketRegimeEngine.mqh |
//|                                  Copyright 2026, GoldEngine V6   |
//|                    Pillar 1: Market Regime State Classifier      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, GoldEngine V6"
#property link      "https://github.com/rpvp007-dev/GoldEngineV6-Quantitative-Master"
#property version   "6.00"

#include "../Core/CoreDefines.mqh"
#include "../Core/Config.mqh"
#include "../Core/Logger.mqh"

enum ENUM_MARKET_REGIME_STATE
{
   REGIME_STATE_TRENDING = 0, // Strong Trend: Target 4.0x ATR (+80 to +120 pips), Profit Lock OFF
   REGIME_STATE_RANGING  = 1, // Range Bound: Target 1.2x ATR (+10 to +15 pips), Quick Exit
   REGIME_STATE_CHOP_DEAD = 2  // Flat Chop: HALT ALL TRADING 100%
};

class CMarketRegimeEngine
{
private:
   CLogger* m_logger;
   CConfig* m_config;
   int      m_adxHandle;
   int      m_atrHandle;

public:
   CMarketRegimeEngine(CLogger* logger, CConfig* config)
      : m_logger(logger), m_config(config)
   {
      m_adxHandle = iADX(_Symbol, PERIOD_M15, 14);
      m_atrHandle = iATR(_Symbol, PERIOD_M15, 14);
   }

   ~CMarketRegimeEngine()
   {
      if(m_adxHandle != INVALID_HANDLE) IndicatorRelease(m_adxHandle);
      if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
   }

   ENUM_MARKET_REGIME_STATE GetRegimeState()
   {
      double adxVal[1];
      double atrVal[1];

      if(CopyBuffer(m_adxHandle, 0, 1, 1, adxVal) <= 0 ||
         CopyBuffer(m_atrHandle, 0, 1, 1, atrVal) <= 0)
      {
         return REGIME_STATE_RANGING; // Safe fallback
      }

      double adx = adxVal[0];
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0) point = 0.01;

      // Calculate ATR in Pips (1 Pip = 10 * _Point)
      double atrPips = atrVal[0] / (point * 10.0);

      // RULE 1: CHOP DEAD State (ATR < 30.0 pips / $3.00) -> HALT ALL TRADING
      if(atrPips < 30.0)
      {
         return REGIME_STATE_CHOP_DEAD;
      }

      // RULE 2: TRENDING State (ADX >= 22.0 and ATR >= 45.0 pips / $4.50) -> LONG TARGETS (+90 PIPS)
      if(adx >= 22.0 && atrPips >= 45.0)
      {
         return REGIME_STATE_TRENDING;
      }

      // RULE 3: RANGING State -> SHORT TARGETS (+30 PIPS)
      return REGIME_STATE_RANGING;
   }

   /**
    * @brief Pillar 1: Check if the price is in "No-Man's Land" (middle 50% zone of day's range)
    */
   bool IsPriceInNoMansLand(double currentPrice)
   {
      MqlDateTime dt;
      TimeCurrent(dt);
      
      // NEW PROTECTION 1: Completely DISABLE No-Man's Land filter during Asian Session (00:00 to 07:00 MT5 time)
      // Because Asian session is naturally a range trading session where scalpers thrive!
      if(dt.hour >= 0 && dt.hour < 7)
      {
         return false; 
      }
      
      // Calculate bars since 00:00 today (M15 timeframe)
      int barsToday = dt.hour * 4 + dt.min / 15;
      if(barsToday <= 0) return false;
      
      MqlRates rates[];
      if(CopyRates(_Symbol, PERIOD_M15, 0, barsToday, rates) <= 0) return false;
      
      double dayHigh = -999999.0;
      double dayLow = 999999.0;
      
      for(int i = 0; i < ArraySize(rates); i++)
      {
         if(rates[i].high > dayHigh) dayHigh = rates[i].high;
         if(rates[i].low < dayLow)   dayLow = rates[i].low;
      }
      
      double range = dayHigh - dayLow;
      if(range <= 0.0) return false;
      
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0) point = 0.01;
      
      // Calculate daily range so far in Pips
      double rangePips = range / (point * 10.0);
      
      // NEW PROTECTION 2: If daily range so far is less than 30.0 Pips ($3.00),
      // we do NOT block entries because the morning session range is still expanding!
      if(rangePips < 30.0)
      {
         return false; 
      }
      
      // Define 25% and 75% boundaries of the daily range
      double lowThreshold = dayLow + range * 0.25;
      double highThreshold = dayLow + range * 0.75;
      
      // If price is stuck in the middle 50% zone, block it!
      if(currentPrice > lowThreshold && currentPrice < highThreshold)
      {
         return true;
      }
      
      return false;
   }

   string GetRegimeStateName()
   {
      ENUM_MARKET_REGIME_STATE state = GetRegimeState();
      switch(state)
      {
         case REGIME_STATE_TRENDING:  return "STATE_TRENDING (Long Targets +80 Pips)";
         case REGIME_STATE_RANGING:   return "STATE_RANGING (Short Targets +12 Pips)";
         case REGIME_STATE_CHOP_DEAD: return "STATE_CHOP_DEAD (Trading Blocked 100%)";
      }
      return "UNKNOWN";
   }
};
