//+------------------------------------------------------------------+
//|                                             ILiquidityEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_ILIQUIDITY_ENGINE_MQH
#define GOLDENGINEV2_ILIQUIDITY_ENGINE_MQH

//+------------------------------------------------------------------+
//| Interface for Liquidity Engine                                   |
//+------------------------------------------------------------------+
class ILiquidityEngine
{
public:
   virtual ~ILiquidityEngine() {}

   /**
    * @brief Initializes indicators/settings for the Liquidity Engine.
    */
   virtual bool      InitializeEngine(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Checks if key liquidity pool level structures are currently present.
    */
   virtual bool      IsLiquidityPresent() = 0;

   /**
    * @brief Gets direction of the closest key liquidity levels (Buy Side, Sell Side, Both, None).
    */
   virtual string    GetLiquidityDirection() = 0;

   /**
    * @brief Gets current Liquidity pool clustering strength (0 to 100).
    */
   virtual double    GetLiquidityStrength() = 0;

   /**
    * @brief Gets Previous Day High (PDH) and Previous Day Low (PDL) prices.
    */
   virtual bool      GetPDH_PDL(double &outPDH, double &outPDL) = 0;

   /**
    * @brief Gets session range boundaries (High/Low) for specified session.
    */
   virtual bool      GetSessionHighLow(const string sessionName, double &outHigh, double &outLow) = 0;

   /**
    * @brief Checks if there was a liquidity sweep on the last closed bar.
    */
   virtual bool      IsLiquiditySweep(bool &outBuySide, bool &outSellSide) = 0;

   /**
    * @brief Checks if a high-volume stop hunt sweep is active.
    */
   virtual bool      IsStopHuntActive() = 0;

   /**
    * @brief Identifies active liquidity pools and returns prices/sizes.
    */
   virtual int       GetLiquidityPools(const string symbol, double &outPrices[], double &outSizes[]) = 0;

   /**
    * @brief Updates liquidity maps.
    */
   virtual void      Update() = 0;
};

#endif // GOLDENGINEV2_ILIQUIDITY_ENGINE_MQH
