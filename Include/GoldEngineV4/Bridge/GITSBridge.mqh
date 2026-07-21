//+------------------------------------------------------------------+
//|                                                   GITSBridge.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_GITS_BRIDGE_MQH
#define GOLDENGINEV2_GITS_BRIDGE_MQH

#include "IGITSBridge.mqh"
#include "../Strategy/IStrategy.mqh"
#include "../QuantEngine/IOpportunityEngine.mqh"
#include "../QuantEngine/IMovementEngine.mqh"
#include "../QuantEngine/IMarketIntentEngine.mqh"
#include "../QuantEngine/ITradePlannerEngine.mqh"
#include "../Core/MarketContext/IMarketContextEngine.mqh"
#include "../Core/DecisionEngine/IDecisionEngine.mqh"
#include "../QuantEngine/IVolumeEngine.mqh"
#include "../QuantEngine/IPullbackReversalEngine.mqh"
#include "../QuantEngine/IAdaptiveExitAIEngine.mqh"
#include "../QuantEngine/IInstitutionalExecutionManager.mqh"

class CGITSBridge : public IGITSBridge
{
private:
   string   m_stateFileName;
   string   m_configFileName;
   datetime m_lastConfigModifyTime;
   IStrategy* m_strategy;
   
   // Helper to escape simple JSON string values
   string EscapeStr(string val)
   {
      StringReplace(val, "\\", "\\\\");
      StringReplace(val, "\"", "\\\"");
      StringReplace(val, "\n", "\\n");
      StringReplace(val, "\r", "\\r");
      return val;
   }

   // JSON Parser Helpers
   double GetDoubleValue(const string json, string key, double defaultValue)
   {
      int pos = StringFind(json, "\"" + key + "\"");
      if(pos == -1) return defaultValue;
      
      pos = StringFind(json, ":", pos);
      if(pos == -1) return defaultValue;
      pos++; // skip ':'
      
      // Skip spaces/control chars
      while(pos < StringLen(json) && (StringGetCharacter(json, pos) == ' ' || StringGetCharacter(json, pos) == '\t' || StringGetCharacter(json, pos) == '\r' || StringGetCharacter(json, pos) == '\n'))
         pos++;
         
      int end = pos;
      while(end < StringLen(json) && 
            ((StringGetCharacter(json, end) >= '0' && StringGetCharacter(json, end) <= '9') || 
             StringGetCharacter(json, end) == '.' || StringGetCharacter(json, end) == '-'))
      {
         end++;
      }
      if(end == pos) return defaultValue;
      string valStr = StringSubstr(json, pos, end - pos);
      return StringToDouble(valStr);
   }

   bool GetBoolValue(const string json, string key, bool defaultValue)
   {
      int pos = StringFind(json, "\"" + key + "\"");
      if(pos == -1) return defaultValue;
      
      pos = StringFind(json, ":", pos);
      if(pos == -1) return defaultValue;
      pos++;
      
      while(pos < StringLen(json) && (StringGetCharacter(json, pos) == ' ' || StringGetCharacter(json, pos) == '\t' || StringGetCharacter(json, pos) == '\r' || StringGetCharacter(json, pos) == '\n'))
         pos++;
         
      if(pos < StringLen(json) && StringSubstr(json, pos, 4) == "true")
         return true;
      if(pos < StringLen(json) && StringSubstr(json, pos, 5) == "false")
         return false;
         
      return defaultValue;
   }

   string GetStringValue(const string json, string key, string defaultValue)
   {
      int pos = StringFind(json, "\"" + key + "\"");
      if(pos == -1) return defaultValue;
      
      pos = StringFind(json, ":", pos);
      if(pos == -1) return defaultValue;
      pos++;
      
      int openQuote = StringFind(json, "\"", pos);
      if(openQuote == -1) return defaultValue;
      
      int closeQuote = StringFind(json, "\"", openQuote + 1);
      if(closeQuote == -1) return defaultValue;
      
      return StringSubstr(json, openQuote + 1, closeQuote - openQuote - 1);
   }

