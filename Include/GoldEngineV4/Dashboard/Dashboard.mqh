//+------------------------------------------------------------------+
//|                                                    Dashboard.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_DASHBOARD_MQH
#define GOLDENGINEV2_DASHBOARD_MQH

#include "IDashboard.mqh"
#include "../Core/Logger.mqh"
#include "../Core/Config.mqh"

#include "../QuantEngine/IOpportunityEngine.mqh"
#include "../QuantEngine/IMovementEngine.mqh"
#include "../QuantEngine/IMarketIntentEngine.mqh"
#include "../QuantEngine/ITradePlannerEngine.mqh"
#include "../QuantEngine/ITradeManager.mqh"
#include "../QuantEngine/IPullbackReversalEngine.mqh"
#include "../QuantEngine/IAdaptiveExitAIEngine.mqh"
#include "../QuantEngine/IInstitutionalExecutionManager.mqh"
#include "../Analytics/TradeMemory.mqh"

//+------------------------------------------------------------------+
//| Concrete Dashboard Class implementation (GITS V5.5 Print-Only)    |
//+------------------------------------------------------------------+
class CDashboard : public IDashboard
{
private:
   CLogger*             m_logger;
   CConfig*             m_config;
   IOpportunityEngine*  m_opportunity;
   IMovementEngine*     m_movement;
   IMarketIntentEngine* m_intent;
   ITradePlannerEngine* m_planner;
   ITradeManager*       m_tradeManager;
   IPullbackReversalEngine* m_pullback;
   IAdaptiveExitAIEngine*   m_adaptiveExit;
   IInstitutionalExecutionManager* m_instExecution;
   CTradeMemory*        m_tradeMemory; // GITS V5.2.1 Trade Memory

   // V5.1 Research Mode Dashboard counters
   ENUM_TRADING_PROFILE m_profile;
   int                  m_totalSignals;
   int                  m_executedSignals;
   int                  m_rejectedSignals;
   string               m_lastRejectionReason;

public:
   /**
    * @brief Constructor.
    */
   CDashboard(CLogger* logger, CConfig* config, 
              IOpportunityEngine* opportunity = NULL, 
              IMovementEngine* movement = NULL,
              IMarketIntentEngine* intent = NULL,
              ITradePlannerEngine* planner = NULL,
              ITradeManager* tradeManager = NULL,
              IPullbackReversalEngine* pullback = NULL,
              IAdaptiveExitAIEngine* adaptiveExit = NULL,
              IInstitutionalExecutionManager* instExecution = NULL)
      : m_logger(logger),
        m_config(config),
        m_opportunity(opportunity),
        m_movement(movement),
        m_intent(intent),
        m_planner(planner),
        m_tradeManager(tradeManager),
        m_pullback(pullback),
        m_adaptiveExit(adaptiveExit),
        m_instExecution(instExecution),
        m_tradeMemory(NULL),
        m_profile(PROFILE_RESEARCH),
        m_totalSignals(0),
        m_executedSignals(0),
        m_rejectedSignals(0),
        m_lastRejectionReason("None")
   {}

   virtual void SetTradeMemory(CTradeMemory* memory) { m_tradeMemory = memory; }

   /**
    * @brief Destructor.
    */
   ~CDashboard() {}

   /**
    * @brief Draws/Renders graphical dashboard elements on the chart.
    */
   virtual void Render() override
   {
      m_logger.Debug("Dashboard: HUD telemetry rendered to logger.");
   }

   /**
    * @brief Sets the active trading profile for display.
    */
   void SetProfile(ENUM_TRADING_PROFILE profile) { m_profile = profile; }

   /**
    * @brief Records a signal result for dashboard counters.
    */
   void RecordSignalResult(bool executed, const string reason)
   {
      m_totalSignals++;
      if(executed)
      {
         m_executedSignals++;
      }
      else
      {
         m_rejectedSignals++;
         if(reason != "")
            m_lastRejectionReason = reason;
      }
   }

