//+------------------------------------------------------------------+
//|                                               IMarketQuality.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IMARKET_QUALITY_MQH
#define GOLDENGINEV2_IMARKET_QUALITY_MQH

#include "../Core/Config.mqh"
#include "ITrendEngine.mqh"
#include "IMomentumEngine.mqh"
#include "IVolatilityEngine.mqh"
#include "IVolumeEngine.mqh"
#include "IMarketStructureEngine.mqh"
#include "ILiquidityEngine.mqh"
#include "ISessionEngine.mqh"

//+------------------------------------------------------------------+
//| Interface for Market Quality Score composite calculator           |
//+------------------------------------------------------------------+
class IMarketQuality
{
public:
   virtual ~IMarketQuality() {}

   /**
    * @brief Links configurations and dependent Quant Engine instances.
    */
   virtual bool Initialize(
      CConfig*                config,
      ITrendEngine*           trend,
      IMomentumEngine*        momentum,
      IVolatilityEngine*      volatility,
      IVolumeEngine*          volume,
      IMarketStructureEngine* structure,
      ILiquidityEngine*       liquidity,
      ISessionEngine*         session) = 0;

   /**
    * @brief Computes the weighted Market Quality Score (0 to 100).
    */
   virtual double    CalculateMarketQualityScore() = 0;

   /**
    * @brief Interpets score (Poor, Weak, Average, Good, Excellent).
    */
   virtual string    GetMarketQualityInterpretation() = 0;
};

#endif // GOLDENGINEV2_IMARKET_QUALITY_MQH
