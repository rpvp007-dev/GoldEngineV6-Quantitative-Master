//+------------------------------------------------------------------+
//|                                            ResearchFramework.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_RESEARCH_FRAMEWORK_MQH
#define GOLDENGINEV2_RESEARCH_FRAMEWORK_MQH

#include "IResearchFramework.mqh"
#include "../Core/Logger.mqh"
#include "../Core/Config.mqh"
#include "../Core/MarketContext/IMarketContextEngine.mqh"

// Struct for dynamic grouping statistics
struct GroupStats
{
   string Name;
   int    Total;
   int    Wins;
   int    Losses;
   double NetProfit;
   double ProfitSum;
   double LossSum;
   double HoldTimeSum;
   double MfesSum;
   double MaesSum;
};

//+------------------------------------------------------------------+
//| Concrete Research Framework Implementation                        |
//+------------------------------------------------------------------+
class CResearchFramework : public IResearchFramework
{
private:
   CLogger*             m_logger;
   CConfig*             m_config;

   ActiveTradeResearch  m_activeTrades[];
   int                  m_activeCount;

   TradeResearchRecord  m_records[];
   int                  m_recordsCount;

   /**
    * @brief Helper to translate Trend direction to string.
    */
   string GetTrendStateString(ITrendEngine* trend)
   {
      if(trend == NULL) return "Neutral";
      int dir = trend.GetTrendDirection(_Symbol, _Period);
      if(dir > 0)  return "Bullish";
      if(dir < 0)  return "Bearish";
      return "Neutral";
   }

   /**
    * @brief Helper to translate Movement state to string.
    */
   string GetMovementStateString(IMovementEngine* movement)
   {
      if(movement == NULL) return "Neutral";
      MovementContext ctx = movement.GetMovementContext();
      switch(ctx.MovementState)
      {
         case MOVEMENT_STATE_DEAD:      return "Dead";
         case MOVEMENT_STATE_SLOW:      return "Slow";
         case MOVEMENT_STATE_HEALTHY:   return "Healthy";
         case MOVEMENT_STATE_FAST:      return "Fast";
         case MOVEMENT_STATE_EXPLOSIVE: return "Explosive";
         default:                       return "Neutral";
      }
   }

   /**
    * @brief Helper to translate execution mode to string.
    */
   string GetExecutionModeString(ENUM_EXECUTION_MODE mode)
   {
      switch(mode)
      {
         case MODE_AVOID:    return "Avoid";
         case MODE_PROBE:    return "Probe";
         case MODE_SCALP:    return "Scalp";
         case MODE_MOMENTUM: return "Momentum";
         case MODE_RUNNER:   return "Runner";
         default:            return "Unknown";
      }
   }

   /**
    * @brief Helper to translate Market Regime to string.
    */
   string GetMarketRegimeString(ENUM_MARKET_REGIME regime)
   {
      switch(regime)
      {
         case REGIME_TRENDING:    return "Trending";
         case REGIME_RANGING:     return "Ranging";
         case REGIME_BREAKOUT:    return "Breakout";
         case REGIME_REVERSAL:    return "Reversal";
         case REGIME_COMPRESSION: return "Compression";
         case REGIME_EXPANSION:   return "Expansion";
         case REGIME_TRANSITION:  return "Transition";
         default:                 return "Unknown";
      }
   }

