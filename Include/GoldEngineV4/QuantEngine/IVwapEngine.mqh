//+------------------------------------------------------------------+
//|                                                 IVwapEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IVWAP_ENGINE_MQH
#define GOLDENGINEV2_IVWAP_ENGINE_MQH

//+------------------------------------------------------------------+
//| Interface for VWAP Engine                                        |
//+------------------------------------------------------------------+
class IVwapEngine
{
public:
   virtual ~IVwapEngine() {}

   /**
    * @brief Gets Volume Weighted Average Price (VWAP).
    */
   virtual double    GetVWAP(const string symbol, ENUM_TIMEFRAMES tf, int shift) = 0;

   /**
    * @brief Updates VWAP calculations.
    */
   virtual void      Update() = 0;
};

#endif // GOLDENGINEV2_IVWAP_ENGINE_MQH
