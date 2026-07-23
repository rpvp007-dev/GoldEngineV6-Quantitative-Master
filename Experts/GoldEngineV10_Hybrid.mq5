//+------------------------------------------------------------------+
//|                                                GoldEngineV10.mq5 |
//|                                  Copyright 2026, GoldEngine V10  |
//|                    Adaptive Multi-Timeframe Hybrid EA (Pro)      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, GoldEngine V10"
#property link      "https://github.com/rpvp007-dev"
#property version   "20.00"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Subclass CTrade to implement automatic order retries and updates  |
//+------------------------------------------------------------------+
class CTradeSafe : public CTrade
{
public:
   bool Buy(double volume, const string symbol=NULL, double price=0, double sl=0, double tp=0, const string comment="")
   {
      int maxRetries = 3;
      for(int r = 0; r < maxRetries; r++)
      {
         if(CTrade::Buy(volume, symbol, price, sl, tp, comment))
         {
            uint retcode = ResultRetcode();
            if(retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED) return true;
         }
         PrintFormat("[Trade Retry] Buy failed (Retcode: %d). Retrying %d/%d in 200ms...", ResultRetcode(), r+1, maxRetries);
         Sleep(200);
         price = SymbolInfoDouble(symbol == NULL ? _Symbol : symbol, SYMBOL_ASK);
      }
      return false;
   }
   
   bool Sell(double volume, const string symbol=NULL, double price=0, double sl=0, double tp=0, const string comment="")
   {
      int maxRetries = 3;
      for(int r = 0; r < maxRetries; r++)
      {
         if(CTrade::Sell(volume, symbol, price, sl, tp, comment))
         {
            uint retcode = ResultRetcode();
            if(retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED) return true;
         }
         PrintFormat("[Trade Retry] Sell failed (Retcode: %d). Retrying %d/%d in 200ms...", ResultRetcode(), r+1, maxRetries);
         Sleep(200);
         price = SymbolInfoDouble(symbol == NULL ? _Symbol : symbol, SYMBOL_BID);
      }
      return false;
   }
   
   bool BuyLimit(double volume, double price, const string symbol=NULL, double sl=0, double tp=0, ENUM_ORDER_TYPE_TIME type=ORDER_TIME_GTC, datetime expiration=0, const string comment="")
   {
      int maxRetries = 3;
      for(int r = 0; r < maxRetries; r++)
      {
         if(CTrade::BuyLimit(volume, price, symbol, sl, tp, type, expiration, comment))
         {
            uint retcode = ResultRetcode();
            if(retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED) return true;
         }
         PrintFormat("[Trade Retry] BuyLimit failed (Retcode: %d). Retrying %d/%d in 200ms...", ResultRetcode(), r+1, maxRetries);
         Sleep(200);
      }
      return false;
   }
   
   bool SellLimit(double volume, double price, const string symbol=NULL, double sl=0, double tp=0, ENUM_ORDER_TYPE_TIME type=ORDER_TIME_GTC, datetime expiration=0, const string comment="")
   {
      int maxRetries = 3;
      for(int r = 0; r < maxRetries; r++)
      {
         if(CTrade::SellLimit(volume, price, symbol, sl, tp, type, expiration, comment))
         {
            uint retcode = ResultRetcode();
            if(retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED) return true;
         }
         PrintFormat("[Trade Retry] SellLimit failed (Retcode: %d). Retrying %d/%d in 200ms...", ResultRetcode(), r+1, maxRetries);
         Sleep(200);
      }
      return false;
   }
   
   bool BuyStop(double volume, double price, const string symbol=NULL, double sl=0, double tp=0, ENUM_ORDER_TYPE_TIME type=ORDER_TIME_GTC, datetime expiration=0, const string comment="")
   {
      int maxRetries = 3;
      for(int r = 0; r < maxRetries; r++)
      {
         if(CTrade::BuyStop(volume, price, symbol, sl, tp, type, expiration, comment))
         {
            uint retcode = ResultRetcode();
            if(retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED) return true;
         }
         PrintFormat("[Trade Retry] BuyStop failed (Retcode: %d). Retrying %d/%d in 200ms...", ResultRetcode(), r+1, maxRetries);
         Sleep(200);
      }
      return false;
   }
   
   bool SellStop(double volume, double price, const string symbol=NULL, double sl=0, double tp=0, ENUM_ORDER_TYPE_TIME type=ORDER_TIME_GTC, datetime expiration=0, const string comment="")
   {
      int maxRetries = 3;
      for(int r = 0; r < maxRetries; r++)
      {
         if(CTrade::SellStop(volume, price, symbol, sl, tp, type, expiration, comment))
         {
            uint retcode = ResultRetcode();
            if(retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED) return true;
         }
         PrintFormat("[Trade Retry] SellStop failed (Retcode: %d). Retrying %d/%d in 200ms...", ResultRetcode(), r+1, maxRetries);
         Sleep(200);
      }
      return false;
   }
};

//--- Timeframe Mode Enum
enum ENUM_TF_MODE {
   TF_AUTO,     // Auto-Detect Chart Timeframe (Default)
   TF_M1,       // M1 (1-Minute) Presets
   TF_M5,       // M5 (5-Minute) Presets
   TF_M15,      // M15 (15-Minute) Presets
   TF_H1,       // H1 (1-Hour) Presets
   TF_CUSTOM    // Custom Settings (Use manual inputs below)
};

enum ENUM_AI_ENGINE {
   AI_GROQ,            // Groq Llama-3.1 (Recommended: Fast & High Quotas)
   AI_GEMINI,          // Gemini Flash
   AI_BOTH_FAILOVER    // Gemini first, failover to Groq
};

//--- Input Parameters
input group "--- Target Timeframe Selection ---"
input ENUM_TF_MODE InpTimeframeMode = TF_AUTO;    // Target Chart Timeframe Mode

input group "--- AI Engine Settings ---"
input string   InpGeminiAPIKey       = ""; // Gemini API Key (aistudio.google.com)
input string   InpGroqAPIKey         = ""; // Groq API Key (console.groq.com)
input bool     InpUseAIEngines       = true;    // Enable AI Brain Integration
input ENUM_AI_ENGINE InpAIEngineSelection = AI_GROQ; // AI Engine Selection
input int      InpMinConviction      = 50;      // Minimum AI Conviction to trade (0-100)

input group "--- Core Risk Settings ---"
input double   InpLotSize          = 0.10;     // Fixed Lot Size (If Compounding is disabled)
input double   InpTargetRiskUSD    = 25.00;    // Target dollar risk per trade ($)
input ulong    InpMagicNumber      = 123456;   // Magic Number

input group "--- Compounding Settings ---"
input bool     InpEnableCompounding = true;    // Enable Lot Compounding (scales target risk)
input double   InpLotsPerStep       = 0.10;    // (Legacy reference lot size)
input double   InpBalanceStep       = 100.00;  // Per how much account balance ($) to scale risk

input group "--- Sideways Hybrid Mode Settings ---"
input bool     InpEnableHybridMode   = true;   // Enable Breakout/Reversion Switch
input bool     InpUseLocalDonchianBreakout = true; // Use Donchian Breakout for local trending breakouts
input double   InpMinADX             = 20.0;   // Custom Mode ONLY: ADX Threshold (Sideways < 20)
input double   InpLimitOffset        = 0.05;   // Front-running offset for limit orders (points)
input double   InpPriceRoundStep     = 0.05;   // Rounding step for limit orders (0.0 to disable)

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

input group "--- Strategy 1: Donchian Breakout Settings ---"
input int      InpChannelLength   = 20;       // Donchian Channel Period
input int      InpEMAPeriod       = 200;      // Trend Filter EMA Period
input double   InpDonchianATRMult = 2.0;      // ATR Multiplier for Stop Loss
input double   InpTargetMult      = 1.5;      // Take Profit Multiplier (1.5x SL)
input double   InpMinSLPct        = 1.0;      // Default Min SL as % of price
input double   InpMaxSLPct        = 3.0;      // Default Max SL as % of price

input group "--- Strategy 2: Crypto Volume Breakout Settings ---"
input double   InpVolumeMult1     = 1.8;      // Vol Breakout Multiplier
input double   InpVolumeBreakTPMult = 2.0;    // Vol Breakout TP Multiplier (2.0x SL)
input bool     InpUseLocalVolBreakout = true;  // Use Volume Breakout for local breakouts

input group "--- Strategy 3: Crypto Scalp Momentum Settings ---"
input double   InpVolumeMult2     = 1.2;      // Scalp Momentum Multiplier
input int      InpEMA9Length      = 9;        // Pullback EMA Length
input double   InpScalpTPMult     = 1.5;      // Scalp TP Multiplier (1.5x SL)
input bool     InpUseLocalVWAPPullback = true; // Use VWAP Pullback for local setups


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
CTradeSafe     trade;
datetime       g_lastBarTime;
datetime       g_lastOrderPlacedBarTime = 0; // Tracks if order was placed successfully for this candle
int            g_lastDay = 0;                // Tracks day changes for Daily Bias calculation

int            g_emaHandle;         // Local EMA handle
int            g_emaHigherHandle;   // Higher timeframe EMA handle
int            g_atrHandle;         // ATR handle
int            g_rsiHandle;         // RSI handle
int            g_adxHandle;         // ADX handle
int            g_ema200Handle;      // EMA 200 Trend Filter handle
int            g_ema9Handle;        // EMA 9 handle

// Spread smoothing buffers
double         g_spreadBuffer[10];
int            g_spreadCount;

// Dynamic preset outputs
double         g_lotSize;
double         g_priceOffset;
double         g_stopLossDist;
double         g_takeProfitDist;

// Mid-Candle AI Call Cooldowns
bool           g_midCandleQueried = false;
datetime       g_lastAICallTime = 0;
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
string         g_aiStrategy = "NONE";
string         g_tradeHorizon = "SHORT_TERM"; // SHORT_TERM or LONG_TERM holding time horizon
string         g_aiRegime = "BREAKOUT";     // Holds current active AI regime
string         g_upcomingNews = "None"; // Holds parsed news for the current day
datetime       g_lastCalendarFetchTime = 0; // Tracks when we last fetched calendar

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

bool CalculateReversionMode(double adxVal, bool isMomHour, bool isVolSpike, bool aiAct, string rawReg)
{
   if(!InpEnableHybridMode) return false;
   
   // Global Trend Guard: if ADX shows a very strong trend, NEVER reversion trade range limits
   if(adxVal > 25.0) return false;
   
   if(adxVal < g_minADX) return true;
   
   if(InpUseSessionHours && !isMomHour)
   {
      if(isVolSpike) return false;
      return true;
   }
   
   if(aiAct)
   {
      return (rawReg == "REVERSION");
   }
   
   return false;
}

double RoundToStep(double value, double step)
{
   if(step <= 0.0) return value;
   return NormalizeDouble(MathRound(value / step) * step, _Digits);
}

