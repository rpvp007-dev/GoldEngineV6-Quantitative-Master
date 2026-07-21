//+------------------------------------------------------------------+
//|                                                   TrendEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_TREND_ENGINE_MQH
#define GOLDENGINEV2_TREND_ENGINE_MQH

#include "ITrendEngine.mqh"

//+------------------------------------------------------------------+
//| Trend Engine Implementation (GITS V2.4)                          |
//+------------------------------------------------------------------+
class CTrendEngine : public ITrendEngine
{
private:
   int               m_handleEma9;
   int               m_handleEma20;
   int               m_handleEma50;
   int               m_handleEma200;
   
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   bool              m_isInitialized;

   /**
    * @brief Helper to fetch historical EMA value.
    */
   double FetchEma(int handle, int shift)
   {
      if(handle == INVALID_HANDLE) return 0.0;
      double buffer[1];
      if(CopyBuffer(handle, 0, shift, 1, buffer) > 0)
      {
         return buffer[0];
      }
      return 0.0;
   }

   /**
    * @brief Helper to fetch close price of shift.
    */
   double FetchClose(int shift)
   {
      double buffer[1];
      if(CopyClose(m_symbol, m_tf, shift, 1, buffer) > 0)
      {
         return buffer[0];
      }
      return 0.0;
   }

public:
   /**
    * @brief Constructor.
    */
   CTrendEngine()
      : m_handleEma9(INVALID_HANDLE),
        m_handleEma20(INVALID_HANDLE),
        m_handleEma50(INVALID_HANDLE),
        m_handleEma200(INVALID_HANDLE),
        m_symbol(""),
        m_tf(PERIOD_CURRENT),
        m_isInitialized(false)
   {}

   /**
    * @brief Destructor. Releases indicator handles.
    */
   ~CTrendEngine()
   {
      if(m_handleEma9 != INVALID_HANDLE) IndicatorRelease(m_handleEma9);
      if(m_handleEma20 != INVALID_HANDLE) IndicatorRelease(m_handleEma20);
      if(m_handleEma50 != INVALID_HANDLE) IndicatorRelease(m_handleEma50);
      if(m_handleEma200 != INVALID_HANDLE) IndicatorRelease(m_handleEma200);
   }