   /**
    * @brief Accumulates statistics inside dynamically resized GroupStats arrays.
    */
   void AccumulateGroup(GroupStats &arr[], string name, const TradeResearchRecord &rec)
   {
      int size = ArraySize(arr);
      int foundIdx = -1;
      for(int i = 0; i < size; i++)
      {
         if(arr[i].Name == name)
         {
            foundIdx = i;
            break;
         }
      }
      if(foundIdx == -1)
      {
         ArrayResize(arr, size + 1);
         foundIdx = size;
         arr[foundIdx].Name = name;
         arr[foundIdx].Total = 0;
         arr[foundIdx].Wins = 0;
         arr[foundIdx].Losses = 0;
         arr[foundIdx].NetProfit = 0.0;
         arr[foundIdx].ProfitSum = 0.0;
         arr[foundIdx].LossSum = 0.0;
         arr[foundIdx].HoldTimeSum = 0.0;
         arr[foundIdx].MfesSum = 0.0;
         arr[foundIdx].MaesSum = 0.0;
      }
      
      arr[foundIdx].Total++;
      double net = rec.Profit - rec.Loss;
      arr[foundIdx].NetProfit += net;
      if(net > 0.0)
      {
         arr[foundIdx].Wins++;
         arr[foundIdx].ProfitSum += rec.Profit;
      }
      else
      {
         arr[foundIdx].Losses++;
         arr[foundIdx].LossSum += rec.Loss;
      }
      arr[foundIdx].HoldTimeSum += rec.HoldingTime;
      arr[foundIdx].MfesSum += rec.MFE;
      arr[foundIdx].MaesSum += rec.MAE;
   }

   /**
    * @brief Helper to display stats for a specific group of records.
    */
   void PrintGroupReport(string title, GroupStats &arr[])
   {
      m_logger.Info("--------------------------------------------------");
      m_logger.Info(" Group-by: " + title);
      m_logger.Info("--------------------------------------------------");
      int size = ArraySize(arr);
      for(int i = 0; i < size; i++)
      {
         double winRate = (arr[i].Total > 0) ? (arr[i].Wins / (double)arr[i].Total) * 100.0 : 0.0;
         double avgWin = (arr[i].Wins > 0) ? arr[i].ProfitSum / arr[i].Wins : 0.0;
         double avgLoss = (arr[i].Losses > 0) ? arr[i].LossSum / arr[i].Losses : 0.0;
         double pf = (arr[i].LossSum > 0.0) ? arr[i].ProfitSum / arr[i].LossSum : (arr[i].ProfitSum > 0.0 ? 99.9 : 0.0);
         double expectancy = (arr[i].Total > 0) ? arr[i].NetProfit / arr[i].Total : 0.0;
         double avgHold = (arr[i].Total > 0) ? arr[i].HoldTimeSum / arr[i].Total : 0.0;
         double avgMFE = (arr[i].Total > 0) ? arr[i].MfesSum / arr[i].Total : 0.0;
         double avgMAE = (arr[i].Total > 0) ? arr[i].MaesSum / arr[i].Total : 0.0;

         m_logger.Info(StringFormat(" %s: Count=%d | Net=%.2f | WinRate=%.1f%% | PF=%.2f | Expectancy=%.2f",
            arr[i].Name, arr[i].Total, arr[i].NetProfit, winRate, pf, expectancy));
         m_logger.Info(StringFormat("   AvgWin=%.2f | AvgLoss=%.2f | AvgHold=%.0f sec | MFE=%.1f pts | MAE=%.1f pts",
            avgWin, avgLoss, avgHold, avgMFE, avgMAE));
      }
   }

public:
   /**
    * @brief Constructor.
    */
   CResearchFramework(CLogger* logger, CConfig* config)
      : m_logger(logger),
        m_config(config),
        m_activeCount(0),
        m_recordsCount(0)
   {}

   /**
    * @brief Destructor automatically triggers reporting.
    */
   ~CResearchFramework()
   {
      AnalyzeAndReport();
   }

