//+------------------------------------------------------------------+
//|                                                     MonEA.mq5    |
//|                        Copyright 2024, MetaQuotes Ltd.           |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Range Breakout Asian Session EA for FundedNext"
#property strict

//--- Include files
#include "MonEA_Config.mqh"
#include "MonEA_TradeManager.mqh"
#include "MonEA_RangeCalculator.mqh"
#include "MonEA_NewsFilter.mqh"
#include "MonEA_Indicators.mqh"
#include "MonEA_Utilities.mqh"

//--- Global variables
CTradeManager      *tradeManager;
CRangeCalculator   *rangeCalc;
CNewsFilter        *newsFilter;
CIndicators        *indicators;
CUtilities         *utils;

//--- Session time variables
datetime asianSessionStart, asianSessionEnd, londonSessionStart;
datetime lastTradeTime = 0;
int dailyTradesCount = 0;
double dailyPnL = 0.0;
double dailyPnLLimit = 0.0;
bool dailyLimitReached = false;
bool weekendClosed = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize utility class
   utils = new CUtilities();
   
   //--- Initialize trade manager
   tradeManager = new CTradeManager();
   if(!tradeManager.Init())
   {
      Print("Failed to initialize Trade Manager");
      return INIT_FAILED;
   }
   
   //--- Initialize range calculator
   rangeCalc = new CRangeCalculator();
   if(!rangeCalc.Init())
   {
      Print("Failed to initialize Range Calculator");
      return INIT_FAILED;
   }
   
   //--- Initialize news filter
   newsFilter = new CNewsFilter();
   if(!newsFilter.Init())
   {
      Print("Failed to initialize News Filter");
      return INIT_FAILED;
   }
   
   //--- Initialize indicators
   indicators = new CIndicators();
   if(!indicators.Init())
   {
      Print("Failed to initialize Indicators");
      return INIT_FAILED;
   }
   
   //--- Calculate session times
   CalculateSessionTimes();
   
   //--- Calculate daily P&L limit
   dailyPnLLimit = -AccountInfoDouble(ACCOUNT_EQUITY) * (sDailyDDPC / 100.0);
   
   //--- Reset daily counters
   ResetDailyCounters();
   
   Print("MonEA initialized successfully");
   Print("Asian Session: ", TimeToString(asianSessionStart), " to ", TimeToString(asianSessionEnd));
   Print("London Session starts at: ", TimeToString(londonSessionStart));
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Delete objects
   delete tradeManager;
   delete rangeCalc;
   delete newsFilter;
   delete indicators;
   delete utils;
   
   Print("MonEA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check if EA should be active
   if(!CheckTradingConditions())
      return;
   
   //--- Update daily P&L
   UpdateDailyPnL();
   
   //--- Check daily drawdown limit
   if(CheckDailyDrawdownLimit())
      return;
   
   //--- Check weekend close
   if(sWeekendClose && CheckWeekendClose())
      return;
   
   //--- Check if we can place new trades
   if(!CanPlaceNewTrade())
      return;
   
   //--- Main trading logic
   ProcessTradingLogic();
}

//+------------------------------------------------------------------+
//| Calculate session times                                          |
//+------------------------------------------------------------------+
void CalculateSessionTimes()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   
   //--- Asian session: 00:00 to 06:00 GMT
   dt.hour = sAsianStartHour;
   dt.min = sAsianStartMinute;
   dt.sec = 0;
   asianSessionStart = StructToTime(dt);
   
   dt.hour = sAsianEndHour;
   dt.min = sAsianEndMinute;
   asianSessionEnd = StructToTime(dt);
   
   //--- London session start: 08:00 GMT
   dt.hour = sLondonStartHour;
   dt.min = sLondonStartMinute;
   londonSessionStart = StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Check trading conditions                                         |
