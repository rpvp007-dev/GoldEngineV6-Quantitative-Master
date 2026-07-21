//+------------------------------------------------------------------+
//|                                                BridgeDefines.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_BRIDGE_DEFINES_MQH
#define GOLDENGINEV2_BRIDGE_DEFINES_MQH

//--- Runtime Config Override Structure for X001
struct X001RuntimeConfig
{
   bool     ResearchMode;
   double   ResearchMinScore;
   double   MinEntryScore;
   double   AggressivenessBonus;
   int      MaxBuyPositions;
   int      MaxSellPositions;
   int      MinSpacingPoints;
   double   MaxTotalExposure;
   int      MaxTradesPerHour;
   int      MaxTradesPerSession;
   double   MomentumExitThreshold;
   
   double   ProbeTPPoints;
   double   ProbeSLPoints;
   double   ScalpTPPoints;
   double   ScalpSLPoints;
   double   MomentumTPPoints;
   double   MomentumSLPoints;
   double   RunnerTrailPoints;
   double   RunnerActivationPts;
   double   SidewaysTPPoints;
   double   TrendTPPoints;
   int      MinExitHoldSeconds; // V5.5
};

//--- Runtime Config Override Structure for General Risk
struct GITSRiskConfig
{
   double   RiskPercent;
   double   MaxDailyLossPercent;
   double   MaxWeeklyLossPercent;
   int      MaxPositions;
   double   MaxExposurePercent;
};

//--- Runtime Config Override Structure for GITS Trade Manager V1
struct GITSTradeManagerConfig
{
   bool     EnableTradeManager;
   bool     EnableBreakEven;
   double   BreakEvenTrigger;
   double   BreakEvenOffset;
   bool     EnableTrailing;
   int      TrailingMode;
   double   TmAtrMultiplier;
   double   MinTrailDistance;
   double   MaxTrailDistance;
   bool     EnableProfitLock;
   double   ProfitLockStep;
   double   MinLockedProfit;
};

//--- Combined configuration structure
struct GITSBridgeConfig
{
   string                 Mode;
   bool                   X001Enabled;
   GITSRiskConfig         Risk;
   X001RuntimeConfig      X001;
   GITSTradeManagerConfig TM;
};

#endif
