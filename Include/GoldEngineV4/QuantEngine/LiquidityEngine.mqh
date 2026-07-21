//+------------------------------------------------------------------+
//|                                                 LiquidityEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_LIQUIDITY_ENGINE_MQH
#define GOLDENGINEV2_LIQUIDITY_ENGINE_MQH

#include "ILiquidityEngine.mqh"

//+------------------------------------------------------------------+
//| Liquidity Engine Concrete Implementation (GITS V2.4)             |
//+------------------------------------------------------------------+
class CLiquidityEngine : public ILiquidityEngine
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   bool              m_isInitialized;

   double            m_pdh;
   double            m_pdl;
   
   // Session ranges caches (for the current day)
   double            m_asiaHigh;
   double            m_asiaLow;
   double            m_londonHigh;
   double            m_londonLow;
   double            m_nyHigh;
   double            m_nyLow;

   /**
    * @brief Updates daily boundaries (PDH and PDL).
    */
   void UpdateDailyLevels()
   {
      MqlRates dailyRates[];
      int copied = CopyRates(m_symbol, PERIOD_D1, 1, 1, dailyRates);
      if(copied > 0)
      {
         m_pdh = dailyRates[0].high;
         m_pdl = dailyRates[0].low;
      }
   }

   /**
    * @brief Updates active session ranges from M5 rates.
    */
   void UpdateSessionLevels()
   {
      m_asiaHigh   = 0.0; m_asiaLow   = 999999.0;
      m_londonHigh = 0.0; m_londonLow = 999999.0;
      m_nyHigh     = 0.0; m_nyLow     = 999999.0;

      MqlRates rates[];
      // Copy today's rates for session calculation
      int copied = CopyRates(m_symbol, _Period, 0, 300, rates);
      if(copied <= 0) return;

      MqlDateTime dt;
      for(int i = 0; i < copied; i++)
      {
         TimeToStruct(rates[i].time, dt);
         int hour = dt.hour;

         // Asia hours (00:00 - 09:00 broker server hours)
         if(hour >= 0 && hour < 9)
         {
            if(rates[i].high > m_asiaHigh) m_asiaHigh = rates[i].high;
            if(rates[i].low < m_asiaLow)   m_asiaLow  = rates[i].low;
         }
         // London hours (08:00 - 17:00 broker server hours)
         if(hour >= 8 && hour < 17)
         {
            if(rates[i].high > m_londonHigh) m_londonHigh = rates[i].high;
            if(rates[i].low < m_londonLow)   m_londonLow  = rates[i].low;
         }
         // NY hours (13:00 - 22:00 broker server hours)
         if(hour >= 13 && hour < 22)
         {
            if(rates[i].high > m_nyHigh) m_nyHigh = rates[i].high;
            if(rates[i].low < m_nyLow)   m_nyLow  = rates[i].low;
         }
      }
      
      // Clean up low defaults if no hours found
      if(m_asiaLow == 999999.0) m_asiaLow = 0.0;
      if(m_londonLow == 999999.0) m_londonLow = 0.0;
      if(m_nyLow == 999999.0) m_nyLow = 0.0;
   }

