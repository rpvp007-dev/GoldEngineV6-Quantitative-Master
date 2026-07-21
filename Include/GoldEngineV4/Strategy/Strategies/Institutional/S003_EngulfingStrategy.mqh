//+------------------------------------------------------------------+
//|                                       S003_EngulfingStrategy.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_S003_ENGULFING_STRATEGY_MQH
#define GOLDENGINEV2_S003_ENGULFING_STRATEGY_MQH

#include "../../IStrategy.mqh"
#include "../../../Core/Config.mqh"
#include "../../../Core/Logger.mqh"
#include "../../../QuantEngine/IMomentumEngine.mqh"
#include "../../../QuantEngine/IVolatilityEngine.mqh"
#include "../../../Core/MarketContext/IMarketContextEngine.mqh"

//+------------------------------------------------------------------+
//| S003 RSI Engulfing Candlestick Strategy Plug-in with Adv Filters |
//+------------------------------------------------------------------+
class CS003_EngulfingStrategy : public IStrategy
{
private:
   bool                       m_enabled;
   string                     m_name;
   CLogger*                   m_logger;
   CConfig*                   m_config;

   // Quant Engine references
   IMomentumEngine*           m_momentum;
   IVolatilityEngine*         m_volatility;
   IMarketContextEngine*      m_context;

   // Cumulative stats
   long                       m_barsEvaluated;
   long                       m_buyCount;
   long                       m_sellCount;
   long                       m_noTradeCount;

public:
   /**
    * @brief Constructor.
    */
   CS003_EngulfingStrategy(CLogger* logger, CConfig* config)
      : m_enabled(true),
        m_name("S-003"),
        m_logger(logger),
        m_config(config),
        m_momentum(NULL),
        m_volatility(NULL),
        m_context(NULL),
        m_barsEvaluated(0),
        m_buyCount(0),
        m_sellCount(0),
        m_noTradeCount(0)
   {}

   /**
    * @brief Destructor.
    */
   ~CS003_EngulfingStrategy()
   {
      PrintCumulativeStats();
   }

   /**
    * @brief Print diagnostic cumulative telemetry.
    */
   void PrintCumulativeStats()
   {
      m_logger.Info("====================================");
      m_logger.Info("S003 DIAGNOSTIC CUMULATIVE STATS");
      m_logger.Info("====================================");
      m_logger.Info(StringFormat("Bars Evaluated: %I64d", m_barsEvaluated));
      m_logger.Info(StringFormat("BUY Signals Generated: %I64d", m_buyCount));
      m_logger.Info(StringFormat("SELL Signals Generated: %I64d", m_sellCount));
      m_logger.Info(StringFormat("NO_TRADE Signals Generated: %I64d", m_noTradeCount));
      m_logger.Info("====================================");
   }

   /**
    * @brief Link required engines.
    */
   virtual bool Initialize(const QuantEnginesContainer &engines) override
   {
      m_momentum = engines.Momentum;
      m_volatility = engines.Volatility;
      m_context = engines.MarketContext;

      if(m_momentum == NULL)
      {
         m_logger.Error("S-003: Failed linking Momentum Engine pointer.");
         return false;
      }
      if(m_volatility == NULL)
      {
         m_logger.Error("S-003: Failed linking Volatility Engine pointer.");
         return false;
      }
      if(m_context == NULL)
      {
         m_logger.Error("S-003: Failed linking Market Context Engine pointer.");
         return false;
      }

      m_logger.Info("S-003: RSI Engulfing Strategy Plug-in successfully initialized with Advanced Filters.");
      return true;
   }

   virtual string GetName() const override { return m_name; }
   virtual void SetEnabled(bool enabled) override { m_enabled = enabled; }
   virtual bool IsEnabled() const override { return m_enabled; }

