//+------------------------------------------------------------------+
//|                                                 ITrendEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_ITREND_ENGINE_MQH
#define GOLDENGINEV2_ITREND_ENGINE_MQH

//+------------------------------------------------------------------+
//| Enums for Trend Engine                                           |
//+------------------------------------------------------------------+
enum ENUM_GEV2_EMA_ALIGNMENT
{
   GEV2_ALIGN_MIXED = 0,
   GEV2_ALIGN_BULLISH = 1,
   GEV2_ALIGN_BEARISH = -1
};

//+------------------------------------------------------------------+
//| Interface for Trend Engine                                       |
//+------------------------------------------------------------------+
class ITrendEngine
{
public:
   virtual ~ITrendEngine() {}
   
   /**
    * @brief Initializes indicator handles for symbol and timeframe.
    */
   virtual bool      InitializeEngine(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Gets current trend direction.
    * @return 1 = Bullish, -1 = Bearish, 0 = Neutral
    */
   virtual int       GetTrendDirection(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Gets strength of the trend.
    * @return Double value e.g. 0.0 to 100.0
    */
   virtual double    GetTrendStrength(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Gets the current alignment of the 4 EMAs.
    */
   virtual ENUM_GEV2_EMA_ALIGNMENT GetEmaAlignment(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Gets the alignment confidence score (0 to 100).
    */
   virtual double    GetEmaAlignmentConfidence(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Gets calculated EMA value.
    */
   virtual double    GetEmaValue(const string symbol, ENUM_TIMEFRAMES tf, int emaPeriod, int shift) = 0;

   /**
    * @brief Gets text description of current Price Position relative to EMAs.
    */
   virtual string    GetPricePositionDesc(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Updates trend state (hook for indicator polling).
    */
   virtual void      Update() = 0;
};

#endif // GOLDENGINEV2_ITREND_ENGINE_MQH
