//+------------------------------------------------------------------+
//|                                        IMarketContextEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IMARKET_CONTEXT_ENGINE_MQH
#define GOLDENGINEV2_IMARKET_CONTEXT_ENGINE_MQH

#include "MarketContextDefines.mqh"
#include "../../Strategy/IStrategy.mqh"
#include "../../QuantEngine/MarketQuality.mqh"

//+------------------------------------------------------------------+
//| Institutional Market Context Engine Interface                    |
//+------------------------------------------------------------------+
class IMarketContextEngine
{
public:
   virtual ~IMarketContextEngine() {}

   /**
    * @brief Initializes engine with container references to all quant engines and market quality calculator.
    */
   virtual bool Initialize(const QuantEnginesContainer &engines, CMarketQuality* quality) = 0;

   /**
    * @brief Updates the market context states for the current tick/candle.
    */
   virtual void UpdateContext(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Retrieves the compiled market context data.
    */
   virtual MarketContext GetContext() const = 0;
};

#endif // GOLDENGINEV2_IMARKET_CONTEXT_ENGINE_MQH