   int GetIntValue(const string json, string key, int defaultValue)
   {
      return (int)GetDoubleValue(json, key, (double)defaultValue);
   }

public:
   CGITSBridge()
   {
      m_stateFileName = "";
      m_configFileName = "";
      m_lastConfigModifyTime = 0;
      m_strategy = NULL;
   }
   
   ~CGITSBridge() {}
   
   virtual void RegisterStrategyReference(IStrategy* strategy)
   {
      m_strategy = strategy;
   }
   
   virtual bool Initialize(string stateFileName, string configFileName)
   {
      m_stateFileName = stateFileName;
      m_configFileName = configFileName;
      m_lastConfigModifyTime = 0;
      
      // Reset config modification time so we load it at start
      if(FileIsExist(m_configFileName))
      {
         m_lastConfigModifyTime = (datetime)FileGetInteger(m_configFileName, FILE_MODIFY_DATE, false);
      }
      return true;
   }
   
   virtual void ExportState(const QuantEnginesContainer &container,
                            ITradeStatistics* stats,
                            IPerformanceTracker* tracker,
                            IRiskGuardian* risk,
                            double currentSpreadPoints)
   {
      if(m_stateFileName == "") return;
      
      // Fetch engine data safely
      double compScore = 0.0;
      string dirRec = "None";
      string execMode = "Avoid";
      double mvPillar = 0.0, oppPillar = 0.0, intPillar = 0.0, ctxPillar = 0.0, volPillar = 0.0;
      string regime = "Unknown";
      
      string mvNarrative = "Movement Engine Offline";
      string intNarrative = "Intent Engine Offline";
      string tradeNarrative = "Planner Engine Offline";
      
      // Get volume RVOL
      double rvol = 0.0;
      if(container.Volume != NULL)
      {
         rvol = container.Volume.GetRelativeVolume();
         if(rvol >= 1.5)      volPillar = 10.0;
         else if(rvol >= 1.0) volPillar =  7.0;
         else if(rvol >= 0.7) volPillar =  4.0;
         else                 volPillar =  1.0;
      }
      
      // Mapped values
      if(container.Opportunity != NULL)
      {
         OpportunityContext opp = container.Opportunity.GetOpportunityContext();
         oppPillar = (double)opp.OpportunityClass; // enum map in X001
      }
      if(container.Movement != NULL)
      {
         MovementContext mov = container.Movement.GetMovementContext();
         mvPillar = (double)mov.MovementState; // enum map in X001
         mvNarrative = EscapeStr(mov.MovementNarrative);
      }
      if(container.Intent != NULL)
      {
         MarketIntentContext intent = container.Intent.GetMarketIntentContext();
         intPillar = (double)intent.MarketCommitment; // enum map in X001
         intNarrative = EscapeStr(intent.IntentNarrative);
      }
      if(container.MarketContext != NULL)
      {
         MarketContext ctx = container.MarketContext.GetContext();
         ctxPillar = (double)ctx.MarketRegime; // enum map in X001
         
         switch(ctx.MarketRegime)
         {
            case REGIME_TRENDING:    regime = "TRENDING"; break;
            case REGIME_RANGING:     regime = "RANGING"; break;
            case REGIME_BREAKOUT:    regime = "BREAKOUT"; break;
            case REGIME_REVERSAL:    regime = "REVERSAL"; break;
            case REGIME_COMPRESSION: regime = "COMPRESSION"; break;
            case REGIME_EXPANSION:   regime = "EXPANSION"; break;
            case REGIME_TRANSITION:  regime = "TRANSITION"; break;
            default:                 regime = "UNKNOWN"; break;
         }
      }
      if(container.Planner != NULL)
      {
         TradePlanContext plan = container.Planner.GetTradePlanContext();
         
         switch(plan.DirectionRec)
         {
            case REC_DIR_BUY:  dirRec = "BUY"; break;
            case REC_DIR_SELL: dirRec = "SELL"; break;
            case REC_DIR_NONE: 
            default:           dirRec = "NONE"; break;
         }
         
         switch(plan.ExecutionMode)
         {
            case MODE_PROBE:    execMode = "PROBE"; break;
            case MODE_SCALP:    execMode = "SCALP"; break;
            case MODE_MOMENTUM: execMode = "MOMENTUM"; break;
            case MODE_RUNNER:   execMode = "RUNNER"; break;
            case MODE_AVOID:
            default:            execMode = "AVOID"; break;
         }
         tradeNarrative = EscapeStr(plan.TradeNarrative);
      }
      
      // Collect positions
      int openCount = 0;
      int buyCount = 0;
      int sellCount = 0;
      double totalLots = 0.0;
      double unrealizedPnL = 0.0;
      
      string posListJson = "";
      
      int totalPos = PositionsTotal();
      for(int i = 0; i < totalPos; i++)
      {
         if(PositionGetSymbol(i) == _Symbol)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double lots = PositionGetDouble(POSITION_VOLUME);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double pnl = PositionGetDouble(POSITION_PROFIT);
            string comment = PositionGetString(POSITION_COMMENT);
            
            openCount++;
            totalLots += lots;
            unrealizedPnL += pnl;
            
            string typeStr = "BUY";
            if(type == POSITION_TYPE_BUY) { buyCount++; typeStr = "BUY"; }
            else { sellCount++; typeStr = "SELL"; }
            
            if(posListJson != "") posListJson += ",";
            posListJson += StringFormat("{\"ticket\":%d,\"type\":\"%s\",\"lots\":%.2f,\"open_price\":%.2f,\"pnl\":%.2f,\"comment\":\"%s\"}",
                                        ticket, typeStr, lots, openPrice, pnl, EscapeStr(comment));
         }
      }
      
