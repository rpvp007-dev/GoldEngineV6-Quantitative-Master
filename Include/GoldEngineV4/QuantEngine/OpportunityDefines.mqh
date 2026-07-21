//+------------------------------------------------------------------+
//|                                         OpportunityDefines.mqh   |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_OPPORTUNITY_DEFINES_MQH
#define GOLDENGINEV2_OPPORTUNITY_DEFINES_MQH

//--- Opportunity Classes
enum ENUM_OPPORTUNITY_CLASS
{
   OPPORTUNITY_CLASS_VERY_LOW,
   OPPORTUNITY_CLASS_LOW,
   OPPORTUNITY_CLASS_MEDIUM,
   OPPORTUNITY_CLASS_HIGH,
   OPPORTUNITY_CLASS_EXTREME
};

//--- Trade Window State
enum ENUM_TRADE_WINDOW
{
   TRADE_WINDOW_NO_TRADE,
   TRADE_WINDOW_VERY_SHORT,
   TRADE_WINDOW_SHORT,
   TRADE_WINDOW_MEDIUM,
   TRADE_WINDOW_LONG
};

//--- Recommendation Type
enum ENUM_SCALP_RECOMMENDATION
{
   SCALP_RECOMMENDATION_AVOID,
   SCALP_RECOMMENDATION_SCALP,
   SCALP_RECOMMENDATION_NORMAL,
   SCALP_RECOMMENDATION_RUNNER
};

//--- Opportunity Context Struct
struct OpportunityContext
{
   double                  OpportunityScore;       // 0 to 100
   ENUM_OPPORTUNITY_CLASS  OpportunityClass;       // VERY_LOW to EXTREME
   double                  ExpectedMove;           // Estimated movement in points
   double                  ExpectedRisk;           // Estimated stop risk in points
   double                  ExpectedReward;         // Estimated target reward in points
   double                  ExpectedRR;             // Expected Reward/Risk Ratio
   ENUM_TRADE_WINDOW       TradeWindow;            // NO_TRADE to LONG
   string                  OpportunityNarrative;   // Analytical text explanation
   ENUM_SCALP_RECOMMENDATION ScalpRec;             // AVOID, SCALP, NORMAL, RUNNER
   ENUM_SCALP_RECOMMENDATION RunnerRec;            // AVOID, SCALP, NORMAL, RUNNER
   double                  EntryQuality;           // Entry Quality Score (0 to 100)
   double                  ExitQuality;            // Exit Quality Score (0 to 100)
};

#endif // GOLDENGINEV2_OPPORTUNITY_DEFINES_MQH
