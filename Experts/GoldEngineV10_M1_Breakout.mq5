//+------------------------------------------------------------------+
//|                                     GoldEngineV10_M1_Breakout.mq5 |
//|                                  Copyright 2026, GoldEngine V10  |
//|                    Adaptive Multi-Timeframe Breakout EA          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, GoldEngine V10"
#property link      "https://github.com/rpvp007-dev"
#property version   "10.00"

#include <Trade\Trade.mqh>

//--- Timeframe Mode Enum
enum ENUM_TF_MODE {
   TF_M1,       // M1 (1-Minute) Presets
   TF_M5,       // M5 (5-Minute) Presets
   TF_M15,      // M15 (15-Minute) Presets
   TF_H1,       // H1 (1-Hour) Presets
   TF_CUSTOM    // Custom Settings (Use manual inputs below)
};

//--- Input Parameters
input group "--- Target Timeframe Selection ---"
input ENUM_TF_MODE InpTimeframeMode = TF_M1;     // Target Chart Timeframe Mode

input group "--- Core Risk Settings ---"
input double   InpLotSize          = 0.10;     // Lot Size (Applied to all modes)
input ulong    InpMagicNumber      = 123456;   // Magic Number

input group "--- CUSTOM MODE ONLY: Entry & Stop Distances ---"
input double   InpPriceOffset      = 0.30;     // Custom Entry Offset from High/Low ($)
input double   InpStopLossDist     = 1.30;     // Custom Stop Loss Distance ($)
input double   InpTakeProfitDist   = 0.00;     // Custom Take Profit Distance ($) [0 = Unlimited]

input group "--- CUSTOM MODE ONLY: Stage 1 Break-Even ---"
input bool     InpEnableBE         = true;     // Custom Enable Initial Break-Even
input double   InpBETrigger        = 1.00;     // Custom Break-Even Trigger ($ profit)
input double   InpBEOffset         = 0.10;     // Custom Break-Even Lock Offset ($)

input group "--- CUSTOM MODE ONLY: Stage 2 Wide Trailing ---"
input bool     InpEnableStage1     = true;     // Custom Enable Stage 1 (Wide Trail)
input double   InpStage1Trigger    = 1.50;     // Custom Stage 1 Trigger ($ profit)
input double   InpStage1Distance   = 1.50;     // Custom Stage 1 Trail Distance ($)

input group "--- CUSTOM MODE ONLY: Stage 3 Tight Trailing ---"
input bool     InpEnableStage2     = true;     // Custom Enable Stage 2 (Tight Trail)
input double   InpStage2Trigger    = 2.50;     // Custom Stage 2 Trigger ($ profit)
input double   InpStage2Distance   = 0.60;     // Custom Stage 2 Trail Distance ($)

input group "--- CUSTOM MODE ONLY: Time-Decay Settings ---"
input bool     InpEnableTimeDecay  = true;     // Custom Enable Time-Decay Exit
input int      InpMaxHoldMinutes   = 45;       // Custom Maximum Hold Time (Minutes)

//--- Global Variables / Presets Map
CTrade         trade;
datetime       g_lastBarTime;

