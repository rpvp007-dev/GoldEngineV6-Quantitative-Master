//+------------------------------------------------------------------+
//|                                              IVolumeEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IVOLUME_ENGINE_MQH
#define GOLDENGINEV2_IVOLUME_ENGINE_MQH

//+------------------------------------------------------------------+
//| Interface for Volume Engine                                      |
//+------------------------------------------------------------------+
class IVolumeEngine
{
public:
   virtual ~IVolumeEngine() {}

   /**
    * @brief Initializes indicators/settings for the Volume Engine.
    */
   virtual bool      InitializeEngine(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Gets tick volume for symbol.
    */
   virtual long      GetTicksVolume(const string symbol, ENUM_TIMEFRAMES tf, int shift) = 0;

   /**
    * @brief Gets real volume for symbol.
    */
   virtual long      GetRealVolume(const string symbol, ENUM_TIMEFRAMES tf, int shift) = 0;

   /**
    * @brief Gets average volume over a specified period.
    */
   virtual double    GetAverageVolume(int period) = 0;

   /**
    * @brief Gets Relative Volume (RVOL = Current closed volume / Average volume).
    */
   virtual double    GetRelativeVolume() = 0;

   /**
    * @brief Detects if there is a volume spike present.
    */
   virtual bool      IsVolumeSpike(double spikeRatio) = 0;

   /**
    * @brief Gets Volume Trend (Increasing, Decreasing, Flat).
    */
   virtual string    GetVolumeTrend() = 0;

   /**
    * @brief Calculates a normalized Volume Strength Score (0 to 100).
    */
   virtual double    GetVolumeStrengthScore() = 0;

   /**
    * @brief Identifies Volume State (Low, Normal, High, Extreme).
    */
   virtual string    GetVolumeState() = 0;

   /**
    * @brief Updates volume calculations.
    */
   virtual void      Update() = 0;
};

#endif // GOLDENGINEV2_IVOLUME_ENGINE_MQH
