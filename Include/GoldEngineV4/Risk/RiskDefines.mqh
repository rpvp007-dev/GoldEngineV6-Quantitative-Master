//+------------------------------------------------------------------+
//|                                                 RiskDefines.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_RISK_DEFINES_MQH
#define GOLDENGINEV2_RISK_DEFINES_MQH

//+------------------------------------------------------------------+
//| Risk Guardian Audit Response structure                           |
//+------------------------------------------------------------------+
struct RiskAuditResponse
{
   bool              Approved;            // true if passes all risk criteria, false if rejected
   string            Reason;              // Clear descriptive reason if rejected
   double            CurrentRiskLevel;    // Today's total risk level
   double            CurrentExposure;     // Total portfolio exposure in percentage of balance
   double            CurrentDrawdown;     // Peak equity drawdown in percentage
   double            RemainingDailyLoss;  // Remaining daily loss allowed in cash amount
   double            RemainingWeeklyLoss; // Remaining weekly loss allowed in cash amount
   double            PenaltyScore;        // Accumulated soft penalties score
};

#endif // GOLDENGINEV2_RISK_DEFINES_MQH