double         g_lotSize;
double         g_priceOffset;
double         g_stopLossDist;
double         g_takeProfitDist;
bool           g_enableBE;
double         g_beTrigger;
double         g_beOffset;
bool           g_enableStage1;
double         g_stage1Trigger;
double         g_stage1Distance;
bool           g_enableStage2;
double         g_stage2Trigger;
double         g_stage2Distance;
bool           g_enableTimeDecay;
int            g_maxHoldMinutes;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   g_lastBarTime = 0;
   
   // Load settings based on selected timeframe
   LoadTimeframePresets();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment(""); // Clear chart comments
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Load presets dynamically to allow adjustments in test/live
   LoadTimeframePresets();

   // 1. Verify that chart timeframe matches target timeframe input
   if(VerifyTimeframeMismatch())
   {
      return; // Halt trading execution if timeframe mismatch
   }

   // 2. Manage active position progressive trailing/locking on EVERY single tick
   ManageActivePositions();

   // Check if a new candle has formed on the current timeframe
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == g_lastBarTime)
      return; // Not a new bar, exit
      
   // Update last bar time
   g_lastBarTime = currentBarTime;

   // 3. Cancel unexecuted pending orders from previous candle
   CancelPendingOrders();

   // 4. Fetch High and Low of the previous candle (bar index 1)
   double prevHigh = iHigh(_Symbol, _Period, 1);
   double prevLow  = iLow(_Symbol, _Period, 1);

   if(prevHigh == 0 || prevLow == 0)
      return;

   // 5. Calculate dynamic spread
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = currentAsk - currentBid;

   // 6. Calculate Order Prices (Buy Stop gets spread-adjusted to prevent premature fill)
   double buyStopPrice  = NormalizeDouble(prevHigh + g_priceOffset + spread, _Digits);
   double buySL         = NormalizeDouble(buyStopPrice - g_stopLossDist, _Digits);
   double buyTP         = (g_takeProfitDist > 0.0) ? NormalizeDouble(buyStopPrice + g_takeProfitDist, _Digits) : 0.0;

   double sellStopPrice = NormalizeDouble(prevLow - g_priceOffset, _Digits);
   double sellSL        = NormalizeDouble(sellStopPrice + g_stopLossDist, _Digits);
   double sellTP        = (g_takeProfitDist > 0.0) ? NormalizeDouble(sellStopPrice - g_takeProfitDist, _Digits) : 0.0;

   // 7. Place Buy Stop & Sell Stop Orders
   trade.BuyStop(g_lotSize, buyStopPrice, _Symbol, buySL, buyTP, ORDER_TIME_GTC, 0, "Buy Breakout");
   trade.SellStop(g_lotSize, sellStopPrice, _Symbol, sellSL, sellTP, ORDER_TIME_GTC, 0, "Sell Breakout");
}

//+------------------------------------------------------------------+
//| Verify chart timeframe matches input settings                    |
//+------------------------------------------------------------------+
bool VerifyTimeframeMismatch()
{
   ENUM_TIMEFRAMES currentPeriod = _Period;
   bool tfMismatch = false;
   string targetTfStr = "";
   
   if(InpTimeframeMode == TF_M1 && currentPeriod != PERIOD_M1) { tfMismatch = true; targetTfStr = "M1 (1-Minute)"; }
   else if(InpTimeframeMode == TF_M5 && currentPeriod != PERIOD_M5) { tfMismatch = true; targetTfStr = "M5 (5-Minute)"; }
   else if(InpTimeframeMode == TF_M15 && currentPeriod != PERIOD_M15) { tfMismatch = true; targetTfStr = "M15 (15-Minute)"; }
   else if(InpTimeframeMode == TF_H1 && currentPeriod != PERIOD_H1) { tfMismatch = true; targetTfStr = "H1 (1-Hour)"; }
   
   if(tfMismatch)
   {
      string msg = "WARNING: Timeframe mismatch! Please change chart period to: " + targetTfStr;
      Comment(msg);
      
      static datetime lastAlertTime = 0;
      if(TimeCurrent() - lastAlertTime > 60) // Alert at most once per minute
      {
         Alert(msg);
         lastAlertTime = TimeCurrent();
      }
      return true; // Mismatch exists
   }
   
   Comment(""); // Clear comment if correct
   return false;
}

