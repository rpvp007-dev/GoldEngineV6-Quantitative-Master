//+------------------------------------------------------------------+
//|                                              IMovementEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IMOVEMENT_ENGINE_MQH
#define GOLDENGINEV2_IMOVEMENT_ENGINE_MQH

#include "MovementDefines.mqh"

// Forward declaration to resolve circular dependency
struct QuantEnginesContainer;

//+------------------------------------------------------------------+
//| Interface for Movement Intelligence Engine                       |
//+------------------------------------------------------------------+
class IMovementEngine
{
public:
   virtual ~IMovementEngine() {}

   /**
    * @brief Initializes engine with container references to other engines.
    */
   virtual bool      Initialize(const QuantEnginesContainer &engines) = 0;

   /**
    * @brief Updates movement calculations for the closed candle.
    */
   virtual void      UpdateMovement(const string symbol, ENUM_TIMEFRAMES tf) = 0;

   /**
    * @brief Retrieves the calculated movement context data.
    */
   virtual MovementContext GetMovementContext() const = 0;
};

#endif // GOLDENGINEV2_IMOVEMENT_ENGINE_MQH
