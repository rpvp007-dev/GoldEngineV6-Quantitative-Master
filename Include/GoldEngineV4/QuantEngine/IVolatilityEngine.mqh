//+------------------------------------------------------------------+
//|                                           IVolatilityEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IVOLATILITY_ENGINE_MQH
#define GOLDENGINEV2_IVOLATILITY_ENGINE_MQH

//+------------------------------------------------------------------+
//| Interface for Volatility Engine                                  |
//+------------------------------------------------------------------+
class IVolatilityEngine
{
public:
   virtual ~IVolatilityEngine() {}

   /**
    * @brief Initializes indicator handles for symbol and timeframe.
    */
   virtual bool      InitializeEngine(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Gets ATR indicator value.
    */
   virtual double    GetATR(const string symbol, ENUM_TIMEFRAMES tf, int period, int shift) = 0;

   /**
    * @brief Calculates ATR percentile over the last 100 bars.
    */
   virtual double    GetATRPercentile(const string symbol, ENUM_TIMEFRAMES tf, int period) = 0;

   /**
    * @brief Gets Average Candle Size (High - Low) over a specified period.
    */
   virtual double    GetAverageCandleSize(const string symbol, ENUM_TIMEFRAMES tf, int period) = 0;

   /**
    * @brief Gets the Candle Expansion Ratio (Current closed range / Average range).
    */
   virtual double    GetCandleExpansionRatio(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Identifies Volatility Regime (Low, Normal, High, Extreme).
    */
   virtual string    GetVolatilityRegime(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Calculates a normalized volatility score (0 to 100).
    */
   virtual double    GetVolatilityScore(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Gets Bollinger Bands boundaries.
    */
   virtual bool      GetBollingerBands(const string symbol, ENUM_TIMEFRAMES tf, int period, double deviation, int shift, double &outUpper, double &outMiddle, double &outLower) = 0;

   /**
    * @brief Updates volatility calculations.
    */
   virtual void      Update() = 0;
};

#endif // GOLDENGINEV2_IVOLATILITY_ENGINE_MQH
