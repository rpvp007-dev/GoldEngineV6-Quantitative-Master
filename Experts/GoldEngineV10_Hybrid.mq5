//+------------------------------------------------------------------+
//|                                                GoldEngineV10.mq5 |
//|                                  Copyright 2026, GoldEngine V10  |
//|                    Adaptive Multi-Timeframe Hybrid EA (Pro)      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, GoldEngine V10"
#property link      "https://github.com/rpvp007-dev"
#property version   "18.00"

#include <Trade\Trade.mqh>

//--- Timeframe Mode Enum
enum ENUM_TF_MODE {
   TF_AUTO,     // Auto-Detect Chart Timeframe (Default)
   TF_M1,       // M1 (1-Minute) Presets
   TF_M5,       // M5 (5-Minute) Presets
   TF_M15,      // M15 (15-Minute) Presets
   TF_H1,       // H1 (1-Hour) Presets
   TF_CUSTOM    // Custom Settings (Use manual inputs below)
};

//--- Input Parameters
input group "--- Target Timeframe Selection ---"
input ENUM_TF_MODE InpTimeframeMode = TF_AUTO;    // Target Chart Timeframe Mode

input group "--- AI Engine Settings ---"
input string   InpGeminiAPIKey       = "AIzaSyB6PZqz_ck3sGIsr2XmBTK6Qo02zpkSt60"; // Gemini API Key (aistudio.google.com)
input string   InpGroqAPIKey         = "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"; // Groq API Key (console.groq.com)
input bool     InpUseGeminiAI        = true;    // Use AI Engines for Trade Decisions
input int      InpMinConviction      = 50;      // Minimum AI Conviction to trade (0-100)

input group "--- Core Risk Settings ---"
input double   InpLotSize          = 0.10;     // Fixed Lot Size (If Compounding is disabled)
input double   InpTargetRiskUSD    = 10.00;    // Target dollar risk per trade ($)
input ulong    InpMagicNumber      = 123456;   // Magic Number

input group "--- Compounding Settings ---"
input bool     InpEnableCompounding = true;    // Enable Lot Compounding (scales target risk)
input double   InpLotsPerStep       = 0.10;    // (Legacy reference lot size)
input double   InpBalanceStep       = 500.00;  // Per how much account balance ($) to scale risk

input group "--- Sideways Hybrid Mode Settings ---"
input bool     InpEnableHybridMode   = true;   // Enable Breakout/Reversion Switch
input double   InpMinADX             = 20.0;   // Custom Mode ONLY: ADX Threshold (Sideways < 20)

input group "--- Session Momentum Hours ---"
input bool     InpUseSessionHours    = true;   // Breakouts allowed ONLY during Momentum Hours
input int      InpLondonStartHour    = 7;      // London Open Hour (Server time)
input int      InpLondonEndHour      = 10;     // London End Hour (Server time)
input int      InpNYStartHour        = 13;     // NY Open Hour (Server time)
input int      InpNYStartMin         = 30;     // NY Open Minute (Server time)
input int      InpNYEndHour          = 16;     // NY End Hour (Server time)
input int      InpNYEndMin           = 30;     // NY End Minute (Server time)

input group "--- Precision & Volume Filters (BREAKOUT ONLY) ---"
input bool     InpUseVolumeFilter    = true;   // Tick Volume Filter (confirm breakout volume)
input bool     InpUseMTFTrendFilter  = true;   // Dual-Timeframe Trend Alignment (Macro direction)
input bool     InpUseEMAFilter       = true;   // Filter entries by 50 EMA Trend (Local direction)
input bool     InpUseRSIFilter       = true;   // Filter out Trend Exhaustion (RSI 70/30)
input bool     InpUseATRFilter       = true;   // Block trading if ATR Volatility is low

input group "--- Volatility-Adjusted Entry Offset ---"
input bool     InpUseATROffset       = true;   // Dynamic Entry Offset based on ATR
input double   InpATROffsetMultiplier = 0.15;  // Custom Mode ONLY: ATR Multiplier for Entry Offset

input group "--- Volatility-Adjusted Stop Loss ---"
input bool     InpUseATRStopLoss     = true;   // Stop Loss dynamic based on ATR
input double   InpATRMultiplier      = 1.5;    // Custom Mode ONLY: ATR Multiplier for Stop Loss distance

input group "--- Profit Management Settings ---"
input bool     InpEnablePartialClose = true;   // Close 50% lot at Break-Even Stage

input group "--- Active Loss-Cutting Settings ---"
input bool     InpEnableCandleTrail   = true;  // Trail SL by Candle Lows/Highs
input double   InpCandleTrailBuffer   = 0.10;  // Custom Mode ONLY: Buffer below Low / above High ($)
input bool     InpEnableRejectionExit = true;  // Close trade if candle closes opposite

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
input double   InpMinATR           = 0.50;     // Custom Minimum ATR (Volatility Limit)

//--- Global Variables / Presets Map
CTrade         trade;
datetime       g_lastBarTime;
datetime       g_lastOrderPlacedBarTime = 0; // Tracks if order was placed successfully for this candle
int            g_lastDay = 0;                // Tracks day changes for Daily Bias calculation

int            g_emaHandle;         // Local EMA handle
int            g_emaHigherHandle;   // Higher timeframe EMA handle
int            g_atrHandle;         // ATR handle
int            g_rsiHandle;         // RSI handle
int            g_adxHandle;         // ADX handle

// Spread smoothing buffers
double         g_spreadBuffer[10];
int            g_spreadCount;

// Dynamic preset outputs
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
double         g_minATR;

// Timeframe-adapted settings
double         g_minADX;
double         g_atrSLMultiplier;
double         g_atrOffsetMultiplier;
double         g_candleTrailBuffer;

// UI controls
bool           g_eaRunning = true;  // Button state toggle

// AI Conviction & Bias Outputs
string         g_dailySentiment = "BI_DIRECTIONAL";
string         g_dailySentimentReason = "Analyzing macro...";
string         g_aiDecision = "WAITING";
int            g_aiConviction = 0;
string         g_aiReason = "Awaiting setup...";

//+------------------------------------------------------------------+
//| Determine higher timeframe for trend alignment                  |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetHigherTimeframe()
{
   ENUM_TIMEFRAMES period = _Period;
   if(period == PERIOD_M1)  return PERIOD_M15;
   if(period == PERIOD_M5)  return PERIOD_H1;
   if(period == PERIOD_M15) return PERIOD_H4;
   if(period == PERIOD_H1)  return PERIOD_D1;
   return PERIOD_H4; // fallback
}

//+------------------------------------------------------------------+
//| Update running spread buffer on every single tick                |
//+------------------------------------------------------------------+
void UpdateSpreadBuffer()
{
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentSpread = currentAsk - currentBid;
   
   // Shift buffer
   for(int j = 9; j > 0; j--)
   {
      g_spreadBuffer[j] = g_spreadBuffer[j-1];
   }
   g_spreadBuffer[0] = currentSpread;
   if(g_spreadCount < 10) g_spreadCount++;
}

