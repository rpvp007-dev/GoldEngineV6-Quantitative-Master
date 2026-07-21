//+------------------------------------------------------------------+
//|                                                        Utils.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_UTILS_MQH
#define GOLDENGINEV2_UTILS_MQH

//+------------------------------------------------------------------+
//| Shared Utilities class                                           |
//+------------------------------------------------------------------+
class CUtils
{
public:
   /**
    * @brief Normalizes a price according to symbol properties.
    * @param symbol Symbol name (e.g. "XAUUSD")
    * @param price Raw price value
    * @return Normalized price double
    */
   static double NormalizePrice(const string symbol, double price)
   {
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize <= 0.0)
      {
         int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
         return NormalizeDouble(price, digits);
      }
      return NormalizeDouble(MathRound(price / tickSize) * tickSize, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   }

   /**
    * @brief Normalizes a lot size according to symbol properties.
    * @param symbol Symbol name
    * @param lot Raw lot size
    * @return Normalized lot size double
    */
   static double NormalizeLot(const string symbol, double lot)
   {
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      double normalized = MathFloor(lot / lotStep) * lotStep;
      if(normalized < minLot) normalized = minLot;
      if(normalized > maxLot) normalized = maxLot;
      
      return NormalizeDouble(normalized, 2);
   }

   /**
    * @brief Validates if a price meets broker Stops Level requirement.
    * @param symbol Symbol name
    * @param entryPrice Proposed entry price
    * @param levelPrice Proposed stop loss or take profit price
    * @return true if valid distance, false if too close
    */
   static bool CheckStopsLevel(const string symbol, double entryPrice, double levelPrice)
   {
      int stopsLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      if(stopsLevel == 0) return true; // No stops level limitation

      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double distance = MathAbs(entryPrice - levelPrice);
      double minDistance = stopsLevel * point;

      return (distance >= minDistance);
   }

   /**
    * @brief Checks if a string contains another string (case-insensitive).
    */
   static bool StringContains(string haystack, string needle)
   {
      StringToLower(haystack);
      StringToLower(needle);
      return (StringFind(haystack, needle) >= 0);
   }
};

#endif // GOLDENGINEV2_UTILS_MQH