string GetCandlePattern(int index)
{
   double openPrice  = iOpen(_Symbol, _Period, index);
   double highPrice  = iHigh(_Symbol, _Period, index);
   double lowPrice   = iLow(_Symbol, _Period, index);
   double closePrice = iClose(_Symbol, _Period, index);
   
   double range = highPrice - lowPrice;
   if(range <= 0.0) return "Normal";
   
   double body = MathAbs(closePrice - openPrice);
   double upperWick = highPrice - MathMax(openPrice, closePrice);
   double lowerWick = MathMin(openPrice, closePrice) - lowPrice;
   
   // Doji check
   if(body / range < 0.1) return "Doji (Indecision)";
   
   // Hammer / Pin Bar check (Bullish Rejection)
   if(lowerWick / range > 0.6 && upperWick / range < 0.2)
      return "Hammer (Bullish Rejection)";
      
   // Shooting Star check (Bearish Rejection)
   if(upperWick / range > 0.6 && lowerWick / range < 0.2)
      return "Shooting Star (Bearish Rejection)";
      
   // Engulfing check (requires index + 1)
   double prevOpen  = iOpen(_Symbol, _Period, index + 1);
   double prevClose = iClose(_Symbol, _Period, index + 1);
   double prevBody  = MathAbs(prevClose - prevOpen);
   
   if(closePrice > openPrice && prevClose < prevOpen && body > prevBody && openPrice <= prevClose && closePrice >= prevOpen)
      return "Bullish Engulfing";
      
   if(closePrice < openPrice && prevClose > prevOpen && body > prevBody && openPrice >= prevClose && closePrice <= prevOpen)
      return "Bearish Engulfing";
      
   return (closePrice > openPrice) ? "Bullish Candle" : "Bearish Candle";
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
   // Redesigned: 550px wide, 360px high to fit spaced-out dashboard rows
   int panelWidth  = 550;
   int panelHeight = 360;
   int margin      = 25;
   int textX       = 20 + margin;
   int fontSize    = 8; 
   
   // 1. Create Background Shield
   CreatePanelBg("DbPanelBg", 20, 60, panelWidth, panelHeight, C'20,20,20', C'70,70,70');
   
   // 2. Create Header
   CreateLabel("DbTitle", textX, 75, "GOLD ENGINE V10 - HYBRID PRO", 10, C'255,179,0', "Segoe UI Semibold");
   
   // 3. Create Rows (Clean spaced-out 22px line height)
   CreateLabel("DbTimeframe", textX, 100, "Chart Timeframe : ", fontSize, clrWhite);
   CreateLabel("DbLotSize",   textX, 122, "Dynamic Lot Size: ", fontSize, clrWhite);
   CreateLabel("DbADX",       textX, 144, "Current ADX     : ", fontSize, clrWhite);
   CreateLabel("DbATR",       textX, 166, "Current ATR     : ", fontSize, clrWhite);
   CreateLabel("DbMode",      textX, 188, "Active Mode     : ", fontSize, clrWhite);
   CreateLabel("DbSL",        textX, 210, "Stop Loss (ATR) : ", fontSize, clrWhite);
   
   // AI Dashboard Rows
   CreateLabel("DbBias",      textX, 232, "AI Daily Bias   : ", fontSize, clrWhite);
   CreateLabel("DbDecision",  textX, 254, "AI Decision     : ", fontSize, clrWhite);
   CreateLabel("DbConviction",textX, 276, "AI Conviction   : ", fontSize, clrWhite);
   CreateLabel("DbReason",    textX, 298, "AI Reason       : ", fontSize, clrWhite);
   
   // 4. Create Button (Nested at the bottom of the panel with margins aligned)
   string btnName = "BtnEAToggle";
   if(ObjectFind(0, btnName) < 0)
   {
      ObjectCreate(0, btnName, OBJ_BUTTON, 0, 0, 0);
   }
   ObjectSetInteger(0, btnName, OBJPROP_XDISTANCE, textX);
   ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, 365); // Moved down to fit spaced-out rows
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
   
   string modeStr = reversionModeActive ? "SIDEWAYS" : "TRENDING";
   string shortStrategy = g_aiStrategy;
   if(shortStrategy == "MEAN_REVERSION") shortStrategy = "Mean Rev";
   else if(shortStrategy == "VOLUME_BREAKOUT") shortStrategy = "Vol Break";
   else if(shortStrategy == "DONCHIAN_BREAKOUT") shortStrategy = "Donchian";
   else if(shortStrategy == "VWAP_PULLBACK") shortStrategy = "VWAP Pull";
   else if(shortStrategy == "PULLBACK") shortStrategy = "Pullback";
   else if(shortStrategy == "STRADDLE") shortStrategy = "Straddle";
   else if(shortStrategy == "SCALPING") shortStrategy = "Scalp";
   else if(shortStrategy == "BREAKOUT") shortStrategy = "Breakout";
   
   if(shortStrategy != "NONE" && shortStrategy != "")
   {
      modeStr += " (" + shortStrategy + ")";
   }
   if(InpUseAIEngines && g_tradeHorizon != "")
   {
      string shortHorizon = (g_tradeHorizon == "LONG_TERM") ? "LONG" : "SHORT";
      modeStr += " [" + shortHorizon + "]";
   }
   
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
   string displayDecision = g_aiDecision;
   if(CountActiveTrades() > 0)
   {
      for(int idx = 0; idx < PositionsTotal(); idx++)
      {
         if(PositionGetSymbol(idx) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            displayDecision = (posType == POSITION_TYPE_BUY) ? "HOLDING BUY" : "HOLDING SELL";
            break;
         }
      }
   }
   
   ObjectSetString(0, "DbDecision",  OBJPROP_TEXT, "AI Decision     : " + displayDecision);
   if(StringFind(displayDecision, "BUY") >= 0)
      ObjectSetInteger(0, "DbDecision", OBJPROP_COLOR, C'76,175,80');  // Green
   else if(StringFind(displayDecision, "SELL") >= 0)
      ObjectSetInteger(0, "DbDecision", OBJPROP_COLOR, C'239,83,80'); // Red
   else if(StringFind(displayDecision, "HOLD") >= 0)
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
   
   // AI Reason (truncated at 60 chars to fit panel nicely)
   string cleanReason = g_aiReason;
   if(StringLen(cleanReason) > 60)
   {
      cleanReason = StringSubstr(cleanReason, 0, 57) + "...";
   }
   ObjectSetString(0, "DbReason",    OBJPROP_TEXT, "AI Reason       : " + cleanReason);
   
   // Highlight Active Mode Color
   if(reversionModeActive)
      ObjectSetInteger(0, "DbMode", OBJPROP_COLOR, C'255,179,0'); 
   else
      ObjectSetInteger(0, "DbMode", OBJPROP_COLOR, C'76,175,80');
       
   double nearestHighs[];
   double nearestLows[];
   string tempStr = "";
   GetUntestedMagnets(nearestHighs, nearestLows, tempStr);
   
   // Clean up any old lines first
   for(int i = 1; i <= 3; i++)
   {
      ObjectDelete(0, "MagnetHighLine_" + (string)i);
      ObjectDelete(0, "MagnetLowLine_" + (string)i);
   }
   
   // Draw High Magnets (closest to furthest)
   color goldColors[3] = { C'255,215,0', C'218,165,32', C'184,134,11' }; // Gold, Goldenrod, Dark Goldenrod
   int highCount = ArraySize(nearestHighs);
   for(int i = 0; i < highCount; i++)
   {
      DrawMagnetLine("MagnetHighLine_" + (string)(i+1), nearestHighs[i], goldColors[i]);
   }
   
   // Draw Low Magnets (closest to furthest)
   color aquaColors[3] = { C'0,255,255', C'72,209,204', C'32,178,170' }; // Aqua, Medium Turquoise, Light Sea Green
   int lowCount = ArraySize(nearestLows);
   for(int i = 0; i < lowCount; i++)
   {
      DrawMagnetLine("MagnetLowLine_" + (string)(i+1), nearestLows[i], aquaColors[i]);
   }

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
void CancelPendingOrdersEx(bool cancelLimits)
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
            else if(cancelLimits && (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT))
            {
               trade.OrderDelete(ticket);
            }
         }
      }
   }
}

void VerifyAndSyncSidewaysLimits(double targetBuyPrice, double targetSellPrice)
{
   bool buyLimitExists = false;
   bool sellLimitExists = false;
   double currentBuyLimitPrice = 0.0;
   double currentSellLimitPrice = 0.0;
   ulong buyTicket = 0;
   ulong sellTicket = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(type == ORDER_TYPE_BUY_LIMIT)
            {
               buyLimitExists = true;
               currentBuyLimitPrice = OrderGetDouble(ORDER_PRICE_OPEN);
               buyTicket = ticket;
            }
            else if(type == ORDER_TYPE_SELL_LIMIT)
            {
               sellLimitExists = true;
               currentSellLimitPrice = OrderGetDouble(ORDER_PRICE_OPEN);
               sellTicket = ticket;
            }
         }
      }
   }
   
   // If target price shifted, cancel the misaligned order
   if(buyLimitExists && targetBuyPrice > 0.0 && MathAbs(currentBuyLimitPrice - targetBuyPrice) > 0.05)
   {
      trade.OrderDelete(buyTicket);
      g_lastOrderPlacedBarTime = 0; // force re-evaluation
   }
   if(sellLimitExists && targetSellPrice > 0.0 && MathAbs(currentSellLimitPrice - targetSellPrice) > 0.05)
   {
      trade.OrderDelete(sellTicket);
      g_lastOrderPlacedBarTime = 0; // force re-evaluation
   }
}

//+------------------------------------------------------------------+
//| Manage active positions on candle close (Active Loss-Cutting)    |
//+------------------------------------------------------------------+
void ManageCandleCloseLossCutting(bool reversionModeActive)
{
   bool isSidewaysRegime = reversionModeActive || IsInsideGNNChannel();
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
               if(InpEnableRejectionExit && prevClose < prevOpen && !isSidewaysRegime && g_tradeHorizon != "LONG_TERM")
               {
                  Print(StringFormat("[V10 SOFT STOP] Closing BUY ticket #%I64u due to Bearish Close.", ticket));
                  trade.PositionClose(ticket);
                  continue;
               }
               
               if(InpEnableCandleTrail && !isSidewaysRegime && g_tradeHorizon != "LONG_TERM")
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
               if(InpEnableRejectionExit && prevClose > prevOpen && !isSidewaysRegime && g_tradeHorizon != "LONG_TERM")
               {
                  Print(StringFormat("[V10 SOFT STOP] Closing SELL ticket #%I64u due to Bullish Close.", ticket));
                  trade.PositionClose(ticket);
                  continue;
               }
               
               if(InpEnableCandleTrail && !isSidewaysRegime && g_tradeHorizon != "LONG_TERM")
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
   // Try matching escaped quotes first: \"key\"
   string searchKey = "\\\"" + key + "\\\"";
   int startIdx = StringFind(json, searchKey);
   
   // If not found, try matching normal quotes: "key"
   if(startIdx < 0)
   {
      searchKey = "\"" + key + "\"";
      startIdx = StringFind(json, searchKey);
   }
   
   // If still not found, try matching single quotes: 'key'
   if(startIdx < 0)
   {
      searchKey = "'" + key + "'";
      startIdx = StringFind(json, searchKey);
   }
   
   if(startIdx < 0) return "";
   
   int colonIdx = StringFind(json, ":", startIdx + StringLen(searchKey));
   if(colonIdx < 0) return "";
   
   int valStart = colonIdx + 1;
   while(valStart < StringLen(json))
   {
      string charStr = StringSubstr(json, valStart, 1);
      if(charStr == " " || charStr == "\t" || charStr == "\r" || charStr == "\n" || 
         charStr == "\"" || charStr == "'" || charStr == "\\" || charStr == "{")
      {
         valStart++;
      }
      else
      {
         break;
      }
   }
   
   int valEnd = valStart;
   while(valEnd < StringLen(json))
   {
      string charStr = StringSubstr(json, valEnd, 1);
      if(charStr == "\"" || charStr == "'" || charStr == "," || charStr == "}" || 
         charStr == "\\" || charStr == "\r" || charStr == "\n")
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
//| Central AI client caller with user selection & failover          |
//+------------------------------------------------------------------+
bool QueryGeminiDirect(string prompt, string &responseText)
{
   if(InpGeminiAPIKey == "" || InpGeminiAPIKey == "PASTE_YOUR_API_KEY_HERE") return false;
   
   string cleanPrompt = prompt;
   // Replace backslashes first, then replace quotes and control characters to ensure clean JSON
   StringReplace(cleanPrompt, "\\", "\\\\");
   StringReplace(cleanPrompt, "\"", "\\\"");
   StringReplace(cleanPrompt, "\r", " ");
   StringReplace(cleanPrompt, "\n", " ");
   StringReplace(cleanPrompt, "\t", " ");
   
   string requestBody = "{\"contents\":[{\"parts\":[{\"text\":\"" + cleanPrompt + "\"}]}]}";
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
      responseText = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      Print("[Gemini Success] Response: ", responseText);
      return true;
   }
   else
   {
      string err = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      Print("[Gemini Fail] HTTP Status: ", res, ", Error Response: ", err);
   }
   return false;
}

bool QueryGroqDirect(string prompt, string &responseText)
{
   if(InpGroqAPIKey == "" || InpGroqAPIKey == "PASTE_YOUR_API_KEY_HERE") return false;
   
   string cleanPrompt = prompt;
   StringReplace(cleanPrompt, "\"", "\\\"");
   string requestBody = "{\"model\":\"llama-3.1-8b-instant\",\"messages\":[{\"role\":\"user\",\"content\":\"" + cleanPrompt + "\"}],\"temperature\":0.2,\"response_format\":{\"type\":\"json_object\"}}";
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
      responseText = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      Print("[Groq Success] Response: ", responseText);
      return true;
   }
   else
   {
      string err = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      Print("[Groq Fail] HTTP Status: ", res, ", Error Response: ", err);
   }
   return false;
}