   /**
    * @brief Snapshot active trade details at entry trigger.
    */
   virtual void OnTradeOpen(ulong ticket, const StrategyResponse &signal, const QuantEnginesContainer &container) override
   {
      // Verify signal
      if(signal.Signal != GEV2_SIGNAL_BUY && signal.Signal != GEV2_SIGNAL_SELL) return;

      ArrayResize(m_activeTrades, m_activeCount + 1);
      
      ActiveTradeResearch active;
      active.Ticket = ticket;
      active.EntryTime = TimeCurrent();
      active.EntryPrice = signal.EntryPrice;
      active.Direction = (signal.Signal == GEV2_SIGNAL_BUY) ? 1 : -1;
      active.MFE = 0.0;
      active.MAE = 0.0;

      // Capture snapshot values from intelligence models
      active.OpportunityScore = (container.Opportunity != NULL) ? container.Opportunity.GetOpportunityContext().OpportunityScore : 0.0;
      active.MovementScore    = (container.Movement != NULL) ? container.Movement.GetMovementContext().MovementScore : 0.0;
      active.MarketIntent     = (container.Intent != NULL) ? container.Intent.GetMarketIntentContext().IntentNarrative : "Neutral";
      active.TradeConfidence  = (container.Planner != NULL) ? container.Planner.GetTradePlanContext().TradeConfidence : 0.0;
      active.ExpectedMove     = (container.Planner != NULL) ? container.Planner.GetTradePlanContext().ExpectedMove : 0.0;
      active.EntryQuality     = (container.Opportunity != NULL) ? container.Opportunity.GetOpportunityContext().EntryQuality : 0.0;
      active.RiskRewardPlanned= (container.Planner != NULL) ? container.Planner.GetTradePlanContext().ExpectedRR : 0.0;
      
      active.ExecutionMode    = (container.Planner != NULL) ? GetExecutionModeString(container.Planner.GetTradePlanContext().ExecutionMode) : "Scalp";
      active.MarketContext    = (container.MarketContext != NULL) ? GetMarketRegimeString(container.MarketContext.GetContext().MarketRegime) : "Normal";
      active.Session          = (container.Session != NULL) ? container.Session.GetCurrentSession() : "London";
      active.TrendState       = GetTrendStateString(container.Trend);
      active.MovementState    = GetMovementStateString(container.Movement);
      active.OpportunityClass = (container.Opportunity != NULL) ? container.Opportunity.GetOpportunityContext().OpportunityClass : 0;

      m_activeTrades[m_activeCount] = active;
      m_activeCount++;
      m_logger.Debug(StringFormat("Research Framework: Tracked open position ticket #%I64u (Mode: %s)", ticket, active.ExecutionMode));
   }

   /**
    * @brief Tick-by-tick updates tracking MFE / MAE excursions.
    */
   virtual void UpdateOnTick(const string symbol) override
   {
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0.0) point = 0.0001;