      // Session info
      string sessionStr = "Unknown";
      if(container.Session != NULL)
      {
         sessionStr = container.Session.GetCurrentSession();
      }
      
      // Risk guardian metrics
      double maxDD = 0.0;
      if(tracker != NULL)
      {
         maxDD = tracker.GetMaxDrawdownPercent();
      }
      
      // Build JSON State String
      string json = "{";
      
      // Meta
      json += StringFormat("\"_meta\":{\"gits_version\":\"4.4\",\"symbol\":\"%s\",\"timestamp_utc\":\"%s\",\"uptime_sec\":%d},",
                           _Symbol, TimeToString(TimeGMT(), TIME_DATE|TIME_MINUTES|TIME_SECONDS), GetTickCount() / 1000);
                           
      // Market
      json += StringFormat("\"market\":{\"bid\":%.2f,\"ask\":%.2f,\"spread_points\":%.1f,\"session\":\"%s\"},",
                           SymbolInfoDouble(_Symbol, SYMBOL_BID), SymbolInfoDouble(_Symbol, SYMBOL_ASK), currentSpreadPoints, sessionStr);
                           
      // Engines
      // Real composite score calculation helper mapping X001's internal ComputeCompositeScore
      // Since ComputeCompositeScore uses internal structures, we show the last computed score
      // Note: we fetch composite score from OpportunityEngine or compute it locally.
      // For accurate display, we fetch composite score by calling OpportunityEngine's score
      double opportunityScore = 0.0;
      if(container.Opportunity != NULL)
      {
         OpportunityContext opp = container.Opportunity.GetOpportunityContext();
         opportunityScore = opp.OpportunityScore;
      }
      
      json += StringFormat("\"engines\":{\"composite_score\":%.1f,\"direction\":\"%s\",\"execution_mode\":\"%s\",",
                           opportunityScore, dirRec, execMode);
      json += StringFormat("\"pillar_movement\":%.1f,\"pillar_opportunity\":%.1f,\"pillar_intent\":%.1f,",
                           mvPillar, oppPillar, intPillar);
      json += StringFormat("\"pillar_context\":%.1f,\"pillar_volume\":%.1f,\"market_regime\":\"%s\",",
                           ctxPillar, volPillar, regime);
      json += StringFormat("\"movement_narrative\":\"%s\",\"intent_narrative\":\"%s\",\"trade_narrative\":\"%s\"},",
                           mvNarrative, intNarrative, tradeNarrative);
                           