bool CallAI(string prompt, string &responseText)
{
   // --- Option 1: Groq Only ---
   if(InpAIEngineSelection == AI_GROQ)
   {
      return QueryGroqDirect(prompt, responseText);
   }
   
   // --- Option 2: Gemini Only ---
   if(InpAIEngineSelection == AI_GEMINI)
   {
      return QueryGeminiDirect(prompt, responseText);
   }
   
   // --- Option 3: Gemini first, failover to Groq ---
   if(InpAIEngineSelection == AI_BOTH_FAILOVER)
   {
      if(QueryGeminiDirect(prompt, responseText)) return true;
      Print("[AI Failover] Gemini API unavailable. Switching to Groq Llama-3.1...");
      return QueryGroqDirect(prompt, responseText);
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
      "Gold (XAUUSD) Daily Bias Analysis in json format. Current price=%.2f. Daily candles history: %s. "+
      "As a professional macro analyst, determine today's directional bias. "+
      "Respond strictly with a json object containing: 'bias' ('BUY_ONLY', 'SELL_ONLY', or 'BI_DIRECTIONAL') and 'reason' (short 10 words). "+
      "Example output format: { \"bias\": \"BUY_ONLY\", \"reason\": \"Strong daily bullish engulfing\" }.",
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
            
            if(g_enableTimeDecay && g_tradeHorizon != "LONG_TERM")
            {
               int durationSec = (int)(TimeCurrent() - openTime);
               if(durationSec >= g_maxHoldMinutes * 60)
               {
                  trade.PositionClose(ticket);
                  continue; 
               }
            }
            
            double mult = (g_tradeHorizon == "LONG_TERM") ? 2.0 : 1.0;
            double actBETrigger     = g_beTrigger * mult;
            double actBEOffset      = g_beOffset * mult;
            double actStage1Trigger = g_stage1Trigger * mult;
            double actStage1Dist    = g_stage1Distance * mult;
            double actStage2Trigger = g_stage2Trigger * mult;
            double actStage2Dist    = g_stage2Distance * mult;
            
            if(type == POSITION_TYPE_BUY)
            {
               double currentProfit = currentBid - entryPrice;
               double targetSL = 0.0;
               
               if(g_enableStage2 && currentProfit >= actStage2Trigger)
               {
                  targetSL = NormalizeDouble(currentBid - actStage2Dist, _Digits);
               }
               else if(g_enableStage1 && currentProfit >= actStage1Trigger)
               {
                  targetSL = NormalizeDouble(currentBid - actStage1Dist, _Digits);
               }
               else if(g_enableBE && currentProfit >= actBETrigger)
               {
                  if(InpEnablePartialClose && currentVolume >= g_lotSize)
                  {
                     double closeLots = NormalizeDouble(g_lotSize / 2.0, 2);
                     if(closeLots > 0.0)
                     {
                        trade.PositionClosePartial(ticket, closeLots);
                      }
                   }
                   targetSL = NormalizeDouble(entryPrice + actBEOffset, _Digits);
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
                
                if(g_enableStage2 && currentProfit >= actStage2Trigger)
                {
                   targetSL = NormalizeDouble(currentAsk + actStage2Dist, _Digits);
                }
                else if(g_enableStage1 && currentProfit >= actStage1Trigger)
                {
                   targetSL = NormalizeDouble(currentAsk + actStage1Dist, _Digits);
                }
                else if(g_enableBE && currentProfit >= actBETrigger)
                {
                   if(InpEnablePartialClose && currentVolume >= g_lotSize)
                   {
                      double closeLots = NormalizeDouble(g_lotSize / 2.0, 2);
                      if(closeLots > 0.0)
                      {
                         trade.PositionClosePartial(ticket, closeLots);
                      }
                   }
                   targetSL = NormalizeDouble(entryPrice - actBEOffset, _Digits);
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
            "Recent 3 closed candles: %s. "+
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
//| Extract recent closed trades history under this magic number     |
//+------------------------------------------------------------------+
void GetRecentTradesHistory(string &historyStr)
{
   historyStr = "";
   if(!HistorySelect(TimeCurrent() - 7 * 86400, TimeCurrent()))
   {
      historyStr = "No trade history available yet.";
      return;
   }
   
   int totalDeals = HistoryDealsTotal();
   int count = 0;
   
   for(int i = totalDeals - 1; i >= 0 && count < 3; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
         long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         
         if(symbol == _Symbol && magic == InpMagicNumber && (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY))
         {
            long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_COMMISSION) + HistoryDealGetDouble(ticket, DEAL_SWAP);
            double price = HistoryDealGetDouble(ticket, DEAL_PRICE);
            
            double entryPrice = 0.0;
            long entryType = -1;
            ulong positionId = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
            
            for(int j = 0; j < totalDeals; j++)
            {
               ulong tEntry = HistoryDealGetTicket(j);
               if(HistoryDealGetInteger(tEntry, DEAL_POSITION_ID) == positionId && 
                  (HistoryDealGetInteger(tEntry, DEAL_ENTRY) == DEAL_ENTRY_IN))
               {
                  entryPrice = HistoryDealGetDouble(tEntry, DEAL_PRICE);
                  entryType = HistoryDealGetInteger(tEntry, DEAL_TYPE);
                  break;
               }
            }
            
            string typeStr = (entryType == DEAL_TYPE_BUY) ? "BUY" : "SELL";
            string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
            
            historyStr += StringFormat("[Trade %d: %s entry %.2f, exit %.2f, profit=%.2f$, comment='%s'] ", 
               count + 1, typeStr, entryPrice, price, profit, comment);
            count++;
         }
      }
   }
   
   if(historyStr == "")
   {
      historyStr = "No recent closed trades under this magic number.";
   }
}

//+------------------------------------------------------------------+
//| Fetch ForexFactory Economic Calendar and parse USD news          |
//+------------------------------------------------------------------+
string GetXMLNodeValue(string xml, string tag)
{
   string startTag = "<" + tag + ">";
   string endTag = "</" + tag + ">";
   
   int startIdx = StringFind(xml, startTag);
   if(startIdx < 0) return "";
   
   int endIdx = StringFind(xml, endTag, startIdx);
   if(endIdx < 0) return "";
   
   int valStart = startIdx + StringLen(startTag);
   return StringSubstr(xml, valStart, endIdx - valStart);
}

void FetchEconomicCalendar()
{
   // Check terminal global variable to see when the last successful fetch occurred
   datetime lastFetch = 0;
   if(GlobalVariableCheck("GoldEngine_LastCalendarFetch"))
   {
      lastFetch = (datetime)GlobalVariableGet("GoldEngine_LastCalendarFetch");
   }
   
   // If last fetch was less than 6 hours ago, read the cached news string from file
   if(lastFetch > 0 && TimeCurrent() - lastFetch < 21600)
   {
      int fileHandle = FileOpen("GoldEngine_Calendar.txt", FILE_READ|FILE_TXT|FILE_ANSI);
      if(fileHandle != INVALID_HANDLE)
      {
         g_upcomingNews = FileReadString(fileHandle);
         FileClose(fileHandle);
         g_lastCalendarFetchTime = lastFetch;
         if(g_upcomingNews != "" && g_upcomingNews != "None")
         {
            Print("[Calendar Cache] Loaded from file: ", g_upcomingNews);
            return;
         }
      }
   }
   
   // If we got rate-limited recently (429 status code), back off for 1 hour to cool down
   datetime lastFail = 0;
   if(GlobalVariableCheck("GoldEngine_LastCalendarFail"))
   {
      lastFail = (datetime)GlobalVariableGet("GoldEngine_LastCalendarFail");
   }
   if(lastFail > 0 && TimeCurrent() - lastFail < 3600)
   {
      // Load fallback cache if available
      int fileHandle = FileOpen("GoldEngine_Calendar.txt", FILE_READ|FILE_TXT|FILE_ANSI);
      if(fileHandle != INVALID_HANDLE)
      {
         g_upcomingNews = FileReadString(fileHandle);
         FileClose(fileHandle);
      }
      if(g_upcomingNews == "") g_upcomingNews = "None";
      Print("[Calendar Cooldown] Backing off after rate limit. Fallback: ", g_upcomingNews);
      return;
   }
   
   string url = "https://nfs.faireconomy.media/ff_calendar_thisweek.xml";
   string headers = "";
   char post[];
   char result[];
   string responseHeaders = "";
   
   ResetLastError();
   int res = WebRequest("GET", url, headers, 5000, post, result, responseHeaders);
   if(res != 200)
   {
      Print("[Calendar Fail] HTTP Status: ", res, ", Error code: ", GetLastError());
      
      // Store fail timestamp to back off
      GlobalVariableSet("GoldEngine_LastCalendarFail", (double)TimeCurrent());
      
      // Load fallback cache so the EA continues to work
      int fileHandle = FileOpen("GoldEngine_Calendar.txt", FILE_READ|FILE_TXT|FILE_ANSI);
      if(fileHandle != INVALID_HANDLE)
      {
         g_upcomingNews = FileReadString(fileHandle);
         FileClose(fileHandle);
      }
      if(g_upcomingNews == "") g_upcomingNews = "None";
      return;
   }
   
   string xml = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   
   // Get today's date formatted as mm-dd-yyyy (matches ForexFactory XML date format)
   MqlDateTime dt;
   TimeCurrent(dt);
   string todayStr = StringFormat("%02d-%02d-%04d", dt.mon, dt.day, dt.year);
   
   g_upcomingNews = "";
   int pos = 0;
   
   while(true)
   {
      int startEvent = StringFind(xml, "<event>", pos);
      if(startEvent < 0) break;
      int endEvent = StringFind(xml, "</event>", startEvent);
      if(endEvent < 0) break;
      
      string eventXml = StringSubstr(xml, startEvent, endEvent - startEvent);
      pos = endEvent + 8;
      
      // Parse fields
      string title = GetXMLNodeValue(eventXml, "title");
      string country = GetXMLNodeValue(eventXml, "country");
      string date = GetXMLNodeValue(eventXml, "date");
      string time = GetXMLNodeValue(eventXml, "time");
      string impact = GetXMLNodeValue(eventXml, "impact");
      string forecast = GetXMLNodeValue(eventXml, "forecast");
      string previous = GetXMLNodeValue(eventXml, "previous");
      
      // Filter: USD High/Medium impact events for today
      if(country == "USD" && (impact == "High" || impact == "Medium") && date == todayStr)
      {
         if(g_upcomingNews != "") g_upcomingNews += ", ";
         g_upcomingNews += StringFormat("%s at %s (Forecast: %s, Previous: %s)", title, time, forecast, previous);
      }
   }
   
   if(g_upcomingNews == "")
   {
      g_upcomingNews = "None";
   }
   
   // Cache successful result to file and update terminal global variable
   GlobalVariableSet("GoldEngine_LastCalendarFetch", (double)TimeCurrent());
   int fileHandle = FileOpen("GoldEngine_Calendar.txt", FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(fileHandle != INVALID_HANDLE)
   {
      FileWriteString(fileHandle, g_upcomingNews);
      FileClose(fileHandle);
   }
   
   Print("[Calendar Success] USD Today's News: ", g_upcomingNews);
}

//+------------------------------------------------------------------+
//| Get Volume SMA and anchor-free Daily VWAP calculation           |
//+------------------------------------------------------------------+
double GetVolumeSMA(int period)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, _Period, 1, period, rates) > 0)
   {
      double sum = 0.0;
      for(int i = 0; i < period; i++)
      {
         double vol = (double)rates[i].tick_volume;
         if(rates[i].real_volume > 0) vol = (double)rates[i].real_volume;
         sum += vol;
      }
      return sum / period;
   }
   return 0.0;
}

double GetDailyVWAP()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime todayStart = TimeCurrent() - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(_Symbol, _Period, todayStart, TimeCurrent(), rates);
   if(copied <= 0) return 0.0;
   
   double sumPV = 0.0;
   double sumV = 0.0;
   for(int i = 0; i < copied; i++)
   {
      double typicalPrice = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      double vol = (double)rates[i].tick_volume;
      if(rates[i].real_volume > 0) vol = (double)rates[i].real_volume;
      
      sumPV += typicalPrice * vol;
      sumV += vol;
   }
   
   if(sumV > 0.0) return sumPV / sumV;
   return 0.0;
}

