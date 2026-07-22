//+------------------------------------------------------------------+
//|                                                 GoldEngineV7.mq5 |
//|                                  Copyright 2026, GoldEngine V7   |
//|                    Clean Slate Prev-Candle Breakout EA           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, GoldEngine V7"
#property link      "https://github.com/rpvp007-dev"
#property version   "7.00"

#include <Trade\Trade.mqh>

//--- Input Parameters
input group "--- Risk & Order Settings ---"
input double   InpLotSize          = 0.10;     // Fixed Lot Size (if Compounding disabled)
input bool     InpEnableCompounding = true;     // Enable Lot Compounding
input double   InpCompoundingStep  = 100.0;    // Balance Step ($100)
input double   InpLotStep          = 0.10;     // Lot Step for Compounding (0.10)
input double   InpPriceOffset      = 0.30;     // Entry Offset from High/Low ($)
input double   InpStopLossDist     = 1.30;     // Stop Loss Distance ($)
input double   InpTakeProfitDist   = 1.00;     // Take Profit Distance ($)
input ulong    InpMagicNumber      = 777777;   // Magic Number

//--- Global Variables
CTrade         trade;
datetime       g_lastBarTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(30);
   g_lastBarTime = 0;
   
   Print("[V7 INIT] GoldEngineV7 initialized successfully. Compounding: ", InpEnableCompounding ? "ENABLED" : "DISABLED");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("[V7 DEINIT] GoldEngineV7 shut down.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if a new candle has formed on the current timeframe
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == g_lastBarTime)
      return; // Not a new bar, exit
      
   // Update last bar time
   g_lastBarTime = currentBarTime;

   // 1. Cancel unexecuted pending orders from previous candle
   CancelPendingOrders();

   // 2. Fetch High and Low of the previous candle (bar index 1)
   double prevHigh = iHigh(_Symbol, _Period, 1);
   double prevLow  = iLow(_Symbol, _Period, 1);

   if(prevHigh == 0 || prevLow == 0)
      return;

   // 3. Calculate Lot Size with Compounding Option
   double lotSize = InpLotSize;
   if(InpEnableCompounding)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      // Smooth continuous compounding based on balance (e.g. $150 balance = 0.15 lots)
      lotSize = (balance / InpCompoundingStep) * InpLotStep;
   }

   // Normalize Volume to broker specifications
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(stepVol <= 0.0) stepVol = 0.01;

   double normalizedLot = MathRound(lotSize / stepVol) * stepVol;
   int volDecimals = 0;
   double tempStep = stepVol;
   while(tempStep < 1.0) { tempStep *= 10.0; volDecimals++; if(volDecimals > 4) break; }
   normalizedLot = NormalizeDouble(normalizedLot, volDecimals);

   if(normalizedLot < minVol) normalizedLot = minVol;
   if(normalizedLot > maxVol) normalizedLot = maxVol;

   // 4. Calculate Order Prices
   double buyStopPrice  = NormalizeDouble(prevHigh + InpPriceOffset, _Digits);
   double buySL         = NormalizeDouble(buyStopPrice - InpStopLossDist, _Digits);
   double buyTP         = NormalizeDouble(buyStopPrice + InpTakeProfitDist, _Digits);

   double sellStopPrice = NormalizeDouble(prevLow - InpPriceOffset, _Digits);
   double sellSL        = NormalizeDouble(sellStopPrice + InpStopLossDist, _Digits);
   double sellTP        = NormalizeDouble(sellStopPrice - InpTakeProfitDist, _Digits);

   // Fetch Stops Level to avoid placement errors
   double stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Adjust Buy Stop if too close to current price
   if(buyStopPrice - currentAsk < stopsLevel)
   {
      buyStopPrice = currentAsk + stopsLevel + SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      buyStopPrice = NormalizeDouble(buyStopPrice, _Digits);
      buySL        = NormalizeDouble(buyStopPrice - InpStopLossDist, _Digits);
      buyTP        = NormalizeDouble(buyStopPrice + InpTakeProfitDist, _Digits);
   }

   // Adjust Sell Stop if too close to current price
   if(currentBid - sellStopPrice < stopsLevel)
   {
      sellStopPrice = currentBid - stopsLevel - SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      sellStopPrice = NormalizeDouble(sellStopPrice, _Digits);
      sellSL        = NormalizeDouble(sellStopPrice + InpStopLossDist, _Digits);
      sellTP        = NormalizeDouble(sellStopPrice - InpTakeProfitDist, _Digits);
   }

   // 5. Place Buy Stop & Sell Stop Orders
   Print(StringFormat("[V7 BREAKOUT] Placing Pending Orders: Lot=%.2f | Buy Stop at %.2f (SL: %.2f, TP: %.2f) | Sell Stop at %.2f (SL: %.2f, TP: %.2f)",
         normalizedLot, buyStopPrice, buySL, buyTP, sellStopPrice, sellSL, sellTP));

   trade.BuyStop(normalizedLot, buyStopPrice, _Symbol, buySL, buyTP, ORDER_TIME_GTC, 0, "Buy Breakout V7");
   trade.SellStop(normalizedLot, sellStopPrice, _Symbol, sellSL, sellTP, ORDER_TIME_GTC, 0, "Sell Breakout V7");
}

//+------------------------------------------------------------------+
//| Function to delete unexecuted pending orders                     |
//+------------------------------------------------------------------+
void CancelPendingOrders()
{
   int cancelledCount = 0;
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
               if(trade.OrderDelete(ticket))
                  cancelledCount++;
            }
         }
      }
   }
   if(cancelledCount > 0)
   {
      Print(StringFormat("[V7 CLEANUP] Cancelled %d unexecuted pending orders for Magic %d", cancelledCount, InpMagicNumber));
   }
}
//+------------------------------------------------------------------+
