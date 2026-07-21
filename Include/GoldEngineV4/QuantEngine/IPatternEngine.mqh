//+------------------------------------------------------------------+
//|                                               IPatternEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IPATTERN_ENGINE_MQH
#define GOLDENGINEV2_IPATTERN_ENGINE_MQH

//+------------------------------------------------------------------+
//| Interface for Pattern Recognition Engine                         |
//+------------------------------------------------------------------+
class IPatternEngine
{
public:
   virtual ~IPatternEngine() {}

   /**
    * @brief Identifies candlestick patterns.
    */
   virtual string    DetectCandlePattern(const string symbol, ENUM_TIMEFRAMES tf, int shift) = 0;

   /**
    * @brief Updates patterns database.
    */
   virtual void      Update() = 0;
};

#endif // GOLDENGINEV2_IPATTERN_ENGINE_MQH