//+------------------------------------------------------------------+
//| Get Untested Swing High/Low Magnets and Draw them on chart       |
//+------------------------------------------------------------------+
void GetUntestedMagnets(double &nearestHighs[], double &nearestLows[], string &outputStr)
{
   ArrayResize(nearestHighs, 0);
   ArrayResize(nearestLows, 0);
   outputStr = "";
   
   int lookback = 150;
   double highs[];
   double lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   
   if(CopyHigh(_Symbol, _Period, 1, lookback, highs) <= 0 ||
      CopyLow(_Symbol, _Period, 1, lookback, lows) <= 0)
   {
      outputStr = "Failed to copy high/low series.";
      return;
   }
   
   double currentPrice = iClose(_Symbol, _Period, 1);
   
   double rawHighs[];
   int rawHighAges[];
   double rawLows[];
   int rawLowAges[];
   
   ArrayResize(rawHighs, 0);
   ArrayResize(rawHighAges, 0);
   ArrayResize(rawLows, 0);
   ArrayResize(rawLowAges, 0);
   
   // Find swing highs/lows
   for(int i = 2; i < lookback - 2; i++)
   {
      if(highs[i] > highs[i-1] && highs[i] > highs[i-2] &&
         highs[i] > highs[i+1] && highs[i] > highs[i+2])
      {
         bool tested = false;
         for(int k = 1; k < i; k++)
         {
            if(highs[k] > highs[i]) { tested = true; break; }
         }
         if(!tested && highs[i] > currentPrice)
         {
            int sz = ArraySize(rawHighs);
            ArrayResize(rawHighs, sz + 1);
            ArrayResize(rawHighAges, sz + 1);
            rawHighs[sz] = highs[i];
            rawHighAges[sz] = i + 1;
         }
      }
      
      if(lows[i] < lows[i-1] && lows[i] < lows[i-2] &&
         lows[i] < lows[i+1] && lows[i] < lows[i+2])
      {
         bool tested = false;
         for(int k = 1; k < i; k++)
         {
            if(lows[k] < lows[i]) { tested = true; break; }
         }
         if(!tested && lows[i] < currentPrice)
         {
            int sz = ArraySize(rawLows);
            ArrayResize(rawLows, sz + 1);
            ArrayResize(rawLowAges, sz + 1);
            rawLows[sz] = lows[i];
            rawLowAges[sz] = i + 1;
         }
      }
   }
   
   // Sort rawHighs ascending (bubble sort)
   int numHighs = ArraySize(rawHighs);
   for(int i = 0; i < numHighs - 1; i++)
   {
      for(int j = i + 1; j < numHighs; j++)
      {
         if(rawHighs[i] > rawHighs[j])
         {
            double tempP = rawHighs[i]; rawHighs[i] = rawHighs[j]; rawHighs[j] = tempP;
            int tempA = rawHighAges[i]; rawHighAges[i] = rawHighAges[j]; rawHighAges[j] = tempA;
         }
      }
   }
   
   // Sort rawLows descending
   int numLows = ArraySize(rawLows);
   for(int i = 0; i < numLows - 1; i++)
   {
      for(int j = i + 1; j < numLows; j++)
      {
         if(rawLows[i] < rawLows[j])
         {
            double tempP = rawLows[i]; rawLows[i] = rawLows[j]; rawLows[j] = tempP;
            int tempA = rawLowAges[i]; rawLowAges[i] = rawLowAges[j]; rawLowAges[j] = tempA;
         }
      }
   }
   
   // Copy top 3
   int limitHigh = MathMin(3, numHighs);
   ArrayResize(nearestHighs, limitHigh);
   string highsDesc = "";
   for(int i = 0; i < limitHigh; i++)
   {
      nearestHighs[i] = rawHighs[i];
      highsDesc += StringFormat("[Price=%.2f, Age=%d bars, Dist=%.2f] ", rawHighs[i], rawHighAges[i], rawHighs[i] - currentPrice);
   }
   
   int limitLow = MathMin(3, numLows);
   ArrayResize(nearestLows, limitLow);
   string lowsDesc = "";
   for(int i = 0; i < limitLow; i++)
   {
      nearestLows[i] = rawLows[i];
      lowsDesc += StringFormat("[Price=%.2f, Age=%d bars, Dist=%.2f] ", rawLows[i], rawLowAges[i], currentPrice - rawLows[i]);
   }
   
   if(highsDesc == "") highsDesc = "None";
   if(lowsDesc == "") lowsDesc = "None";
   
   outputStr = "Untested Swing High Price Magnets: " + highsDesc + ". Untested Swing Low Price Magnets: " + lowsDesc;
}

void DrawMagnetLine(string name, double price, color clr)
{
   if(price <= 0.0)
   {
      ObjectDelete(0, name);
      return;
   }
   
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   else
   {
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   }
}

//+------------------------------------------------------------------+
//| Donchian Channel High/Low and dynamic Stop Loss calculation     |
//+------------------------------------------------------------------+
double GetChannelHigh(int length)
{
   int highest_index = iHighest(_Symbol, _Period, MODE_HIGH, length, 2);
   return iHigh(_Symbol, _Period, highest_index);
}

double GetChannelLow(int length)
{
   int lowest_index = iLowest(_Symbol, _Period, MODE_LOW, length, 2);
   return iLow(_Symbol, _Period, lowest_index);
}

double GetStopLossDistance(string sym, double price, double atr)
{
   double lo = 0.0;
   double hi = 0.0;

   if(sym == "BTCUSD" || sym == "BTCUSDT") 
   {
      lo = 100.0;
      hi = 800.0;
   }
   else if(sym == "ETHUSD" || sym == "ETHUSDT") 
   {
      lo = 5.0;
      hi = 40.0;
   }
   else 
   {
      // Fallback percentage based bands
      lo = price * InpMinSLPct / 100.0;
      hi = price * InpMaxSLPct / 100.0;
   }

   // Clamp the base SL between lo and hi
   double base_sl = InpDonchianATRMult * atr;
   if(base_sl < lo) base_sl = lo;
   if(base_sl > hi) base_sl = hi;

   // Apply noise floor (1.5x ATR)
   double noise_floor = 1.5 * atr;
   return MathMax(base_sl, noise_floor);
}

