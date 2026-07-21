//+------------------------------------------------------------------+
//|                                               IRiskGuardian.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_IRISK_GUARDIAN_MQH
#define GOLDENGINEV2_IRISK_GUARDIAN_MQH

#include "../Strategy/StrategyDefines.mqh"
#include "../QuantEngine/ISessionEngine.mqh"
#include "RiskDefines.mqh"

//+------------------------------------------------------------------+
//| Enhanced Risk Guardian Interface (GITS V2.3)                      |
//+------------------------------------------------------------------+
class IRiskGuardian
{
public:
   virtual ~IRiskGuardian() {}

   /**
    * @brief Initializes Session Engine dependency for trading hours validation.
    */
   virtual void      InitializeRiskGuardian(ISessionEngine* sessionEngine) = 0;

   /**
    * @brief Scans all protective constraints and returns a structured risk response.
    * @param signal The candidate strategy response.
    * @param outResponse The structured return object compiling audit status and metrics.
    * @return true if approved, false if blocked.
    */
   virtual bool      AuditSignal(const StrategyResponse &signal, RiskAuditResponse &outResponse) = 0;

   /**
    * @brief Evaluates whether a proposed strategy signal complies with risk bounds.
    * @param signal The strategy signal response being audited.
    * @return true if trade passes risk limits, false if trade must be blocked.
    */
   virtual bool      CanTrade(const StrategyResponse &signal) = 0;

   /**
    * @brief Computes maximum risk capital allowed (lot size bounds) for a proposed signal.
    */
   virtual double    AllowedRisk(const StrategyResponse &signal) = 0;

   /**
    * @brief Audits whether exposure or position risk can be increased.
    */
   virtual bool      CanIncreaseRisk(double currentRisk) = 0;

   /**
    * @brief Audits whether system is allowed to open additional positions concurrently.
    */
   virtual bool      CanOpenAdditionalPosition() = 0;

   /**
    * @brief Returns maximum exposure limit double.
    */
   virtual double    MaximumExposure() = 0;

   /**
    * @brief Pauses all trading events within the system.
    */
   virtual void      PauseTrading(const string reason) = 0;

   /**
    * @brief Resumes trading events.
    */
   virtual void      ResumeTrading() = 0;

   /**
    * @brief Returns description of why the last check was blocked or paused.
    */
   virtual string    Reason() const = 0;

   /**
    * @brief Updates daily drawdown metrics.
    */
   virtual void      UpdateRiskState() = 0;
};

#endif // GOLDENGINEV2_IRISK_GUARDIAN_MQH
