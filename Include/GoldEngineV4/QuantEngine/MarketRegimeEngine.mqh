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
      double atr = atrVal[0] / _Point; // In points

      // Rule 1: CHOP DEAD State (ATR < 60 points / 6 pips or ADX < 14) -> HALT ALL TRADING
      if(atr < 60.0 || adx < 14.0)
      {
         return REGIME_STATE_CHOP_DEAD;
      }

      // Rule 2: TRENDING State (ADX > 25 and ATR > 100 points / 10 pips) -> LONG TARGETS (+80 PIPS)
      if(adx >= 25.0 && atr >= 100.0)
      {
         return REGIME_STATE_TRENDING;
      }

      // Rule 3: RANGING State (ADX between 14 and 25) -> SHORT TARGETS (+12 PIPS)
      return REGIME_STATE_RANGING;
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
