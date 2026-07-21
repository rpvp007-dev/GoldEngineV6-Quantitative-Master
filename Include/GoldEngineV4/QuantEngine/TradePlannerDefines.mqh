//+------------------------------------------------------------------+
//|                                         TradePlannerDefines.mqh  |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_TRADE_PLANNER_DEFINES_MQH
#define GOLDENGINEV2_TRADE_PLANNER_DEFINES_MQH

//--- Trade Direction Recommendation
enum ENUM_TRADE_DIRECTION_REC
{
   REC_DIR_BUY,
   REC_DIR_SELL,
   REC_DIR_NONE
};

//--- Execution Modes
enum ENUM_EXECUTION_MODE
{
   MODE_AVOID,
   MODE_PROBE,
   MODE_SCALP,
   MODE_MOMENTUM,
   MODE_RUNNER
};

//--- Holding Time Units
enum ENUM_HOLDING_TIME_UNIT
{
   HOLD_SECONDS,
   HOLD_MINUTES,
   HOLD_HOURS
};

//--- Trade Plan Context Structure
struct TradePlanContext
{
   ENUM_TRADE_DIRECTION_REC DirectionRec;            // BUY, SELL, NONE
   ENUM_EXECUTION_MODE   ExecutionMode;              // AVOID, PROBE, SCALP, MOMENTUM, RUNNER
   double                  ExpectedMove;             // Points
   double                  ExpectedHoldingTime;      // Holding time duration value
   ENUM_HOLDING_TIME_UNIT  HoldingTimeUnit;          // SECONDS, MINUTES, HOURS
   double                  EntryQuality;             // 0 to 100 entry zone quality
   double                  RecEntryZoneStart;        // Recommended Entry range low
   double                  RecEntryZoneEnd;          // Recommended Entry range high
   double                  RecStopZoneStart;         // Recommended Stop range low
   double                  RecStopZoneEnd;           // Recommended Stop range high
   double                  RecProfitZoneStart;       // Recommended Profit range low
   double                  RecProfitZoneEnd;         // Recommended Profit range high
   double                  RecPartialExitPrice;      // First target level for scale-outs
   double                  RecTrailActivationPrice;  // Activation point to trail stop
   double                  ExpectedRisk;             // Points
   double                  ExpectedReward;           // Points
   double                  ExpectedRR;               // Reward/Risk ratio
   double                  TradeConfidence;          // 0 to 100 composite confidence
   string                  TradeNarrative;           // Narrative explainability
};

#endif // GOLDENGINEV2_TRADE_PLANNER_DEFINES_MQH
