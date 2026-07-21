//+------------------------------------------------------------------+
//|                                                  CoreDefines.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_CORE_DEFINES_MQH
#define GOLDENGINEV2_CORE_DEFINES_MQH

//+------------------------------------------------------------------+
//| Log levels for structured logging                                |
//+------------------------------------------------------------------+
enum ENUM_GEV2_LOG_LEVEL
{
   GEV2_LOG_DEBUG,
   GEV2_LOG_INFO,
   GEV2_LOG_WARNING,
   GEV2_LOG_ERROR,
   GEV2_LOG_CRITICAL
};

//+------------------------------------------------------------------+
//| Trading signal types                                             |
//+------------------------------------------------------------------+
enum ENUM_GEV2_SIGNAL_TYPE
{
   GEV2_SIGNAL_NONE,
   GEV2_SIGNAL_BUY,
   GEV2_SIGNAL_SELL
};

//+------------------------------------------------------------------+
//| Order types supported by the Execution Engine                    |
//+------------------------------------------------------------------+
enum ENUM_GEV2_ORDER_TYPE
{
   GEV2_ORDER_MARKET_BUY,
   GEV2_ORDER_MARKET_SELL,
   GEV2_ORDER_LIMIT_BUY,
   GEV2_ORDER_LIMIT_SELL,
   GEV2_ORDER_STOP_BUY,
   GEV2_ORDER_STOP_SELL
};

//+------------------------------------------------------------------+
//| System states for lifecycle management                           |
//+------------------------------------------------------------------+
enum ENUM_GEV2_SYSTEM_STATE
{
   GEV2_STATE_UNINITIALIZED,
   GEV2_STATE_INITIALIZING,
   GEV2_STATE_OPERATIONAL,
   GEV2_STATE_PAUSED,
   GEV2_STATE_SHUTTING_DOWN,
   GEV2_STATE_ERROR
};

//+------------------------------------------------------------------+
//| Filter Modes for strategy optimization                           |
//+------------------------------------------------------------------+
enum ENUM_FILTER_MODE
{
   FILTER_MODE_DISABLED = 0, // Filter is ignored
   FILTER_MODE_SOFT     = 1, // Filter contributes to score, does not block
   FILTER_MODE_HARD     = 2  // Filter is mandatory, blocks immediately
};

//+------------------------------------------------------------------+
//| Trading Profile — controls the restriction framework behavior    |
//| PROFILE_RESEARCH  : All internal restrictions disabled.          |
//|                     For Strategy Tester / Demo research only.    |
//| PROFILE_PRODUCTION: Full Risk Guardian safety framework active.  |
//+------------------------------------------------------------------+
enum ENUM_TRADING_PROFILE
{
   PROFILE_RESEARCH   = 0, // Research Mode — unlimited trading, no internal restrictions
   PROFILE_PRODUCTION = 1  // Production Mode — full Risk Guardian safety framework active
};

#endif // GOLDENGINEV2_CORE_DEFINES_MQH