      // Positions
      json += StringFormat("\"positions\":{\"open_count\":%d,\"buy_count\":%d,\"sell_count\":%d,\"total_lots\":%.2f,\"unrealized_pnl\":%.2f,\"list\":[%s]},",
                           openCount, buyCount, sellCount, totalLots, unrealizedPnL, posListJson);
                           
      // Trade Manager info (V4.6 addition)
      string tmJson = "{\"active\":false,\"tracking_count\":0,\"list\":[]}";
      if(container.TradeManager != NULL)
      {
         int tmCount = container.TradeManager.GetActiveTrackingCount();
         string tmList = "";
         for(int j = 0; j < tmCount; j++)
         {
            TradeTrackingState tmState;
            if(container.TradeManager.GetTrackingState(j, tmState))
            {
               if(tmList != "") tmList += ",";
               tmList += StringFormat("{\"ticket\":%d,\"be_active\":%s,\"trail_active\":%s,\"locked_profit\":%.1f,\"mfe\":%.1f,\"mae\":%.1f,\"duration_sec\":%d,\"health_score\":%.1f,\"health_state\":\"%s\",\"health_narrative\":\"%s\"}",
                                      tmState.Ticket,
                                      tmState.BreakEvenActive ? "true" : "false",
                                      tmState.TrailingActive ? "true" : "false",
                                      tmState.LockedProfitPoints,
                                      tmState.MaxProfitReachedPoints,
                                      tmState.MaxLossReachedPoints,
                                      tmState.TradeDurationSec,
                                      tmState.HealthScore,
                                      tmState.HealthStateStr,
                                      EscapeStr(tmState.HealthNarrative));
            }
         }
         tmJson = StringFormat("{\"active\":true,\"tracking_count\":%d,\"list\":[%s]}", tmCount, tmList);
      }
      json += StringFormat("\"trade_manager\":%s,", tmJson);
      
      // Trade Optimization info (V4.8 addition)
      string optJson = "{\"active\":false,\"win_rate\":0.0,\"profit_factor\":0.0,\"expectancy\":0.0,\"best_session\":\"None\",\"worst_session\":\"None\",\"best_regime\":\"None\",\"worst_regime\":\"None\",\"observations\":[]}";
      if(container.TradeOptimization != NULL)
      {
         GITSPerformanceStats optStats = container.TradeOptimization.GetPerformanceStats();
         string obsList = "";
         int obsCount = container.TradeOptimization.GetObservationsCount();
         for(int k = 0; k < obsCount; k++)
         {
            if(obsList != "") obsList += ",";
            obsList += StringFormat("\"%s\"", EscapeStr(container.TradeOptimization.GetObservation(k)));
         }
         optJson = StringFormat("{\"active\":true,\"win_rate\":%.1f,\"profit_factor\":%.2f,\"expectancy\":%.1f,\"best_session\":\"%s\",\"worst_session\":\"%s\",\"best_regime\":\"%s\",\"worst_regime\":\"%s\",\"observations\":[%s]}",
                                optStats.WinRate,
                                optStats.ProfitFactor,
                                optStats.Expectancy,
                                EscapeStr(optStats.BestSession),
                                EscapeStr(optStats.WorstSession),
                                EscapeStr(optStats.BestRegime),
                                EscapeStr(optStats.WorstRegime),
                                obsList);
      }
      json += StringFormat("\"optimization\":%s,", optJson);
      
