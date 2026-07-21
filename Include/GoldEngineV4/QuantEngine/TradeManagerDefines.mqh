//+------------------------------------------------------------------+
//|                                         TradeManagerDefines.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_TRADE_MANAGER_DEFINES_MQH
#define GOLDENGINEV2_TRADE_MANAGER_DEFINES_MQH

//--- Trailing stop mode
enum ENUM_TRAILING_MODE
{
   TRAILING_MODE_FIXED, // Fixed Points
   TRAILING_MODE_ATR    // ATR Multiplier Based
};

#include "TradeHealthDefines.mqh"

//--- Runtime Tracking State of Active Trade
struct TradeTrackingState
{
   ulong    Ticket;
   double   EntryPrice;
   double   CurrentProfitPoints;
   double   CurrentSL;
   double   MaxProfitReachedPoints; // Maximum Favorable Excursion (MFE) in points
   double   MaxLossReachedPoints;   // Maximum Adverse Excursion (MAE) in points
   double   LockedProfitPoints;     // Currently locked profit in points
   double   TrailingDistancePoints; // Current trailing distance in points
   bool     BreakEvenActive;        // Has break-even been activated?
   bool     TrailingActive;         // Has trailing stop been activated?
   int      TradeDurationSec;       // Time since entry in seconds
   double   HealthScore;            // Evaluated Trade Health Score (0-100)
   string   HealthStateStr;         // Health classification string (Excellent, Healthy, Stable, Weakening, Danger, Critical)
   string   HealthNarrative;        // Detailed explanation narrative
   int      PrevHealthState;        // Cache for detecting state changes
   double   RecoveryProbability;    // Evaluated Recovery Probability (0-100)
   string   CurrentExitReason;      // Reason for current trade exit
   
   // V5.2.1 Trade Memory entry metrics
   ENUM_GEV2_SIGNAL_TYPE Direction;
   string   Session;
   int      MarketRegime;
   string   Structure;
   int      Trend;
   double   OpportunityScore;
   double   MomentumScore;

   // V5.3 Quality & Profit optimization metrics
   double   CurrentTP;
   double   EntryQualityScore;

   // V5.5 Exit Stabilization counters
   int      LowRecoveryTickCount;    // Consecutive evaluations with recoveryProb < 40 (exit after 2)
   int      LowTrendReverseCount;    // Consecutive evaluations with trend reversed (exit after 2)
   double   LastAEExitScore;         // Most recent Adaptive Exit exitScore (for diagnostic log)
   double   LastHealthScore;         // Most recent health score cached for diagnostic log
   string   TrendDirectionAtEntry;   // "BUY-aligned" or "SELL-aligned" for diagnostic log
   bool     ScaledOut;               // GITS V5.5: Has trade been partially scaled out?
   int      LockStage;               // GITS V5.6: Current active Multi-Stage Lock (0=None, 1=Stage 1, 2=Stage 2, 3=Stage 3)
};

#endif // GOLDENGINEV2_TRADE_MANAGER_DEFINES_MQH
