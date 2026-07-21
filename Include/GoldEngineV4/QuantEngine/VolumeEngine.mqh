//+------------------------------------------------------------------+
//|                                                   VolumeEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_VOLUME_ENGINE_MQH
#define GOLDENGINEV2_VOLUME_ENGINE_MQH

#include "IVolumeEngine.mqh"

//+------------------------------------------------------------------+
//| Volume Engine Concrete Implementation (GITS V2.4)                |
//+------------------------------------------------------------------+
class CVolumeEngine : public IVolumeEngine
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   bool              m_isInitialized;

   /**
    * @brief Helper to fetch tick volume for specified shift.
    */
   long FetchVolume(int shift)
   {
      MqlRates rates[];
      if(CopyRates(m_symbol, m_tf, shift, 1, rates) > 0)
      {
         return rates[0].tick_volume;
      }
      return 0;
   }

public:
   /**
    * @brief Constructor.
    */
   CVolumeEngine()
      : m_symbol(""),
        m_tf(PERIOD_CURRENT),
        m_isInitialized(false)
   {}

   /**
    * @brief Destructor.
    */
   ~CVolumeEngine() {}

   /**
    * @brief Initializes Volume Engine.
    */
   virtual bool InitializeEngine(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      m_symbol = symbol;
      m_tf = tf;
      m_isInitialized = true;
      return true;
   }

   /**
    * @brief Gets tick volume for symbol.
    */
   virtual long GetTicksVolume(const string symbol, ENUM_TIMEFRAMES tf, int shift) override
   {
      if(!m_isInitialized) return 0;
      return FetchVolume(shift);
   }

   /**
    * @brief Gets real volume for symbol.
    */
   virtual long GetRealVolume(const string symbol, ENUM_TIMEFRAMES tf, int shift) override
   {
      if(!m_isInitialized) return 0;
      MqlRates rates[];
      if(CopyRates(m_symbol, m_tf, shift, 1, rates) > 0)
      {
         return rates[0].real_volume;
      }
      return 0;
   }

   /**
    * @brief Gets average tick volume over a period.
    */
   virtual double GetAverageVolume(int period) override
   {
      if(!m_isInitialized || period <= 0) return 0.0;

      MqlRates rates[];
      int copied = CopyRates(m_symbol, m_tf, 1, period, rates);
      if(copied <= 0) return 0.0;

      double sum = 0.0;
      for(int i = 0; i < copied; i++)
      {
         sum += (double)rates[i].tick_volume;
      }
      return sum / copied;
   }

   /**
    * @brief Gets Relative Volume (RVOL).
    */
   virtual double GetRelativeVolume() override
   {
      if(!m_isInitialized) return 1.0;
      
      double currentVolume = (double)FetchVolume(1); // Closed bar volume
      double averageVolume = GetAverageVolume(20);
      
      if(averageVolume <= 0.0) return 1.0;
      return currentVolume / averageVolume;
   }

   /**
    * @brief Detects if volume spike is active.
    */
   virtual bool IsVolumeSpike(double spikeRatio) override
   {
      return (GetRelativeVolume() >= spikeRatio);
   }

   /**
    * @brief Gets description of volume trend.
    */
   virtual string GetVolumeTrend() override
   {
      double shortAvg = GetAverageVolume(5);
      double longAvg = GetAverageVolume(20);

      if(longAvg <= 0.0) return "Flat";
      if(shortAvg > longAvg * 1.05) return "Increasing";
      if(shortAvg < longAvg * 0.95) return "Decreasing";
      return "Flat";
   }

   /**
    * @brief Calculates normalized Volume Strength Score (0 to 100).
    */
   virtual double GetVolumeStrengthScore() override
   {
      double rvol = GetRelativeVolume();
      double score = rvol * 50.0; // RVOL = 1.0 is score 50, RVOL >= 2.0 is score 100
      
      if(score < 0.0) score = 0.0;
      if(score > 100.0) score = 100.0;
      return score;
   }

   /**
    * @brief Identifies Volume State.
    */
   virtual string GetVolumeState() override
   {
      double rvol = GetRelativeVolume();
      if(rvol < 0.75) return "Low";
      if(rvol < 1.5)  return "Normal";
      if(rvol < 2.5)  return "High";
      return "Extreme";
   }

   virtual void Update() override {}
};

#endif // GOLDENGINEV2_VOLUME_ENGINE_MQH