      // Pullback vs Reversal info (V4.9 addition)
      string pbJson = "{\"active\":false,\"state\":\"None\",\"continuation_pct\":50.0,\"reversal_pct\":0.0,\"breakout_authenticity\":50.0,\"recommendation\":\"WAIT\",\"narrative\":\"Pullback engine inactive.\",\"confidence\":0.0}";
      if(container.PullbackReversal != NULL)
      {
         PullbackReversalContext pbCtx = container.PullbackReversal.GetEvaluationContext();
         pbJson = StringFormat("{\"active\":true,\"state\":\"%s\",\"continuation_pct\":%.1f,\"reversal_pct\":%.1f,\"breakout_authenticity\":%.1f,\"recommendation\":\"%s\",\"narrative\":\"%s\",\"confidence\":%.1f}",
                               PullbackStateToString(pbCtx.State),
                               pbCtx.ContinuationProb,
                               pbCtx.ReversalProb,
                               pbCtx.BreakoutAuthenticity,
                               PullbackRecToString(pbCtx.Recommendation),
                               EscapeStr(pbCtx.Narrative),
                               pbCtx.Confidence);
      }
      json += StringFormat("\"pullback\":%s,", pbJson);
      
      // Adaptive Exit AI info (V4.10 addition)
      string aeJson = "{\"active\":false,\"recommendation\":\"WAIT\",\"confidence\":50.0,\"narrative\":\"Adaptive exit inactive.\",\"risk_level\":\"Low\",\"expected_remaining_move\":0.0,\"recommended_stop\":0.0,\"recommended_trail\":50.0,\"hold_score\":50.0,\"exit_score\":0.0,\"runner_score\":0.0}";
      if(container.AdaptiveExit != NULL)
      {
         AdaptiveExitContext aeCtx = container.AdaptiveExit.GetExitContext();
         aeJson = StringFormat("{\"active\":true,\"recommendation\":\"%s\",\"confidence\":%.1f,\"narrative\":\"%s\",\"risk_level\":\"%s\",\"expected_remaining_move\":%.1f,\"recommended_stop\":%.2f,\"recommended_trail\":%.1f,\"hold_score\":%.1f,\"exit_score\":%.1f,\"runner_score\":%.1f}",
                               AdaptiveExitActionToString(aeCtx.Recommendation),
                               aeCtx.Confidence,
                               EscapeStr(aeCtx.Narrative),
                               EscapeStr(aeCtx.RiskLevel),
                               aeCtx.ExpectedRemainingMove,
                               aeCtx.RecommendedStop,
                               aeCtx.RecommendedTrail,
                               aeCtx.HoldScore,
                               aeCtx.ExitScore,
                               aeCtx.RunnerScore);
      }
      json += StringFormat("\"adaptive_exit\":%s,", aeJson);
      
      // Institutional Execution info (V5.0 addition)
      string ieJson = "{\"active\":false,\"recommendation\":\"WAIT\",\"portfolio_health\":100.0,\"total_exposure\":0.0,\"long_exposure\":0.0,\"short_exposure\":0.0,\"net_exposure\":0.0,\"portfolio_risk\":0.0,\"active_scouts\":0,\"active_scalps\":0,\"active_momentums\":0,\"active_runners\":0,\"capital_allocation\":0.1,\"priority_score\":50.0,\"narrative\":\"Execution manager inactive.\"}";
      if(container.InstitutionalExecution != NULL)
      {
         InstitutionalExecutionContext ieCtx = container.InstitutionalExecution.GetExecutionContext();
         ieJson = StringFormat("{\"active\":true,\"recommendation\":\"%s\",\"portfolio_health\":%.1f,\"total_exposure\":%.2f,\"long_exposure\":%.2f,\"short_exposure\":%.2f,\"net_exposure\":%.2f,\"portfolio_risk\":%.1f,\"active_scouts\":%d,\"active_scalps\":%d,\"active_momentums\":%d,\"active_runners\":%d,\"capital_allocation\":%.2f,\"priority_score\":%.1f,\"narrative\":\"%s\"}",
                               InstitutionalExecActionToString(ieCtx.Recommendation),
                               ieCtx.PortfolioHealth,
                               ieCtx.TotalExposure,
                               ieCtx.LongExposure,
                               ieCtx.ShortExposure,
                               ieCtx.NetExposure,
                               ieCtx.PortfolioRisk,
                               ieCtx.ActiveScouts,
                               ieCtx.ActiveScalps,
                               ieCtx.ActiveMomentums,
                               ieCtx.ActiveRunners,
                               ieCtx.CapitalAllocation,
                               ieCtx.PriorityScore,
                               EscapeStr(ieCtx.Narrative));
      }
      json += StringFormat("\"institutional_execution\":%s,", ieJson);
                            