//+------------------------------------------------------------------+
//| Fetch averaged (smoothed) spread from buffer                     |
//+------------------------------------------------------------------+
double GetSmoothedSpread()
{
   if(g_spreadCount == 0)
   {
      return SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   
   double sum = 0.0;
   for(int j = 0; j < g_spreadCount; j++)
   {
      sum += g_spreadBuffer[j];
   }
   return NormalizeDouble(sum / g_spreadCount, _Digits);
}

//+------------------------------------------------------------------+
//| Verify chart timeframe matches input settings                    |
//+------------------------------------------------------------------+
bool VerifyTimeframeMismatch()
{
   if(InpTimeframeMode == TF_AUTO || InpTimeframeMode == TF_CUSTOM)
      return false; // Auto and Custom modes have no mismatch
      
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
         lastAlertTime = TimeCurrent();
         Alert(msg);
      }
      return true; // Mismatch exists
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Helper to create label text elements                             |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, int fontSize, color clr, string font="Segoe UI")
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Helper to create background panel rectangle                      |
//+------------------------------------------------------------------+
void CreatePanelBg(string name, int x, int y, int width, int height, color bgColor, color borderColor)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, borderColor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Update layout/color of the button                                |
//+------------------------------------------------------------------+
void UpdateButtonState()
{
   string name = "BtnEAToggle";
   if(ObjectFind(0, name) >= 0)
   {
      if(g_eaRunning)
      {
         ObjectSetString(0, name, OBJPROP_TEXT, "EA STATUS: ACTIVE");
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'46,125,50'); // Dark Green
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      }
      else
      {
         ObjectSetString(0, name, OBJPROP_TEXT, "EA STATUS: PAUSED");
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'198,40,40'); // Dark Red
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      }
   }
}

//+------------------------------------------------------------------+
//| Create the interactive toggle button and panel on chart          |
//+------------------------------------------------------------------+
void CreateInterface()
{
   // Redesigned: 350px wide, 330px high to fit Combined Master System
   int panelWidth  = 350;
   int panelHeight = 330;
   int margin      = 25;
   int textX       = 20 + margin;
   int fontSize    = 8; 
   
   // 1. Create Background Shield
   CreatePanelBg("DbPanelBg", 20, 60, panelWidth, panelHeight, C'20,20,20', C'70,70,70');
   
   // 2. Create Header
   CreateLabel("DbTitle", textX, 75, "GOLD ENGINE V10 - HYBRID PRO", 10, C'255,179,0', "Segoe UI Semibold");
   
   // 3. Create Rows (Clean 18px line height)
   CreateLabel("DbTimeframe", textX, 100, "Chart Timeframe : ", fontSize, clrWhite);
   CreateLabel("DbLotSize",   textX, 118, "Dynamic Lot Size: ", fontSize, clrWhite);
   CreateLabel("DbADX",       textX, 136, "Current ADX     : ", fontSize, clrWhite);
   CreateLabel("DbATR",       textX, 154, "Current ATR     : ", fontSize, clrWhite);
   CreateLabel("DbMode",      textX, 172, "Active Mode     : ", fontSize, clrWhite);
   CreateLabel("DbSL",        textX, 190, "Stop Loss (ATR) : ", fontSize, clrWhite);
   
   // AI Dashboard Rows
   CreateLabel("DbBias",      textX, 208, "AI Daily Bias   : ", fontSize, clrWhite);
   CreateLabel("DbDecision",  textX, 226, "AI Decision     : ", fontSize, clrWhite);
   CreateLabel("DbConviction",textX, 244, "AI Conviction   : ", fontSize, clrWhite);
   CreateLabel("DbReason",    textX, 262, "AI Reason       : ", fontSize, clrWhite);
   
   // 4. Create Button (Nested at the bottom of the panel with margins aligned)
   string btnName = "BtnEAToggle";
   if(ObjectFind(0, btnName) < 0)
   {
      ObjectCreate(0, btnName, OBJ_BUTTON, 0, 0, 0);
   }
   ObjectSetInteger(0, btnName, OBJPROP_XDISTANCE, textX);
   ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, 340); // Moved down to fit rows
   ObjectSetInteger(0, btnName, OBJPROP_XSIZE, panelWidth - (margin * 2));
   ObjectSetInteger(0, btnName, OBJPROP_YSIZE, 32);
   ObjectSetInteger(0, btnName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, btnName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, btnName, OBJPROP_TEXT, "EA STATUS: ACTIVE");
   ObjectSetString(0, btnName, OBJPROP_FONT, "Segoe UI Semibold");
   ObjectSetInteger(0, btnName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnName, OBJPROP_HIDDEN, true);
   
   UpdateButtonState();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Display active status information on the dashboard               |