   /**
    * @brief Evaluate logic on closed bars.
    */
   virtual StrategyResponse Evaluate(const string symbol) override
   {
      StrategyResponse response;
      response.Signal         = GEV2_SIGNAL_NONE;
      response.EntryPrice     = 0.0;
      response.StopLoss       = 0.0;
      response.TakeProfit     = 0.0;
      response.Confidence     = 0.0;
      response.StrategyScore  = 0.0;
      response.TradeGrade     = "D";
      response.Reason         = "No Trade";
      response.StrategyName   = GetName();
      response.RawStrategyScore = 0.0;
      response.CompositeScore   = 0.0;
      response.PenaltyScore     = 0.0;

      if(!m_enabled)
      {
         response.Reason = "Strategy Disabled";
         return response;
      }

      m_barsEvaluated++;

      // 1. Spread Audit (News spike spread protection)
      long currentSpread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      double maxSpreadPoints = m_config.GetS003_MaxSpreadPoints();
      if((double)currentSpread > maxSpreadPoints)
      {
         response.Reason = StringFormat("Spread too high (%d points > %.1f max points). Rejecting trade setup.", currentSpread, maxSpreadPoints);
         m_noTradeCount++;
         return response;
      }

      // 2. Regime & Trade Environment Audit (Sideways/Low-quality chop protection)
      MarketContext ctx = m_context.GetContext();
      if(m_config.IsS003_FilterRanging())
      {
         if(ctx.MarketRegime == REGIME_RANGING || ctx.MarketRegime == REGIME_COMPRESSION)
         {
            response.Reason = StringFormat("Market regime is sideways/ranging (%s). Rejecting trade setup.", 
               (ctx.MarketRegime == REGIME_RANGING ? "RANGING" : "COMPRESSION"));
            m_noTradeCount++;
            return response;
         }
      }

      double minEnvScore = m_config.GetS003_MinEnvironmentScore();
      if(ctx.TradeEnvScore < minEnvScore)
      {
         response.Reason = StringFormat("Trade Environment Score too low (%.1f < %.1f minimum). Rejecting trade setup.", ctx.TradeEnvScore, minEnvScore);
         m_noTradeCount++;
         return response;
      }

      // 3. Fetch historical closed rates (0 = live, 1 = last closed, 2 = previous closed)
      MqlRates rates[];
      int copied = CopyRates(symbol, _Period, 0, 3, rates);
      if(copied < 3)
      {
         response.Reason = "Not enough history rates";
         m_noTradeCount++;
         return response;
      }
      ArraySetAsSeries(rates, true);

      // 4. Candle Size Audit (Too large = news spike risk, too small = noise risk)
      double atr = m_volatility.GetATR(symbol, _Period, 14, 1);
      double candleHeight = rates[1].high - rates[1].low;
      double maxAtrMult = m_config.GetS003_MaxAtrMultiplier();
      double minAtrMult = m_config.GetS003_MinAtrMultiplier();

      if(atr > 0.0)
      {
         if(candleHeight > maxAtrMult * atr)
         {
            response.Reason = StringFormat("Engulfing candle size too large (%.5f > %.1f * ATR %.5f). Rejecting news spike risk.", 
               candleHeight, maxAtrMult, atr);
            m_noTradeCount++;
            return response;
         }
         if(candleHeight < minAtrMult * atr)
         {
            response.Reason = StringFormat("Engulfing candle size too small (%.5f < %.1f * ATR %.5f). Rejecting market noise.", 
               candleHeight, minAtrMult, atr);
            m_noTradeCount++;
            return response;
         }
      }

      // 5. Fetch last closed RSI value
      double rsiVal = m_momentum.GetRSIValue(1);

      // 6. Define candlestick bodies
      double bodySize1 = rates[1].close - rates[1].open; // positive if bullish, negative if bearish
      double bodySize2 = rates[2].close - rates[2].open;

      bool isBullishEngulfing = false;
      bool isBearishEngulfing = false;

      // Detect Bullish Engulfing pattern
      if(bodySize2 < 0.0 && bodySize1 > 0.0) // Candle 2 was bearish, Candle 1 is bullish
      {
         // Candle 1 body covers Candle 2 body
         if(rates[1].open <= rates[2].close && rates[1].close >= rates[2].open)
         {
            // At least one side must be strictly larger to avoid equal bodies
            if(rates[1].open < rates[2].close || rates[1].close > rates[2].open)
            {
               isBullishEngulfing = true;
            }
         }
      }

      // Detect Bearish Engulfing pattern
      if(bodySize2 > 0.0 && bodySize1 < 0.0) // Candle 2 was bullish, Candle 1 is bearish
      {
         // Candle 1 body covers Candle 2 body
         if(rates[1].open >= rates[2].close && rates[1].close <= rates[2].open)
         {
            // At least one side must be strictly larger to avoid equal bodies
            if(rates[1].open > rates[2].close || rates[1].close < rates[2].open)
            {
               isBearishEngulfing = true;
            }
         }
      }

      // 7. Directional RSI Check: RSI > 50 -> ONLY BUY, RSI < 50 -> ONLY SELL
      if(rsiVal > 50.0)
      {
         if(isBullishEngulfing)
         {
            response.Signal = GEV2_SIGNAL_BUY;
            response.EntryPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
            response.StopLoss = rates[1].low;
            
            double slDistance = response.EntryPrice - response.StopLoss;
            if(slDistance > 0.0)
            {
               response.TakeProfit = response.EntryPrice + 2.0 * slDistance; // 1:2 Risk-Reward ratio
            }
            
            response.Confidence = ctx.ContextConfidence / 100.0;
            response.StrategyScore = ctx.TradeEnvScore;
            response.RawStrategyScore = ctx.TradeEnvScore;
            response.CompositeScore = ctx.TradeEnvScore;
            response.TradeGrade = ctx.MarketQuality;
            response.Reason = StringFormat("RSI above 50 (RSI=%.2f) and Bullish Engulfing pattern confirmed in %s conditions.", rsiVal, ctx.TradeEnvironment);
            m_buyCount++;
         }
         else
         {
            response.Reason = StringFormat("RSI above 50 (RSI=%.2f), only BUY allowed. No Bullish Engulfing pattern.", rsiVal);
            m_noTradeCount++;
         }
      }
      else if(rsiVal < 50.0)
      {
         if(isBearishEngulfing)
         {
            response.Signal = GEV2_SIGNAL_SELL;
            response.EntryPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
            response.StopLoss = rates[1].high;
            
            double slDistance = response.StopLoss - response.EntryPrice;
            if(slDistance > 0.0)
            {
               response.TakeProfit = response.EntryPrice - 2.0 * slDistance; // 1:2 Risk-Reward ratio
            }
            
            response.Confidence = ctx.ContextConfidence / 100.0;
            response.StrategyScore = ctx.TradeEnvScore;
            response.RawStrategyScore = ctx.TradeEnvScore;
            response.CompositeScore = ctx.TradeEnvScore;
            response.TradeGrade = ctx.MarketQuality;
            response.Reason = StringFormat("RSI below 50 (RSI=%.2f) and Bearish Engulfing pattern confirmed in %s conditions.", rsiVal, ctx.TradeEnvironment);
            m_sellCount++;
         }
         else
         {
            response.Reason = StringFormat("RSI below 50 (RSI=%.2f), only SELL allowed. No Bearish Engulfing pattern.", rsiVal);
            m_noTradeCount++;
         }
      }
      else
      {
         response.Reason = StringFormat("RSI neutral (RSI=%.2f). No trade permitted.", rsiVal);
         m_noTradeCount++;
      }

      return response;
   }
};

#endif // GOLDENGINEV2_S003_ENGULFING_STRATEGY_MQH