      // Account
      json += StringFormat("\"account\":{\"balance\":%.2f,\"equity\":%.2f,\"margin_level\":%.2f},",
                           AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY), AccountInfoDouble(ACCOUNT_MARGIN_LEVEL));
                           
      // Performance
      double dailyPnl = 0.0;
      double weeklyPnl = 0.0;
      int tradesToday = 0;
      double winRateToday = 0.0;
      if(stats != NULL)
      {
         dailyPnl = stats.GetTotalProfit();
         tradesToday = stats.GetTotalTrades();
         if(tradesToday > 0)
         {
            winRateToday = ((double)stats.GetWinTrades() / (double)tradesToday) * 100.0;
         }
      }
      json += StringFormat("\"performance\":{\"daily_pnl\":%.2f,\"weekly_pnl\":%.2f,\"drawdown_pct\":%.2f,\"trades_today\":%d,\"win_rate_today\":%.1f},",
                           dailyPnl, weeklyPnl, maxDD, tradesToday, winRateToday);
                           
      // Research counters
      int totalOpps = 0;
      int totalTaken = 0;
      int totalRej = 0;
      double avgScore = 0.0;
      if(m_strategy != NULL)
      {
         totalOpps = m_strategy.GetTotalOpportunities();
         totalTaken = m_strategy.GetTotalTradesTaken();
         totalRej = m_strategy.GetOpportunitiesRejected();
         avgScore = m_strategy.GetAverageEntryScore();
      }
      
      json += StringFormat("\"research\":{\"total_opportunities\":%d,\"total_taken\":%d,\"total_rejected\":%d,\"avg_composite_score\":%.1f,\"avg_mfe_pts\":0.0,\"avg_mae_pts\":0.0,",
                           totalOpps, totalTaken, totalRej, avgScore);
      json += "\"rejection_reasons\":[],\"score_distribution\":[]},";
      
      // Activity Log (blank array or simple print of last message)
      json += "\"activity_log\":[]";
      
      json += "}";
      
      // Write JSON to file
      int handle = FileOpen(m_stateFileName, FILE_WRITE | FILE_TXT | FILE_ANSI);
      if(handle != INVALID_HANDLE)
      {
         FileWriteString(handle, json);
         FileClose(handle);
      }
   }
   
   virtual bool CheckAndApplyConfig(GITSBridgeConfig &outConfig)
   {
      if(m_configFileName == "" || !FileIsExist(m_configFileName)) return false;
      
      datetime modTime = (datetime)FileGetInteger(m_configFileName, FILE_MODIFY_DATE, false);
      if(modTime == m_lastConfigModifyTime) return false;
      
      // File has been modified, parse it!
      m_lastConfigModifyTime = modTime;
      
      int handle = FileOpen(m_configFileName, FILE_READ | FILE_TXT | FILE_ANSI);
      if(handle == INVALID_HANDLE) return false;
      
      string json = "";
      while(!FileIsEnding(handle))
      {
         json += FileReadString(handle);
      }
      FileClose(handle);
      
      if(json == "") return false;
      
      // Parse values
      outConfig.Mode = GetStringValue(json, "mode", "research");
      outConfig.X001Enabled = GetBoolValue(json, "enabled", true);
      
      // Risk Config
      outConfig.Risk.RiskPercent = GetDoubleValue(json, "risk_pct", 1.0);
      outConfig.Risk.MaxDailyLossPercent = GetDoubleValue(json, "daily_loss_pct", 3.0);
      outConfig.Risk.MaxWeeklyLossPercent = GetDoubleValue(json, "weekly_loss_pct", 8.0);
      outConfig.Risk.MaxPositions = GetIntValue(json, "max_positions", 5);
      outConfig.Risk.MaxExposurePercent = GetDoubleValue(json, "max_exposure", 5.0);
      
      // X001 Config
      outConfig.X001.ResearchMode = GetBoolValue(json, "research_mode", false);
      outConfig.X001.ResearchMinScore = GetDoubleValue(json, "research_min_score", 15.0);
      outConfig.X001.MinEntryScore = GetDoubleValue(json, "min_entry_score", 30.0);
      outConfig.X001.AggressivenessBonus = GetDoubleValue(json, "aggressiveness_bonus", 10.0);
      outConfig.X001.MaxBuyPositions = GetIntValue(json, "max_buy_positions", 5);
      outConfig.X001.MaxSellPositions = GetIntValue(json, "max_sell_positions", 5);
      outConfig.X001.MinSpacingPoints = GetIntValue(json, "min_spacing_points", 30);
      outConfig.X001.MaxTotalExposure = GetDoubleValue(json, "max_total_exposure", 5.0);
      outConfig.X001.MaxTradesPerHour = GetIntValue(json, "max_trades_per_hour", 20);
      outConfig.X001.MaxTradesPerSession = GetIntValue(json, "max_trades_per_session", 50);
      outConfig.X001.MomentumExitThreshold = GetDoubleValue(json, "momentum_exit_threshold", 12.0);
      
      outConfig.X001.ProbeTPPoints = GetDoubleValue(json, "probe_tp_points", 50.0);
      outConfig.X001.ProbeSLPoints = GetDoubleValue(json, "probe_sl_points", 30.0);
      outConfig.X001.ScalpTPPoints = GetDoubleValue(json, "scalp_tp_points", 100.0);
      outConfig.X001.ScalpSLPoints = GetDoubleValue(json, "scalp_sl_points", 50.0);
      outConfig.X001.MomentumTPPoints = GetDoubleValue(json, "momentum_tp_points", 150.0);
      outConfig.X001.MomentumSLPoints = GetDoubleValue(json, "momentum_sl_points", 75.0);
      outConfig.X001.RunnerTrailPoints = GetDoubleValue(json, "runner_trail_points", 50.0);
      outConfig.X001.RunnerActivationPts = GetDoubleValue(json, "runner_activation_pts", 80.0);
      outConfig.X001.SidewaysTPPoints = GetDoubleValue(json, "sideways_tp_points", 60.0);
      outConfig.X001.TrendTPPoints = GetDoubleValue(json, "trend_tp_points", 150.0);
      
      // Trade Manager Config (V4.6 additions)
      outConfig.TM.EnableTradeManager = GetBoolValue(json, "tm_enabled", true);
      outConfig.TM.EnableBreakEven = GetBoolValue(json, "tm_be_enabled", true);
      outConfig.TM.BreakEvenTrigger = GetDoubleValue(json, "tm_be_trigger", 100.0);
      outConfig.TM.BreakEvenOffset = GetDoubleValue(json, "tm_be_offset", 20.0);
      outConfig.TM.EnableTrailing = GetBoolValue(json, "tm_trail_enabled", true);
      outConfig.TM.TrailingMode = GetIntValue(json, "tm_trail_mode", 0);
      outConfig.TM.TmAtrMultiplier = GetDoubleValue(json, "tm_atr_mult", 2.0);
      outConfig.TM.MinTrailDistance = GetDoubleValue(json, "tm_min_trail", 50.0);
      outConfig.TM.MaxTrailDistance = GetDoubleValue(json, "tm_max_trail", 250.0);
      outConfig.TM.EnableProfitLock = GetBoolValue(json, "tm_lock_enabled", true);
      outConfig.TM.ProfitLockStep = GetDoubleValue(json, "tm_lock_step", 200.0);
      outConfig.TM.MinLockedProfit = GetDoubleValue(json, "tm_min_lock", 50.0);
      
      return true;
   }
};

#endif
