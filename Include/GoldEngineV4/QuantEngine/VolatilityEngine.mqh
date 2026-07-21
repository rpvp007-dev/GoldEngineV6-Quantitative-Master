//+------------------------------------------------------------------+
//|                                             VolatilityEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_VOLATILITY_ENGINE_MQH
#define GOLDENGINEV2_VOLATILITY_ENGINE_MQH

#include "IVolatilityEngine.mqh"

//+------------------------------------------------------------------+
//| Volatility Engine Implementation (GITS V2.4)                     |
//+------------------------------------------------------------------+
class CVolatilityEngine : public IVolatilityEngine
{
private:
   int               m_handleAtr;
   int               m_handleBands;
   
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   bool              m_isInitialized;

public:
   /**
    * @brief Constructor.
    */
   CVolatilityEngine()
      : m_handleAtr(INVALID_HANDLE),
        m_handleBands(INVALID_HANDLE),
        m_symbol(""),
        m_tf(PERIOD_CURRENT),
        m_isInitialized(false)
   {}

   /**
    * @brief Destructor.
    */
   ~CVolatilityEngine()
   {
      if(m_handleAtr != INVALID_HANDLE) IndicatorRelease(m_handleAtr);
      if(m_handleBands != INVALID_HANDLE) IndicatorRelease(m_handleBands);
   }

   /**
    * @brief Initialize indicator handles.
    */
   virtual bool InitializeEngine(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      m_symbol = symbol;
      m_tf = tf;
      
      m_handleAtr = iATR(m_symbol, m_tf, 14);
      m_handleBands = iBands(m_symbol, m_tf, 20, 0, 2.0, PRICE_CLOSE);

      if(m_handleAtr == INVALID_HANDLE || m_handleBands == INVALID_HANDLE)
      {
         m_isInitialized = false;
         return false;
      }

      m_isInitialized = true;
      return true;
   }

   /**
    * @brief Gets ATR indicator value.
    */
   virtual double GetATR(const string symbol, ENUM_TIMEFRAMES tf, int period, int shift) override
   {
      if(!m_isInitialized) return 0.0;
      
      double buffer[1];
      if(CopyBuffer(m_handleAtr, 0, shift, 1, buffer) > 0)
      {
         return buffer[0];
      }
      return 0.0;
   }

   /**
    * @brief Calculates ATR percentile over the last 100 bars.
    */
   virtual double GetATRPercentile(const string symbol, ENUM_TIMEFRAMES tf, int period) override
   {
      if(!m_isInitialized) return 50.0;

      double atrValues[];
      int copied = CopyBuffer(m_handleAtr, 0, 1, 100, atrValues);
      if(copied <= 0) return 50.0;

      double currentAtr = atrValues[copied - 1]; // Latest ATR (shift=1)
      int lessCount = 0;
      
      for(int i = 0; i < copied; i++)
      {
         if(atrValues[i] <= currentAtr)
         {
            lessCount++;
         }
      }
      return (lessCount / (double)copied) * 100.0;
   }

   /**
    * @brief Calculates Average Candle Size over a period.
    */
   virtual double GetAverageCandleSize(const string symbol, ENUM_TIMEFRAMES tf, int period) override
   {
      MqlRates rates[];
      int copied = CopyRates(m_symbol, m_tf, 1, period, rates);
      if(copied <= 0) return 0.0;

      double totalSize = 0.0;
      for(int i = 0; i < copied; i++)
      {
         totalSize += (rates[i].high - rates[i].low);
      }
      return totalSize / copied;
   }

   /**
    * @brief Gets the Candle Expansion Ratio.
    */
   virtual double GetCandleExpansionRatio(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      double currentRange = 0.0;
      MqlRates rates[];
      if(CopyRates(m_symbol, m_tf, 1, 1, rates) > 0)
      {
         currentRange = (rates[0].high - rates[0].low);
      }
      
      double avgRange = GetAverageCandleSize(symbol, tf, 14);
      if(avgRange <= 0.0) return 1.0;
      return currentRange / avgRange;
   }

   /**
    * @brief Identifies Volatility Regime based on ATR percentile.
    */
   virtual string GetVolatilityRegime(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      double percentile = GetATRPercentile(symbol, tf, 14);
      if(percentile < 25.0) return "Low";
      if(percentile < 75.0) return "Normal";
      if(percentile < 90.0) return "High";
      return "Extreme";
   }

   /**
    * @brief Computes a normalized Volatility Score (0 to 100).
    * Maps the ATR percentile directly.
    */
   virtual double GetVolatilityScore(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      return GetATRPercentile(symbol, tf, 14);
   }

   /**
    * @brief Gets Bollinger Bands boundaries.
    */
   virtual bool GetBollingerBands(const string symbol, ENUM_TIMEFRAMES tf, int period, double deviation, int shift, double &outUpper, double &outMiddle, double &outLower) override
   {
      if(!m_isInitialized) return false;

      double upper[1], middle[1], lower[1];
      if(CopyBuffer(m_handleBands, UPPER_BAND, shift, 1, upper) > 0 &&
         CopyBuffer(m_handleBands, BASE_LINE, shift, 1, middle) > 0 &&
         CopyBuffer(m_handleBands, LOWER_BAND, shift, 1, lower) > 0)
      {
         outUpper = upper[0];
         outMiddle = middle[0];
         outLower = lower[0];
         return true;
      }
      return false;
   }

   virtual void Update() override {}
};

#endif // GOLDENGINEV2_VOLATILITY_ENGINE_MQH
