//+------------------------------------------------------------------+
//|                                         IOptimizationDatabase.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IOPTIMIZATION_DATABASE_MQH
#define GOLDENGINEV2_IOPTIMIZATION_DATABASE_MQH

//+------------------------------------------------------------------+
//| Interface for Optimization Database component                     |
//+------------------------------------------------------------------+
class IOptimizationDatabase
{
public:
   virtual ~IOptimizationDatabase() {}

   virtual void      LogOptimizationPass(int passId, double profit, double drawdown) = 0;
   virtual bool      RetrieveBestParameters(int &outBestParams[]) = 0;
};

#endif // GOLDENGINEV2_IOPTIMIZATION_DATABASE_MQH