   /**
    * @brief Updates metrics in the dashboard from the Analytics components.
    */
   virtual void UpdateMetrics(ITradeStatistics* stats, IPerformanceTracker* perf) override
   {
      // V5.1 Research Mode Status Header
      string profileStr = (m_profile == PROFILE_RESEARCH) ? "RESEARCH" : "PRODUCTION";
      bool   research   = (m_profile == PROFILE_RESEARCH);
      m_logger.Info(StringFormat(
         "[PROFILE] %s | Research Mode: %s | Unlimited Trading: %s | Unlimited Frequency: %s | "
         "Unlimited Sessions: %s | Unlimited P&L: %s | "
         "Total Signals: %d | Executed: %d | Rejected: %d | Last Rejection: %s",
         profileStr,
         research ? "ACTIVE" : "OFF",
         research ? "YES" : "NO",
         research ? "YES" : "NO",
         research ? "YES" : "NO",
         research ? "YES" : "NO",
         m_totalSignals, m_executedSignals, m_rejectedSignals,
         m_lastRejectionReason));

      m_logger.Info("[UNIFIED DECISION HUD] Standardized Scores: Raw Strategy Score | Composite Score | Penalty Score | Final Execution Score | Decision");

      if(m_tradeMemory != NULL)
      {
         m_logger.Info(StringFormat("[ADAPTIVE EXECUTION HUD] Threshold: %.1f | Memory Size: %d/20 | Win Rate: %.1f%% | BUY Modifier: %.1f%% | SELL Modifier: %.1f%%",
            m_tradeMemory.GetAdaptiveThreshold(),
            m_tradeMemory.GetCount(),
            m_tradeMemory.GetWinRate(),
            m_tradeMemory.GetBuyModifier(),
            m_tradeMemory.GetSellModifier()));
      }

      if(stats != NULL && perf != NULL)
      {
         string oppInfo = "";
         if(m_opportunity != NULL)
         {
            OpportunityContext oppCtx = m_opportunity.GetOpportunityContext();
            oppInfo = StringFormat(" | Opp Score: %.1f (Class: %d)", oppCtx.OpportunityScore, oppCtx.OpportunityClass);
         }
         string movInfo = "";
         if(m_movement != NULL)
         {
            MovementContext movCtx = m_movement.GetMovementContext();
            movInfo = " | Movement: " + movCtx.MovementNarrative;
         }
         string intentInfo = "";
         if(m_intent != NULL)
         {
            MarketIntentContext intentCtx = m_intent.GetMarketIntentContext();
            intentInfo = " | Intent: " + intentCtx.IntentNarrative;
         }
         string planInfo = "";
         if(m_planner != NULL)
         {
            TradePlanContext planCtx = m_planner.GetTradePlanContext();
            planInfo = " | Plan: " + planCtx.TradeNarrative;
         }
         
         // Trade Manager tracking summary
         string tmInfo = "";
         if(m_tradeManager != NULL && m_config.IsTradeManagerEnabled())
         {
            int count = m_tradeManager.GetActiveTrackingCount();
            tmInfo = StringFormat(" | TM Tracking: %d", count);
            for(int j = 0; j < count; j++)
            {
               TradeTrackingState tmState;
               if(m_tradeManager.GetTrackingState(j, tmState))
               {
                   string protStatus = "None";
                   if(tmState.TrailingActive) protStatus = StringFormat("Trailing (%.1f pts)", tmState.TrailingDistancePoints);
                   else if(tmState.LockedProfitPoints > 0.0) protStatus = StringFormat("Lock (%.1f pts)", tmState.LockedProfitPoints);
                   else if(tmState.BreakEvenActive) protStatus = "Break-even";

                   m_logger.Info(StringFormat(
                      "[TRADE MANAGER HUD] Ticket: %d | Entry Quality: %.1f | Recovery Prob: %.1f%% | Dynamic TP: %.2f | Adaptive SL: %.2f | Profit Protection: %s | Trade Health: %.1f (%s) | Confidence: %.1f%%",
                      tmState.Ticket,
                      tmState.EntryQualityScore,
                      tmState.RecoveryProbability,
                      tmState.CurrentTP,
                      tmState.CurrentSL,
                      protStatus,
                      tmState.HealthScore,
                      tmState.HealthStateStr,
                      tmState.OpportunityScore));
               }
            }
         }
         
         string pullbackInfo = "";
         if(m_pullback != NULL)
         {
            PullbackReversalContext pbCtx = m_pullback.GetEvaluationContext();
            pullbackInfo = StringFormat(" | Pullback: %s (Cont: %.0f%%, Rev: %.0f%%, Rec: %s)",
                                        PullbackStateToString(pbCtx.State),
                                        pbCtx.ContinuationProb,
                                        pbCtx.ReversalProb,
                                        PullbackRecToString(pbCtx.Recommendation));
         }
         
         string aeInfo = "";
         if(m_adaptiveExit != NULL)
         {
            AdaptiveExitContext aeCtx = m_adaptiveExit.GetExitContext();
            aeInfo = StringFormat(" | AI Exit: %s (Conf: %.0f%%, Hold: %.0f%%, Exit: %.0f%%)",
                                  AdaptiveExitActionToString(aeCtx.Recommendation),
                                  aeCtx.Confidence,
                                  aeCtx.HoldScore,
                                  aeCtx.ExitScore);
         }
         string ieInfo = "";
         if(m_instExecution != NULL)
         {
            InstitutionalExecutionContext ieCtx = m_instExecution.GetExecutionContext();
            ieInfo = StringFormat(" | PortHealth: %.0f (Exp: %.2fL, Long: %.2fL, Short: %.2fL)",
                                  ieCtx.PortfolioHealth,
                                  ieCtx.TotalExposure,
                                  ieCtx.LongExposure,
                                  ieCtx.ShortExposure);
         }
         
         m_logger.Debug(StringFormat("Dashboard HUD Update: Trades=%d Profit=%.2f Sharpe=%.2f Drawdown=%.2f%%%s%s%s%s%s%s%s%s",
            stats.GetTotalTrades(), stats.GetTotalProfit(), perf.GetSharpeRatio(), perf.GetMaxDrawdownPercent(), oppInfo, movInfo, intentInfo, planInfo, tmInfo, pullbackInfo, aeInfo, ieInfo));
      }
   }

   /**
    * @brief Removes/Deletes all graphical objects from the chart.
    */
   virtual void DestroyHUD() override
   {
      m_logger.Debug("Dashboard: Clearing print-only HUD state.");
   }

   /**
    * @brief Empty chart event handler.
    */
   virtual void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) override
   {
      // No graphic actions
   }
};

#endif // GOLDENGINEV2_DASHBOARD_MQH
