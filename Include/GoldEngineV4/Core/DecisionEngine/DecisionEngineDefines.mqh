//+------------------------------------------------------------------+
//|                                         DecisionEngineDefines.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_DECISION_ENGINE_DEFINES_MQH
#define GOLDENGINEV2_DECISION_ENGINE_DEFINES_MQH

//--- Trade Decision States
enum ENUM_TRADE_DECISION
{
   DECISION_BUY,
   DECISION_SELL,
   DECISION_WAIT,
   DECISION_AVOID
};

//--- Trade Confidence Level
enum ENUM_TRADE_CONFIDENCE
{
   TRADE_CONF_LOW,
   TRADE_CONF_MEDIUM,
   TRADE_CONF_HIGH
};

//--- Institutional Decision Context Data Contract
struct DecisionContext
{
   double               TradeProbability;       // Composite probability of a successful trade setup (0 to 100)
   double               TrendContinuationProb;  // Probability of trend continuation (0 to 100)
   double               ReversalProb;           // Probability of trend reversal (0 to 100)
   double               BreakoutProb;           // Probability of dynamic breakout (0 to 100)
   double               RangeProb;              // Probability of rangebound trading (0 to 100)
   double               ExpectedRR;             // Expected target Reward/Risk ratio (e.g. 2.0)
   ENUM_TRADE_CONFIDENCE TradeConfidence;       // LOW, MEDIUM, HIGH
   ENUM_TRADE_DECISION  Decision;              // BUY, SELL, WAIT, AVOID
   string               Reason;                 // Complete explanatory narrative explanation
};

#endif // GOLDENGINEV2_DECISION_ENGINE_DEFINES_MQH
