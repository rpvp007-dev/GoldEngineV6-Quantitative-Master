//+------------------------------------------------------------------+
//|                                              ISessionEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_ISESSION_ENGINE_MQH
#define GOLDENGINEV2_ISESSION_ENGINE_MQH

//+------------------------------------------------------------------+
//| Interface for Session Engine                                     |
//+------------------------------------------------------------------+
class ISessionEngine
{
public:
   virtual ~ISessionEngine() {}

   /**
    * @brief Checks if a specific session (e.g. LONDON, TOKYO) is active.
    */
   virtual bool      IsSessionActive(const string sessionName) = 0;

   /**
    * @brief Gets current trading session name.
    */
   virtual string    GetCurrentSession() = 0;

   /**
    * @brief Checks if there is a session overlap active.
    */
   virtual bool      IsOverlapActive() = 0;

   /**
    * @brief Gets session progress percentage (0.0 to 100.0).
    */
   virtual double    GetSessionProgress(const string sessionName) = 0;

   /**
    * @brief Gets remaining minutes in the specified session.
    */
   virtual int       GetSessionTimeRemaining(const string sessionName) = 0;

   /**
    * @brief Calculates a session volatility profile index (normalized).
    */
   virtual double    GetSessionVolatilityProfile(const string sessionName) = 0;

   /**
    * @brief Updates session boundaries.
    */
   virtual void      Update() = 0;

   /**
    * @brief Checks if current time is within windowMinutes of any session open.
    */
   virtual bool      IsSessionOpenWindow(int windowMinutes) = 0;
};

#endif // GOLDENGINEV2_ISESSION_ENGINE_MQH