//+------------------------------------------------------------------+
bool CheckTradingConditions()
{
   //--- Check if symbol is allowed
   if(!IsSymbolAllowed())
      return false;
   
   //--- Check news filter
   if(sNewsFilter && newsFilter.IsNewsTime())
      return false;
   
   //--- Check volatility filter
   if(!indicators.CheckVolatility())
      return false;
   
   //--- Check trend filter
   if(sTrendFilter && !indicators.CheckTrend())
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if symbol is allowed                                       |
//+------------------------------------------------------------------+
bool IsSymbolAllowed()
{
   string currentSymbol = Symbol();
   
   //--- Check if symbol is in allowed pairs
   for(int i = 0; i < ArraySize(sAllowedPairs); i++)
   {
      if(sAllowedPairs[i] == currentSymbol)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Update daily P&L                                                 |
//+------------------------------------------------------------------+
void UpdateDailyPnL()
{
   double currentPnL = 0.0;
   
   //--- Calculate P&L from closed positions today
   HistorySelect(TimeCurrent() - 86400, TimeCurrent());
   int total = HistoryDealsTotal();
   
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         currentPnL += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      }
   }
   
   dailyPnL = currentPnL;
}

//+------------------------------------------------------------------+
//| Check daily drawdown limit                                       |
//+------------------------------------------------------------------+
bool CheckDailyDrawdownLimit()
{
   if(dailyPnL <= dailyPnLLimit && !dailyLimitReached)
   {
      Print("Daily drawdown limit reached! Closing all positions and stopping EA.");
      tradeManager.CloseAllPositions();
      dailyLimitReached = true;
      return true;
   }
   
   return dailyLimitReached;
}

//+------------------------------------------------------------------+
//| Check weekend close                                              |
//+------------------------------------------------------------------+
bool CheckWeekendClose()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   
   //--- Check if it's Friday and time to close
   if(dt.day_of_week == 5) // Friday
   {
      int currentHour = dt.hour;
      int currentMinute = dt.min;
      
      //--- Convert close time to minutes
      int closeTimeMinutes = sCloseHourFri * 60 + sCloseMinuteFri;
      int currentTimeMinutes = currentHour * 60 + currentMinute;
      
      if(currentTimeMinutes >= closeTimeMinutes && !weekendClosed)
      {
         Print("Weekend close time reached. Closing all positions.");
         tradeManager.CloseAllPositions();
         weekendClosed = true;
         return true;
      }
   }
   else if(dt.day_of_week == 1) // Monday
   {
      weekendClosed = false;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if we can place new trade                                  |
//+------------------------------------------------------------------+
bool CanPlaceNewTrade()
{
   //--- Check max open trades
   if(PositionsTotal() >= sMaxOpenTrades)
      return false;
   
   //--- Check max trades per day
   if(dailyTradesCount >= sMaxTradesPerDay)
      return false;
   
   //--- Check minimum time between trades
   if(lastTradeTime > 0)
   {
      double hoursSinceLastTrade = (TimeCurrent() - lastTradeTime) / 3600.0;
      if(hoursSinceLastTrade < sMinTimeBetweenTradesHrs)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Process trading logic                                            |
//+------------------------------------------------------------------+
void ProcessTradingLogic()
{
   //--- Check if we're in London session
   if(TimeCurrent() < londonSessionStart)
      return;
   
   //--- Calculate Asian range
   double asianHigh, asianLow;
   if(!rangeCalc.CalculateAsianRange(asianHigh, asianLow))
      return;
   
   //--- Check range width
   double rangeWidth = (asianHigh - asianLow) / Point();
   if(rangeWidth < sMinRangePips || rangeWidth > sMaxRangePips)
      return;
   
   //--- Check if range was already broken
   if(rangeCalc.CheckEarlyBreak(asianHigh, asianLow))
      return;
   
   //--- Calculate entry levels with margin
   double buyEntry = asianHigh + sMarginPips * Point();
   double sellEntry = asianLow - sMarginPips * Point();
   
   //--- Check ATR confirmation
   if(!indicators.CheckATRConfirmation(buyEntry, sellEntry))
      return;
   
   //--- Check volume confirmation
   if(sVolConfirm && !indicators.CheckVolumeConfirmation())
      return;
   
   //--- Calculate stop loss and take profit
   double buySL = asianLow - sSLPips * Point();
   double sellSL = asianHigh + sSLPips * Point();
   
   double buyTP, sellTP;
   if(sTPMethod == FIXED_RR)
   {
      buyTP = buyEntry + (buyEntry - buySL) * sFixedRR;
      sellTP = sellEntry - (sellSL - sellEntry) * sFixedRR;
   }
   else // DYNAMIC_ATR
   {
      double atrValue = indicators.GetATRValue();
      buyTP = buyEntry + atrValue * sATRTPMult;
      sellTP = sellEntry - atrValue * sATRTPMult;
   }
   
   //--- Calculate position size
   double lotSize = tradeManager.CalculateLotSize(MathAbs(buyEntry - buySL) / Point());
   if(lotSize <= 0)
      return;
   
   //--- Place pending orders
   if(Ask < buyEntry)
   {
      tradeManager.PlaceBuyStopOrder(buyEntry, buySL, buyTP, lotSize);
   }
   
   if(Bid > sellEntry)
   {
      tradeManager.PlaceSellStopOrder(sellEntry, sellSL, sellTP, lotSize);
   }
   
   //--- Update trade tracking
   lastTradeTime = TimeCurrent();
   dailyTradesCount++;
}

//+------------------------------------------------------------------+
//| Reset daily counters                                             |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   
   static int lastResetDay = dt.day;
   
   if(dt.day != lastResetDay)
   {
      dailyTradesCount = 0;
      dailyPnL = 0.0;
      dailyLimitReached = false;
      lastResetDay = dt.day;
      
      //--- Recalculate daily P&L limit
      dailyPnLLimit = -AccountInfoDouble(ACCOUNT_EQUITY) * (sDailyDDPC / 100.0);
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   //--- Reset daily counters if needed
   ResetDailyCounters();
   
   //--- Update news filter
   if(sNewsFilter)
      newsFilter.Update();
}

//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
   //--- Handle trailing stops
   if(sTrailMethod != NO_TRAILING)
      tradeManager.CheckTrailingStops();
}

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   //--- Handle order modifications and deletions
   if(trans.type == TRADE_TRANSACTION_ORDER_UPDATE)
   {
      //--- Cancel opposite pending order when one is triggered
      if(trans.order_state == ORDER_STATE_FILLED)
      {
         tradeManager.CancelOppositePendingOrders();
      }
   }
}
