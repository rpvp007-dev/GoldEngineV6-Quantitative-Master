//+------------------------------------------------------------------+
//|                                     TradeOptimizationDefines.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_TRADE_OPTIMIZATION_DEFINES_MQH
#define GOLDENGINEV2_TRADE_OPTIMIZATION_DEFINES_MQH

//--- Record representing a single completed position's parameters
struct CompletedTradeRecord
{
   ulong    Ticket;
   datetime EntryTime;
   datetime ExitTime;
   int      DurationSec;
   double   EntryScore;
   double   EntryHealth;
   double   MovementScore;
   double   OpportunityScore;
   double   BuyerIntent;
   double   SellerIntent;
   string   MarketRegime;
   string   TrendPhase;
   double   LiquidityStrength;
   double   VolatilityScore;
   double   RelativeVolume;
   string   Session;
   string   TradeClass;             // e.g. "Scalp", "Probe", "Momentum", "Runner"
   double   Profit;                 // Gross profit in currency
   double   Loss;                   // Gross loss in currency (as positive or negative)
   double   NetProfit;              // Net outcome
   double   MaxFavorableExcursion;  // MFE in points
   double   MaxAdverseExcursion;    // MAE in points
   string   ExitReason;             // e.g. "TP", "SL", "Manual", "Strategy"
};

//--- Performance stats metrics summary structure
struct GITSPerformanceStats
{
   int      TotalTrades;
   int      WinTrades;
   int      LossTrades;
   double   WinRate;                // % (e.g. 65.5)
   double   TotalProfit;
   double   TotalLoss;
   double   NetProfit;
   double   ProfitFactor;
   double   Expectancy;             // Expected payoff in points or currency
   double   SharpeRatio;
   double   AverageHoldTime;        // seconds
   
   // Segmentation metrics
   string   BestSession;
   string   WorstSession;
   string   BestRegime;
   string   WorstRegime;
   string   BestScoreRange;
   string   WorstScoreRange;
   string   BestTradeClass;
   string   WorstTradeClass;
   string   BestExitMethod;
   string   WorstExitMethod;
};

#endif // GOLDENGINEV2_TRADE_OPTIMIZATION_DEFINES_MQH
