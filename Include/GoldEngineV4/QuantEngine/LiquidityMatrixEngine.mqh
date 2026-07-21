//+------------------------------------------------------------------+
//|                                      LiquidityMatrixEngine.mqh |
//|                                  Copyright 2026, GoldEngine V6   |
//|                 Pillar 2: Liquidity Pool & Order Block Matrix    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, GoldEngine V6"
#property link      "https://github.com/rpvp007-dev/GoldEngineV6-Quantitative-Master"
#property version   "6.00"

#include "../Core/CoreDefines.mqh"
#include "../Core/Config.mqh"
#include "../Core/Logger.mqh"

class CLiquidityMatrixEngine
{
private:
   CLogger* m_logger;
   CConfig* m_config;

public:
   CLiquidityMatrixEngine(CLogger* logger, CConfig* config)
      : m_logger(logger), m_config(config)
   {}

   ~CLiquidityMatrixEngine() {}

   bool IsLiquiditySweepActive(bool &outBuySweep, bool &outSellSweep)
   {
      outBuySweep = false;
      outSellSweep = false;

      // Get Previous Day High / Low
      MqlRates dailyRates[];
      if(CopyRates(_Symbol, PERIOD_D1, 1, 1, dailyRates) <= 0) return false;

      double pdh = dailyRates[0].high;
      double pdl = dailyRates[0].low;

      // Get current M15 high / low
      double currentHigh = iHigh(_Symbol, PERIOD_M15, 1);
      double currentLow  = iLow(_Symbol, PERIOD_M15, 1);
      double currentClose = iClose(_Symbol, PERIOD_M15, 1);

      // Buy-side Liquidity Sweep (PDH swept and rejected back below)
      if(currentHigh > pdh && currentClose < pdh)
      {
         outSellSweep = true; // Liquidity swept on high -> SELL setup
      }

      // Sell-side Liquidity Sweep (PDL swept and rejected back above)
      if(currentLow < pdl && currentClose > pdl)
      {
         outBuySweep = true; // Liquidity swept on low -> BUY setup
      }

      return (outBuySweep || outSellSweep);
   }

   bool IsFairValueGapPresent(ENUM_GEV2_SIGNAL_TYPE signalType)
   {
      MqlRates m15[];
      if(CopyRates(_Symbol, PERIOD_M15, 1, 3, m15) < 3) return false;

      // Bullish FVG: Bar 1 High < Bar 3 Low
      if(signalType == GEV2_SIGNAL_BUY)
      {
         if(m15[0].high < m15[2].low) return true;
      }
      // Bearish FVG: Bar 1 Low > Bar 3 High
      else if(signalType == GEV2_SIGNAL_SELL)
      {
         if(m15[0].low > m15[2].high) return true;
      }

      return false;
   }
};
