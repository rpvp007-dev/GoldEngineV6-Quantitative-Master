//+------------------------------------------------------------------+
//|                                           IExecutionEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IEXECUTION_ENGINE_MQH
#define GOLDENGINEV2_IEXECUTION_ENGINE_MQH

#include "../Strategy/StrategyDefines.mqh"

//+------------------------------------------------------------------+
//| Execution Engine Interface                                       |
//+------------------------------------------------------------------+
class IExecutionEngine
{
public:
   virtual ~IExecutionEngine() {}

   /**
    * @brief Executes an approved trade signal.
    * @param signal The strategy response to execute.
    * @param magicNumber Magic number for order tracking.
    * @return true if successfully dispatched, false otherwise.
    */
   virtual bool      ExecuteSignal(const StrategyResponse &signal, ulong magicNumber) = 0;

   /**
    * @brief Modifies Stop Loss and Take Profit levels of an active trade.
    * @param ticket Trade ticket identifier.
    * @param sl New Stop Loss price.
    * @param tp New Take Profit price.
    * @return true if modification successful, false otherwise.
    */
   virtual bool      ModifyPosition(ulong ticket, double sl, double tp) = 0;

   /**
    * @brief Cancels a pending order.
    * @param ticket Order ticket identifier.
    * @return true if cancel successful, false otherwise.
    */
   virtual bool      CancelOrder(ulong ticket) = 0;

   /**
    * @brief Gets the last execution deal ticket.
    */
   virtual ulong     GetLastDealTicket() = 0;

   /**
    * @brief Gets the last execution order ticket.
    */
   virtual ulong     GetLastOrderTicket() = 0;

   /**
    * @brief Synchronizes internal position lists with the MT5 broker server.
    */
   virtual void      SynchronizeTrades() = 0;
};

#endif // GOLDENGINEV2_IEXECUTION_ENGINE_MQH
