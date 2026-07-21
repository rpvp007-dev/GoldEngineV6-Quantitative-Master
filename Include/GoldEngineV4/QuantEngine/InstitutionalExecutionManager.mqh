//+------------------------------------------------------------------+
//|                                InstitutionalExecutionManager.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_INSTITUTIONAL_EXECUTION_MANAGER_MQH
#define GOLDENGINEV2_INSTITUTIONAL_EXECUTION_MANAGER_MQH

#include "IInstitutionalExecutionManager.mqh"
#include "ITradeManager.mqh"
#include "IAdaptiveExitAIEngine.mqh"
#include "ITradeHealthEngine.mqh"
#include "IOpportunityEngine.mqh"
#include "IMovementEngine.mqh"
#include "IMarketIntentEngine.mqh"
#include "ITradePlannerEngine.mqh"
#include "ITradeOptimizationEngine.mqh"
#include "ITrendEngine.mqh"
#include "IMomentumEngine.mqh"
#include "IVolatilityEngine.mqh"
#include "IVolumeEngine.mqh"
#include "ILiquidityEngine.mqh"
#include "IPullbackReversalEngine.mqh"
#include "../Core/MarketContext/IMarketContextEngine.mqh"

//--- Concrete implementation of Institutional Execution Coordinator
class CInstitutionalExecutionManager : public IInstitutionalExecutionManager
{
private:
   // Engine references
   ITrendEngine*              m_trend;
   IMomentumEngine*           m_momentum;
   IVolatilityEngine*         m_volatility;
   IVolumeEngine*             m_volume;
   ILiquidityEngine*          m_liquidity;
   IOpportunityEngine*        m_opportunity;
   IMovementEngine*           m_movement;
   IMarketIntentEngine*       m_intent;
   IMarketContextEngine*      m_context;
   ITradePlannerEngine*       m_planner;
   ITradeHealthEngine*        m_tradeHealth;
   IPullbackReversalEngine*   m_pullback;
   ITradeOptimizationEngine*  m_tradeOpt;
   ITradeManager*             m_tradeManager;
   IAdaptiveExitAIEngine*     m_adaptiveExit;

   // Inputs settings
   bool                       m_enable;
   bool                       m_multiPosition;
   int                        m_maxConcurrent;
   int                        m_maxBuy;
   int                        m_maxSell;
   double                     m_maxLots;
   double                     m_maxRiskPercent;
   bool                       m_scaleIn;
   double                     m_scaleInThreshold;
   bool                       m_scaleOut;
   string                     m_partialExitLevels;
   double                     m_runnerThreshold;
   bool                       m_dynamicAllocation;
   double                     m_fixedLotMode;
   double                     m_priorityThreshold;
   double                     m_healthThreshold;

   bool                       m_isInitialized;

   // Context cache
   InstitutionalExecutionContext m_execCtx;
   ENUM_INSTITUTIONAL_EXEC_ACTION m_prevLoggedAction;

   // Scale Out states tracker (tracks if milestone partial exits were processed per position)
   ulong                      m_scaledTickets[50];
   int                        m_scaledLevels[50]; // bitmask (1=5pt, 2=10pt, 4=20pt scaled)
   int                        m_scaledCount;

   // Internal computation helper
   void                       EvaluatePortfolio(const string symbol);
   void                       WriteToCSV(const string symbol, ENUM_POSITION_ROLE role, double priority, double alloc, string evType);
   void                       CheckAndWriteCSVHeader();

public:
   CInstitutionalExecutionManager();
   virtual ~CInstitutionalExecutionManager();

   virtual bool Initialize(const QuantEnginesContainer &engines,
                           bool     enable,
                           bool     multiPosition,
                           int      maxConcurrent,
                           int      maxBuy,
                           int      maxSell,
                           double   maxLots,
                           double   maxRiskPercent,
                           bool     scaleIn,
                           double   scaleInThreshold,
                           bool     scaleOut,
                           string   partialExitLevels,
                           double   runnerThreshold,
                           bool     dynamicAllocation,
                           double   fixedLotMode,
                           double   priorityThreshold,
                           double   healthThreshold) override;

