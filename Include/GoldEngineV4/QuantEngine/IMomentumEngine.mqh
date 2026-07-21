//+------------------------------------------------------------------+
//|                                             IMomentumEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IMOMENTUM_ENGINE_MQH
#define GOLDENGINEV2_IMOMENTUM_ENGINE_MQH

//+------------------------------------------------------------------+
//| Interface for Momentum Engine                                    |
//+------------------------------------------------------------------+
class IMomentumEngine
{
public:
   virtual ~IMomentumEngine() {}

   /**
    * @brief Initializes Momentum Engine and RSI handle.
    */
   virtual bool      InitializeEngine(const string symbol, ENUM_TIMEFRAMES tf, int rsiPeriod) = 0;

   /**
    * @brief Gets current or historical RSI value.
    */
   virtual double    GetRSIValue(int shift) = 0;

   /**
    * @brief Gets Rate of Change (ROC) over the RSI period.
    */
   virtual double    GetROCValue(int shift) = 0;

   /**
    * @brief Gets normalized Momentum Strength (0 to 100).
    */
   virtual double    GetMomentumStrength() = 0;

   /**
    * @brief Gets Momentum Acceleration (ROC change rate).
    */
   virtual double    GetMomentumAcceleration() = 0;

   /**
    * @brief Gets description of momentum direction (Increasing, Decreasing, Flat).
    */
   virtual string    GetMomentumDirectionDesc() = 0;

   /**
    * @brief Gets the composite Momentum Score (0 to 100).
    */
   virtual double    GetMomentumScore() = 0;

   /**
    * @brief Updates momentum engine calculations.
    */
   virtual void      Update() = 0;
};

#endif // GOLDENGINEV2_IMOMENTUM_ENGINE_MQH
