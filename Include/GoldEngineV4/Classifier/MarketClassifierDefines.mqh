//+------------------------------------------------------------------+
//|                                     MarketClassifierDefines.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_MARKET_CLASSIFIER_DEFINES_MQH
#define GOLDENGINEV2_MARKET_CLASSIFIER_DEFINES_MQH

//+------------------------------------------------------------------+
//| Trend States                                                     |
//+------------------------------------------------------------------+
enum ENUM_GEV2_TREND_STATE
{
   GEV2_TREND_NEUTRAL,
   GEV2_TREND_BULLISH,
   GEV2_TREND_BEARISH
};

//+------------------------------------------------------------------+
//| Momentum States                                                  |
//+------------------------------------------------------------------+
enum ENUM_GEV2_MOMENTUM_STATE
{
   GEV2_MOM_WEAK,
   GEV2_MOM_MEDIUM,
   GEV2_MOM_STRONG
};

//+------------------------------------------------------------------+
//| Volatility States                                                |
//+------------------------------------------------------------------+
enum ENUM_GEV2_VOLATILITY_STATE
{
   GEV2_VOL_LOW,
   GEV2_VOL_NORMAL,
   GEV2_VOL_HIGH
};

//+------------------------------------------------------------------+
//| Market Phases                                                    |
//+------------------------------------------------------------------+
enum ENUM_GEV2_MARKET_PHASE
{
   GEV2_PHASE_RANGE,
   GEV2_PHASE_TREND,
   GEV2_PHASE_PULLBACK,
   GEV2_PHASE_BREAKOUT,
   GEV2_PHASE_REVERSAL
};

//+------------------------------------------------------------------+
//| Market Sessions                                                  |
//+------------------------------------------------------------------+
enum ENUM_GEV2_SESSION
{
   GEV2_SESS_UNKNOWN,
   GEV2_SESS_ASIA,
   GEV2_SESS_LONDON,
   GEV2_SESS_NEWYORK
};

//+------------------------------------------------------------------+
//| Consolidated Market State structure                              |
//+------------------------------------------------------------------+
struct MarketState
{
   ENUM_GEV2_TREND_STATE      Trend;
   ENUM_GEV2_MOMENTUM_STATE   Momentum;
   ENUM_GEV2_VOLATILITY_STATE Volatility;
   ENUM_GEV2_MARKET_PHASE     Phase;
   ENUM_GEV2_SESSION          Session;
   int                        ConfidenceScore; // 0 to 100
};

#endif // GOLDENGINEV2_MARKET_CLASSIFIER_DEFINES_MQH