//+------------------------------------------------------------------+
//| Load dynamic presets based on the timeframe mode                 |
//+------------------------------------------------------------------+
void LoadTimeframePresets()
{
   g_lotSize = InpLotSize; // Load lot size from user input
   
   if(InpTimeframeMode == TF_M1)
   {
      g_priceOffset      = 0.25;
      g_stopLossDist     = 1.30;
      g_takeProfitDist   = 0.00;
      g_enableBE         = true;
      g_beTrigger        = 0.60;
      g_beOffset         = 0.05;
      g_enableStage1     = true;
      g_stage1Trigger    = 1.00;
      g_stage1Distance   = 0.80;
      g_enableStage2     = true;
      g_stage2Trigger    = 1.60;
      g_stage2Distance   = 0.40;
      g_enableTimeDecay  = true;
      g_maxHoldMinutes   = 2;
   }
   else if(InpTimeframeMode == TF_M5)
   {
      g_priceOffset      = 0.30;
      g_stopLossDist     = 2.00;
      g_takeProfitDist   = 0.00;
      g_enableBE         = true;
      g_beTrigger        = 1.20;
      g_beOffset         = 0.10;
      g_enableStage1     = true;
      g_stage1Trigger    = 2.00;
      g_stage1Distance   = 1.50;
      g_enableStage2     = true;
      g_stage2Trigger    = 3.00;
      g_stage2Distance   = 0.80;
      g_enableTimeDecay  = true;
      g_maxHoldMinutes   = 15;
   }
   else if(InpTimeframeMode == TF_M15)
   {
      g_priceOffset      = 0.40;
      g_stopLossDist     = 3.50;
      g_takeProfitDist   = 0.00;
      g_enableBE         = true;
      g_beTrigger        = 2.50;
      g_beOffset         = 0.20;
      g_enableStage1     = true;
      g_stage1Trigger    = 3.50;
      g_stage1Distance   = 2.50;
      g_enableStage2     = true;
      g_stage2Trigger    = 5.00;
      g_stage2Distance   = 1.20;
      g_enableTimeDecay  = true;
      g_maxHoldMinutes   = 45;
   }
   else if(InpTimeframeMode == TF_H1)
   {
      g_priceOffset      = 0.80;
      g_stopLossDist     = 8.00;
      g_takeProfitDist   = 0.00;
      g_enableBE         = true;
      g_beTrigger        = 6.00;
      g_beOffset         = 0.50;
      g_enableStage1     = true;
      g_stage1Trigger    = 8.00;
      g_stage1Distance   = 6.00;
      g_enableStage2     = true;
      g_stage2Trigger    = 12.00;
      g_stage2Distance   = 2.50;
      g_enableTimeDecay  = true;
      g_maxHoldMinutes   = 180;
   }
   else // TF_CUSTOM
   {
      g_priceOffset      = InpPriceOffset;
      g_stopLossDist     = InpStopLossDist;
      g_takeProfitDist   = InpTakeProfitDist;
      g_enableBE         = InpEnableBE;
      g_beTrigger        = InpBETrigger;
      g_beOffset         = InpBEOffset;
      g_enableStage1     = InpEnableStage1;
      g_stage1Trigger    = InpStage1Trigger;
      g_stage1Distance   = InpStage1Distance;
      g_enableStage2     = InpEnableStage2;
      g_stage2Trigger    = InpStage2Trigger;
      g_stage2Distance   = InpStage2Distance;
      g_enableTimeDecay  = InpEnableTimeDecay;
      g_maxHoldMinutes   = InpMaxHoldMinutes;
   }
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
            if(g_enableTimeDecay)
            {
               int durationSec = (int)(TimeCurrent() - openTime);
               if(durationSec >= g_maxHoldMinutes * 60)
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
               if(g_enableStage2 && currentProfit >= g_stage2Trigger)
               {
                  targetSL = NormalizeDouble(currentBid - g_stage2Distance, _Digits);
               }
               // Stage 2: Wide Trail (Breathing room)
               else if(g_enableStage1 && currentProfit >= g_stage1Trigger)
               {
                  targetSL = NormalizeDouble(currentBid - g_stage1Distance, _Digits);
               }
               // Stage 1: Initial Break-Even (Price-to-Price)
               else if(g_enableBE && currentProfit >= g_beTrigger && currentSL < entryPrice)
               {
                  targetSL = NormalizeDouble(entryPrice + g_beOffset, _Digits);
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
               if(g_enableStage2 && currentProfit >= g_stage2Trigger)
               {
                  targetSL = NormalizeDouble(currentAsk + g_stage2Distance, _Digits);
               }
               // Stage 2: Wide Trail (Breathing room)
               else if(g_enableStage1 && currentProfit >= g_stage1Trigger)
               {
                  targetSL = NormalizeDouble(currentAsk + g_stage1Distance, _Digits);
               }
               // Stage 1: Initial Break-Even (Price-to-Price)
               else if(g_enableBE && currentProfit >= g_beTrigger && (currentSL > entryPrice || currentSL == 0.0))
               {
                  targetSL = NormalizeDouble(entryPrice - g_beOffset, _Digits);
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