//+------------------------------------------------------------------+
void DrawChartStatus(double currentADX, double currentATR, bool reversionModeActive)
{
   if(ObjectFind(0, "DbPanelBg") < 0)
   {
      CreateInterface();
   }
   
   if(!g_eaRunning)
   {
      ObjectSetString(0, "DbTimeframe", OBJPROP_TEXT, "         SYSTEM PAUSED         ");
      ObjectSetInteger(0, "DbTimeframe", OBJPROP_COLOR, C'239,83,80'); 
      
      ObjectSetString(0, "DbLotSize",   OBJPROP_TEXT, "No new trades allowed.");
      ObjectSetString(0, "DbADX",       OBJPROP_TEXT, "Active positions will");
      ObjectSetString(0, "DbATR",       OBJPROP_TEXT, "still be managed safely.");
      ObjectSetString(0, "DbMode",      OBJPROP_TEXT, "");
      ObjectSetString(0, "DbSL",        OBJPROP_TEXT, "");
      ObjectSetString(0, "DbBias",      OBJPROP_TEXT, "");
      ObjectSetString(0, "DbDecision",  OBJPROP_TEXT, "");
      ObjectSetString(0, "DbConviction",OBJPROP_TEXT, "");
      ObjectSetString(0, "DbReason",    OBJPROP_TEXT, "");
      ChartRedraw();
      return;
   }
   
   string tfName = "UNKNOWN";
   ENUM_TIMEFRAMES period = _Period;
   if(period == PERIOD_M1) tfName = "M1 (1-Minute)";
   else if(period == PERIOD_M5) tfName = "M5 (5-Minute)";
   else if(period == PERIOD_M15) tfName = "M15 (15-Minute)";
   else if(period == PERIOD_H1) tfName = "H1 (1-Hour)";
   
   string modeStr = reversionModeActive ? "SIDEWAYS (Limits)" : "TRENDING (Stops)";
   
   ObjectSetString(0, "DbTimeframe", OBJPROP_TEXT, "Chart Timeframe : " + tfName);
   ObjectSetInteger(0, "DbTimeframe", OBJPROP_COLOR, clrWhite);
   
   ObjectSetString(0, "DbLotSize",   OBJPROP_TEXT, StringFormat("Dynamic Lot Size: %.2f lots", g_lotSize));
   ObjectSetString(0, "DbADX",       OBJPROP_TEXT, StringFormat("Current ADX     : %.2f (Min: %.1f)", currentADX, g_minADX));
   ObjectSetString(0, "DbATR",       OBJPROP_TEXT, StringFormat("Current ATR     : %.2f (Min: %.2f)", currentATR, g_minATR));
   ObjectSetString(0, "DbMode",      OBJPROP_TEXT, "Active Mode     : " + modeStr);
   ObjectSetString(0, "DbSL",        OBJPROP_TEXT, StringFormat("Stop Loss (ATR) : %.2f $", g_stopLossDist));
   
   // AI Daily Bias
   ObjectSetString(0, "DbBias",      OBJPROP_TEXT, "AI Daily Bias   : " + g_dailySentiment);
   if(g_dailySentiment == "BUY_ONLY")
      ObjectSetInteger(0, "DbBias", OBJPROP_COLOR, C'76,175,80');  // Green
   else if(g_dailySentiment == "SELL_ONLY")
      ObjectSetInteger(0, "DbBias", OBJPROP_COLOR, C'239,83,80'); // Red
   else
      ObjectSetInteger(0, "DbBias", OBJPROP_COLOR, C'255,179,0'); // Yellow
   
   // AI Decision
   ObjectSetString(0, "DbDecision",  OBJPROP_TEXT, "AI Decision     : " + g_aiDecision);
   if(StringFind(g_aiDecision, "BUY") >= 0)
      ObjectSetInteger(0, "DbDecision", OBJPROP_COLOR, C'76,175,80');  // Green
   else if(StringFind(g_aiDecision, "SELL") >= 0)
      ObjectSetInteger(0, "DbDecision", OBJPROP_COLOR, C'239,83,80'); // Red
   else if(StringFind(g_aiDecision, "HOLD") >= 0)
      ObjectSetInteger(0, "DbDecision", OBJPROP_COLOR, C'255,179,0'); // Yellow
   else
      ObjectSetInteger(0, "DbDecision", OBJPROP_COLOR, clrWhite);
   
   // AI Conviction
   string convictionStr = (g_aiDecision == "LOCAL RULES" || g_aiDecision == "WAITING") ? "N/A" : StringFormat("%d%%", g_aiConviction);
   if(g_aiConviction >= 80) convictionStr += " (HIGH CONFIDENCE)";
   else if(g_aiConviction >= 50) convictionStr += " (MEDIUM CONFIDENCE)";
   else if(g_aiConviction > 0) convictionStr += " (LOW CONFIDENCE - BLOCKED)";
   ObjectSetString(0, "DbConviction", OBJPROP_TEXT, "AI Conviction   : " + convictionStr);
   
   if(g_aiDecision == "LOCAL RULES" || g_aiDecision == "WAITING")
      ObjectSetInteger(0, "DbConviction", OBJPROP_COLOR, clrWhite);
   else if(g_aiConviction >= 80)
      ObjectSetInteger(0, "DbConviction", OBJPROP_COLOR, C'76,175,80'); // Green
   else if(g_aiConviction >= 50)
      ObjectSetInteger(0, "DbConviction", OBJPROP_COLOR, C'255,179,0'); // Yellow
   else
      ObjectSetInteger(0, "DbConviction", OBJPROP_COLOR, C'239,83,80'); // Red
   
   // AI Reason (truncated at 32 chars to fit panel nicely)
   string cleanReason = g_aiReason;
   if(StringLen(cleanReason) > 32)
   {
      cleanReason = StringSubstr(cleanReason, 0, 29) + "...";
   }
   ObjectSetString(0, "DbReason",    OBJPROP_TEXT, "AI Reason       : " + cleanReason);
   
   // Highlight Active Mode Color
   if(reversionModeActive)
      ObjectSetInteger(0, "DbMode", OBJPROP_COLOR, C'255,179,0'); 
   else
      ObjectSetInteger(0, "DbMode", OBJPROP_COLOR, C'76,175,80');  
      
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Count active trades and pending orders for safety                |
//+------------------------------------------------------------------+
int CountActiveTrades()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         count++;
      }
   }
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Calculate dynamic SL distance, Entry Offset and Lot Size         |
//+------------------------------------------------------------------+
void CalculateDynamicSLAndLots()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0) balance = AccountInfoDouble(ACCOUNT_EQUITY);
   
   double atrVal[];
   ArraySetAsSeries(atrVal, true);
   double currentATR = 0.80; 
   if(g_atrHandle != INVALID_HANDLE && CopyBuffer(g_atrHandle, 0, 1, 1, atrVal) > 0)
   {
      currentATR = atrVal[0];
   }
   
   if(InpUseATROffset)
   {
      g_priceOffset = NormalizeDouble(g_atrOffsetMultiplier * currentATR, _Digits);
      double minSafeOffset = (InpTimeframeMode == TF_M1 || (InpTimeframeMode == TF_AUTO && _Period == PERIOD_M1)) ? 0.10 : 0.20;
      if(g_priceOffset < minSafeOffset) g_priceOffset = minSafeOffset;
   }
   
   if(InpUseATRStopLoss)
   {
      g_stopLossDist = NormalizeDouble(g_atrSLMultiplier * currentATR, _Digits);
      double minSafeSL = (InpTimeframeMode == TF_M1 || (InpTimeframeMode == TF_AUTO && _Period == PERIOD_M1)) ? 0.80 : 1.30;
      if(g_stopLossDist < minSafeSL) g_stopLossDist = minSafeSL;
   }
   else
   {
      ENUM_TIMEFRAMES period = _Period;
      if(period == PERIOD_M1)       g_stopLossDist = 1.30;
      else if(period == PERIOD_M5)  g_stopLossDist = 2.00;
      else if(period == PERIOD_M15) g_stopLossDist = 3.50;
      else if(period == PERIOD_H1)  g_stopLossDist = 8.00;
      else                          g_stopLossDist = InpStopLossDist;
   }
   
   double dollarRisk = InpTargetRiskUSD;
   if(InpEnableCompounding)
   {
      dollarRisk = (balance / InpBalanceStep) * InpTargetRiskUSD;
   }
   
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   if(tickSize > 0.0 && tickValue > 0.0 && g_stopLossDist > 0.0)
   {
      g_lotSize = dollarRisk / ((g_stopLossDist / tickSize) * tickValue);
   }
   else
   {
      g_lotSize = InpLotSize; 
   }
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   g_lotSize = MathFloor(g_lotSize / lotStep) * lotStep;
   if(g_lotSize < minLot) g_lotSize = minLot;
   if(g_lotSize > maxLot) g_lotSize = maxLot;
}

