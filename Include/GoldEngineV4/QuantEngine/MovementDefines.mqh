//+------------------------------------------------------------------+
//|                                             MovementDefines.mqh  |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_MOVEMENT_DEFINES_MQH
#define GOLDENGINEV2_MOVEMENT_DEFINES_MQH

//--- Movement States
enum ENUM_MOVEMENT_STATE
{
   MOVEMENT_STATE_DEAD,
   MOVEMENT_STATE_SLOW,
   MOVEMENT_STATE_HEALTHY,
   MOVEMENT_STATE_FAST,
   MOVEMENT_STATE_EXPLOSIVE
};

//--- Price Acceleration Classification
enum ENUM_PRICE_ACCELERATION
{
   ACCEL_STRONG_NEGATIVE,
   ACCEL_NEGATIVE,
   ACCEL_NEUTRAL,
   ACCEL_POSITIVE,
   ACCEL_STRONG_POSITIVE
};

//--- Pullback Quality Classification
enum ENUM_PULLBACK_QUALITY
{
   PULLBACK_WEAK,
   PULLBACK_HEALTHY,
   PULLBACK_DEEP,
   PULLBACK_FAILED
};

//--- Movement Context Data Structure
struct MovementContext
{
   double                  MovementScore;       // 0 to 100
   ENUM_MOVEMENT_STATE     MovementState;       // DEAD, SLOW, HEALTHY, FAST, EXPLOSIVE
   double                  Velocity;            // 0 to 100 price velocity
   ENUM_PRICE_ACCELERATION Acceleration;        // Acceleration classification
   double                  Persistence;         // 0 to 100 directional persistence
   ENUM_PULLBACK_QUALITY   PullbackQuality;     // Pullback quality classification
   double                  BreakoutEnergy;      // 0 to 100 breakout intensity
   double                  Compression;         // 0 to 100 consolidation score
   double                  Expansion;           // 0 to 100 volatility expansion score
   double                  Exhaustion;          // 0 to 100 price exhaustion score
   double                  Efficiency;          // 0 to 100 path efficiency ratio
   string                  MovementNarrative;   // Humanity narrative explainability
};

#endif // GOLDENGINEV2_MOVEMENT_DEFINES_MQH
