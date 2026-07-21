//+------------------------------------------------------------------+
//|                                InstitutionalExecutionDefines.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_INSTITUTIONAL_EXECUTION_DEFINES_MQH
#define GOLDENGINEV2_INSTITUTIONAL_EXECUTION_DEFINES_MQH

//--- Role category for an active position
enum ENUM_POSITION_ROLE
{
   POSITION_ROLE_SCOUT,
   POSITION_ROLE_SCALP,
   POSITION_ROLE_MOMENTUM,
   POSITION_ROLE_RUNNER,
   POSITION_ROLE_RECOVERY
};

//--- Action recommendations issued by the execution manager
enum ENUM_INSTITUTIONAL_EXEC_ACTION
{
   EXEC_ACTION_OPEN_POSITION,
   EXEC_ACTION_ADD_POSITION,
   EXEC_ACTION_REDUCE_EXPOSURE,
   EXEC_ACTION_PROMOTE_RUNNER,
   EXEC_ACTION_SCALE_OUT,
   EXEC_ACTION_HOLD,
   EXEC_ACTION_WAIT,
   EXEC_ACTION_RISK_REDUCTION
};

//--- Context structures output by the Institutional Execution Engine
struct InstitutionalExecutionContext
{
   ENUM_INSTITUTIONAL_EXEC_ACTION Recommendation;
   double                        PortfolioHealth;             // 0 - 100
   double                        TotalExposure;                // in lots
   double                        LongExposure;                 // in lots
   double                        ShortExposure;                // in lots
   double                        NetExposure;                  // in lots
   double                        PortfolioRisk;                // overall risk metric
   int                           ActiveScouts;
   int                           ActiveScalps;
   int                           ActiveMomentums;
   int                           ActiveRunners;
   double                        CapitalAllocation;            // sizing in lots
   double                        PriorityScore;                // ranking score
   string                        Narrative;
};

//--- Inline conversion helpers
inline string PositionRoleToString(ENUM_POSITION_ROLE role)
{
   switch(role)
   {
      case POSITION_ROLE_SCOUT:      return "SCOUT";
      case POSITION_ROLE_SCALP:      return "SCALP";
      case POSITION_ROLE_MOMENTUM:  return "MOMENTUM";
      case POSITION_ROLE_RUNNER:    return "RUNNER";
      case POSITION_ROLE_RECOVERY:  return "RECOVERY";
      default:                      return "UNKNOWN";
   }
}

inline string InstitutionalExecActionToString(ENUM_INSTITUTIONAL_EXEC_ACTION action)
{
   switch(action)
   {
      case EXEC_ACTION_OPEN_POSITION:   return "OPEN_POSITION";
      case EXEC_ACTION_ADD_POSITION:    return "ADD_POSITION";
      case EXEC_ACTION_REDUCE_EXPOSURE: return "REDUCE_EXPOSURE";
      case EXEC_ACTION_PROMOTE_RUNNER:  return "PROMOTE_RUNNER";
      case EXEC_ACTION_SCALE_OUT:       return "SCALE_OUT";
      case EXEC_ACTION_HOLD:            return "HOLD";
      case EXEC_ACTION_WAIT:            return "WAIT";
      case EXEC_ACTION_RISK_REDUCTION:  return "RISK_REDUCTION";
      default:                          return "WAIT";
   }
}

#endif // GOLDENGINEV2_INSTITUTIONAL_EXECUTION_DEFINES_MQH
