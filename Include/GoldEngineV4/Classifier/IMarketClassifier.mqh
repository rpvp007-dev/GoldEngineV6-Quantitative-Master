//+------------------------------------------------------------------+
//|                                           IMarketClassifier.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IMARKET_CLASSIFIER_MQH
#define GOLDENGINEV2_IMARKET_CLASSIFIER_MQH

#include "MarketClassifierDefines.mqh"
#include "../QuantEngine/ITrendEngine.mqh"
#include "../QuantEngine/IMomentumEngine.mqh"
#include "../QuantEngine/IVolatilityEngine.mqh"
#include "../QuantEngine/IVolumeEngine.mqh"
#include "../QuantEngine/IVwapEngine.mqh"
#include "../QuantEngine/ILiquidityEngine.mqh"
#include "../QuantEngine/IPatternEngine.mqh"
#include "../QuantEngine/ISessionEngine.mqh"
#include "../QuantEngine/IMarketStructureEngine.mqh"

//+------------------------------------------------------------------+
//| Interface for Market Classifier                                  |
//+------------------------------------------------------------------+
class IMarketClassifier
{
public:
   virtual ~IMarketClassifier() {}

   /**
    * @brief Initializes the classifier with the dependencies on the 9 Quant Engines.
    */
   virtual bool      Initialize(
                        ITrendEngine* trend,
                        IMomentumEngine* momentum,
                        IVolatilityEngine* volatility,
                        IVolumeEngine* volume,
                        IVwapEngine* vwap,
                        ILiquidityEngine* liquidity,
                        IPatternEngine* pattern,
                        ISessionEngine* session,
                        IMarketStructureEngine* marketStructure
                     ) = 0;

   /**
    * @brief Processes information from all Quant Engines and returns the normalized market state.
    */
   virtual MarketState GetMarketState(const string symbol) = 0;

   /**
    * @brief Triggers classification processing.
    */
   virtual void      Update(const string symbol) = 0;
};

#endif // GOLDENGINEV2_IMARKET_CLASSIFIER_MQH
