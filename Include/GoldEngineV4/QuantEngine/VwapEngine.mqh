//+------------------------------------------------------------------+
//|                                                   VwapEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_VWAP_ENGINE_MQH
#define GOLDENGINEV2_VWAP_ENGINE_MQH

#include "IVwapEngine.mqh"

//+------------------------------------------------------------------+
//| VWAP Engine Concrete Implementation (Skeleton)                   |
//+------------------------------------------------------------------+
class CVwapEngine : public IVwapEngine
{
public:
   CVwapEngine() {}
   ~CVwapEngine() {}

   virtual double    GetVWAP(const string symbol, ENUM_TIMEFRAMES tf, int shift) override { return 0.0; }
   virtual void      Update() override {}
};

#endif // GOLDENGINEV2_VWAP_ENGINE_MQH
