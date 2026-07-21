//+------------------------------------------------------------------+
//|                                             IStrategyRanking.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_ISTRATEGY_RANKING_MQH
#define GOLDENGINEV2_ISTRATEGY_RANKING_MQH

//+------------------------------------------------------------------+
//| Interface for Strategy Ranking component                         |
//+------------------------------------------------------------------+
class IStrategyRanking
{
public:
   virtual ~IStrategyRanking() {}

   virtual void      EvaluateRankings() = 0;
   virtual double    GetStrategyScore(const string strategyName) = 0;
   virtual int       GetStrategyPriority(const string strategyName) = 0;
};

#endif // GOLDENGINEV2_ISTRATEGY_RANKING_MQH
