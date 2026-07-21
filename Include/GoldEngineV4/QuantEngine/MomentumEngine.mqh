//+------------------------------------------------------------------+
//|                                               MomentumEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_MOMENTUM_ENGINE_MQH
#define GOLDENGINEV2_MOMENTUM_ENGINE_MQH

#include "IMomentumEngine.mqh"

//+------------------------------------------------------------------+
//| Momentum Engine Implementation (GITS V2.4)                       |
//+------------------------------------------------------------------+
class CMomentumEngine : public IMomentumEngine
{
private:
   int               m_handleRsi;
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   int               m_rsiPeriod;
   bool              m_isInitialized;

   /**
    * @brief Helper to fetch RSI value.
    */
   double FetchRsi(int shift)
   {
      if(m_handleRsi == INVALID_HANDLE) return 50.0;
      double buffer[1];
      if(CopyBuffer(m_handleRsi, 0, shift, 1, buffer) > 0)
      {
         return buffer[0];
      }
      return 50.0;
   }

   /**
    * @brief Helper to fetch historical close price.
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
   CMomentumEngine()
      : m_handleRsi(INVALID_HANDLE),
        m_symbol(""),
        m_tf(PERIOD_CURRENT),
        m_rsiPeriod(14),
        m_isInitialized(false)
   {}

   /**
    * @brief Destructor.
    */
   ~CMomentumEngine()
   {
      if(m_handleRsi != INVALID_HANDLE) IndicatorRelease(m_handleRsi);
   }

   /**
    * @brief Initializes indicators.
    */
   virtual bool InitializeEngine(const string symbol, ENUM_TIMEFRAMES tf, int rsiPeriod) override
   {
      m_symbol = symbol;
      m_tf = tf;
      m_rsiPeriod = rsiPeriod;

      m_handleRsi = iRSI(m_symbol, m_tf, m_rsiPeriod, PRICE_CLOSE);
      if(m_handleRsi == INVALID_HANDLE)
      {
         m_isInitialized = false;
         return false;
      }

      m_isInitialized = true;
      return true;
   }

   /**
    * @brief Gets current or historical RSI value.
    */
   virtual double GetRSIValue(int shift) override
   {
      if(!m_isInitialized) return 50.0;
      return FetchRsi(shift);
   }

   /**
    * @brief Gets Rate of Change (ROC).
    */
   virtual double GetROCValue(int shift) override
   {
      if(!m_isInitialized) return 0.0;

      double currentClose = FetchClose(shift);
      double pastClose = FetchClose(shift + m_rsiPeriod);

      if(pastClose <= 0.0) return 0.0;
      return ((currentClose - pastClose) / pastClose) * 100.0;
   }

   /**
    * @brief Gets normalized Momentum Strength (0 to 100).
    * Measures deviation of RSI from the 50 neutral line.
    */
   virtual double GetMomentumStrength() override
   {
      if(!m_isInitialized) return 0.0;
      double rsi = FetchRsi(1);
      return MathAbs(rsi - 50.0) * 2.0;
   }

   /**
    * @brief Gets Momentum Acceleration (ROC change rate).
    */
   virtual double GetMomentumAcceleration() override
   {
      if(!m_isInitialized) return 0.0;
      double roc1 = GetROCValue(1);
      double roc2 = GetROCValue(2);
      return roc1 - roc2;
   }

   /**
    * @brief Gets description of momentum direction.
    */
   virtual string GetMomentumDirectionDesc() override
   {
      if(!m_isInitialized) return "Flat";
      double roc1 = GetROCValue(1);
      double roc2 = GetROCValue(2);

      if(roc1 > roc2 + 0.01) return "Increasing";
      if(roc1 < roc2 - 0.01) return "Decreasing";
      return "Flat";
   }

   /**
    * @brief Gets Momentum Score (0 to 100). Directly maps RSI.
    */
   virtual double GetMomentumScore() override
   {
      if(!m_isInitialized) return 50.0;
      return FetchRsi(1);
   }

   virtual void Update() override {}
};

#endif // GOLDENGINEV2_MOMENTUM_ENGINE_MQH
