//+------------------------------------------------------------------+
//|                                IInstitutionalExecutionManager.mqh|
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IINSTITUTIONAL_EXECUTION_MANAGER_MQH
#define GOLDENGINEV2_IINSTITUTIONAL_EXECUTION_MANAGER_MQH

#include "InstitutionalExecutionDefines.mqh"
#include "../Strategy/IStrategy.mqh"

//--- Abstract Interface for Institutional Execution Coordinator
class IInstitutionalExecutionManager
{
public:
   virtual ~IInstitutionalExecutionManager() {}

   /**
    * @brief Initializes references, thresholds, and execution configurations.
    */
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
                           double   healthThreshold) = 0;

   /**
    * @brief Evaluates active positions, logs changes, computes dynamic sizing, and issues recommendations on tick.
    */
   virtual void Update(const string symbol) = 0;

   /**
    * @brief Retrieves the compiled Institutional Execution Context.
    */
   virtual InstitutionalExecutionContext GetExecutionContext() const = 0;
};

#endif // GOLDENGINEV2_IINSTITUTIONAL_EXECUTION_MANAGER_MQH
