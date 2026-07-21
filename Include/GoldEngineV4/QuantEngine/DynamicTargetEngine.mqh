//+------------------------------------------------------------------+
//|                                         DynamicTargetEngine.mqh |
//|                                  Copyright 2026, GoldEngine V6   |
//|                    Dynamic Target & Exit Intelligence Engine     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, GoldEngine V6"
#property link      "https://github.com/rpvp007-dev/GoldEngineV6-Quantitative-Master"
#property version   "6.00"

#include "../Core/CoreDefines.mqh"
#include "../Core/Config.mqh"
#include "../Core/Logger.mqh"
#include "MarketRegimeEngine.mqh"

class CDynamicTargetEngine
{
private:
   CLogger*              m_logger;
   CConfig*              m_config;
   CMarketRegimeEngine*  m_regimeEngine;

public:
   CDynamicTargetEngine(CLogger* logger, CConfig* config, CMarketRegimeEngine* regimeEngine)
      : m_logger(logger), m_config(config), m_regimeEngine(regimeEngine)
   {}

   ~CDynamicTargetEngine() {}

   bool CalculateDynamicTargets(ENUM_GEV2_SIGNAL_TYPE signalType, double entryPrice, double atrPoints, double &outSL, double &outTP, double &outBETrigger)
   {
      ENUM_MARKET_REGIME_STATE state = m_regimeEngine.GetRegimeState();

      // Case 1: CHOP DEAD -> Reject trade completely
      if(state == REGIME_STATE_CHOP_DEAD)
      {
         m_logger.Warning("[V6 TARGET ENGINE] Trade Blocked: Market in STATE_CHOP_DEAD (ATR < 6 pips or ADX < 14)");
         return false;
      }

      double slDistance = 0.0;
      double tpDistance = 0.0;

      // Case 2: TRENDING -> Long Targets (+80 to +120 Pips), Wide BE
      if(state == REGIME_STATE_TRENDING)
      {
         slDistance = MathMax(200.0, atrPoints * 1.5); // Min 20 pips
         tpDistance = MathMax(800.0, atrPoints * 4.0); // Min 80 pips LONG TARGET
         outBETrigger = 300.0; // 30.0 Pips BE trigger
      }
      // Case 3: RANGING -> Short Targets (+12 to +15 Pips), Quick Exit
      else if(state == REGIME_STATE_RANGING)
      {
         slDistance = MathMax(120.0, atrPoints * 1.0); // Min 12 pips
         tpDistance = MathMax(150.0, atrPoints * 1.2); // Min 15 pips SHORT TARGET
         outBETrigger = 120.0; // 12.0 Pips BE trigger
      }

      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

      if(signalType == GEV2_SIGNAL_BUY)
      {
         outSL = NormalizeDouble(entryPrice - (slDistance * _Point), digits);
         outTP = NormalizeDouble(entryPrice + (tpDistance * _Point), digits);
      }
      else if(signalType == GEV2_SIGNAL_SELL)
      {
         outSL = NormalizeDouble(entryPrice + (slDistance * _Point), digits);
         outTP = NormalizeDouble(entryPrice - (tpDistance * _Point), digits);
      }

      m_logger.Info(StringFormat("[V6 TARGET ENGINE] Calculated Targets (%s): TP=%.2f pips, SL=%.2f pips, BE=%.2f pips",
                    m_regimeEngine.GetRegimeStateName(), tpDistance / 10.0, slDistance / 10.0, outBETrigger / 10.0));

      return true;
   }
};