//+------------------------------------------------------------------+
//| Load dynamic presets based on the timeframe mode                 |
//+------------------------------------------------------------------+
void LoadTimeframePresets()
{
   ENUM_TF_MODE activeMode = InpTimeframeMode;
   if(InpTimeframeMode == TF_AUTO)
   {
      ENUM_TIMEFRAMES period = _Period;
      if(period == PERIOD_M1)       activeMode = TF_M1;
      else if(period == PERIOD_M5)  activeMode = TF_M5;
      else if(period == PERIOD_M15) activeMode = TF_M15;
      else if(period == PERIOD_H1)  activeMode = TF_H1;
      else                          activeMode = TF_M1; 
   }

   if(activeMode == TF_M1)
   {
      g_minADX             = 22.0; 
      g_atrSLMultiplier    = 1.6;  
      g_atrOffsetMultiplier = 0.20;
      g_candleTrailBuffer  = 0.05;
   }
   else if(activeMode == TF_M5)
   {
      g_minADX             = 20.0;
      g_atrSLMultiplier    = 1.5;
      g_atrOffsetMultiplier = 0.15;
      g_candleTrailBuffer  = 0.10;
   }
   else if(activeMode == TF_M15)
   {
      g_minADX             = 20.0;
      g_atrSLMultiplier    = 1.5;
      g_atrOffsetMultiplier = 0.15;
      g_candleTrailBuffer  = 0.20;
   }
   else if(activeMode == TF_H1)
   {
      g_minADX             = 18.0; 
      g_atrSLMultiplier    = 1.4;
      g_atrOffsetMultiplier = 0.12;
      g_candleTrailBuffer  = 0.50;
   }
   else 
   {
      g_minADX             = InpMinADX;
      g_atrSLMultiplier    = InpATRMultiplier;
      g_atrOffsetMultiplier = InpATROffsetMultiplier;
      g_candleTrailBuffer  = InpCandleTrailBuffer;
   }

   CalculateDynamicSLAndLots();
   
   if(activeMode == TF_M1)
   {
      if(!InpUseATROffset) g_priceOffset = 0.25;
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
      g_minATR           = 0.35; 
   }
   else if(activeMode == TF_M5)
   {
      if(!InpUseATROffset) g_priceOffset = 0.30;
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
      g_minATR           = 0.60;
   }
   else if(activeMode == TF_M15)
   {
      if(!InpUseATROffset) g_priceOffset = 0.40;
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
      g_minATR           = 1.20;
   }
   else if(activeMode == TF_H1)
   {
      if(!InpUseATROffset) g_priceOffset = 0.80;
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
      g_minATR           = 3.00;
   }
   else 
   {
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
      g_minATR           = InpMinATR;
      
      if(!InpUseATROffset)  g_priceOffset = InpPriceOffset;
      if(!InpUseATRStopLoss) g_stopLossDist = InpStopLossDist;
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
            if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP ||
               type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT)
            {
               trade.OrderDelete(ticket);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage active positions on candle close (Active Loss-Cutting)    |
//+------------------------------------------------------------------+
void ManageCandleCloseLossCutting()
{
   double stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            
            double prevOpen  = iOpen(_Symbol, _Period, 1);
            double prevClose = iClose(_Symbol, _Period, 1);
            double prevHigh  = iHigh(_Symbol, _Period, 1);
            double prevLow   = iLow(_Symbol, _Period, 1);
            
            if(type == POSITION_TYPE_BUY)
            {
               if(InpEnableRejectionExit && prevClose < prevOpen)
               {
                  Print(StringFormat("[V10 SOFT STOP] Closing BUY ticket #%I64u due to Bearish Close.", ticket));
                  trade.PositionClose(ticket);
                  continue;
               }
               
               if(InpEnableCandleTrail)
               {
                  double targetSL = NormalizeDouble(prevLow - g_candleTrailBuffer, _Digits);
                  if(targetSL > currentSL || currentSL == 0.0)
                  {
                     double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                     if(currentBid - targetSL >= stopsLevel)
                     {
                        if(trade.PositionModify(ticket, targetSL, currentTP))
                        {
                           Print(StringFormat("[V10 CANDLE TRAIL] Trailed BUY SL to candle Low: %.2f", targetSL));
                        }
                     }
                  }
               }
            }
            else if(type == POSITION_TYPE_SELL)
            {
               if(InpEnableRejectionExit && prevClose > prevOpen)
               {
                  Print(StringFormat("[V10 SOFT STOP] Closing SELL ticket #%I64u due to Bullish Close.", ticket));
                  trade.PositionClose(ticket);
                  continue;
               }
               
               if(InpEnableCandleTrail)
               {
                  double targetSL = NormalizeDouble(prevHigh + g_candleTrailBuffer, _Digits);
                  if(targetSL < currentSL || currentSL == 0.0)
                  {
                     double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                     if(targetSL - currentAsk >= stopsLevel)
                     {
                        if(trade.PositionModify(ticket, targetSL, currentTP))
                        {
                           Print(StringFormat("[V10 CANDLE TRAIL] Trailed SELL SL to candle High: %.2f", targetSL));
                        }
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Simple string parsing helper to extract value by key from JSON   |
//+------------------------------------------------------------------+
string ExtractJSONValue(string json, string key)
{
   string searchKey = "\"" + key + "\"";
   int startIdx = StringFind(json, searchKey);
   if(startIdx < 0) return "";
   
   int colonIdx = StringFind(json, ":", startIdx + StringLen(searchKey));
   if(colonIdx < 0) return "";
   
   int valStart = colonIdx + 1;
   while(valStart < StringLen(json) && 
         (StringSubstr(json, valStart, 1) == " " || 
          StringSubstr(json, valStart, 1) == "\t" || 
          StringSubstr(json, valStart, 1) == "\r" || 
          StringSubstr(json, valStart, 1) == "\n" || 
          StringSubstr(json, valStart, 1) == "\"" ||
          StringSubstr(json, valStart, 1) == "'"))
   {
      valStart++;
   }
   
   int valEnd = valStart;
   while(valEnd < StringLen(json))
   {
      string charStr = StringSubstr(json, valEnd, 1);
      if(charStr == "\"" || charStr == "'" || charStr == "," || charStr == "}" || charStr == "\r" || charStr == "\n")
      {
         break;
      }
      valEnd++;
   }
   
   if(valEnd > valStart)
   {
      return StringSubstr(json, valStart, valEnd - valStart);
   }
   return "";
}

//+------------------------------------------------------------------+
//| Central AI client caller with automatic failover (Gemini->Groq)   |
//+------------------------------------------------------------------+
bool CallAI(string prompt, string &responseText)
{
   // 1. Try Gemini first
   if(InpGeminiAPIKey != "" && InpGeminiAPIKey != "PASTE_YOUR_API_KEY_HERE")
   {
      string requestBody = "{\"contents\":[{\"parts\":[{\"text\":\"" + prompt + "\"}]}]}";
      string url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=" + InpGeminiAPIKey;
      string headers = "Content-Type: application/json\r\n";
      
      char post[];
      char result[];
      string responseHeaders = "";
      int bytes = StringToCharArray(requestBody, post, 0, WHOLE_ARRAY, CP_UTF8);
      if(bytes > 0 && post[bytes-1] == 0)
      {
         ArrayResize(post, bytes - 1);
      }
      
      ResetLastError();
      int res = WebRequest("POST", url, headers, 8000, post, result, responseHeaders);
      if(res == 200)
      {
         responseText = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
         return true;
      }
      else
      {
         string err = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
         Print("[Gemini Fail] HTTP Status: ", res, ", Error Response: ", err);
      }
   }
   
   // 2. Failover to Groq (Llama-3.1-8B-Instant)
   if(InpGroqAPIKey != "" && InpGroqAPIKey != "PASTE_YOUR_API_KEY_HERE")
   {
      string cleanPrompt = prompt;
      StringReplace(cleanPrompt, "\"", "\\\"");
      string requestBody = "{\"model\":\"llama-3.1-8b-instant\",\"messages\":[{\"role\":\"user\",\"content\":\"" + cleanPrompt + "\"}],\"temperature\":0.2}";
      string url = "https://api.groq.com/openai/v1/chat/completions";
      string headers = "Content-Type: application/json\r\nAuthorization: Bearer " + InpGroqAPIKey + "\r\n";
      
      char post[];
      char result[];
      string responseHeaders = "";
      int bytes = StringToCharArray(requestBody, post, 0, WHOLE_ARRAY, CP_UTF8);
      if(bytes > 0 && post[bytes-1] == 0)
      {
         ArrayResize(post, bytes - 1);
      }
      
      ResetLastError();
      int res = WebRequest("POST", url, headers, 8000, post, result, responseHeaders);
      if(res == 200)
      {
         responseText = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
         return true;
      }
      else
      {
         string err = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
         Print("[Groq Fail] HTTP Status: ", res, ", Error Response: ", err);
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Query AI for Daily Sentiment Directional Anchor                  |
//+------------------------------------------------------------------+
bool QueryAIDailySentiment()
{
   string dailyHistory = "";
   for(int i = 3; i >= 1; i--)
   {
      dailyHistory += StringFormat("[D1 Bar %d: O=%.2f, H=%.2f, L=%.2f, C=%.2f] ", 
         i, iOpen(_Symbol, PERIOD_D1, i), iHigh(_Symbol, PERIOD_D1, i), iLow(_Symbol, PERIOD_D1, i), iClose(_Symbol, PERIOD_D1, i));
   }
   
   string prompt = StringFormat(
      "Gold (XAUUSD) Daily Bias Analysis. Current price=%.2f. Daily candles history: %s. "+
      "As a professional macro analyst, determine today's directional bias. "+
      "Respond strictly with a JSON object containing: 'bias' ('BUY_ONLY', 'SELL_ONLY', or 'BI_DIRECTIONAL') and 'reason' (short 10 words). "+
      "Example output format: { 'bias': 'BUY_ONLY', 'reason': 'Strong daily bullish engulfing' }.",
      SymbolInfoDouble(_Symbol, SYMBOL_BID), dailyHistory
   );
   
   string responseText = "";
   if(!CallAI(prompt, responseText))
   {
      g_dailySentiment = "BI_DIRECTIONAL";
      g_dailySentimentReason = "AI offline, trading both sides.";
      return false;
   }
   
   string rawBias = ExtractJSONValue(responseText, "bias");
   string rawReason = ExtractJSONValue(responseText, "reason");
   
   if(StringFind(rawBias, "BUY_ONLY") >= 0) g_dailySentiment = "BUY_ONLY";
   else if(StringFind(rawBias, "SELL_ONLY") >= 0) g_dailySentiment = "SELL_ONLY";
   else g_dailySentiment = "BI_DIRECTIONAL";
   
   g_dailySentimentReason = (rawReason != "") ? rawReason : "Daily bias analyzed.";
   Print("[AI Bias] Daily Sentiment set to: ", g_dailySentiment, " (Reason: ", g_dailySentimentReason, ")");
   return true;
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
            double currentVolume = PositionGetDouble(POSITION_VOLUME);
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
            
            if(g_enableTimeDecay)
            {
               int durationSec = (int)(TimeCurrent() - openTime);
               if(durationSec >= g_maxHoldMinutes * 60)
               {
                  trade.PositionClose(ticket);
                  continue; 
               }
            }
            
            if(type == POSITION_TYPE_BUY)
            {
               double currentProfit = currentBid - entryPrice;
               double targetSL = 0.0;
               
               if(g_enableStage2 && currentProfit >= g_stage2Trigger)
               {
                  targetSL = NormalizeDouble(currentBid - g_stage2Distance, _Digits);
               }
               else if(g_enableStage1 && currentProfit >= g_stage1Trigger)
               {
                  targetSL = NormalizeDouble(currentBid - g_stage1Distance, _Digits);
               }
               else if(g_enableBE && currentProfit >= g_beTrigger)
               {
                  if(InpEnablePartialClose && currentVolume >= g_lotSize)
                  {
                     double closeLots = NormalizeDouble(g_lotSize / 2.0, 2);
                     if(closeLots > 0.0)
                     {
                        trade.PositionClosePartial(ticket, closeLots);
                     }
                  }
                  targetSL = NormalizeDouble(entryPrice + g_beOffset, _Digits);
               }
               
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
               
               if(g_enableStage2 && currentProfit >= g_stage2Trigger)
               {
                  targetSL = NormalizeDouble(currentAsk + g_stage2Distance, _Digits);
               }
               else if(g_enableStage1 && currentProfit >= g_stage1Trigger)
               {
                  targetSL = NormalizeDouble(currentAsk + g_stage1Distance, _Digits);
               }
               else if(g_enableBE && currentProfit >= g_beTrigger)
               {
                  if(InpEnablePartialClose && currentVolume >= g_lotSize)
                  {
                     double closeLots = NormalizeDouble(g_lotSize / 2.0, 2);
                     if(closeLots > 0.0)
                     {
                        trade.PositionClosePartial(ticket, closeLots);
                     }
                  }
                  targetSL = NormalizeDouble(entryPrice - g_beOffset, _Digits);
               }
               
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
//| Query AI for Active Trade Management (Dynamic Trailing Stop)     |
//+------------------------------------------------------------------+
void QueryAIActiveTradeManagement()
{
   double stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentTP = PositionGetDouble(POSITION_TP);
         double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double currentProfit = (type == POSITION_TYPE_BUY) ? (currentPrice - entryPrice) : (entryPrice - currentPrice);
         
         // Gather recent 3 bars history for trend context
         string barsHistory = "";
         for(int j = 3; j >= 1; j--)
         {
            barsHistory += StringFormat("[Bar %d: O=%.2f, H=%.2f, L=%.2f, C=%.2f] ", 
               j, iOpen(_Symbol, _Period, j), iHigh(_Symbol, _Period, j), iLow(_Symbol, _Period, j), iClose(_Symbol, _Period, j));
         }
         
         string prompt = StringFormat(
            "Gold (XAUUSD) active position management review. Type=%s, EntryPrice=%.2f, CurrentPrice=%.2f, CurrentSL=%.2f, CurrentProfit=%.2f. "+
            "Recent 3 M1 candles: %s. "+
            "Evaluate position exit/trail. Respond strictly with a JSON object containing: 'action' ('HOLD', 'TIGHTEN', 'WIDEN', or 'CLOSE'), 'stop_distance' (double dollar offset from current price, e.g. 0.70), and 'reason' (short 10 words). "+
            "Example format: { 'action': 'TIGHTEN', 'stop_distance': 0.60, 'reason': 'Bearish trend forming close' }.",
            (type == POSITION_TYPE_BUY ? "BUY" : "SELL"), entryPrice, currentPrice, currentSL, currentProfit, barsHistory
         );
         
         string responseText = "";
         if(CallAI(prompt, responseText))
         {
            string rawAction = ExtractJSONValue(responseText, "action");
            double stopDistance = StringToDouble(ExtractJSONValue(responseText, "stop_distance"));
            string rawReason = ExtractJSONValue(responseText, "reason");
            
            if(rawReason != "") g_aiReason = "Trade Mgmt: " + rawReason;
            
            if(rawAction == "CLOSE")
            {
               Print(StringFormat("[AI Dynamic Exit] Closing trade #%I64u. Reason: %s", ticket, rawReason));
               trade.PositionClose(ticket);
               continue;
            }
            else if((rawAction == "TIGHTEN" || rawAction == "WIDEN") && stopDistance > 0.0)
            {
               double targetSL = 0.0;
               if(type == POSITION_TYPE_BUY)
               {
                  targetSL = NormalizeDouble(currentPrice - stopDistance, _Digits);
                  // Ensure we only move SL in profit direction (trailing stop rules)
                  if(targetSL > currentSL || currentSL == 0.0)
                  {
                     if(currentPrice - targetSL >= stopsLevel)
                     {
                        trade.PositionModify(ticket, targetSL, currentTP);
                        Print(StringFormat("[AI Dynamic SL] Modified BUY #%I64u SL to %.2f (offset %.2f). Reason: %s", ticket, targetSL, stopDistance, rawReason));
                     }
                  }
               }
               else if(type == POSITION_TYPE_SELL)
               {
                  targetSL = NormalizeDouble(currentPrice + stopDistance, _Digits);
                  // Ensure we only move SL in profit direction (trailing stop rules)
                  if(targetSL < currentSL || currentSL == 0.0)
                  {
                     if(targetSL - currentPrice >= stopsLevel)
                     {
                        trade.PositionModify(ticket, targetSL, currentTP);
                        Print(StringFormat("[AI Dynamic SL] Modified SELL #%I64u SL to %.2f (offset %.2f). Reason: %s", ticket, targetSL, stopDistance, rawReason));
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Execute new order placement (Once per candle or on recovery)     |
//+------------------------------------------------------------------+
bool ExecuteNewOrderPlacement(datetime currentBarTime)
{
   double prevHigh = iHigh(_Symbol, _Period, 1);
   double prevLow  = iLow(_Symbol, _Period, 1);
   double prevClose = iClose(_Symbol, _Period, 1);

   if(prevHigh == 0 || prevLow == 0)
      return false;

   double emaVal[];
   double atrVal[];
   double rsiVal[];
   double adxVal[];
   ArraySetAsSeries(emaVal, true);
   ArraySetAsSeries(atrVal, true);
   ArraySetAsSeries(rsiVal, true);
   ArraySetAsSeries(adxVal, true);
   
   if(CopyBuffer(g_emaHandle, 0, 1, 1, emaVal) <= 0 || 
      CopyBuffer(g_atrHandle, 0, 1, 1, atrVal) <= 0 ||
      CopyBuffer(g_rsiHandle, 0, 1, 1, rsiVal) <= 0 ||
      CopyBuffer(g_adxHandle, 0, 1, 1, adxVal) <= 0)
   {
      return false;
   }
   
   double currentEMA = emaVal[0];
   double currentATR = atrVal[0];
   double currentRSI = rsiVal[0];
   double currentADX = adxVal[0];

   double atrSum = 0.0;
   int atrCount = 0;
   for(int j = 2; j <= 11; j++)
   {
      double atrTemp[];
      ArraySetAsSeries(atrTemp, true);
      if(CopyBuffer(g_atrHandle, 0, j, 1, atrTemp) > 0)
      {
         atrSum += atrTemp[0];
         atrCount++;
      }
   }
   double avgATR = (atrCount > 0) ? (atrSum / atrCount) : currentATR;
   bool isVolatilitySpike = (avgATR > 0.0 && currentATR > 1.4 * avgATR);

   double spread = GetSmoothedSpread();

   MqlDateTime dt;
   TimeCurrent(dt);
   bool isMomentumHour = false;
   if(dt.hour >= InpLondonStartHour && dt.hour < InpLondonEndHour)
   {
      isMomentumHour = true;
   }
   int currentMinutesSinceMidnight = dt.hour * 60 + dt.min;
   int nyStartMinutes = InpNYStartHour * 60 + InpNYStartMin;
   int nyEndMinutes = InpNYEndHour * 60 + InpNYEndMin;
   if(currentMinutesSinceMidnight >= nyStartMinutes && currentMinutesSinceMidnight < nyEndMinutes)
   {
      isMomentumHour = true;
   }

   // --- Query the AI Conviction Engine ---
   string barsHistory = "";
   for(int i = 5; i >= 1; i--)
   {
      barsHistory += StringFormat("[Bar %d: O=%.2f, H=%.2f, L=%.2f, C=%.2f, V=%I64d] ", 
         i, iOpen(_Symbol, _Period, i), iHigh(_Symbol, _Period, i), iLow(_Symbol, _Period, i), iClose(_Symbol, _Period, i), iVolume(_Symbol, _Period, i));
   }
   
   string prompt = StringFormat(
      "Gold (XAUUSD) setup analysis. Current price=%.2f. Indicators: ADX=%.2f, ATR=%.2f, RSI=%.2f, EMA50=%.2f. "+
      "Price History: %s. "+
      "As a professional quant, evaluate market regime (sideways limits vs breakout trend) and directional strength. "+
      "Respond strictly with a JSON object containing: 'decision' ('BUY', 'SELL', or 'HOLD'), 'conviction' (integer 0 to 100), 'regime' ('BREAKOUT' or 'REVERSION'), and 'reason' (short 10 words). "+
      "Example output: { 'decision': 'BUY', 'conviction': 85, 'regime': 'BREAKOUT', 'reason': 'Momentum breaking high' }.",
      prevClose, currentADX, currentATR, currentRSI, currentEMA, barsHistory
   );

   bool aiActive = false;
   string responseText = "";
   string rawRegime = "BREAKOUT"; // default
   
   if(InpUseGeminiAI)
   {
      aiActive = CallAI(prompt, responseText);
      if(aiActive)
      {
         string rawDecision = ExtractJSONValue(responseText, "decision");
         string rawConviction = ExtractJSONValue(responseText, "conviction");
         string rawReason = ExtractJSONValue(responseText, "reason");
         rawRegime = ExtractJSONValue(responseText, "regime");
         
         // Clean decision
         if(StringFind(rawDecision, "BUY") >= 0) g_aiDecision = "BUY";
         else if(StringFind(rawDecision, "SELL") >= 0) g_aiDecision = "SELL";
         else if(StringFind(rawDecision, "HOLD") >= 0) g_aiDecision = "HOLD";
         else g_aiDecision = "HOLD";
         
         g_aiConviction = (int)StringToInteger(rawConviction);
         if(g_aiConviction < 0) g_aiConviction = 0;
         if(g_aiConviction > 100) g_aiConviction = 100;
         
         g_aiReason = (rawReason != "") ? rawReason : "AI analyzed successfully.";
      }
      else
      {
         g_aiDecision = "API ERROR";
         g_aiConviction = 0;
         g_aiReason = "AI services offline.";
      }
   }
   else
   {
      g_aiDecision = "LOCAL RULES";
      g_aiConviction = 0;
      g_aiReason = "AI Engine is disabled.";
   }

   // Lock queries for the current candle to exactly once
   g_lastOrderPlacedBarTime = currentBarTime;

   // Dynamic Risk Scaling factor based on conviction
   double convictionMultiplier = 1.0;
   if(aiActive)
   {
      // Block trades below the threshold
      if(g_aiConviction < InpMinConviction)
      {
         Print(StringFormat("[Conviction Engine Blocked] Score %d is below the minimum threshold %d. Reason: %s", 
            g_aiConviction, InpMinConviction, g_aiReason));
         g_aiDecision = "BLOCKED";
         DrawChartStatus(currentADX, currentATR, (rawRegime == "REVERSION"));
         return false; 
      }
      
      // Scale position size dynamically:
      // High Conviction (80+): 100% size
      // Medium Conviction (50-79): 50% size
      if(g_aiConviction < 80)
      {
         convictionMultiplier = 0.50;
      }
   }

   double finalLotSize = NormalizeDouble(g_lotSize * convictionMultiplier, 2);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(finalLotSize < minLot) finalLotSize = minLot;

   // --- Determine Entry Mode (AI Regime Switch or local ADX fallback) ---
   bool useReversionMode = false;
   if(InpEnableHybridMode)
   {
      if(aiActive)
      {
         useReversionMode = (rawRegime == "REVERSION");
      }
      else
      {
         // Fallback to local indicators
         if(InpUseSessionHours && !isMomentumHour)
         {
            useReversionMode = true;
            if(isVolatilitySpike)
            {
               useReversionMode = false;
            }
         }
         else if(currentADX < g_minADX)
         {
            useReversionMode = true;
         }
      }
   }

   // Place Orders in accordance with Daily Sentiment Anchor
   if(useReversionMode)
   {
      // --- SIDEWAYS RANGE MODE (Limit Orders) ---
      double reversionOffset = (InpTimeframeMode == TF_M1 || (InpTimeframeMode == TF_AUTO && _Period == PERIOD_M1)) ? 0.08 : 0.15;
      
      bool placeBuy = (g_dailySentiment != "SELL_ONLY") && (!aiActive || StringFind(g_aiDecision, "BUY") >= 0);
      bool placeSell = (g_dailySentiment != "BUY_ONLY") && (!aiActive || StringFind(g_aiDecision, "SELL") >= 0);
      
      if(placeBuy)
      {
         double buyLimitPrice  = NormalizeDouble(prevLow - reversionOffset, _Digits);
         double buySL          = NormalizeDouble(buyLimitPrice - g_stopLossDist, _Digits);
         double buyTP          = (g_takeProfitDist > 0.0) ? NormalizeDouble(buyLimitPrice + g_takeProfitDist, _Digits) : 0.0;
         trade.BuyLimit(finalLotSize, buyLimitPrice, _Symbol, buySL, buyTP, ORDER_TIME_GTC, 0, "AI Buy Limit Reversion");
      }
      
      if(placeSell)
      {
         double sellLimitPrice = NormalizeDouble(prevHigh + reversionOffset, _Digits);
         double sellSL         = NormalizeDouble(sellLimitPrice + g_stopLossDist, _Digits);
         double sellTP         = (g_takeProfitDist > 0.0) ? NormalizeDouble(sellLimitPrice - g_takeProfitDist, _Digits) : 0.0;
         trade.SellLimit(finalLotSize, sellLimitPrice, _Symbol, sellSL, sellTP, ORDER_TIME_GTC, 0, "AI Sell Limit Reversion");
      }
      
      return true;
   }
   else
   {
      // --- TRENDING BREAKOUT MODE (Stop Orders) ---
      if(InpUseATRFilter && currentATR < g_minATR) return false;
      
      if(InpUseVolumeFilter)
      {
         long prevVolume = iVolume(_Symbol, _Period, 1);
         long volumeSum = 0;
         for(int j = 2; j <= 11; j++)
         {
            volumeSum += iVolume(_Symbol, _Period, j);
         }
         double avgVolume = volumeSum / 10.0;
         if(prevVolume < avgVolume) return false;
      }

      bool allowBuy = (g_dailySentiment != "SELL_ONLY");
      bool allowSell = (g_dailySentiment != "BUY_ONLY");
      
      if(aiActive)
      {
         allowBuy  = allowBuy && (StringFind(g_aiDecision, "BUY") >= 0);
         allowSell = allowSell && (StringFind(g_aiDecision, "SELL") >= 0);
      }
      else
      {
         if(InpUseEMAFilter)
         {
            allowBuy = allowBuy && (prevClose > currentEMA);
            allowSell = allowSell && (prevClose < currentEMA);
         }
         
         if(InpUseMTFTrendFilter)
         {
            double emaHighVal[];
            ArraySetAsSeries(emaHighVal, true);
            if(CopyBuffer(g_emaHigherHandle, 0, 1, 1, emaHighVal) > 0)
            {
               double higherEMA = emaHighVal[0];
               double higherClose = iClose(_Symbol, GetHigherTimeframe(), 1);
               allowBuy  = allowBuy && (higherClose > higherEMA);
               allowSell = allowSell && (higherClose < higherEMA);
            }
         }

         if(InpUseRSIFilter)
         {
            allowBuy  = allowBuy && (currentRSI < 70.0);
            allowSell = allowSell && (currentRSI > 30.0);
         }
      }

      bool orderPlaced = false;
      if(allowBuy)
      {
         double buyStopPrice  = NormalizeDouble(prevHigh + g_priceOffset + spread, _Digits);
         double buySL         = NormalizeDouble(buyStopPrice - g_stopLossDist, _Digits);
         double buyTP         = (g_takeProfitDist > 0.0) ? NormalizeDouble(buyStopPrice + g_takeProfitDist, _Digits) : 0.0;
         
         trade.BuyStop(finalLotSize, buyStopPrice, _Symbol, buySL, buyTP, ORDER_TIME_GTC, 0, "AI Buy Stop Breakout");
         orderPlaced = true;
      }
      
      if(allowSell)
      {
         double sellStopPrice = NormalizeDouble(prevLow - g_priceOffset, _Digits);
         double sellSL        = NormalizeDouble(sellStopPrice + g_stopLossDist, _Digits);
         double sellTP        = (g_takeProfitDist > 0.0) ? NormalizeDouble(sellStopPrice - g_takeProfitDist, _Digits) : 0.0;
         
         trade.SellStop(finalLotSize, sellStopPrice, _Symbol, sellSL, sellTP, ORDER_TIME_GTC, 0, "AI Sell Stop Breakout");
         orderPlaced = true;
      }
      
      if(orderPlaced)
      {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Query Google Gemini and Groq APIs to verify keys on startup      |
//+------------------------------------------------------------------+
void TestAIEngines()
{
   bool geminiSuccess = false;
   bool groqSuccess = false;
   
   // 1. Test Gemini
   if(InpGeminiAPIKey != "" && InpGeminiAPIKey != "PASTE_YOUR_API_KEY_HERE")
   {
      string prompt = "Respond strictly with the single word: OK";
      string responseText = "";
      
      string requestBody = "{\"contents\":[{\"parts\":[{\"text\":\"" + prompt + "\"}]}]}";
      string url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=" + InpGeminiAPIKey;
      string headers = "Content-Type: application/json\r\n";
      
      char post[];
      char result[];
      string responseHeaders = "";
      int bytes = StringToCharArray(requestBody, post, 0, WHOLE_ARRAY, CP_UTF8);
      if(bytes > 0 && post[bytes-1] == 0) ArrayResize(post, bytes - 1);
      
      ResetLastError();
      int res = WebRequest("POST", url, headers, 8000, post, result, responseHeaders);
      if(res == 200)
      {
         Print("[Gemini API Diagnostic] Connection successful!");
         geminiSuccess = true;
      }
      else
      {
         string errText = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
         Print("[Gemini API Diagnostic Failed] HTTP Status: ", res, ", Response: ", errText);
      }
   }
   
   // 2. Test Groq
   if(InpGroqAPIKey != "" && InpGroqAPIKey != "PASTE_YOUR_API_KEY_HERE")
   {
      string prompt = "Respond strictly with the word OK";
      string responseText = "";
      
      string requestBody = "{\"model\":\"llama-3.1-8b-instant\",\"messages\":[{\"role\":\"user\",\"content\":\"" + prompt + "\"}],\"temperature\":0.2}";
      string url = "https://api.groq.com/openai/v1/chat/completions";
      string headers = "Content-Type: application/json\r\nAuthorization: Bearer " + InpGroqAPIKey + "\r\n";
      
      char post[];
      char result[];
      string responseHeaders = "";
      int bytes = StringToCharArray(requestBody, post, 0, WHOLE_ARRAY, CP_UTF8);
      if(bytes > 0 && post[bytes-1] == 0) ArrayResize(post, bytes - 1);
      
      ResetLastError();
      int res = WebRequest("POST", url, headers, 8000, post, result, responseHeaders);
      if(res == 200)
      {
         Print("[Groq API Diagnostic] Connection successful!");
         groqSuccess = true;
      }
      else
      {
         string errText = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
         Print("[Groq API Diagnostic Failed] HTTP Status: ", res, ", Response: ", errText);
      }
   }
   
   // 3. Update Dashboard Status
   if(geminiSuccess)
   {
      g_aiDecision = "WAITING";
      g_aiReason = "Gemini API OK";
   }
   else if(groqSuccess)
   {
      g_aiDecision = "WAITING";
      g_aiReason = "Groq API OK (Gemini Offline)";
   }
   else
   {
      g_aiDecision = "API ERROR";
      g_aiReason = "Both AI services offline";
   }
}

//+------------------------------------------------------------------+
//| Expert initialization presets and indicators loading             |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   g_lastBarTime = 0;
   g_lastOrderPlacedBarTime = 0;
   g_lastDay = 0;
   g_spreadCount = 0;
   ArrayInitialize(g_spreadBuffer, 0.0);
   
   // 1. Initialize Indicators first
   g_emaHandle = iMA(_Symbol, _Period, 50, 0, MODE_EMA, PRICE_CLOSE);
   g_emaHigherHandle = iMA(_Symbol, GetHigherTimeframe(), 50, 0, MODE_EMA, PRICE_CLOSE);
   g_atrHandle = iATR(_Symbol, _Period, 14);
   g_rsiHandle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   g_adxHandle = iADX(_Symbol, _Period, 14);
   
   if(g_emaHandle == INVALID_HANDLE || g_emaHigherHandle == INVALID_HANDLE || 
      g_atrHandle == INVALID_HANDLE || g_rsiHandle == INVALID_HANDLE || g_adxHandle == INVALID_HANDLE)
   {
      Print("[V10 INIT ERROR] Failed to initialize indicators.");
      return(INIT_FAILED);
   }
   
   // 2. Load presets safely
   LoadTimeframePresets();
   
   // 3. Create UI elements
   CreateInterface();
   
   // 4. Test AI Engines connection live on startup
   TestAIEngines();
   
   // 5. Establish initial Daily Sentiment Anchor
   QueryAIDailySentiment();
   
   MqlDateTime dt;
   TimeCurrent(dt);
   g_lastDay = dt.day;
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment(""); 
   IndicatorRelease(g_emaHandle);
   IndicatorRelease(g_emaHigherHandle);
   IndicatorRelease(g_atrHandle);
   IndicatorRelease(g_rsiHandle);
   IndicatorRelease(g_adxHandle);
   
   // Delete UI elements
   ObjectDelete(0, "DbPanelBg");
   ObjectDelete(0, "DbTitle");
   ObjectDelete(0, "DbTimeframe");
   ObjectDelete(0, "DbLotSize");
   ObjectDelete(0, "DbADX");
   ObjectDelete(0, "DbATR");
   ObjectDelete(0, "DbMode");
   ObjectDelete(0, "DbSL");
   ObjectDelete(0, "DbBias");
   ObjectDelete(0, "DbDecision");
   ObjectDelete(0, "DbConviction");
   ObjectDelete(0, "DbReason");
   ObjectDelete(0, "BtnEAToggle");
}

//+------------------------------------------------------------------+
//| Chart Event Handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == "BtnEAToggle")
      {
         g_eaRunning = !g_eaRunning;
         UpdateButtonState();
         ChartRedraw();
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateSpreadBuffer();
   LoadTimeframePresets();

   if(VerifyTimeframeMismatch())
   {
      return;
   }

   ManageActivePositions();

   double emaVal[];
   double atrVal[];
   double rsiVal[];
   double adxVal[];
   ArraySetAsSeries(emaVal, true);
   ArraySetAsSeries(atrVal, true);
   ArraySetAsSeries(rsiVal, true);
   ArraySetAsSeries(adxVal, true);
   
   double currentADX = 0.0;
   double currentATR = 0.0;
   bool useReversionMode = false;
   
   if(CopyBuffer(g_emaHandle, 0, 1, 1, emaVal) > 0 && 
      CopyBuffer(g_atrHandle, 0, 1, 1, atrVal) > 0 &&
      CopyBuffer(g_rsiHandle, 0, 1, 1, rsiVal) > 0 &&
      CopyBuffer(g_adxHandle, 0, 1, 1, adxVal) > 0)
   {
      currentADX = adxVal[0];
      currentATR = atrVal[0];
      
      MqlDateTime dt;
      TimeCurrent(dt);
      
      // Update Daily Sentiment Anchor on new calendar day
      if(dt.day != g_lastDay)
      {
         g_lastDay = dt.day;
         QueryAIDailySentiment();
      }
      
      bool isMomentumHour = false;
      if(dt.hour >= InpLondonStartHour && dt.hour < InpLondonEndHour)
      {
         isMomentumHour = true;
      }
      int currentMinutesSinceMidnight = dt.hour * 60 + dt.min;
      int nyStartMinutes = InpNYStartHour * 60 + InpNYStartMin;
      int nyEndMinutes = InpNYEndHour * 60 + InpNYEndMin;
      if(currentMinutesSinceMidnight >= nyStartMinutes && currentMinutesSinceMidnight < nyEndMinutes)
      {
         isMomentumHour = true;
      }
      
      if(InpEnableHybridMode)
      {
         if(InpUseSessionHours && !isMomentumHour)
         {
            useReversionMode = true;
            double atrSum = 0.0;
            int atrCount = 0;
            for(int j = 2; j <= 11; j++)
            {
               double atrTemp[];
               ArraySetAsSeries(atrTemp, true);
               if(CopyBuffer(g_atrHandle, 0, j, 1, atrTemp) > 0)
               {
                  atrSum += atrTemp[0];
                  atrCount++;
               }
            }
            double avgATR = (atrCount > 0) ? (atrSum / atrCount) : currentATR;
            if(avgATR > 0.0 && currentATR > 1.4 * avgATR)
            {
               useReversionMode = false;
            }
         }
         else if(currentADX < g_minADX)
         {
            useReversionMode = true;
         }
      }
   }
   
   // Keep dashboard drawn and updated on every tick
   DrawChartStatus(currentADX, currentATR, useReversionMode);

   // Check if EA is paused by the on-chart button
   if(!g_eaRunning)
   {
      CancelPendingOrders();
      return;
   }

   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   bool isNewBar = (currentBarTime != g_lastBarTime);
   
   if(isNewBar)
   {
      if(g_lastBarTime != 0)
      {
         ManageCandleCloseLossCutting();
         
         // Trigger AI active trade management dynamically on candle close
         if(CountActiveTrades() > 0)
         {
            QueryAIActiveTradeManagement();
         }
      }
      
      g_lastBarTime = currentBarTime;
      CancelPendingOrders();
   }

   // Place orders if not yet successfully processed for this candle and no open orders exist
   if(g_eaRunning && g_lastOrderPlacedBarTime != currentBarTime)
   {
      if(CountActiveTrades() == 0)
      {
         ExecuteNewOrderPlacement(currentBarTime);
      }
   }
}
//+------------------------------------------------------------------+
