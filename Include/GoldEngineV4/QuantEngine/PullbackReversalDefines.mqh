//+------------------------------------------------------------------+
//|                                     PullbackReversalDefines.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_PULLBACK_REVERSAL_DEFINES_MQH
#define GOLDENGINEV2_PULLBACK_REVERSAL_DEFINES_MQH

//--- Pullback states classification
enum ENUM_PULLBACK_STATE
{
   PULLBACK_STATE_NONE,
   PULLBACK_STATE_HEALTHY_PULLBACK,
   PULLBACK_STATE_NORMAL_PULLBACK,
   PULLBACK_STATE_DEEP_PULLBACK,
   PULLBACK_STATE_FAILED_PULLBACK,
   PULLBACK_STATE_REVERSAL,
   PULLBACK_STATE_TREND_EXHAUSTION,
   PULLBACK_STATE_FALSE_BREAKOUT,
   PULLBACK_STATE_TRUE_BREAKOUT
};

//--- Advisory action recommendations
enum ENUM_PULLBACK_RECOMMENDATION
{
   PULLBACK_REC_HOLD,
   PULLBACK_REC_TIGHTEN_STOP,
   PULLBACK_REC_MOVE_BREAK_EVEN,
   PULLBACK_REC_TRAIL,
   PULLBACK_REC_EXIT,
   PULLBACK_REC_ADD_POSITION,
   PULLBACK_REC_WAIT
};

//--- Pullback and Reversal evaluation output context
struct PullbackReversalContext
{
   ENUM_PULLBACK_STATE           State;
   double                        ContinuationProb;       // 0 - 100
   double                        ReversalProb;           // 0 - 100
   double                        TrendRecoveryProb;      // 0 - 100
   double                        BreakoutAuthenticity;   // 0 - 100
   double                        FakeBreakoutProb;       // 0 - 100
   double                        PullbackProb;           // 0 - 100
   ENUM_PULLBACK_RECOMMENDATION  Recommendation;
   string                        Narrative;
   double                        Confidence;             // 0 - 100
};

//--- Inline conversion helper
inline string PullbackStateToString(ENUM_PULLBACK_STATE state)
{
   switch(state)
   {
      case PULLBACK_STATE_NONE:             return "None";
      case PULLBACK_STATE_HEALTHY_PULLBACK: return "Healthy Pullback";
      case PULLBACK_STATE_NORMAL_PULLBACK:  return "Normal Pullback";
      case PULLBACK_STATE_DEEP_PULLBACK:    return "Deep Pullback";
      case PULLBACK_STATE_FAILED_PULLBACK:  return "Failed Pullback";
      case PULLBACK_STATE_REVERSAL:         return "Reversal";
      case PULLBACK_STATE_TREND_EXHAUSTION: return "Trend Exhaustion";
      case PULLBACK_STATE_FALSE_BREAKOUT:   return "False Breakout";
      case PULLBACK_STATE_TRUE_BREAKOUT:    return "True Breakout";
      default:                              return "Unknown";
   }
}

inline string PullbackRecToString(ENUM_PULLBACK_RECOMMENDATION rec)
{
   switch(rec)
   {
      case PULLBACK_REC_HOLD:             return "HOLD";
      case PULLBACK_REC_TIGHTEN_STOP:     return "TIGHTEN_STOP";
      case PULLBACK_REC_MOVE_BREAK_EVEN:  return "MOVE_BREAK_EVEN";
      case PULLBACK_REC_TRAIL:            return "TRAIL";
      case PULLBACK_REC_EXIT:             return "EXIT";
      case PULLBACK_REC_ADD_POSITION:     return "ADD_POSITION";
      case PULLBACK_REC_WAIT:             return "WAIT";
      default:                            return "WAIT";
   }
}

#endif // GOLDENGINEV2_PULLBACK_REVERSAL_DEFINES_MQH
