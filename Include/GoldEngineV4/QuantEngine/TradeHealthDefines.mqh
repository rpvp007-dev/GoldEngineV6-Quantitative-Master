//+------------------------------------------------------------------+
//|                                           TradeHealthDefines.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_TRADE_HEALTH_DEFINES_MQH
#define GOLDENGINEV2_TRADE_HEALTH_DEFINES_MQH

//--- Trade Health Classification State
enum ENUM_TRADE_HEALTH_STATE
{
   HEALTH_EXCELLENT = 0,   // Score 85-100
   HEALTH_HEALTHY   = 1,   // Score 70-84
   HEALTH_STABLE    = 2,   // Score 55-69
   HEALTH_WEAKENING = 3,   // Score 40-54
   HEALTH_DANGER    = 4,   // Score 25-39
   HEALTH_CRITICAL  = 5    // Score 0-24
};

//--- Context structure holding computed health telemetry
struct TradeHealthContext
{
   double                  HealthScore;      // Weighted score from 0.0 to 100.0
   ENUM_TRADE_HEALTH_STATE HealthState;      // Categorized rating state
   string                  HealthNarrative;  // Quantitative narrative log
};

//+------------------------------------------------------------------+
//| Helper to convert ENUM_TRADE_HEALTH_STATE to string              |
//+------------------------------------------------------------------+
inline string TradeHealthStateToString(ENUM_TRADE_HEALTH_STATE state)
{
   switch(state)
   {
      case HEALTH_EXCELLENT: return "Excellent";
      case HEALTH_HEALTHY:   return "Healthy";
      case HEALTH_STABLE:    return "Stable";
      case HEALTH_WEAKENING: return "Weakening";
      case HEALTH_DANGER:    return "Danger";
      case HEALTH_CRITICAL:  return "Critical";
      default:               return "Unknown";
   }
}

#endif // GOLDENGINEV2_TRADE_HEALTH_DEFINES_MQH