public:
   /**
    * @brief Constructor.
    */
   CLiquidityEngine()
      : m_symbol(""),
        m_tf(PERIOD_CURRENT),
        m_isInitialized(false),
        m_pdh(0.0),
        m_pdl(0.0),
        m_asiaHigh(0.0), m_asiaLow(0.0),
        m_londonHigh(0.0), m_londonLow(0.0),
        m_nyHigh(0.0), m_nyLow(0.0)
   {}

   /**
    * @brief Destructor.
    */
   ~CLiquidityEngine() {}

   /**
    * @brief Initializes Liquidity Engine.
    */
   virtual bool InitializeEngine(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      m_symbol = symbol;
      m_tf = tf;
      m_isInitialized = true;
      
      Update();
      return true;
   }

   virtual bool IsLiquidityPresent() override
   {
      return (m_pdh > 0.0 && m_pdl > 0.0);
   }

   /**
    * @brief Determines liquidity direction bias based on proximity.
    */
   virtual string GetLiquidityDirection() override
   {
      if(!IsLiquidityPresent()) return "None";

      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double distToHigh = MathAbs(m_pdh - bid);
      double distToLow = MathAbs(m_pdl - bid);

      double range = m_pdh - m_pdl;
      if(range <= 0.0) return "None";

      // If price is within 20% of PDH, classify as Buy Side.
      if(distToHigh < range * 0.20) return "Buy Side";
      if(distToLow < range * 0.20) return "Sell Side";
      
      return "Both";
   }

   /**
    * @brief Calculates pool clustering strength based on proximity.
    */
   virtual double GetLiquidityStrength() override
   {
      if(!IsLiquidityPresent()) return 0.0;

      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double distToHigh = MathAbs(m_pdh - bid);
      double distToLow = MathAbs(m_pdl - bid);

      double range = m_pdh - m_pdl;
      if(range <= 0.0) return 0.0;

      double minDist = (distToHigh < distToLow) ? distToHigh : distToLow;
      double ratio = minDist / range; // 0.0 (directly on level) to 0.5 (exact middle)

      // Inverse map ratio to 0-100 score
      double score = (0.5 - ratio) * 200.0;
      if(score < 0.0) score = 0.0;
      if(score > 100.0) score = 100.0;
      return score;
   }

   virtual bool GetPDH_PDL(double &outPDH, double &outPDL) override
   {
      outPDH = m_pdh;
      outPDL = m_pdl;
      return (m_pdh > 0.0 && m_pdl > 0.0);
   }

   virtual bool GetSessionHighLow(const string sessionName, double &outHigh, double &outLow) override
   {
      string name = sessionName;
      StringToUpper(name);

      if(name == "ASIA" || name == "TOKYO")
      {
         outHigh = m_asiaHigh; outLow = m_asiaLow;
         return (m_asiaHigh > 0.0);
      }
      if(name == "LONDON" || name == "EUROPE")
      {
         outHigh = m_londonHigh; outLow = m_londonLow;
         return (m_londonHigh > 0.0);
      }
      if(name == "NEWYORK" || name == "NY" || name == "US")
      {
         outHigh = m_nyHigh; outLow = m_nyLow;
         return (m_nyHigh > 0.0);
      }
      return false;
   }

   /**
    * @brief Checks if a wick sweep happened on the last closed bar.
    */
   virtual bool IsLiquiditySweep(bool &outBuySide, bool &outSellSide) override
   {
      outBuySide = false;
      outSellSide = false;

      if(!IsLiquidityPresent()) return false;

      MqlRates rates[];
      if(CopyRates(m_symbol, m_tf, 1, 1, rates) <= 0) return false;

      double high = rates[0].high;
      double low = rates[0].low;
      double close = rates[0].close;

      // Buy side sweep: High broke PDH but close stayed below PDH
      if(high > m_pdh && close < m_pdh)
      {
         outBuySide = true;
      }
      // Sell side sweep: Low broke PDL but close stayed above PDL
      if(low < m_pdl && close > m_pdl)
      {
         outSellSide = true;
      }

      return (outBuySide || outSellSide);
   }

   /**
    * @brief Checks if a stop hunt sweep (sweep on volume spike) is active.
    */
   virtual bool IsStopHuntActive() override
   {
      bool buySweep = false, sellSweep = false;
      if(IsLiquiditySweep(buySweep, sellSweep))
      {
         // Verify volume spike on the closed sweep candle
         MqlRates rates[];
         if(CopyRates(m_symbol, m_tf, 1, 21, rates) > 0)
         {
            double sum = 0.0;
            for(int i = 0; i < 20; i++)
            {
               sum += (double)rates[i].tick_volume;
            }
            double avgVolume = sum / 20.0;
            double sweepVolume = (double)rates[20].tick_volume; // latest closed bar volume
 
            if(avgVolume > 0.0 && sweepVolume >= avgVolume * 1.5)
            {
               return true;
            }
         }
      }
      return false;
   }

   virtual int GetLiquidityPools(const string symbol, double &outPrices[], double &outSizes[]) override
   {
      ArrayResize(outPrices, 2);
      ArrayResize(outSizes, 2);
      outPrices[0] = m_pdh; outSizes[0] = 100.0;
      outPrices[1] = m_pdl; outSizes[1] = 100.0;
      return 2;
   }

   virtual void Update() override
   {
      UpdateDailyLevels();
      UpdateSessionLevels();
   }
};

#endif // GOLDENGINEV2_LIQUIDITY_ENGINE_MQH
