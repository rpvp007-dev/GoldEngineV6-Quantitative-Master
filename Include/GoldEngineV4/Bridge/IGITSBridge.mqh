//+------------------------------------------------------------------+
//|                                                   IGITSBridge.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_I_GITS_BRIDGE_MQH
#define GOLDENGINEV2_I_GITS_BRIDGE_MQH

#include "BridgeDefines.mqh"
#include "../Core/CoreDefines.mqh"
#include "../Analytics/ITradeStatistics.mqh"
#include "../Analytics/IPerformanceTracker.mqh"
#include "../Risk/IRiskGuardian.mqh"

// Forward declaration of QuantEnginesContainer
struct QuantEnginesContainer;

class IGITSBridge
{
public:
   virtual bool Initialize(string stateFileName, string configFileName) = 0;
   virtual void RegisterStrategyReference(IStrategy* strategy) = 0;
   virtual void ExportState(const QuantEnginesContainer &container,
                            ITradeStatistics* stats,
                            IPerformanceTracker* tracker,
                            IRiskGuardian* risk,
                            double currentSpreadPoints) = 0;
   virtual bool CheckAndApplyConfig(GITSBridgeConfig &outConfig) = 0;
};

#endif
