//+------------------------------------------------------------------+
//|                                     GoldEngineV10_M1_Breakout.mq5 |
//|                                  Copyright 2026, GoldEngine V10  |
//|                    Clean Slate Prev-Candle Breakout EA (V10)     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, GoldEngine V10"
#property link      "https://github.com/rpvp007-dev"
#property version   "10.00"

#include <Trade\Trade.mqh>

//--- Input Parameters
input group "--- Risk & Order Settings ---"
input double   InpLotSize          = 0.10;     // Lot Size
input double   InpPriceOffset      = 0.25;     // Entry Offset from High/Low ($)
input double   InpStopLossDist     = 0.80;     // Stop Loss Distance ($)
input double   InpTakeProfitDist   = 0.00;     // Take Profit Distance ($) [0 = Unlimited Trailing]
input ulong    InpMagicNumber      = 123456;   // Magic Number

input group "--- Stage 1: Initial Break-Even ---"
input bool     InpEnableBE         = true;     // Enable Initial Break-Even
input double   InpBETrigger        = 0.60;     // Break-Even Trigger ($ profit)
input double   InpBEOffset         = 0.05;     // Break-Even Lock Offset ($)

input group "--- Stage 2: Wide Trailing Stop ---"
input bool     InpEnableStage1     = true;     // Enable Stage 1 (Wide Trail)
input double   InpStage1Trigger    = 1.00;     // Stage 1 Trigger ($ profit)
input double   InpStage1Distance   = 0.80;     // Stage 1 Trail Distance ($)

input group "--- Stage 3: Tight Trailing Stop ---"
input bool     InpEnableStage2     = true;     // Enable Stage 2 (Tight Trail)
input double   InpStage2Trigger    = 1.60;     // Stage 2 Trigger ($ profit)
input double   InpStage2Distance   = 0.40;     // Stage 2 Trail Distance ($)

input group "--- Time-Decay Settings ---"
input bool     InpEnableTimeDecay  = true;     // Close trade after max hold time
input int      InpMaxHoldMinutes   = 2;        // Maximum hold time (Minutes)

//--- Global Variables
CTrade         trade;
datetime       g_lastBarTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   g_lastBarTime = 0;
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Manage active position progressive trailing/locking on EVERY single tick
   ManageActivePositions();

   // Check if a new candle has formed on the current timeframe
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == g_lastBarTime)
      return; // Not a new bar, exit
      
   // Update last bar time
   g_lastBarTime = currentBarTime;

   // 2. Cancel unexecuted pending orders from previous candle
   CancelPendingOrders();

   // 3. Fetch High and Low of the previous candle (bar index 1)
   double prevHigh = iHigh(_Symbol, _Period, 1);
   double prevLow  = iLow(_Symbol, _Period, 1);

   if(prevHigh == 0 || prevLow == 0)
      return;

   // 4. Calculate dynamic spread
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = currentAsk - currentBid;

   // 5. Calculate Order Prices (Buy Stop gets spread-adjusted to prevent premature fill)
   double buyStopPrice  = NormalizeDouble(prevHigh + InpPriceOffset + spread, _Digits);
   double buySL         = NormalizeDouble(buyStopPrice - InpStopLossDist, _Digits);
   double buyTP         = (InpTakeProfitDist > 0.0) ? NormalizeDouble(buyStopPrice + InpTakeProfitDist, _Digits) : 0.0;

   double sellStopPrice = NormalizeDouble(prevLow - InpPriceOffset, _Digits);
   double sellSL        = NormalizeDouble(sellStopPrice + InpStopLossDist, _Digits);
   double sellTP        = (InpTakeProfitDist > 0.0) ? NormalizeDouble(sellStopPrice - InpTakeProfitDist, _Digits) : 0.0;

   // 6. Place Buy Stop & Sell Stop Orders
   trade.BuyStop(InpLotSize, buyStopPrice, _Symbol, buySL, buyTP, ORDER_TIME_GTC, 0, "Buy Breakout");
   trade.SellStop(InpLotSize, sellStopPrice, _Symbol, sellSL, sellTP, ORDER_TIME_GTC, 0, "Sell Breakout");
}

//+------------------------------------------------------------------+
//| Function to delete unexecuted pending orders                     |
//+------------------------------------------------------------------+
void CancelPendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
            {
               trade.OrderDelete(ticket);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Function to manage active positions (BE, Trailing, Time-Decay)   |
//+------------------------------------------------------------------+
void ManageActivePositions()
{
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
            
            // --- 1. TIME DECAY EXIT ---
            if(InpEnableTimeDecay)
            {
               int durationSec = (int)(TimeCurrent() - openTime);
               if(durationSec >= InpMaxHoldMinutes * 60)
               {
                  trade.PositionClose(ticket);
                  continue; // Position closed, skip SL updates
               }
            }
            
            // --- 2. PROGRESSIVE SL LOCKING ---
            if(type == POSITION_TYPE_BUY)
            {
               double currentProfit = currentBid - entryPrice;
               double targetSL = 0.0;
               
               // Stage 3: Tight Trail (Halfway/Near Target)
               if(InpEnableStage2 && currentProfit >= InpStage2Trigger)
               {
                  targetSL = NormalizeDouble(currentBid - InpStage2Distance, _Digits);
               }
               // Stage 2: Wide Trail (Breathing room)
               else if(InpEnableStage1 && currentProfit >= InpStage1Trigger)
               {
                  targetSL = NormalizeDouble(currentBid - InpStage1Distance, _Digits);
               }
               // Stage 1: Initial Break-Even (Price-to-Price)
               else if(InpEnableBE && currentProfit >= InpBETrigger && currentSL < entryPrice)
               {
                  targetSL = NormalizeDouble(entryPrice + InpBEOffset, _Digits);
               }
               
               // Modify SL if target is valid and moves the SL higher
               if(targetSL > 0.0 && (targetSL > currentSL || currentSL == 0.0))
               {
                  if(currentBid - targetSL >= stopsLevel)
                  {
                     trade.PositionModify(ticket, targetSL, currentTP);
                  }
               }
            }
            else if(type == POSITION_TYPE_SELL)
            {
               double currentProfit = entryPrice - currentAsk;
               double targetSL = 0.0;
               
               // Stage 3: Tight Trail (Halfway/Near Target)
               if(InpEnableStage2 && currentProfit >= InpStage2Trigger)
               {
                  targetSL = NormalizeDouble(currentAsk + InpStage2Distance, _Digits);
               }
               // Stage 2: Wide Trail (Breathing room)
               else if(InpEnableStage1 && currentProfit >= InpStage1Trigger)
               {
                  targetSL = NormalizeDouble(currentAsk + InpStage1Distance, _Digits);
               }
               // Stage 1: Initial Break-Even (Price-to-Price)
               else if(InpEnableBE && currentProfit >= InpBETrigger && (currentSL > entryPrice || currentSL == 0.0))
               {
                  targetSL = NormalizeDouble(entryPrice - InpBEOffset, _Digits);
               }
               
               // Modify SL if target is valid and moves the SL lower
               if(targetSL > 0.0 && (targetSL < currentSL || currentSL == 0.0))
               {
                  if(targetSL - currentAsk >= stopsLevel)
                  {
                     trade.PositionModify(ticket, targetSL, currentTP);
                  }
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