//+------------------------------------------------------------------+
//| Execute new order placement (Once per candle or on recovery)     |
//+------------------------------------------------------------------+
bool ExecuteNewOrderPlacement(datetime currentBarTime, bool isMidCandle = false)
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

   double ema200Val[];
   ArraySetAsSeries(ema200Val, true);
   double currentEMA200 = 0.0;
   if(CopyBuffer(g_ema200Handle, 0, 1, 1, ema200Val) > 0)
   {
      currentEMA200 = ema200Val[0];
   }
   
   double ema9Val[];
   ArraySetAsSeries(ema9Val, true);
   double currentEMA9 = 0.0;
   if(CopyBuffer(g_ema9Handle, 0, 1, 1, ema9Val) > 0)
   {
      currentEMA9 = ema9Val[0];
   }
   
   double currentVWAP = GetDailyVWAP();
   double volSMA10    = GetVolumeSMA(10);
   double volSMA20    = GetVolumeSMA(20);

   // --- Query the AI Conviction Engine ---
   string barsHistory = "";
   for(int i = 10; i >= 1; i--)
   {
      barsHistory += StringFormat("[Bar %d: O=%.2f, H=%.2f, L=%.2f, C=%.2f, V=%I64d] ", 
         i, iOpen(_Symbol, _Period, i), iHigh(_Symbol, _Period, i), iLow(_Symbol, _Period, i), iClose(_Symbol, _Period, i), iVolume(_Symbol, _Period, i));
   }
   
   // Macro timeframe history for trend alignment
   string macroHistory = "";
   ENUM_TIMEFRAMES HTF = GetHigherTimeframe();
   string htfName = (HTF == PERIOD_M15) ? "M15" : ((HTF == PERIOD_H1) ? "H1" : "H4");
   for(int i = 5; i >= 1; i--)
   {
      macroHistory += StringFormat("[%s Bar %d: O=%.2f, H=%.2f, L=%.2f, C=%.2f] ", 
         htfName, i, iOpen(_Symbol, HTF, i), iHigh(_Symbol, HTF, i), iLow(_Symbol, HTF, i), iClose(_Symbol, HTF, i));
   }
   
   // Explicit trend description
   string trendDesc = "Neutral/Rangebound (Price is oscillating)";
   if(prevClose > currentEMA200 && prevClose > currentVWAP)
      trendDesc = "Strong Bullish Trend (Price is above EMA200 and VWAP)";
   else if(prevClose < currentEMA200 && prevClose < currentVWAP)
      trendDesc = "Strong Bearish Trend (Price is below EMA200 and VWAP)";
   
   string candlePatterns = StringFormat("Bar 1: %s, Bar 2: %s, Bar 3: %s", GetCandlePattern(1), GetCandlePattern(2), GetCandlePattern(3));

   string tradeHistory = "";
   GetRecentTradesHistory(tradeHistory);
   
   g_aiStrategy = "NONE";
   
   double fvgLow = 0.0, fvgHigh = 0.0;
   int fvgType = 0;
   GetLatestUnmitigatedFVG(fvgLow, fvgHigh, fvgType);
   
   double bullOB_Low = 0.0, bullOB_High = 0.0;
   double bearOB_Low = 0.0, bearOB_High = 0.0;
   GetNearestOrderBlocks(bullOB_Low, bullOB_High, bearOB_Low, bearOB_High);
   
   string ictDesc = "";
   if(fvgType == 1) ictDesc += StringFormat("Latest unmitigated Bullish FVG (imbalance vacuum) at %.2f-%.2f. ", fvgLow, fvgHigh);
   else if(fvgType == -1) ictDesc += StringFormat("Latest unmitigated Bearish FVG (imbalance vacuum) at %.2f-%.2f. ", fvgLow, fvgHigh);
   else ictDesc += "No active FVG gaps. ";
   
   if(bullOB_Low > 0.0) ictDesc += StringFormat("Nearest Bullish Order Block (Bank Demand Wall) at %.2f-%.2f. ", bullOB_Low, bullOB_High);
   if(bearOB_Low > 0.0) ictDesc += StringFormat("Nearest Bearish Order Block (Bank Supply Wall) at %.2f-%.2f. ", bearOB_Low, bearOB_High);
    
   string magnetDesc = "";
   double nearestHighs[];
   double nearestLows[];
   GetUntestedMagnets(nearestHighs, nearestLows, magnetDesc);

   string prompt = StringFormat(
      "Gold (XAUUSD) setup analysis. Current price=%.2f. Trend Direction: %s. Indicators: ADX=%.2f, ATR=%.2f, RSI=%.2f, EMA50=%.2f, EMA200=%.2f, EMA9=%.2f, VWAP=%.2f, VolSMA10=%.1f, VolSMA20=%.1f, Spread=%.2f. "+
      "Upcoming High-Impact News today: %s. "+
      "Price History (Active Timeframe): %s. "+
      "Macro Price History (Higher Timeframe): %s. "+
      "Candle Patterns (Last 3 Bars): %s. "+
      "Recent closed trades history: %s. "+
      "Untested Price Magnets (Liquidity Pools): %s. "+"ICT Market Structure (Order Blocks & Fair Value Gaps): %s. "+
      "As a professional self-correcting quant trader, analyze the macro trend, price history, candle patterns (like Hammer/Pin Bar wicks representing rejection at support/resistance floors), and GNN magnets. "+
      "Instructions: 1. During strong trends (ADX > 25.0 and clear direction above/below EMA200/VWAP), you are highly encouraged to execute a LONG_TERM trade in the direction of the trend (e.g., using VOLUME_BREAKOUT or DONCHIAN_BREAKOUT) to capture a major multi-hour move (targeting 30-50+ points) with a wide Stop Loss. 2. If the price has deeply retraced to a macro GNN support floor (like Aqua lines) and you detect a bullish rejection (Hammers/long lower shadows), issue a LONG_TERM BUY swing trade targeting the Golden GNN resistance ceiling (50+ points above) with a wide Stop Loss below the support floor. 3. Conversely, if price has spiked to a Golden resistance ceiling and shows bearish rejection (Shooting Stars), issue a LONG_TERM SELL swing trade targeting the Aqua support floor. 4. LONG_TERM trades bypass all time decay exits and are intended to run for 4-5 hours to secure large trend gains, even with small lot sizes. 5. CRITICAL: Do NOT execute SELL trades when the price is close to (within 5 points of) an untested GNN Support floor (Aqua line), and do NOT execute BUY trades when the price is close to (within 5 points of) an untested GNN Resistance ceiling (Golden line). Selling the support floor or buying the resistance ceiling leads to instant losses on pullbacks. Wait for a breakout or trade the bounce. Identify wick rejections and adjust your decision or stop loss buffer to let wicks breathe. 7. RANGE FLUX PATIENCE: When price is oscillating inside the GNN Golden/Aqua channel, be patient. Bounces are normal. The system automatically bypasses soft-stops inside the channel and will execute a break-even escape (+$0.20) on pullbacks rather than taking range losses. 6. Under ICT Concepts: You are highly encouraged to buy when the price retraces to a Bullish Order Block, or sell when it rises to a Bearish Order Block. If a breakout leaves an FVG, you can choose to enter a limit order in the FVG zone rather than buying the top or selling the bottom. "+
      "Respond strictly with a JSON object containing: "+
      "'decision' ('BUY', 'SELL', or 'HOLD'), "+
      "'conviction' (integer 0 to 100), "+
      "'regime' ('BREAKOUT' or 'REVERSION'), "+
      "'strategy' ('BREAKOUT', 'MEAN_REVERSION', 'PULLBACK', 'STRADDLE', 'SCALPING', 'DONCHIAN_BREAKOUT', 'VOLUME_BREAKOUT', or 'VWAP_PULLBACK'), "+
      "'horizon' ('SHORT_TERM' or 'LONG_TERM'), "+
      "'stop_loss_price' (double target stop loss price level, or 0.0 to use default), "+
      "'take_profit_price' (double target take profit price level, or 0.0 to use default), "+
      "'reason' (short 10 words explaining decision and why you adjusted based on recent trades). "+
      "Example output: { 'decision': 'BUY', 'conviction': 95, 'regime': 'REVERSION', 'strategy': 'MEAN_REVERSION', 'horizon': 'LONG_TERM', 'stop_loss_price': 4065.00, 'take_profit_price': 4125.00, 'reason': 'Deep retracement to Aqua support with Hammer wick rejection' }.",
      prevClose, trendDesc, currentADX, currentATR, currentRSI, currentEMA, currentEMA200, currentEMA9, currentVWAP, volSMA10, volSMA20, spread, g_upcomingNews, barsHistory, macroHistory, candlePatterns, tradeHistory, magnetDesc, ictDesc
   );

   bool aiActive = false;
   string responseText = "";
   string rawRegime = "BREAKOUT"; // default
   
   if(InpUseAIEngines)
   {
      aiActive = CallAI(prompt, responseText);
      if(aiActive)
      {
         string rawDecision = ExtractJSONValue(responseText, "decision");
         string rawConviction = ExtractJSONValue(responseText, "conviction");
         string rawReason = ExtractJSONValue(responseText, "reason");
         rawRegime = ExtractJSONValue(responseText, "regime");
          g_aiRegime = rawRegime;
         string rawStrategy = ExtractJSONValue(responseText, "strategy");
         
         // Clean decision
         if(StringFind(rawDecision, "BUY") >= 0) g_aiDecision = "BUY";
         else if(StringFind(rawDecision, "SELL") >= 0) g_aiDecision = "SELL";
         else if(StringFind(rawDecision, "HOLD") >= 0) g_aiDecision = "HOLD";
         else g_aiDecision = "HOLD";
         
         g_aiConviction = (int)StringToInteger(rawConviction);
         if(g_aiConviction < 0) g_aiConviction = 0;
         if(g_aiConviction > 100) g_aiConviction = 100;
         
         g_aiStrategy = (rawStrategy != "") ? rawStrategy : "BREAKOUT";
         string rawHorizon = ExtractJSONValue(responseText, "horizon");
         if(StringFind(rawHorizon, "LONG_TERM") >= 0) g_tradeHorizon = "LONG_TERM";
         else g_tradeHorizon = "SHORT_TERM";
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
   if(!isMidCandle) g_lastOrderPlacedBarTime = currentBarTime;

   bool useReversionMode = CalculateReversionMode(currentADX, isMomentumHour, isVolatilitySpike, aiActive, g_aiRegime);

   // Trend Adaptation: if ADX trend guard blocks reversion, convert range strategy to breakout
   if(!useReversionMode && (g_aiStrategy == "MEAN_REVERSION" || g_aiStrategy == "SCALPING" || g_aiStrategy == "NONE" || g_aiStrategy == ""))
   {
      g_aiStrategy = "VOLUME_BREAKOUT";
      Print("[Trend Adaptation] Converted AI range strategy to VOLUME_BREAKOUT due to high ADX Trend Guard.");
   }

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
      
      // Scale position size dynamically based on conviction:
      if(g_aiConviction >= 90)
      {
         convictionMultiplier = 1.00;
      }
      else if(g_aiConviction >= 80)
      {
         convictionMultiplier = 0.80;
      }
      else if(g_aiConviction >= 70)
      {
         convictionMultiplier = 0.50;
      }
      else
      {
         convictionMultiplier = 0.30;
      }
    }

    double finalLotSize = NormalizeDouble(g_lotSize * convictionMultiplier, 2);
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if(finalLotSize < minLot) finalLotSize = minLot;

    // --- Parse AI Suggested Structural Stop Loss and Take Profit ---
    double structuralSL = 0.0;
    double structuralTP = 0.0;
    if(aiActive)
    {
       structuralSL = StringToDouble(ExtractJSONValue(responseText, "stop_loss_price"));
       structuralTP = StringToDouble(ExtractJSONValue(responseText, "take_profit_price"));
    }

    // --- Execute Specific Strategy if Selected by AI ---
    if(aiActive && !useReversionMode)
    {
       if(g_aiStrategy == "SCALPING")
       {
          double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
          double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
          
          double scalpingSL = (structuralSL > 0.0 && structuralSL < currentAsk) ? structuralSL : NormalizeDouble(currentBid - 0.60, _Digits);
          double scalpingTP = (structuralTP > 0.0) ? structuralTP : NormalizeDouble(currentBid + 0.80, _Digits);
          
          if(g_aiDecision == "BUY" && (g_dailySentiment != "SELL_ONLY"))
          {
             // Validate and cap Stop Loss
             double maxRiskSL = NormalizeDouble(currentBid - (2.0 * g_stopLossDist), _Digits);
             if(scalpingSL < maxRiskSL) scalpingSL = maxRiskSL; // Safety Cap
             
             trade.Buy(finalLotSize, _Symbol, currentAsk, scalpingSL, scalpingTP, "AI Scalp BUY");
             return true;
          }
          else if(g_aiDecision == "SELL" && (g_dailySentiment != "BUY_ONLY"))
          {
             scalpingSL = (structuralSL > currentBid) ? structuralSL : NormalizeDouble(currentAsk + 0.60, _Digits);
             scalpingTP = (structuralTP > 0.0) ? structuralTP : NormalizeDouble(currentAsk - 0.80, _Digits);
             
             double maxRiskSL = NormalizeDouble(currentAsk + (2.0 * g_stopLossDist), _Digits);
             if(scalpingSL > maxRiskSL) scalpingSL = maxRiskSL; // Safety Cap
             
             trade.Sell(finalLotSize, _Symbol, currentBid, scalpingSL, scalpingTP, "AI Scalp SELL");
             return true;
          }
          return false;
       }
       
       if(g_aiStrategy == "PULLBACK")
       {
          double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
          double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
          
          if(g_aiDecision == "BUY" && (g_dailySentiment != "SELL_ONLY"))
          {
             double limitPrice = (bullOB_High > 0.0) ? bullOB_High : ((fvgType == 1) ? fvgHigh : NormalizeDouble(currentEMA, _Digits));
             double pullbackSL = (structuralSL > 0.0 && structuralSL < limitPrice) ? structuralSL : ((bullOB_Low > 0.0) ? bullOB_Low : NormalizeDouble(limitPrice - 0.80, _Digits));
             double pullbackTP = (structuralTP > 0.0) ? structuralTP : NormalizeDouble(limitPrice + 2.00, _Digits);
             
             // Risk Cap
             double maxRiskSL = NormalizeDouble(limitPrice - (2.0 * g_stopLossDist), _Digits);
             if(pullbackSL < maxRiskSL) pullbackSL = maxRiskSL;
             
             if(MathAbs(currentBid - currentEMA) <= 0.30)
             {
                trade.Buy(finalLotSize, _Symbol, currentAsk, pullbackSL, pullbackTP, "AI Pullback BUY Market");
             }
             else
             {
                if(limitPrice > currentAsk)
                {
                   trade.BuyStop(finalLotSize, limitPrice, _Symbol, pullbackSL, pullbackTP, ORDER_TIME_GTC, 0, "AI Pullback BUY Stop");
                }
                else
                {
                   trade.BuyLimit(finalLotSize, limitPrice, _Symbol, pullbackSL, pullbackTP, ORDER_TIME_GTC, 0, "AI Pullback BUY Limit");
                }
             }
             return true;
          }
          else if(g_aiDecision == "SELL" && (g_dailySentiment != "BUY_ONLY"))
          {
             double limitPrice = (bearOB_Low > 0.0) ? bearOB_Low : ((fvgType == -1) ? fvgLow : NormalizeDouble(currentEMA, _Digits));
             double pullbackSL = (structuralSL > limitPrice) ? structuralSL : ((bearOB_High > 0.0) ? bearOB_High : NormalizeDouble(limitPrice + 0.80, _Digits));
             double pullbackTP = (structuralTP > 0.0) ? structuralTP : NormalizeDouble(limitPrice - 2.00, _Digits);
             
             // Risk Cap
             double maxRiskSL = NormalizeDouble(limitPrice + (2.0 * g_stopLossDist), _Digits);
             if(pullbackSL > maxRiskSL) pullbackSL = maxRiskSL;
             
             if(MathAbs(currentAsk - currentEMA) <= 0.30)
             {
                trade.Sell(finalLotSize, _Symbol, currentBid, pullbackSL, pullbackTP, "AI Pullback SELL Market");
             }
             else
             {
                if(limitPrice < currentBid)
                {
                   trade.SellStop(finalLotSize, limitPrice, _Symbol, pullbackSL, pullbackTP, ORDER_TIME_GTC, 0, "AI Pullback SELL Stop");
                }
                else
                {
                   trade.SellLimit(finalLotSize, limitPrice, _Symbol, pullbackSL, pullbackTP, ORDER_TIME_GTC, 0, "AI Pullback SELL Limit");
                }
             }
             return true;
          }
          return false;
       }
       
        if(g_aiStrategy == "STRADDLE")
        {
           double buyStopPrice  = NormalizeDouble(prevHigh + g_priceOffset + spread, _Digits);
           double buySL         = (structuralSL > 0.0 && structuralSL < buyStopPrice) ? structuralSL : NormalizeDouble(buyStopPrice - g_stopLossDist, _Digits);
           double buyTP         = (structuralTP > 0.0) ? structuralTP : ((g_takeProfitDist > 0.0) ? NormalizeDouble(buyStopPrice + g_takeProfitDist, _Digits) : 0.0);
           
           // Risk Cap
           double maxBuyRiskSL = NormalizeDouble(buyStopPrice - (2.0 * g_stopLossDist), _Digits);
           if(buySL < maxBuyRiskSL) buySL = maxBuyRiskSL;
           
           double sellStopPrice = NormalizeDouble(prevLow - g_priceOffset, _Digits);
           double sellSL        = (structuralSL > sellStopPrice) ? structuralSL : NormalizeDouble(sellStopPrice + g_stopLossDist, _Digits);
           double sellTP        = (structuralTP > 0.0) ? structuralTP : ((g_takeProfitDist > 0.0) ? NormalizeDouble(sellStopPrice - g_takeProfitDist, _Digits) : 0.0);
           
           // Risk Cap
           double maxSellRiskSL = NormalizeDouble(sellStopPrice + (2.0 * g_stopLossDist), _Digits);
           if(sellSL > maxSellRiskSL) sellSL = maxSellRiskSL;
          
          if(g_dailySentiment != "SELL_ONLY")
          {
             trade.BuyStop(finalLotSize, buyStopPrice, _Symbol, buySL, buyTP, ORDER_TIME_GTC, 0, "AI Straddle BUY");
          }
          if(g_dailySentiment != "BUY_ONLY")
          {
              trade.SellStop(finalLotSize, sellStopPrice, _Symbol, sellSL, sellTP, ORDER_TIME_GTC, 0, "AI Straddle SELL");
           }
           return true;
        }
        
        if(g_aiStrategy == "DONCHIAN_BREAKOUT")
        {
           double ema200Val[];
           ArraySetAsSeries(ema200Val, true);
           if(CopyBuffer(g_ema200Handle, 0, 1, 1, ema200Val) > 0)
           {
              double curr_ema200 = ema200Val[0];
              double ch_high = GetChannelHigh(InpChannelLength);
              double ch_low = GetChannelLow(InpChannelLength);
              
              double donchianSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
              if(structuralSL > 0.0)
              {
                 double suggestedSLDist = MathAbs(prevClose - structuralSL);
                 double maxCap = 2.0 * g_stopLossDist;
                 if(suggestedSLDist < donchianSL) suggestedSLDist = donchianSL;
                 if(suggestedSLDist > maxCap) suggestedSLDist = maxCap;
                 donchianSL = suggestedSLDist;
              }
              double donchianTP = donchianSL * InpTargetMult;
              if(structuralTP > 0.0)
              {
                 double suggestedTPDist = MathAbs(prevClose - structuralTP);
                 if(suggestedTPDist < donchianSL) suggestedTPDist = donchianSL;
                 donchianTP = suggestedTPDist;
              }
              
              double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
              double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
              
              bool triggerBuy  = aiActive ? true : ((prevClose > ch_high) && (prevClose >= curr_ema200));
              bool triggerSell = aiActive ? true : ((prevClose < ch_low)  && (prevClose < curr_ema200));
              
              if(g_aiDecision == "BUY" && (g_dailySentiment != "SELL_ONLY"))
              {
                 if(!triggerBuy)
                 {
                    Print("[Quant Guard] Blocked AI Donchian BUY: Close (", prevClose, ") is not above Channel High (", ch_high, ") or EMA200 (", curr_ema200, ").");
                    return false;
                 }
                 double buySL = currentAsk - donchianSL;
                 double buyTP = currentAsk + donchianTP;
                 
                 // Risk Cap
                 double maxRiskSL = NormalizeDouble(currentAsk - (2.0 * g_stopLossDist), _Digits);
                 if(buySL < maxRiskSL) buySL = maxRiskSL;
                 
                 trade.Buy(finalLotSize, _Symbol, currentAsk, buySL, buyTP, "AI Donchian BUY");
                 return true;
              }
              else if(g_aiDecision == "SELL" && (g_dailySentiment != "BUY_ONLY"))
              {
                 if(!triggerSell)
                 {
                    Print("[Quant Guard] Blocked AI Donchian SELL: Close (", prevClose, ") is not below Channel Low (", ch_low, ") or EMA200 (", curr_ema200, ").");
                    return false;
                 }
                 double sellSL = currentBid + donchianSL;
                 double sellTP = currentBid - donchianTP;
                 
                 // Risk Cap
                 double maxRiskSL = NormalizeDouble(currentBid + (2.0 * g_stopLossDist), _Digits);
                 if(sellSL > maxRiskSL) sellSL = maxRiskSL;
                 
                 trade.Sell(finalLotSize, _Symbol, currentBid, sellSL, sellTP, "AI Donchian SELL");
                 return true;
              }
           }
           return false;
        }

        if(g_aiStrategy == "VOLUME_BREAKOUT")
        {
           double ema200Val[];
           ArraySetAsSeries(ema200Val, true);
           if(CopyBuffer(g_ema200Handle, 0, 1, 1, ema200Val) > 0)
           {
              double curr_ema200 = ema200Val[0];
              double ch_high = GetChannelHigh(InpChannelLength);
              double ch_low = GetChannelLow(InpChannelLength);
              
              double donchianSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
              if(structuralSL > 0.0)
              {
                 double suggestedSLDist = MathAbs(prevClose - structuralSL);
                 double maxCap = 2.0 * g_stopLossDist;
                 if(suggestedSLDist < donchianSL) suggestedSLDist = donchianSL;
                 if(suggestedSLDist > maxCap) suggestedSLDist = maxCap;
                 donchianSL = suggestedSLDist;
              }
              double donchianTP = donchianSL * InpVolumeBreakTPMult;
              if(structuralTP > 0.0)
              {
                 double suggestedTPDist = MathAbs(prevClose - structuralTP);
                 if(suggestedTPDist < donchianSL) suggestedTPDist = donchianSL;
                 donchianTP = suggestedTPDist;
              }
              
              double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
              double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
              
              double currVol = (double)iVolume(_Symbol, _Period, 1);
              double volSMA10 = GetVolumeSMA(10);
              bool volOk = (currVol >= InpVolumeMult1 * volSMA10);
              
              bool triggerBuy  = aiActive ? true : ((prevClose > ch_high) && (prevClose >= curr_ema200) && volOk);
              bool triggerSell = aiActive ? true : ((prevClose < ch_low)  && (prevClose < curr_ema200)  && volOk);
              
              if(g_aiDecision == "BUY" && (g_dailySentiment != "SELL_ONLY"))
              {
                 if(!triggerBuy)
                 {
                    Print("[Quant Guard] Blocked AI Vol Breakout BUY: Close (", prevClose, ") not above High (", ch_high, ") or Vol (", currVol, ") < 1.8x SMA (", volSMA10, ").");
                    return false;
                 }
                 double buySL = currentAsk - donchianSL;
                 double buyTP = currentAsk + donchianTP;
                 
                 double maxRiskSL = NormalizeDouble(currentAsk - (2.0 * g_stopLossDist), _Digits);
                 if(buySL < maxRiskSL) buySL = maxRiskSL;
                 
                 trade.Buy(finalLotSize, _Symbol, currentAsk, buySL, buyTP, "AI Vol Breakout BUY");
                 return true;
              }
              else if(g_aiDecision == "SELL" && (g_dailySentiment != "BUY_ONLY"))
              {
                 if(!triggerSell)
                 {
                    Print("[Quant Guard] Blocked AI Vol Breakout SELL: Close (", prevClose, ") not below Low (", ch_low, ") or Vol (", currVol, ") < 1.8x SMA (", volSMA10, ").");
                    return false;
                 }
                 double sellSL = currentBid + donchianSL;
                 double sellTP = currentBid - donchianTP;
                 
                 double maxRiskSL = NormalizeDouble(currentBid + (2.0 * g_stopLossDist), _Digits);
                 if(sellSL > maxRiskSL) sellSL = maxRiskSL;
                 
                 trade.Sell(finalLotSize, _Symbol, currentBid, sellSL, sellTP, "AI Vol Breakout SELL");
                 return true;
              }
           }
           return false;
        }
        
        if(g_aiStrategy == "VWAP_PULLBACK")
        {
           double ema200Val[];
           ArraySetAsSeries(ema200Val, true);
           if(CopyBuffer(g_ema200Handle, 0, 1, 1, ema200Val) > 0)
           {
              double curr_ema200 = ema200Val[0];
              double currentVWAP = GetDailyVWAP();
              
              double pullbackSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
              if(structuralSL > 0.0)
              {
                 double suggestedSLDist = MathAbs(prevClose - structuralSL);
                 double maxCap = 2.0 * g_stopLossDist;
                 if(suggestedSLDist < pullbackSL) suggestedSLDist = pullbackSL;
                 if(suggestedSLDist > maxCap) suggestedSLDist = maxCap;
                 pullbackSL = suggestedSLDist;
              }
              double pullbackTP = pullbackSL * InpScalpTPMult;
              if(structuralTP > 0.0)
              {
                 double suggestedTPDist = MathAbs(prevClose - structuralTP);
                 if(suggestedTPDist < pullbackSL) suggestedTPDist = pullbackSL;
                 pullbackTP = suggestedTPDist;
              }
              
              double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
              double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
              
              double ema9Val[];
               ArraySetAsSeries(ema9Val, true);
               if(CopyBuffer(g_ema9Handle, 0, 1, 3, ema9Val) > 0)
               {
                  double close1 = iClose(_Symbol, _Period, 1);
                  double close2 = iClose(_Symbol, _Period, 2);
                  
                  double low1 = iLow(_Symbol, _Period, 1);
                  double low2 = iLow(_Symbol, _Period, 2);
                  double low3 = iLow(_Symbol, _Period, 3);
                  
                  double high1 = iHigh(_Symbol, _Period, 1);
                  double high2 = iHigh(_Symbol, _Period, 2);
                  double high3 = iHigh(_Symbol, _Period, 3);
                  
                  double currRSI = currentRSI;
                  double currVol = (double)iVolume(_Symbol, _Period, 1);
                  double volSMA20 = GetVolumeSMA(20);
                  bool volOk = (currVol >= InpVolumeMult2 * volSMA20);
                  
                  bool pullbackBuy = (low1 <= ema9Val[0] || low2 <= ema9Val[1] || low3 <= ema9Val[2]);
                  bool triggerBuy = (close1 > ema9Val[0] && close2 <= ema9Val[1]);
                  bool rsiBuyOk = (currRSI >= 45.0 && currRSI <= 65.0);
                  bool trendBuyOk = (close1 > curr_ema200 && close1 > currentVWAP);
                  
                  bool pullbackSell = (high1 >= ema9Val[0] || high2 >= ema9Val[1] || high3 >= ema9Val[2]);
                  bool triggerSell = (close1 < ema9Val[0] && close2 >= ema9Val[1]);
                  bool rsiSellOk = (currRSI >= 35.0 && currRSI <= 55.0);
                  bool trendSellOk = (close1 < curr_ema200 && close1 < currentVWAP);
                  
                  if(g_aiDecision == "BUY" && (g_dailySentiment != "SELL_ONLY"))
                  {
                     if(!aiActive && !(trendBuyOk && pullbackBuy && triggerBuy && volOk && rsiBuyOk))
                     {
                        Print("[Quant Guard] Blocked AI VWAP Pullback BUY: Indicators mismatch.");
                        return false;
                     }
                     double buySL = currentAsk - pullbackSL;
                     double buyTP = currentAsk + pullbackTP;
                     
                     double maxRiskSL = NormalizeDouble(currentAsk - (2.0 * g_stopLossDist), _Digits);
                     if(buySL < maxRiskSL) buySL = maxRiskSL;
                     
                     trade.Buy(finalLotSize, _Symbol, currentAsk, buySL, buyTP, "AI VWAP Pullback BUY");
                     return true;
                  }
                  else if(g_aiDecision == "SELL" && (g_dailySentiment != "BUY_ONLY"))
                  {
                     if(!aiActive && !(trendSellOk && pullbackSell && triggerSell && volOk && rsiSellOk))
                     {
                        Print("[Quant Guard] Blocked AI VWAP Pullback SELL: Indicators mismatch.");
                        return false;
                     }
                     double sellSL = currentBid + pullbackSL;
                     double sellTP = currentBid - pullbackTP;
                     
                     double maxRiskSL = NormalizeDouble(currentBid + (2.0 * g_stopLossDist), _Digits);
                     if(sellSL > maxRiskSL) sellSL = maxRiskSL;
                     
                     trade.Sell(finalLotSize, _Symbol, currentBid, sellSL, sellTP, "AI VWAP Pullback SELL");
                     return true;
                  }
               }
              else if(g_aiDecision == "SELL" && (g_dailySentiment != "BUY_ONLY"))
              {
                 double sellSL = currentBid + pullbackSL;
                 double sellTP = currentBid - pullbackTP;
                 
                 double maxRiskSL = NormalizeDouble(currentBid + (2.0 * g_stopLossDist), _Digits);
                 if(sellSL > maxRiskSL) sellSL = maxRiskSL;
                 
                 trade.Sell(finalLotSize, _Symbol, currentBid, sellSL, sellTP, "AI VWAP Pullback SELL");
                 return true;
              }
           }
           return false;
        }
     }



    // Place Orders in accordance with Daily Sentiment Anchor
    if(useReversionMode)
    {
       if(!aiActive && InpUseLocalVWAPPullback)
       {
          double ema200Val[];
          ArraySetAsSeries(ema200Val, true);
          if(CopyBuffer(g_ema200Handle, 0, 1, 1, ema200Val) > 0)
          {
             double curr_ema200 = ema200Val[0];
             double currentVWAP = GetDailyVWAP();
             
             double ema9Val[];
             ArraySetAsSeries(ema9Val, true);
             if(CopyBuffer(g_ema9Handle, 0, 1, 3, ema9Val) > 0)
             {
                double close1 = iClose(_Symbol, _Period, 1);
                double close2 = iClose(_Symbol, _Period, 2);
                
                double low1 = iLow(_Symbol, _Period, 1);
                double low2 = iLow(_Symbol, _Period, 2);
                double low3 = iLow(_Symbol, _Period, 3);
                
                double high1 = iHigh(_Symbol, _Period, 1);
                double high2 = iHigh(_Symbol, _Period, 2);
                double high3 = iHigh(_Symbol, _Period, 3);
                
                double currRSI = currentRSI;
                double currVol = (double)iVolume(_Symbol, _Period, 1);
                double volSMA20 = GetVolumeSMA(20);
                
                bool volOk = (currVol >= InpVolumeMult2 * volSMA20);
                
                bool pullbackBuy = (low1 <= ema9Val[0] || low2 <= ema9Val[1] || low3 <= ema9Val[2]);
                bool triggerBuy = (close1 > ema9Val[0] && close2 <= ema9Val[1]);
                bool rsiBuyOk = (currRSI >= 45.0 && currRSI <= 65.0);
                bool trendBuyOk = (close1 > curr_ema200 && close1 > currentVWAP);
                
                bool pullbackSell = (high1 >= ema9Val[0] || high2 >= ema9Val[1] || high3 >= ema9Val[2]);
                bool triggerSell = (close1 < ema9Val[0] && close2 >= ema9Val[1]);
                bool rsiSellOk = (currRSI >= 35.0 && currRSI <= 55.0);
                bool trendSellOk = (close1 < curr_ema200 && close1 < currentVWAP);
                
                if(trendBuyOk && pullbackBuy && triggerBuy && volOk && rsiBuyOk && (g_dailySentiment != "SELL_ONLY"))
                {
                   double pullbackSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
                   double pullbackTP = pullbackSL * InpScalpTPMult;
                   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                   double buySL = currentAsk - pullbackSL;
                   double buyTP = currentAsk + pullbackTP;
                   
                   double maxRiskSL = NormalizeDouble(currentAsk - (2.0 * g_stopLossDist), _Digits);
                   if(buySL < maxRiskSL) buySL = maxRiskSL;
                   
                   trade.Buy(finalLotSize, _Symbol, currentAsk, buySL, buyTP, "Local VWAP Pullback BUY");
                   return true;
                }
                else if(trendSellOk && pullbackSell && triggerSell && volOk && rsiSellOk && (g_dailySentiment != "BUY_ONLY"))
                {
                   double pullbackSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
                   double pullbackTP = pullbackSL * InpScalpTPMult;
                   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                   double sellSL = currentBid + pullbackSL;
                   double sellTP = currentBid - pullbackTP;
                   
                   double maxRiskSL = NormalizeDouble(currentBid + (2.0 * g_stopLossDist), _Digits);
                   if(sellSL > maxRiskSL) sellSL = maxRiskSL;
                   
                   trade.Sell(finalLotSize, _Symbol, currentBid, sellSL, sellTP, "Local VWAP Pullback SELL");
                   return true;
                }
             }
          }
       }

        // --- SIDEWAYS RANGE MODE (Limit Orders) ---
        double reversionOffset = (InpTimeframeMode == TF_M1 || (InpTimeframeMode == TF_AUTO && _Period == PERIOD_M1)) ? 0.08 : 0.15;
        
        bool placeBuy = (g_dailySentiment != "SELL_ONLY");
        bool placeSell = (g_dailySentiment != "BUY_ONLY");
       
       if(placeBuy)
       {
          double rawBuyPrice = (ArraySize(nearestLows) > 0) ? (nearestLows[0] + InpLimitOffset) : (prevLow - reversionOffset);
          double buyLimitPrice = (InpPriceRoundStep > 0.0) ? RoundToStep(rawBuyPrice, InpPriceRoundStep) : NormalizeDouble(rawBuyPrice, _Digits);
          // Strictly use ATR-based Stop Loss for range limits (ignore tight AI structural stops)
          double buySL          = NormalizeDouble(buyLimitPrice - g_stopLossDist, _Digits);
          
          // Buy TP defaults to the target Sell Limit price (front-run Golden Magnet)
          double rawBuyTPPrice = (ArraySize(nearestHighs) > 0) ? (nearestHighs[0] - InpLimitOffset) : 0.0;
          double buyTP = (rawBuyTPPrice > 0.0) ? ((InpPriceRoundStep > 0.0) ? RoundToStep(rawBuyTPPrice, InpPriceRoundStep) : NormalizeDouble(rawBuyTPPrice, _Digits)) : 
                         ((g_takeProfitDist > 0.0) ? NormalizeDouble(buyLimitPrice + g_takeProfitDist, _Digits) : 0.0);
          
          // Apply safety stops clamping
          double maxRiskSL = NormalizeDouble(buyLimitPrice - (2.0 * g_stopLossDist), _Digits);
          if(buySL < maxRiskSL) buySL = maxRiskSL;
          
          // Force minimum 1:1 risk-to-reward on dynamic target
          if(buyTP > buyLimitPrice && buySL < buyLimitPrice)
          {
             double tpDist = buyTP - buyLimitPrice;
             double slDist = buyLimitPrice - buySL;
             if(tpDist < slDist) buyTP = buyLimitPrice + slDist;
          }
          
          trade.BuyLimit(finalLotSize, buyLimitPrice, _Symbol, buySL, buyTP, ORDER_TIME_GTC, 0, "AI Buy Limit Reversion");
       }
       
       if(placeSell)
       {
          double rawSellPrice = (ArraySize(nearestHighs) > 0) ? (nearestHighs[0] - InpLimitOffset) : (prevHigh + reversionOffset);
          double sellLimitPrice = (InpPriceRoundStep > 0.0) ? RoundToStep(rawSellPrice, InpPriceRoundStep) : NormalizeDouble(rawSellPrice, _Digits);
          // Strictly use ATR-based Stop Loss for range limits (ignore tight AI structural stops)
          double sellSL         = NormalizeDouble(sellLimitPrice + g_stopLossDist, _Digits);
          
          // Sell TP defaults to the target Buy Limit price (front-run Aqua Magnet)
          double rawSellTPPrice = (ArraySize(nearestLows) > 0) ? (nearestLows[0] + InpLimitOffset) : 0.0;
          double sellTP = (rawSellTPPrice > 0.0) ? ((InpPriceRoundStep > 0.0) ? RoundToStep(rawSellTPPrice, InpPriceRoundStep) : NormalizeDouble(rawSellTPPrice, _Digits)) : 
                          ((g_takeProfitDist > 0.0) ? NormalizeDouble(sellLimitPrice - g_takeProfitDist, _Digits) : 0.0);
          
          // Apply safety stops clamping
          double maxRiskSL = NormalizeDouble(sellLimitPrice + (2.0 * g_stopLossDist), _Digits);
          if(sellSL > maxRiskSL) sellSL = maxRiskSL;
          
          // Force minimum 1:1 risk-to-reward on dynamic target
          if(sellTP < sellLimitPrice && sellSL > sellLimitPrice)
          {
             double tpDist = sellLimitPrice - sellTP;
             double slDist = sellSL - sellLimitPrice;
             if(tpDist < slDist) sellTP = sellLimitPrice - slDist;
          }
          
          trade.SellLimit(finalLotSize, sellLimitPrice, _Symbol, sellSL, sellTP, ORDER_TIME_GTC, 0, "AI Sell Limit Reversion");
       }
      
      return true;
   }
   else
   {
      // --- TRENDING BREAKOUT MODE ---
      if(!aiActive && InpUseLocalVolBreakout)
      {
         double ema200Val[];
         ArraySetAsSeries(ema200Val, true);
         if(CopyBuffer(g_ema200Handle, 0, 1, 1, ema200Val) > 0)
         {
            double curr_ema200 = ema200Val[0];
            double ch_high = GetChannelHigh(InpChannelLength);
            double ch_low = GetChannelLow(InpChannelLength);
            
            double currVol = (double)iVolume(_Symbol, _Period, 1);
            double volSMA10 = GetVolumeSMA(10);
            bool volOk = (currVol >= InpVolumeMult1 * volSMA10);
            
            bool triggerBuy  = (prevClose > ch_high) && (prevClose >= curr_ema200) && volOk && (g_dailySentiment != "SELL_ONLY");
            bool triggerSell = (prevClose < ch_low)  && (prevClose < curr_ema200)  && volOk && (g_dailySentiment != "BUY_ONLY");
            
            if(triggerBuy)
            {
               double donchianSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
               double donchianTP = donchianSL * InpVolumeBreakTPMult;
               
               double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               double buySL = currentAsk - donchianSL;
               double buyTP = currentAsk + donchianTP;
               
               double maxRiskSL = NormalizeDouble(currentAsk - (2.0 * g_stopLossDist), _Digits);
               if(buySL < maxRiskSL) buySL = maxRiskSL;
               
               trade.Buy(finalLotSize, _Symbol, currentAsk, buySL, buyTP, "Local Vol Breakout BUY");
               return true;
            }
            else if(triggerSell)
            {
               double donchianSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
               double donchianTP = donchianSL * InpVolumeBreakTPMult;
               
               double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               double sellSL = currentBid + donchianSL;
               double sellTP = currentBid - donchianTP;
               
               double maxRiskSL = NormalizeDouble(currentBid + (2.0 * g_stopLossDist), _Digits);
               if(sellSL > maxRiskSL) sellSL = maxRiskSL;
               
               trade.Sell(finalLotSize, _Symbol, currentBid, sellSL, sellTP, "Local Vol Breakout SELL");
               return true;
            }
         }
         return false;
      }

      if(!aiActive && InpUseLocalDonchianBreakout)
      {
         double ema200Val[];
         ArraySetAsSeries(ema200Val, true);
         if(CopyBuffer(g_ema200Handle, 0, 1, 1, ema200Val) > 0)
         {
            double curr_ema200 = ema200Val[0];
            double ch_high = GetChannelHigh(InpChannelLength);
            double ch_low = GetChannelLow(InpChannelLength);
            
            bool triggerBuy  = (prevClose > ch_high) && (prevClose >= curr_ema200) && (g_dailySentiment != "SELL_ONLY");
            bool triggerSell = (prevClose < ch_low)  && (prevClose < curr_ema200)  && (g_dailySentiment != "BUY_ONLY");
            
            if(triggerBuy)
            {
               double donchianSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
               double donchianTP = donchianSL * InpTargetMult;
               
               double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               double buySL = currentAsk - donchianSL;
               double buyTP = currentAsk + donchianTP;
               
               double maxRiskSL = NormalizeDouble(currentAsk - (2.0 * g_stopLossDist), _Digits);
               if(buySL < maxRiskSL) buySL = maxRiskSL;
               
               trade.Buy(finalLotSize, _Symbol, currentAsk, buySL, buyTP, "Local Donchian BUY");
               return true;
            }
            else if(triggerSell)
            {
               double donchianSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
               double donchianTP = donchianSL * InpTargetMult;
               
               double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               double sellSL = currentBid + donchianSL;
               double sellTP = currentBid - donchianTP;
               
               double maxRiskSL = NormalizeDouble(currentBid + (2.0 * g_stopLossDist), _Digits);
               if(sellSL > maxRiskSL) sellSL = maxRiskSL;
               
               trade.Sell(finalLotSize, _Symbol, currentBid, sellSL, sellTP, "Local Donchian SELL");
               return true;
            }
         }
         return false;
      }

      // --- Fallback: Standard Trending Breakout Mode (Stop Orders) ---
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
         double buySL         = (structuralSL > 0.0) ? structuralSL : NormalizeDouble(buyStopPrice - g_stopLossDist, _Digits);
         double buyTP         = (structuralTP > 0.0) ? structuralTP : ((g_takeProfitDist > 0.0) ? NormalizeDouble(buyStopPrice + g_takeProfitDist, _Digits) : 0.0);
         
         double maxRiskSL = NormalizeDouble(buyStopPrice - (2.0 * g_stopLossDist), _Digits);
         if(buySL < maxRiskSL) buySL = maxRiskSL;
         
         trade.BuyStop(finalLotSize, buyStopPrice, _Symbol, buySL, buyTP, ORDER_TIME_GTC, 0, "AI Buy Stop Breakout");
         orderPlaced = true;
      }
      
      if(allowSell)
      {
         double sellStopPrice = NormalizeDouble(prevLow - g_priceOffset, _Digits);
         double sellSL        = (structuralSL > 0.0) ? structuralSL : NormalizeDouble(sellStopPrice + g_stopLossDist, _Digits);
         double sellTP        = (structuralTP > 0.0) ? structuralTP : ((g_takeProfitDist > 0.0) ? NormalizeDouble(sellStopPrice - g_takeProfitDist, _Digits) : 0.0);
         
         double maxRiskSL = NormalizeDouble(sellStopPrice + (2.0 * g_stopLossDist), _Digits);
         if(sellSL > maxRiskSL) sellSL = maxRiskSL;
         
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
   bool success = false;
   string name = "";
   
   if(InpAIEngineSelection == AI_GROQ)
   {
      name = "Groq Llama-3.1";
      string resp = "";
      success = QueryGroqDirect("Respond strictly with status OK in json format. Example: {\"status\":\"OK\"}", resp);
   }
   else if(InpAIEngineSelection == AI_GEMINI)
   {
      name = "Gemini Flash";
      string resp = "";
      success = QueryGeminiDirect("Respond strictly with status OK in json format. Example: {\"status\":\"OK\"}", resp);
   }
   else if(InpAIEngineSelection == AI_BOTH_FAILOVER)
   {
      name = "Gemini & Groq (Failover)";
      string resp = "";
      bool gemSuccess = QueryGeminiDirect("Respond strictly with status OK in json format. Example: {\"status\":\"OK\"}", resp);
      bool groqSuccess = QueryGroqDirect("Respond strictly with status OK in json format. Example: {\"status\":\"OK\"}", resp);
      success = gemSuccess || groqSuccess;
      if(gemSuccess) g_aiReason = "Gemini API OK";
      else if(groqSuccess) g_aiReason = "Groq API OK (Gemini Offline)";
   }
   
   if(success)
   {
      g_aiDecision = "WAITING";
      if(InpAIEngineSelection != AI_BOTH_FAILOVER)
      {
         g_aiReason = name + " OK";
      }
   }
   else
   {
      g_aiDecision = "API ERROR";
      g_aiReason = name + " Offline";
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
   g_ema200Handle = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_ema9Handle   = iMA(_Symbol, _Period, InpEMA9Length, 0, MODE_EMA, PRICE_CLOSE);
   
   if(g_emaHandle == INVALID_HANDLE || g_emaHigherHandle == INVALID_HANDLE || 
      g_atrHandle == INVALID_HANDLE || g_rsiHandle == INVALID_HANDLE || g_adxHandle == INVALID_HANDLE ||
      g_ema200Handle == INVALID_HANDLE || g_ema9Handle == INVALID_HANDLE)
   {
      Print("[V10 INIT ERROR] Failed to initialize indicators.");
      return(INIT_FAILED);
   }
   
   // 2. Load presets safely
   LoadTimeframePresets();
   
   // 3. Create UI elements (clean up old cached objects to force layout recalculations)
   ObjectsDeleteAll(0, "Db");
   ObjectDelete(0, "BtnEAToggle");
   CreateInterface();
   
   // 4. Test AI Engines connection live on startup
   TestAIEngines();
   
   // 5. Fetch Economic Calendar and establish initial Daily Sentiment Anchor
   FetchEconomicCalendar();
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
   IndicatorRelease(g_ema200Handle);
   IndicatorRelease(g_ema9Handle);
   
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
   
   ObjectDelete(0, "MagnetHighLine");
   ObjectDelete(0, "MagnetLowLine");
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

//+------------------------------------------------------------------+
//| Get Latest Unmitigated Fair Value Gap (FVG)                       |
//+------------------------------------------------------------------+
void GetLatestUnmitigatedFVG(double &fvgLow, double &fvgHigh, int &fvgType)
{
   fvgLow = 0.0;
   fvgHigh = 0.0;
   fvgType = 0;
   
   for(int i = 2; i < 30; i++)
   {
      double low1 = iLow(_Symbol, _Period, i);
      double high1 = iHigh(_Symbol, _Period, i);
      
      double low3 = iLow(_Symbol, _Period, i+2);
      double high3 = iHigh(_Symbol, _Period, i+2);
      
      // Check Bullish FVG
      if(low1 > high3)
      {
         bool mitigated = false;
         for(int j = i - 1; j >= 1; j--)
         {
            if(iLow(_Symbol, _Period, j) <= high3)
            {
               mitigated = true;
               break;
            }
         }
         if(!mitigated)
         {
            fvgLow = high3;
            fvgHigh = low1;
            fvgType = 1; // Bullish FVG
            return;
         }
      }
      
      // Check Bearish FVG
      if(high1 < low3)
      {
         bool mitigated = false;
         for(int j = i - 1; j >= 1; j--)
         {
            if(iHigh(_Symbol, _Period, j) >= low3)
            {
               mitigated = true;
               break;
            }
         }
         if(!mitigated)
         {
            fvgLow = high1;
            fvgHigh = low3;
            fvgType = -1; // Bearish FVG
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get Nearest Unmitigated Institutional Order Blocks (OB)          |
//+------------------------------------------------------------------+
void GetNearestOrderBlocks(double &bullOB_Low, double &bullOB_High, double &bearOB_Low, double &bearOB_High)
{
   bullOB_Low = 0.0;
   bullOB_High = 0.0;
   bearOB_Low = 0.0;
   bearOB_High = 0.0;
   
   double atrVal[];
   ArraySetAsSeries(atrVal, true);
   if(CopyBuffer(g_atrHandle, 0, 1, 1, atrVal) <= 0) return;
   double currentATR = atrVal[0];
   
   for(int i = 2; i < 40; i++)
   {
      double o = iOpen(_Symbol, _Period, i);
      double h = iHigh(_Symbol, _Period, i);
      double l = iLow(_Symbol, _Period, i);
      double c = iClose(_Symbol, _Period, i);
      
      // 1. Check Bullish Order Block (bearish candle followed by strong bullish impulse)
      if(c < o && bullOB_Low == 0.0)
      {
         bool impulseFound = false;
         for(int j = i - 1; j >= MathMax(1, i - 3); j--)
         {
            double jo = iOpen(_Symbol, _Period, j);
            double jc = iClose(_Symbol, _Period, j);
            if(jc > jo && (jc - jo) >= 1.2 * currentATR)
            {
               impulseFound = true;
               break;
            }
         }
         
         if(impulseFound)
         {
            bool mitigated = false;
            for(int k = i - 1; k >= 1; k--)
            {
               if(iLow(_Symbol, _Period, k) < l)
               {
                  mitigated = true;
                  break;
               }
            }
            if(!mitigated)
            {
               bullOB_Low = l;
               bullOB_High = h;
            }
         }
      }
      
      // 2. Check Bearish Order Block (bullish candle followed by strong bearish impulse)
      if(c > o && bearOB_Low == 0.0)
      {
         bool impulseFound = false;
         for(int j = i - 1; j >= MathMax(1, i - 3); j--)
         {
            double jo = iOpen(_Symbol, _Period, j);
            double jc = iClose(_Symbol, _Period, j);
            if(jc < jo && (jo - jc) >= 1.2 * currentATR)
            {
               impulseFound = true;
               break;
            }
         }
         
         if(impulseFound)
         {
            bool mitigated = false;
            for(int k = i - 1; k >= 1; k--)
            {
               if(iHigh(_Symbol, _Period, k) > h)
               {
                  mitigated = true;
                  break;
               }
            }
            if(!mitigated)
            {
               bearOB_Low = l;
               bearOB_High = h;
            }
         }
      }
      
      if(bullOB_Low > 0.0 && bearOB_Low > 0.0) break;
   }
}


//+------------------------------------------------------------------+
//| Check if current price is trapped inside GNN golden/aqua channel |
//+------------------------------------------------------------------+
bool IsInsideGNNChannel()
{
   double nearestHighs[];
   double nearestLows[];
   string dummy = "";
   GetUntestedMagnets(nearestHighs, nearestLows, dummy);
   
   if(ArraySize(nearestHighs) > 0 && ArraySize(nearestLows) > 0)
   {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(currentPrice >= nearestLows[0] && currentPrice <= nearestHighs[0])
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Manage Sideways Escape (Exit at break-even in rangebound market) |
//+------------------------------------------------------------------+
void ManageSidewaysEscape(bool reversionModeActive)
{
   bool isSidewaysRegime = reversionModeActive || IsInsideGNNChannel();
   if(!isSidewaysRegime) return;
   
   int totalPositions = PositionsTotal();
   for(int i = totalPositions - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         string comment = PositionGetString(POSITION_COMMENT);
         if(comment == "HEDGE_FREEZE" || comment == "RECOVERY_ENTRY") continue;
         
         datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
         if(TimeCurrent() - posTime >= PeriodSeconds(_Period))
         {
            double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            if(profit >= 0.20)
            {
               PrintFormat("[Sideways Escape] Position #%I64u has been open for > 1 bar. Profit: $%.2f. Closing at range center...", ticket, profit);
               trade.PositionClose(ticket);
            }
         }
      }
   }
}


//+------------------------------------------------------------------+
//| Check Mid-Candle Event Triggers for AI Queries                   |
//+------------------------------------------------------------------+
void CheckMidCandleTriggers(datetime currentBarTime)
{
   if(!InpUseAIEngines || !g_eaRunning) return;
   if(CountActiveTrades() > 0) return;
   
   if(g_midCandleQueried || (TimeCurrent() - g_lastAICallTime < 30)) return;
   
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   bool triggerAI = false;
   string triggerReason = "";
   
   double nearestHighs[];
   double nearestLows[];
   string dummy = "";
   GetUntestedMagnets(nearestHighs, nearestLows, dummy);
   
   if(ArraySize(nearestLows) > 0 && MathAbs(currentBid - nearestLows[0]) <= 0.20)
   {
      triggerAI = true;
      triggerReason = StringFormat("GNN Aqua Support Floor Touch at %.2f", nearestLows[0]);
   }
   else if(ArraySize(nearestHighs) > 0 && MathAbs(currentAsk - nearestHighs[0]) <= 0.20)
   {
      triggerAI = true;
      triggerReason = StringFormat("GNN Golden Resistance Ceiling Touch at %.2f", nearestHighs[0]);
   }
   
   if(!triggerAI)
   {
      double bullOB_Low = 0.0, bullOB_High = 0.0;
      double bearOB_Low = 0.0, bearOB_High = 0.0;
      GetNearestOrderBlocks(bullOB_Low, bullOB_High, bearOB_Low, bearOB_High);
      
      if(bullOB_High > 0.0 && currentBid >= bullOB_Low && currentBid <= bullOB_High)
      {
         triggerAI = true;
         triggerReason = StringFormat("Institutional Demand (Bullish OB) Entry at %.2f", currentBid);
      }
      else if(bearOB_Low > 0.0 && currentAsk >= bearOB_Low && currentAsk <= bearOB_High)
      {
         triggerAI = true;
         triggerReason = StringFormat("Institutional Supply (Bearish OB) Entry at %.2f", currentAsk);
      }
   }
   
   if(!triggerAI)
   {
      double fvgLow = 0.0, fvgHigh = 0.0;
      int fvgType = 0;
      GetLatestUnmitigatedFVG(fvgLow, fvgHigh, fvgType);
      
      if(fvgType == 1 && currentBid >= fvgLow && currentBid <= fvgHigh)
      {
         triggerAI = true;
         triggerReason = StringFormat("Bullish FVG Imbalance Entry at %.2f", currentBid);
      }
      else if(fvgType == -1 && currentAsk >= fvgLow && currentAsk <= fvgHigh)
      {
         triggerAI = true;
         triggerReason = StringFormat("Bearish FVG Imbalance Entry at %.2f", currentAsk);
      }
   }
   
   if(triggerAI)
   {
      g_midCandleQueried = true;
      g_lastAICallTime = TimeCurrent();
      PrintFormat("[Mid-Candle Trigger] Event: %s. Querying AI Brain mid-candle...", triggerReason);
      ExecuteNewOrderPlacement(currentBarTime, true);
   }
}

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
         FetchEconomicCalendar();
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
      bool aiActive = (g_dailySentiment != "WAITING");
      useReversionMode = CalculateReversionMode(currentADX, isMomentumHour, isVolatilitySpike, aiActive, g_aiRegime);
   }
   
   // Keep dashboard drawn and updated on every tick
   DrawChartStatus(currentADX, currentATR, useReversionMode);
   
   // Process Sideways Escape
   ManageSidewaysEscape(useReversionMode);

   // Check if EA is paused by the on-chart button
   if(!g_eaRunning)
   {
      CancelPendingOrdersEx(true);
      return;
   }

   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   bool isNewBar = (currentBarTime != g_lastBarTime);
   
   if(isNewBar)
   {
      if(g_lastBarTime != 0)
      {
         ManageCandleCloseLossCutting(useReversionMode);
         
         // Trigger AI active trade management dynamically on candle close
         if(CountActiveTrades() > 0)
         {
            QueryAIActiveTradeManagement();
         }
      }
      
      g_lastBarTime = currentBarTime;
      CancelPendingOrdersEx(!useReversionMode);
      g_midCandleQueried = false; // Reset mid-candle status for the new bar!
   }

   if(g_eaRunning)
   {
      if(useReversionMode)
      {
         double nearestHighs[];
         double nearestLows[];
         string dummy = "";
         GetUntestedMagnets(nearestHighs, nearestLows, dummy);
         
         double rawBuy = (ArraySize(nearestLows) > 0) ? (nearestLows[0] + InpLimitOffset) : 0.0;
         double targetBuy = (rawBuy > 0.0) ? ((InpPriceRoundStep > 0.0) ? RoundToStep(rawBuy, InpPriceRoundStep) : NormalizeDouble(rawBuy, _Digits)) : 0.0;
         
         double rawSell = (ArraySize(nearestHighs) > 0) ? (nearestHighs[0] - InpLimitOffset) : 0.0;
         double targetSell = (rawSell > 0.0) ? ((InpPriceRoundStep > 0.0) ? RoundToStep(rawSell, InpPriceRoundStep) : NormalizeDouble(rawSell, _Digits)) : 0.0;
         
         VerifyAndSyncSidewaysLimits(targetBuy, targetSell);
      }
      else
      {
         // Clean up sideways limits if we transitioned to trending mode
         CancelPendingOrdersEx(true);
      }
   }

   // Place orders if not yet successfully processed for this candle and no open orders exist
   if(g_eaRunning && g_lastOrderPlacedBarTime != currentBarTime)
   {
      if(CountActiveTrades() == 0)
      {
         ExecuteNewOrderPlacement(currentBarTime);
      }
   }
   
   // Process Mid-Candle Event-Triggered Entries
   CheckMidCandleTriggers(currentBarTime);
}
//+------------------------------------------------------------------+