      for(int i = 0; i < m_activeCount; i++)
      {
         if(m_activeTrades[i].Direction == 1) // BUY
         {
            double fav = (bid - m_activeTrades[i].EntryPrice) / point;
            double adv = (m_activeTrades[i].EntryPrice - bid) / point;
            if(fav > m_activeTrades[i].MFE) m_activeTrades[i].MFE = fav;
            if(adv > m_activeTrades[i].MAE) m_activeTrades[i].MAE = adv;
         }
         else // SELL
         {
            double fav = (m_activeTrades[i].EntryPrice - ask) / point;
            double adv = (ask - m_activeTrades[i].EntryPrice) / point;
            if(fav > m_activeTrades[i].MFE) m_activeTrades[i].MFE = fav;
            if(adv > m_activeTrades[i].MAE) m_activeTrades[i].MAE = adv;
         }
      }
   }

   /**
    * @brief Check closed trades to complete historical metrics.
    */
   virtual void CheckClosedTrades(const string symbol, const QuantEnginesContainer &container) override
   {
      int i = 0;
      while(i < m_activeCount)
      {
         ulong ticket = m_activeTrades[i].Ticket;
         if(!PositionSelectByTicket(ticket))
         {
            // Position was closed! Process exit metrics from deal history
            if(HistorySelect(m_activeTrades[i].EntryTime, TimeCurrent()))
            {
               int totalDeals = HistoryDealsTotal();
               ulong exitDealTicket = 0;
               double exitPrice = 0.0;
               datetime exitTime = 0;
               double profit = 0.0;
               string exitComment = "";

               for(int j = totalDeals - 1; j >= 0; j--)
               {
                  ulong t = HistoryDealGetTicket(j);
                  if(HistoryDealGetInteger(t, DEAL_POSITION_ID) == ticket && HistoryDealGetInteger(t, DEAL_ENTRY) == DEAL_ENTRY_OUT)
                  {
                     exitDealTicket = t;
                     exitPrice = HistoryDealGetDouble(t, DEAL_PRICE);
                     exitTime = (datetime)HistoryDealGetInteger(t, DEAL_TIME);
                     profit = HistoryDealGetDouble(t, DEAL_PROFIT) + HistoryDealGetDouble(t, DEAL_SWAP) + HistoryDealGetDouble(t, DEAL_COMMISSION);
                     exitComment = HistoryDealGetString(t, DEAL_COMMENT);
                     break;
                  }
               }

               if(exitDealTicket != 0)
               {
                  ArrayResize(m_records, m_recordsCount + 1);
                  TradeResearchRecord rec;

                  rec.TradeID = ticket;
                  rec.EntryTime = m_activeTrades[i].EntryTime;
                  rec.ExitTime = exitTime;
                  rec.HoldingTime = (double)(exitTime - m_activeTrades[i].EntryTime);
                  rec.ExecutionMode = m_activeTrades[i].ExecutionMode;
                  rec.OpportunityScore = m_activeTrades[i].OpportunityScore;
                  rec.MovementScore = m_activeTrades[i].MovementScore;
                  rec.MarketIntent = m_activeTrades[i].MarketIntent;
                  rec.TradeConfidence = m_activeTrades[i].TradeConfidence;
                  rec.ExpectedMove = m_activeTrades[i].ExpectedMove;

                  double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
                  if(point <= 0.0) point = 0.0001;

                  rec.ActualMove = MathAbs(exitPrice - m_activeTrades[i].EntryPrice) / point;
                  rec.MFE = m_activeTrades[i].MFE;
                  rec.MAE = m_activeTrades[i].MAE;
                  rec.EntryQuality = m_activeTrades[i].EntryQuality;
                  rec.ExitQuality = (container.Opportunity != NULL) ? container.Opportunity.GetOpportunityContext().ExitQuality : 0.0;
                  rec.RiskRewardPlanned = m_activeTrades[i].RiskRewardPlanned;

                  double slDistance = MathAbs(m_activeTrades[i].EntryPrice - m_activeTrades[i].RiskRewardPlanned); // Relative reference
                  rec.RiskRewardAchieved = (slDistance > 0.0) ? MathAbs(exitPrice - m_activeTrades[i].EntryPrice) / slDistance : 0.0;

                  rec.Profit = (profit > 0.0) ? profit : 0.0;
                  rec.Loss = (profit < 0.0) ? MathAbs(profit) : 0.0;
                  rec.ReasonForExit = (exitComment != "") ? exitComment : "TP/SL/Manual";

                  rec.MarketContext = m_activeTrades[i].MarketContext;
                  rec.Session = m_activeTrades[i].Session;
                  rec.TrendState = m_activeTrades[i].TrendState;
                  rec.MovementState = m_activeTrades[i].MovementState;
                  rec.OpportunityClass = m_activeTrades[i].OpportunityClass;

                  m_records[m_recordsCount] = rec;
                  m_recordsCount++;
                  m_logger.Info(StringFormat("[Research] Closed trade recorded. ID: %I64u | Mode: %s | MFE: %.1f | MAE: %.1f | Profit: %.2f",
                     rec.TradeID, rec.ExecutionMode, rec.MFE, rec.MAE, profit));
               }
            }

            // Remove from active list
            for(int k = i; k < m_activeCount - 1; k++)
            {
               m_activeTrades[k] = m_activeTrades[k+1];
            }
            m_activeCount--;
            ArrayResize(m_activeTrades, m_activeCount);
         }
         else
         {
            i++;
         }
      }
   }

   /**
    * @brief Processes grouped metrics and prints analytical reports.
    */
   virtual void AnalyzeAndReport() override
   {
      if(m_recordsCount == 0)
      {
         m_logger.Info("==================================================");
         m_logger.Info("   QUANT RESEARCH FRAMEWORK - NO CLOSED SAMPLES");
         m_logger.Info("==================================================");
         return;
      }

      GroupStats executionModeStats[];
      GroupStats marketContextStats[];
      GroupStats sessionStats[];
      GroupStats trendStats[];
      GroupStats movementStats[];
      GroupStats opportunityClassStats[];

      for(int i = 0; i < m_recordsCount; i++)
      {
         AccumulateGroup(executionModeStats, m_records[i].ExecutionMode, m_records[i]);
         AccumulateGroup(marketContextStats, m_records[i].MarketContext, m_records[i]);
         AccumulateGroup(sessionStats, m_records[i].Session, m_records[i]);
         AccumulateGroup(trendStats, m_records[i].TrendState, m_records[i]);
         AccumulateGroup(movementStats, m_records[i].MovementState, m_records[i]);
         
         string oppClassStr = StringFormat("Class %d", m_records[i].OpportunityClass);
         AccumulateGroup(opportunityClassStats, oppClassStr, m_records[i]);
      }

      m_logger.Info("==================================================");
      m_logger.Info("   QUANT RESEARCH FRAMEWORK REPORT - V4.1.0");
      m_logger.Info("==================================================");
      
      PrintGroupReport("EXECUTION MODES", executionModeStats);
      PrintGroupReport("MARKET CONTEXT REGIMES", marketContextStats);
      PrintGroupReport("TRADING SESSIONS", sessionStats);
      PrintGroupReport("TREND STATE CONFIGURATIONS", trendStats);
      PrintGroupReport("MOVEMENT DYNAMICS", movementStats);
      PrintGroupReport("OPPORTUNITY CLASSIFICATIONS", opportunityClassStats);

      // Perform Best/Worst analytics mapping
      GroupStats bestMode = {}; bestMode.NetProfit = -99999.0;
      GroupStats worstMode = {}; worstMode.NetProfit = 99999.0;
      int countModes = ArraySize(executionModeStats);
      for(int i = 0; i < countModes; i++)
      {
         if(executionModeStats[i].NetProfit > bestMode.NetProfit) bestMode = executionModeStats[i];
         if(executionModeStats[i].NetProfit < worstMode.NetProfit) worstMode = executionModeStats[i];
      }

      GroupStats bestRegime = {}; bestRegime.NetProfit = -99999.0;
      GroupStats worstRegime = {}; worstRegime.NetProfit = 99999.0;
      int countRegimes = ArraySize(marketContextStats);
      for(int i = 0; i < countRegimes; i++)
      {
         if(marketContextStats[i].NetProfit > bestRegime.NetProfit) bestRegime = marketContextStats[i];
         if(marketContextStats[i].NetProfit < worstRegime.NetProfit) worstRegime = marketContextStats[i];
      }

      m_logger.Info("--------------------------------------------------");
      m_logger.Info(" CRITICAL QUANT INSIGHTS SUMMARY");
      m_logger.Info("--------------------------------------------------");
      if(bestMode.Name != "")
      {
         m_logger.Info(StringFormat(" Top Performing Mode:   %s (Profit: %.2f)", bestMode.Name, bestMode.NetProfit));
      }
      if(worstMode.Name != "")
      {
         m_logger.Info(StringFormat(" Worst Performing Mode: %s (Profit: %.2f)", worstMode.Name, worstMode.NetProfit));
      }
      if(bestRegime.Name != "")
      {
         m_logger.Info(StringFormat(" Top Performing Regime: %s (Profit: %.2f)", bestRegime.Name, bestRegime.NetProfit));
      }
      if(worstRegime.Name != "")
      {
         m_logger.Info(StringFormat(" Worst Performing Regime: %s (Profit: %.2f)", worstRegime.Name, worstRegime.NetProfit));
      }
      m_logger.Info("==================================================");
   }
};

#endif // GOLDENGINEV2_RESEARCH_FRAMEWORK_MQH
