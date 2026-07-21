//+------------------------------------------------------------------+
//|                                           MarketIntentDefines.mqh|
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_MARKET_INTENT_DEFINES_MQH
#define GOLDENGINEV2_MARKET_INTENT_DEFINES_MQH

//--- Breakout Authenticity
enum ENUM_BREAKOUT_AUTHENTICITY
{
   BREAKOUT_REAL,
   BREAKOUT_WEAK,
   BREAKOUT_FALSE
};

//--- Trap Type
enum ENUM_TRAP_TYPE
{
   TRAP_BULL,
   TRAP_BEAR,
   TRAP_NEUTRAL
};

//--- Market Commitment Level
enum ENUM_MARKET_COMMITMENT
{
   COMMITMENT_WEAK,
   COMMITMENT_MEDIUM,
   COMMITMENT_STRONG
};

//--- Market Intent Context Structure
struct MarketIntentContext
{
   double                  BuyerIntent;            // 0 to 100
   double                  SellerIntent;           // 0 to 100
   double                  ContinuationProb;       // 0 to 100
   double                  ReversalProb;           // 0 to 100
   ENUM_BREAKOUT_AUTHENTICITY BreakoutAuthenticity; // REAL, WEAK, FALSE
   double                  LiquidityGrabProb;      // 0 to 100
   ENUM_TRAP_TYPE          TrapType;               // BULL, BEAR, NEUTRAL
   double                  TrapProbability;        // 0 to 100
   ENUM_MARKET_COMMITMENT  MarketCommitment;       // WEAK, MEDIUM, STRONG
   double                  MarketCommitmentScore;  // 0 to 100
   double                  ContinuationFuel;       // 0 to 100
   string                  IntentNarrative;        // human-readable explainability
};

#endif // GOLDENGINEV2_MARKET_INTENT_DEFINES_MQH