   virtual void Update(const string symbol) override;
   virtual InstitutionalExecutionContext GetExecutionContext() const override { return m_execCtx; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CInstitutionalExecutionManager::CInstitutionalExecutionManager()
   : m_trend(NULL), m_momentum(NULL), m_volatility(NULL), m_volume(NULL),
     m_liquidity(NULL), m_opportunity(NULL), m_movement(NULL), m_intent(NULL),
     m_context(NULL), m_planner(NULL), m_tradeHealth(NULL), m_pullback(NULL),
     m_tradeOpt(NULL), m_tradeManager(NULL), m_adaptiveExit(NULL),
     m_enable(true), m_multiPosition(true), m_maxConcurrent(5), m_maxBuy(3), m_maxSell(3),
     m_maxLots(5.0), m_maxRiskPercent(2.0), m_scaleIn(true), m_scaleInThreshold(70.0),
     m_scaleOut(true), m_partialExitLevels("5,10,20"), m_runnerThreshold(75.0),
     m_dynamicAllocation(true), m_fixedLotMode(0.1), m_priorityThreshold(60.0),
     m_healthThreshold(50.0), m_isInitialized(false), m_prevLoggedAction(EXEC_ACTION_WAIT),
     m_scaledCount(0)
{
   ZeroMemory(m_execCtx);
   ArrayInitialize(m_scaledTickets, 0);
   ArrayInitialize(m_scaledLevels, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CInstitutionalExecutionManager::~CInstitutionalExecutionManager()
{
}

//+------------------------------------------------------------------+
//| Initializer                                                      |
//+------------------------------------------------------------------+
bool CInstitutionalExecutionManager::Initialize(const QuantEnginesContainer &engines,
                                                bool     enable,
                                                bool     multiPosition,
                                                int      maxConcurrent,
                                                int      maxBuy,
                                                int      maxSell,
                                                double   maxLots,
                                                double   maxRiskPercent,
                                                bool     scaleIn,
                                                double   scaleInThreshold,
                                                bool     scaleOut,
                                                string   partialExitLevels,
                                                double   runnerThreshold,
                                                bool     dynamicAllocation,
                                                double   fixedLotMode,
                                                double   priorityThreshold,
                                                double   healthThreshold)
{
   m_trend        = engines.Trend;
   m_momentum     = engines.Momentum;
   m_volatility   = engines.Volatility;
   m_volume       = engines.Volume;
   m_liquidity    = engines.Liquidity;
   m_opportunity  = engines.Opportunity;
   m_movement     = engines.Movement;
   m_intent       = engines.Intent;
   m_context      = engines.MarketContext;
   m_planner      = engines.Planner;
   m_tradeHealth  = engines.TradeHealth;
   m_pullback     = engines.PullbackReversal;
   m_tradeOpt     = engines.TradeOptimization;
   m_tradeManager = engines.TradeManager;
   m_adaptiveExit = engines.AdaptiveExit;

   m_enable = enable;
   m_multiPosition = multiPosition;
   m_maxConcurrent = maxConcurrent;
   m_maxBuy = maxBuy;
   m_maxSell = maxSell;
   m_maxLots = maxLots;
   m_maxRiskPercent = maxRiskPercent;
   m_scaleIn = scaleIn;
   m_scaleInThreshold = scaleInThreshold;
   m_scaleOut = scaleOut;
   m_partialExitLevels = partialExitLevels;
   m_runnerThreshold = runnerThreshold;
   m_dynamicAllocation = dynamicAllocation;
   m_fixedLotMode = fixedLotMode;
   m_priorityThreshold = priorityThreshold;
   m_healthThreshold = healthThreshold;

   m_isInitialized = true;
   CheckAndWriteCSVHeader();
   return true;
}

//+------------------------------------------------------------------+
//| Update ticks                                                     |
//+------------------------------------------------------------------+
void CInstitutionalExecutionManager::Update(const string symbol)
{
   if(!m_enable || !m_isInitialized) return;

   EvaluatePortfolio(symbol);

   // Log only when recommendation changes
   if(m_execCtx.Recommendation != m_prevLoggedAction)
   {
      Print(StringFormat("[INSTITUTIONAL EXECUTION] Action: %s | Portfolio Health: %.0f | Long: %.2f Lots | Short: %.2f Lots | Allocation: %.2f Lots | Narrative: %s",
                         InstitutionalExecActionToString(m_execCtx.Recommendation),
                         m_execCtx.PortfolioHealth,
                         m_execCtx.LongExposure,
                         m_execCtx.ShortExposure,
                         m_execCtx.CapitalAllocation,
                         m_execCtx.Narrative));
      
      m_prevLoggedAction = m_execCtx.Recommendation;
   }
}

//+------------------------------------------------------------------+
//| Evaluates portfolio metrics and issues recommendations           |
//+------------------------------------------------------------------+
void CInstitutionalExecutionManager::EvaluatePortfolio(const string symbol)
{
   double totalLots = 0.0;
   double longLots = 0.0;
   double shortLots = 0.0;
   int scouts = 0, scalps = 0, momentums = 0, runners = 0;
   double sumHealth = 0.0;
   int openCount = 0;
   double totalPnl = 0.0;
   double floatingDD = 0.0;
   
   // Loop all open positions matching symbol
   int totalPos = PositionsTotal();
   for(int i = 0; i < totalPos; i++)
   {
      if(PositionGetSymbol(i) == symbol)
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         double lots = PositionGetDouble(POSITION_VOLUME);
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         string comment = PositionGetString(POSITION_COMMENT);
         double profit = PositionGetDouble(POSITION_PROFIT);
         totalPnl += profit;
         openCount++;

         totalLots += lots;
         if(type == POSITION_TYPE_BUY)
         {
            longLots += lots;
         }
         else
         {
            shortLots += lots;
         }

         // Track health
         double posHealth = 50.0;
         if(m_tradeManager != NULL)
         {
            for(int j = 0; j < m_tradeManager.GetActiveTrackingCount(); j++)
            {
               TradeTrackingState snap;
               if(m_tradeManager.GetTrackingState(j, snap) && snap.Ticket == ticket)
               {
                  posHealth = snap.HealthScore;
                  break;
               }
            }
         }
         sumHealth += posHealth;

         // Categorize roles
         ENUM_POSITION_ROLE role = POSITION_ROLE_SCOUT;
         if(StringFind(comment, "Scalp") >= 0 || StringFind(comment, "X001") >= 0)
         {
            scalps++;
            role = POSITION_ROLE_SCALP;
         }
         else if(StringFind(comment, "Momentum") >= 0 || StringFind(comment, "S002") >= 0)
         {
            momentums++;
            role = POSITION_ROLE_MOMENTUM;
         }
         else if(StringFind(comment, "runner") >= 0)
         {
            runners++;
            role = POSITION_ROLE_RUNNER;
         }
         else
         {
            scouts++;
            role = POSITION_ROLE_SCOUT;
         }
      }
   }

   double avgHealth = (openCount > 0) ? (sumHealth / openCount) : 50.0;

   // Floating Drawdown calculation
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance > 0)
   {
      floatingDD = MathMax(0.0, (balance - equity) / balance * 100.0);
   }

   // Win Rate from optimization engine
   double winRate = (m_tradeOpt != NULL) ? m_tradeOpt.GetPerformanceStats().WinRate : 60.0;

   // Used & Free margin
   double usedMargin = AccountInfoDouble(ACCOUNT_MARGIN);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   // Calculate Portfolio Health
   double marginUsagePct = (equity > 0) ? (usedMargin / equity * 100.0) : 0.0;
   double portfolioHealth = 100.0 - (floatingDD * 3.0) - (marginUsagePct * 0.4) + (winRate * 0.1);
   portfolioHealth = MathMax(0.0, MathMin(100.0, portfolioHealth));

   // Opportunity, Movement, and Intent metrics for priorities
   double oppScore = (m_opportunity != NULL) ? m_opportunity.GetOpportunityContext().OpportunityScore : 50.0;
   double movementScore = (m_movement != NULL) ? m_movement.GetMovementContext().MovementScore : 50.0;
   double intentAlign = 50.0;
   if(m_intent != NULL)
   {
      intentAlign = (shortLots >= longLots) ? m_intent.GetMarketIntentContext().SellerIntent : m_intent.GetMarketIntentContext().BuyerIntent;
   }
   double plannerConf = (m_planner != NULL) ? m_planner.GetTradePlanContext().TradeConfidence : 50.0;

   // Sizing: dynamic capital allocation suggestion
   double allocation = m_fixedLotMode;
   if(m_dynamicAllocation)
   {
      double aeConf = (m_adaptiveExit != NULL) ? m_adaptiveExit.GetExitContext().Confidence : 50.0;
      allocation = equity * (m_maxRiskPercent / 100.0) * (oppScore + avgHealth + aeConf) / 300.0 / 100.0; // Dynamic lot size
      allocation = NormalizeDouble(MathMax(0.01, MathMin(m_maxLots, allocation)), 2);
   }

   // Priority score
   double priority = (oppScore * 0.40) + (movementScore * 0.30) + (intentAlign * 0.30);
   priority = MathMax(0.0, MathMin(100.0, priority));

   // Enforce decisions and recommendations
   ENUM_INSTITUTIONAL_EXEC_ACTION rec = EXEC_ACTION_HOLD;
   string narrative = "Portfolio execution stable. Hold.";

   if(openCount == 0)
   {
      rec = EXEC_ACTION_WAIT;
      narrative = "No active positions. Awaiting setups.";
   }
   else if(portfolioHealth < m_healthThreshold)
   {
      rec = EXEC_ACTION_RISK_REDUCTION;
      narrative = "Critical drawdown. Restricting sizes and exposures.";
   }
   else if(totalLots >= m_maxLots || openCount >= m_maxConcurrent)
   {
      rec = EXEC_ACTION_REDUCE_EXPOSURE;
      narrative = "Exposure limit reached. Rejecting new positions.";
   }
   else
   {
      // Check Adaptive Exit AI coordinator recommendation
      if(m_adaptiveExit != NULL)
      {
         AdaptiveExitContext ae = m_adaptiveExit.GetExitContext();
         if(ae.Recommendation == ADAPTIVE_EXIT_CONVERT_TO_RUNNER)
         {
            rec = EXEC_ACTION_PROMOTE_RUNNER;
            narrative = "Promoting qualifying position to runner role.";
         }
         else if(ae.Recommendation == ADAPTIVE_EXIT_PARTIAL_EXIT)
         {
            rec = EXEC_ACTION_SCALE_OUT;
            narrative = "Milestone profit reached. Partial scale-out exit.";
         }
         else if(ae.Recommendation == ADAPTIVE_EXIT_HOLD && m_scaleIn)
         {
            rec = EXEC_ACTION_ADD_POSITION;
            narrative = "Adding position to profitable trend (Scale-in).";
         }
      }
   }

   // Update cached context variables
   m_execCtx.Recommendation = rec;
   m_execCtx.PortfolioHealth = NormalizeDouble(portfolioHealth, 1);
   m_execCtx.TotalExposure = NormalizeDouble(totalLots, 2);
   m_execCtx.LongExposure = NormalizeDouble(longLots, 2);
   m_execCtx.ShortExposure = NormalizeDouble(shortLots, 2);
   m_execCtx.NetExposure = NormalizeDouble(longLots - shortLots, 2);
   m_execCtx.PortfolioRisk = NormalizeDouble(floatingDD + (marginUsagePct / 10.0), 1);
   m_execCtx.ActiveScouts = scouts;
   m_execCtx.ActiveScalps = scalps;
   m_execCtx.ActiveMomentums = momentums;
   m_execCtx.ActiveRunners = runners;
   m_execCtx.CapitalAllocation = allocation;
   m_execCtx.PriorityScore = NormalizeDouble(priority, 1);
   m_execCtx.Narrative = narrative;

   // Scale-out / runner promotions event logging
   if(rec == EXEC_ACTION_SCALE_OUT || rec == EXEC_ACTION_PROMOTE_RUNNER || rec == EXEC_ACTION_ADD_POSITION)
   {
      ENUM_POSITION_ROLE currentRole = POSITION_ROLE_SCALP;
      if(momentums > 0) currentRole = POSITION_ROLE_MOMENTUM;
      WriteToCSV(symbol, currentRole, priority, allocation, InstitutionalExecActionToString(rec));
   }
}

//+------------------------------------------------------------------+
//| Writes event details to InstitutionalExecution.csv              |
//+------------------------------------------------------------------+
void CInstitutionalExecutionManager::WriteToCSV(const string symbol, ENUM_POSITION_ROLE role, double priority, double alloc, string evType)
{
   string fileName = "GITS_Bridge\\InstitutionalExecution.csv";
   int handle = FileOpen(fileName, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(handle != INVALID_HANDLE)
   {
      FileSeek(handle, 0, SEEK_END);
      FileWrite(handle,
         TimeToString(TimeCurrent()),
         symbol,
         PositionRoleToString(role),
         DoubleToString(priority, 1),
         DoubleToString(alloc, 2),
         DoubleToString(m_execCtx.TotalExposure, 2),
         evType,
         DoubleToString(m_execCtx.PortfolioHealth, 1)
      );
      FileClose(handle);
   }
}

//+------------------------------------------------------------------+
//| Check and create CSV headers                                     |
//+------------------------------------------------------------------+
void CInstitutionalExecutionManager::CheckAndWriteCSVHeader()
{
   string fileName = "GITS_Bridge\\InstitutionalExecution.csv";
   int handle = FileOpen(fileName, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(handle != INVALID_HANDLE)
   {
      ulong size = FileSize(handle);
      FileClose(handle);
      if(size > 0) return;
   }

   // File is empty, write header
   handle = FileOpen(fileName, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle != INVALID_HANDLE)
   {
      FileWrite(handle,
         "Timestamp", "Symbol", "Role", "PriorityScore", "AllocationLots", "TotalExposureLots", "Event", "PortfolioHealth"
      );
      FileClose(handle);
   }
}

#endif // GOLDENGINEV2_INSTITUTIONAL_EXECUTION_MANAGER_MQH
