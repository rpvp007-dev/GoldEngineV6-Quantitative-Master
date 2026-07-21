//+------------------------------------------------------------------+
//|                                     IMarketStructureEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IMARKET_STRUCTURE_ENGINE_MQH
#define GOLDENGINEV2_IMARKET_STRUCTURE_ENGINE_MQH

//+------------------------------------------------------------------+
//| Interface for Market Structure Engine                            |
//+------------------------------------------------------------------+
class IMarketStructureEngine
{
public:
   virtual ~IMarketStructureEngine() {}

   /**
    * @brief Initializes indicators/settings for symbol and timeframe.
    */
   virtual bool      InitializeEngine(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Gets the price of the last detected Swing High.
    */
   virtual double    GetLastSwingHighPrice() = 0;

   /**
    * @brief Gets the price of the last detected Swing Low.
    */
   virtual double    GetLastSwingLowPrice() = 0;

   /**
    * @brief Gets the description of current structure (HH, HL, LH, LL).
    */
   virtual string    GetStructureDesc() = 0;

   /**
    * @brief Gets the current structural state (Bullish, Bearish, Range, Transition).
    */
   virtual string    GetStructureState() = 0;

   /**
    * @brief Gets historical support levels.
    */
   virtual double    GetSupportLevel(const string symbol, ENUM_TIMEFRAMES tf, int index) = 0;

   /**
    * @brief Gets historical resistance levels.
    */
   virtual double    GetResistanceLevel(const string symbol, ENUM_TIMEFRAMES tf, int index) = 0;

   /**
    * @brief Detects Break of Structure (BOS).
    */
   virtual bool      DetectBOS(const string symbol, ENUM_TIMEFRAMES tf, string &outType) = 0;

   /**
    * @brief Detects Change of Character (CHoCH).
    */
   virtual bool      DetectCHoCH(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Identifies Equal Highs within a threshold.
    */
   virtual bool      HasEqualHighs(int pointsThreshold) = 0;

   /**
    * @brief Identifies Equal Lows within a threshold.
    */
   virtual bool      HasEqualLows(int pointsThreshold) = 0;

   /**
    * @brief Audits entry against Market Structure Support/Resistance & Spike Violence.
    */
   virtual bool      IsValidInstitutionalEntry(const string symbol, int signalType, double ask, double bid, string &outReason) = 0;

   /**
    * @brief Updates market structures.
    */
   virtual void      Update() = 0;
};

#endif // GOLDENGINEV2_IMARKET_STRUCTURE_ENGINE_MQH
