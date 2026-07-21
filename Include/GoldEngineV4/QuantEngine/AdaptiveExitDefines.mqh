//+------------------------------------------------------------------+
//|                                          AdaptiveExitDefines.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_ADAPTIVE_EXIT_DEFINES_MQH
#define GOLDENGINEV2_ADAPTIVE_EXIT_DEFINES_MQH

//--- Adaptive Exit Actions Recommendation
enum ENUM_ADAPTIVE_EXIT_ACTION
{
   ADAPTIVE_EXIT_HOLD,
   ADAPTIVE_EXIT_MOVE_BREAK_EVEN,
   ADAPTIVE_EXIT_TIGHTEN_STOP,
   ADAPTIVE_EXIT_TRAIL,
   ADAPTIVE_EXIT_LOCK_PROFIT,
   ADAPTIVE_EXIT_PARTIAL_EXIT,
   ADAPTIVE_EXIT_FULL_EXIT,
   ADAPTIVE_EXIT_CONVERT_TO_RUNNER,
   ADAPTIVE_EXIT_WAIT
};

//--- Context details output by the Adaptive Exit AI Engine
struct AdaptiveExitContext
{
   ENUM_ADAPTIVE_EXIT_ACTION  Recommendation;
   double                     Confidence;             // 0 - 100
   string                     Narrative;
   string                     RiskLevel;              // e.g. "Low", "Medium", "High", "Critical"
   double                     ExpectedRemainingMove;  // in points
   double                     RecommendedStop;        // Price level
   double                     RecommendedTrail;       // in points
   
   // Scores metrics breakdown
   double                     HoldScore;              // 0 - 100
   double                     ExitScore;              // 0 - 100
   double                     RunnerScore;            // 0 - 100
};

//--- Inline conversion helper functions
inline string AdaptiveExitActionToString(ENUM_ADAPTIVE_EXIT_ACTION action)
{
   switch(action)
   {
      case ADAPTIVE_EXIT_HOLD:              return "HOLD";
      case ADAPTIVE_EXIT_MOVE_BREAK_EVEN:   return "MOVE_BREAK_EVEN";
      case ADAPTIVE_EXIT_TIGHTEN_STOP:      return "TIGHTEN_STOP";
      case ADAPTIVE_EXIT_TRAIL:             return "TRAIL";
      case ADAPTIVE_EXIT_LOCK_PROFIT:       return "LOCK_PROFIT";
      case ADAPTIVE_EXIT_PARTIAL_EXIT:      return "PARTIAL_EXIT";
      case ADAPTIVE_EXIT_FULL_EXIT:         return "FULL_EXIT";
      case ADAPTIVE_EXIT_CONVERT_TO_RUNNER: return "CONVERT_TO_RUNNER";
      case ADAPTIVE_EXIT_WAIT:              return "WAIT";
      default:                              return "WAIT";
   }
}

#endif // GOLDENGINEV2_ADAPTIVE_EXIT_DEFINES_MQH
