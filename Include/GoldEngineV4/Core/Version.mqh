//+------------------------------------------------------------------+
//|                                                      Version.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_VERSION_MQH
#define GOLDENGINEV2_VERSION_MQH

#define GEV2_PRODUCT_NAME      "GoldEngine V2"
#define GEV2_PRODUCT_VERSION   "5.8.0"
#define GEV2_PRODUCT_BUILD     "580"
#define GEV2_RELEASE_DATE      "2026-07-18"

//+------------------------------------------------------------------+
//| Version information helper class                                 |
//+------------------------------------------------------------------+
class CVersion
{
public:
   static string     GetProductName()   { return GEV2_PRODUCT_NAME; }
   static string     GetProductVersion() { return GEV2_PRODUCT_VERSION; }
   static string     GetProductBuild()   { return GEV2_PRODUCT_BUILD; }
   static string     GetReleaseDate()   { return GEV2_RELEASE_DATE; }
   
   static string     GetFullVersionString()
   {
      return GEV2_PRODUCT_NAME + " v" + GEV2_PRODUCT_VERSION + " (Build " + GEV2_PRODUCT_BUILD + ", " + GEV2_RELEASE_DATE + ")";
   }
};

#endif // GOLDENGINEV2_VERSION_MQH
