//+------------------------------------------------------------------+
//|                                                ITradeManager.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_I_TRADE_MANAGER_MQH
#define GOLDENGINEV2_I_TRADE_MANAGER_MQH

#include "TradeManagerDefines.mqh"

// Forward declarations
struct QuantEnginesContainer;
class CConfig;
class CTradeMemory;

//+------------------------------------------------------------------+
//| Interface for GITS Trade Manager V1                             |
//+------------------------------------------------------------------+
class ITradeManager
{
public:
   virtual ~ITradeManager() {}

   virtual void SetTradeMemory(CTradeMemory* memory) = 0;

   /**
    * @brief Initializes the trade manager with engine references and configuration settings.
    */
   virtual bool Initialize(const QuantEnginesContainer &engines, CConfig* config) = 0;

   /**
    * @brief Processes all active positions on the symbol, applying BE, Trailing, and Profit Lock.
    */
   virtual void ManageActiveTrades(const string symbol) = 0;

   /**
    * @brief Gets total number of trades currently tracked.
    */
   virtual int GetActiveTrackingCount() const = 0;

   /**
    * @brief Retrieves the tracking state of a trade at a specific index.
    */
   virtual bool GetTrackingState(int index, TradeTrackingState &outState) const = 0;
};

#endif // GOLDENGINEV2_I_TRADE_MANAGER_MQH
