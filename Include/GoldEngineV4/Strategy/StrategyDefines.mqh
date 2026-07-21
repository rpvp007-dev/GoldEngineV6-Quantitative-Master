//+------------------------------------------------------------------+
//|                                              StrategyDefines.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_STRATEGY_DEFINES_MQH
#define GOLDENGINEV2_STRATEGY_DEFINES_MQH

#include "../Core/CoreDefines.mqh"

//+------------------------------------------------------------------+
//| Strategy Evaluation Output Response Structure                    |
//+------------------------------------------------------------------+
struct StrategyResponse
{
   ENUM_GEV2_SIGNAL_TYPE Signal;       // BUY, SELL, NONE
   double            EntryPrice;       // Proposed entry level
   double            StopLoss;         // Proposed stop loss level
   double            TakeProfit;       // Proposed take profit level
   double            Confidence;       // Strategy confidence score (0.0 to 1.0)
   double            StrategyScore;    // Strategy composite score (0.0 to 100.0)
   string            TradeGrade;       // A+, A, B, C, D grade based on score
   string            Reason;           // Reason for the signal or rejection
   string            StrategyName;     // Name of strategy generating response
   
   // V5.2.0 Unified Decision Engine scores
   double            RawStrategyScore;
   double            CompositeScore;
   double            PenaltyScore;
};

#endif // GOLDENGINEV2_STRATEGY_DEFINES_MQH
