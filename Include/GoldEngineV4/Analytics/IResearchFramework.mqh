//+------------------------------------------------------------------+
//|                                           IResearchFramework.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IRESEARCH_FRAMEWORK_MQH
#define GOLDENGINEV2_IRESEARCH_FRAMEWORK_MQH

#include "../Strategy/IStrategy.mqh"

//+------------------------------------------------------------------+
//| Trade Research Record Structure                                  |
//+------------------------------------------------------------------+
struct TradeResearchRecord
{
   ulong    TradeID;
   datetime EntryTime;
   datetime ExitTime;
   double   HoldingTime;       // in seconds
   string   ExecutionMode;     // Probe, Scalp, Momentum, Runner
   double   OpportunityScore;
   double   MovementScore;
   string   MarketIntent;
   double   TradeConfidence;
   double   ExpectedMove;      // in points
   double   ActualMove;        // in points
   double   MFE;               // Maximum Favourable Excursion (points)
   double   MAE;               // Maximum Adverse Excursion (points)
   double   EntryQuality;
   double   ExitQuality;
   double   RiskRewardPlanned; // expected R:R ratio
   double   RiskRewardAchieved;// achieved R:R ratio
   double   Profit;
   double   Loss;
   string   ReasonForExit;     // exit comment / reason
   double   EntryScore;        // GITS-X Entry Score
   string   EntryReason;       // Reason for Entry signal
   
   // Grouping Attributes
   string   MarketContext;     // ranging, trending, volatile, etc.
   string   Session;           // London, New York, Tokyo, overlaps, etc.
   string   TrendState;        // Bullish, Bearish, Neutral
   string   MovementState;     // Price velocity regime
   int      OpportunityClass;  // 1, 2, 3, etc.
};

//+------------------------------------------------------------------+
//| Active Trade Excursion Tracking Structure                        |
//+------------------------------------------------------------------+
struct ActiveTradeResearch
{
   ulong    Ticket;
   datetime EntryTime;
   double   EntryPrice;
   int      Direction;         // 1=Buy, -1=Sell
   double   MFE;               // Maximum Favourable Excursion (points)
   double   MAE;               // Maximum Adverse Excursion (points)
   
   // Cached snapshot of parameters at entry
   double   OpportunityScore;
   double   MovementScore;
   string   MarketIntent;
   double   TradeConfidence;
   double   ExpectedMove;
   double   EntryQuality;
   double   RiskRewardPlanned;
   string   ExecutionMode;
   double   EntryScore;
   string   EntryReason;
   
   string   MarketContext;
   string   Session;
   string   TrendState;
   string   MovementState;
   int      OpportunityClass;
};

//+------------------------------------------------------------------+
//| Abstract Research Framework Interface                             |
//+------------------------------------------------------------------+
class IResearchFramework
{
public:
   virtual ~IResearchFramework() {}

   /**
    * @brief Records snapshot metrics at the moment of entry.
    */
   virtual void OnTradeOpen(ulong ticket, const StrategyResponse &signal, const QuantEnginesContainer &container) = 0;

   /**
    * @brief Tracks tick-by-tick excursions (MFE/MAE) for active trades.
    */
   virtual void UpdateOnTick(const string symbol) = 0;

   /**
    * @brief Checks and records details for recently closed trades.
    */
   virtual void CheckClosedTrades(const string symbol, const QuantEnginesContainer &container) = 0;

   /**
    * @brief Processes grouped metrics and prints analytical reports.
    */
   virtual void AnalyzeAndReport() = 0;
};

#endif // GOLDENGINEV2_IRESEARCH_FRAMEWORK_MQH