   /**
    * @brief Initialize engine handles.
    */
   virtual bool InitializeEngine(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      m_symbol = symbol;
      m_tf = tf;
      
      m_handleEma9   = iMA(m_symbol, m_tf, 9, 0, MODE_EMA, PRICE_CLOSE);
      m_handleEma20  = iMA(m_symbol, m_tf, 20, 0, MODE_EMA, PRICE_CLOSE);
      m_handleEma50  = iMA(m_symbol, m_tf, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_handleEma200 = iMA(m_symbol, m_tf, 200, 0, MODE_EMA, PRICE_CLOSE);

      if(m_handleEma9 == INVALID_HANDLE || m_handleEma20 == INVALID_HANDLE ||
         m_handleEma50 == INVALID_HANDLE || m_handleEma200 == INVALID_HANDLE)
      {
         m_isInitialized = false;
         return false;
      }

      m_isInitialized = true;
      return true;
   }

   /**
    * @brief Gets current trend direction (shift = 1 for closed bar).
    */
    virtual int GetTrendDirection(const string symbol, ENUM_TIMEFRAMES tf) override
    {
       if(!m_isInitialized) return 0;
       
       double ema20 = FetchEma(m_handleEma20, 1);
       double ema50_1 = FetchEma(m_handleEma50, 1);
       double ema50_2 = FetchEma(m_handleEma50, 2);
       
       double slope = ema50_1 - ema50_2;

       if(ema20 > ema50_1 && slope > 0.0) return 1;  // Bullish
       if(ema20 < ema50_1 && slope < 0.0) return -1; // Bearish
       return 0;                                     // Neutral
    }

   /**
    * @brief Calculates trend strength (0 to 100).
    */
   virtual double GetTrendStrength(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      if(!m_isInitialized) return 0.0;

      int direction = GetTrendDirection(symbol, tf);

      double ema9 = FetchEma(m_handleEma9, 1);
      double ema20 = FetchEma(m_handleEma20, 1);
      double ema50 = FetchEma(m_handleEma50, 1);
      double ema200 = FetchEma(m_handleEma200, 1);
      double close = FetchClose(1);

      if(direction == 0) // Neutral / Sideways
      {
         double conf = GetEmaAlignmentConfidence(symbol, tf);
         return conf * 0.3; // Scale confidence (0 to 100) down to 0 to 30 range
      }

      double score = 0.0;

      if(direction == 1) // Bullish Trend
      {
         if(close > ema50)   score += 20.0;
         if(ema50 > ema200)  score += 30.0;
         if(ema9 > ema20)    score += 25.0;
         if(ema20 > ema50)   score += 25.0;
      }
      else if(direction == -1) // Bearish Trend
      {
         if(close < ema50)   score += 20.0;
         if(ema50 < ema200)  score += 30.0;
         if(ema9 < ema20)    score += 25.0;
         if(ema20 < ema50)   score += 25.0;
      }

      return score;
   }

   /**
    * @brief Evaluates current EMA alignment stack.
    */
   virtual ENUM_GEV2_EMA_ALIGNMENT GetEmaAlignment(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      if(!m_isInitialized) return GEV2_ALIGN_MIXED;

      double ema9 = FetchEma(m_handleEma9, 1);
      double ema20 = FetchEma(m_handleEma20, 1);
      double ema50 = FetchEma(m_handleEma50, 1);
      double ema200 = FetchEma(m_handleEma200, 1);

      if(ema9 > ema20 && ema20 > ema50 && ema50 > ema200)
      {
         return GEV2_ALIGN_BULLISH;
      }
      if(ema9 < ema20 && ema20 < ema50 && ema50 < ema200)
      {
         return GEV2_ALIGN_BEARISH;
      }
      return GEV2_ALIGN_MIXED;
   }

   /**
    * @brief Gets the alignment confidence score (0 to 100).
    */
   virtual double GetEmaAlignmentConfidence(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      if(!m_isInitialized) return 0.0;

      double ema9 = FetchEma(m_handleEma9, 1);
      double ema20 = FetchEma(m_handleEma20, 1);
      double ema50 = FetchEma(m_handleEma50, 1);
      double ema200 = FetchEma(m_handleEma200, 1);

      int bullCount = 0;
      if(ema9 > ema20) bullCount++;
      if(ema20 > ema50) bullCount++;
      if(ema50 > ema200) bullCount++;

      int bearCount = 0;
      if(ema9 < ema20) bearCount++;
      if(ema20 < ema50) bearCount++;
      if(ema50 < ema200) bearCount++;

      int maxCount = (bullCount > bearCount) ? bullCount : bearCount;
      return (maxCount / 3.0) * 100.0;
   }

   /**
    * @brief Gets calculated EMA value.
    */
   virtual double GetEmaValue(const string symbol, ENUM_TIMEFRAMES tf, int emaPeriod, int shift) override
   {
      if(!m_isInitialized) return 0.0;
      
      int targetHandle = INVALID_HANDLE;
      switch(emaPeriod)
      {
         case 9:   targetHandle = m_handleEma9; break;
         case 20:  targetHandle = m_handleEma20; break;
         case 50:  targetHandle = m_handleEma50; break;
         case 200: targetHandle = m_handleEma200; break;
         default:  return 0.0;
      }
      return FetchEma(targetHandle, shift);
   }

   /**
    * @brief Formulates descriptive position string.
    */
   virtual string GetPricePositionDesc(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      if(!m_isInitialized) return "Uninitialized";

      double ema9 = FetchEma(m_handleEma9, 1);
      double ema20 = FetchEma(m_handleEma20, 1);
      double ema50 = FetchEma(m_handleEma50, 1);
      double ema200 = FetchEma(m_handleEma200, 1);
      double close = FetchClose(1);

      if(close > ema9 && ema9 > ema20 && ema20 > ema50 && ema50 > ema200)
         return "Price above all EMAs (Strong Trend)";
      if(close < ema200 && ema200 < ema50)
         return "Price below all EMAs (Strong Downtrend)";
      if(close > ema20 && close < ema9)
         return "Price inside EMA9-EMA20 compression zone";
      if(close > ema50 && close < ema20)
         return "Price retreading into EMA20-EMA50 zone";
      
      return "Price consolidating inside EMA boundaries";
   }

   virtual void Update() override {}
};

#endif // GOLDENGINEV2_TREND_ENGINE_MQH
