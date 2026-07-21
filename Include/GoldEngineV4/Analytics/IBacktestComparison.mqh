//+------------------------------------------------------------------+
//|                                           IBacktestComparison.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IBACKTEST_COMPARISON_MQH
#define GOLDENGINEV2_IBACKTEST_COMPARISON_MQH

//+------------------------------------------------------------------+
//| Interface for Backtest Comparison component                       |
//+------------------------------------------------------------------+
class IBacktestComparison
{
public:
   virtual ~IBacktestComparison() {}

   virtual void      CompareLiveVsBacktest() = 0;
   virtual double    GetDeviationScore() = 0;
   virtual bool      IsModelDrifting() = 0;
};

#endif // GOLDENGINEV2_IBACKTEST_COMPARISON_MQH
