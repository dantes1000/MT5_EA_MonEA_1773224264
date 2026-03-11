//+------------------------------------------------------------------+
//|                                                      TradeManager.mqh |
//|                        Copyright 2024, MonEA Expert Advisor         |
//|                                             https://www.monea.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MonEA Expert Advisor"
#property link      "https://www.monea.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| CTradeManager class                                              |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
   // Trade objects
   CTrade           m_trade;
   CSymbolInfo      m_symbol;
   CPositionInfo    m_position;
   CAccountInfo     m_account;
   
   // Risk management parameters
   double           m_riskPercent;          // Risk percentage per trade (0.5-1%)
   double           m_slPips;               // Stop loss in pips
   double           m_tpPips;               // Take profit in pips
   string           m_lotType;              // "percentage" or "fixed"
   double           m_minLot;               // Minimum lot size
   double           m_maxLot;               // Maximum lot size
   
   // Position tracking
   int              m_currentTicket;        // Current open position ticket
   datetime         m_lastTradeTime;        // Time of last trade
   double           m_dailyPL;              // Daily profit/loss
   datetime         m_dailyResetTime;       // Time to reset daily PL
   
   // Daily drawdown protection
   double           m_maxDailyDDPercent;    // Maximum daily drawdown percentage
   bool             m_tradingEnabled;       // Trading enabled flag
   
   // News filter
   bool             m_newsFilterEnabled;    // News filter enabled
   datetime         m_newsPauseStart;       // News pause start time
   datetime         m_newsPauseEnd;         // News pause end time
   
   // Trend filter
   bool             m_trendFilterEnabled;   // Trend filter enabled
   int              m_emaPeriod;            // EMA period for trend filter
   ENUM_TIMEFRAMES  m_emaTF;                // Timeframe for EMA
   
   // Volatility filter
   bool             m_volFilterEnabled;     // Volatility filter enabled
   double           m_minATRPips;           // Minimum ATR in pips
   double           m_maxATRPips;           // Maximum ATR in pips
   
   // Volume confirmation
   bool             m_volumeConfirmEnabled; // Volume confirmation enabled
   int              m_volumePeriod;         // Volume SMA period
   double           m_volumeMultiplier;     // Volume multiplier threshold
   
   // Trailing stop
   bool             m_trailingEnabled;      // Trailing stop enabled
   double           m_trailActivationPC;    // Trailing activation percentage
   string           m_trailType;            // "ATR" or "Fixed"
   double           m_trailMultiplier;      // Trailing multiplier
   
   // Weekend close
   bool             m_weekendCloseEnabled;  // Weekend close enabled
   int              m_closeHourFriday;      // Close hour on Friday
   
   // Trade frequency limits
   int              m_minTimeBetweenTrades; // Minimum time between trades in hours
   int              m_maxTradesPerDay;      // Maximum trades per day
   int              m_tradesToday;          // Trades executed today
   
   // Helper methods
   double           CalculateLotSize(double slDistance);
   double           NormalizeLot(double lot);
   bool             CheckDailyDrawdown();
   bool             CheckNewsFilter();
   bool             CheckTrendFilter(ENUM_ORDER_TYPE orderType);
   bool             CheckVolatilityFilter();
   bool             CheckVolumeConfirmation();
   bool             CheckTimeBetweenTrades();
   bool             CheckTradesPerDay();
   bool             CheckWeekendClose();
   void             UpdateTrailingStop();
   void             CloseAllPositions();
   
public:
   // Constructor
   CTradeManager();
   
   // Initialization
   bool              Init(string symbol, double riskPercent, double slPips, double tpPips, 
                         string lotType, double minLot, double maxLot);
   
   // Configuration methods
   void              SetDailyDDProtection(double maxDDPercent);
   void              SetNewsFilter(bool enabled, datetime pauseStart, datetime pauseEnd);
   void              SetTrendFilter(bool enabled, int emaPeriod, ENUM_TIMEFRAMES emaTF);
   void              SetVolatilityFilter(bool enabled, double minATR, double maxATR);
   void              SetVolumeConfirmation(bool enabled, int volPeriod, double volMultiplier);
   void              SetTrailingStop(bool enabled, double activationPC, string trailType, double trailMult);
   void              SetWeekendClose(bool enabled, int closeHourFriday);
   void              SetTradeFrequency(int minTimeHours, int maxTradesPerDay);
   
   // Trade execution
   bool              OpenBuy(double price, double sl, double tp, string comment = "");
   bool              OpenSell(double price, double sl, double tp, string comment = "");
   bool              ClosePosition(int ticket = -1);
   
   // Position management
   bool              HasOpenPosition();
   int               GetOpenPositionTicket();
   double            GetPositionProfit();
   
   // Risk management
   void              UpdateDailyPL();
   bool              IsTradingAllowed();
   
   // Main processing method
   void              OnTick();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager()
{
   m_currentTicket = -1;
   m_lastTradeTime = 0;
   m_dailyPL = 0.0;
   m_dailyResetTime = 0;
   m_tradingEnabled = true;
   m_tradesToday = 0;
   
   // Default values
   m_riskPercent = 1.0;
   m_slPips = 30.0;
   m_tpPips = 60.0;
   m_lotType = "percentage";
   m_minLot = 0.01;
   m_maxLot = 5.0;
   m_maxDailyDDPercent = 5.0;
   
   // Default filter settings
   m_newsFilterEnabled = false;
   m_trendFilterEnabled = false;
   m_volFilterEnabled = false;
   m_volumeConfirmEnabled = false;
   m_trailingEnabled = false;
   m_weekendCloseEnabled = false;
   
   // Default trade frequency
   m_minTimeBetweenTrades = 1;
   m_maxTradesPerDay = 3;
   m_closeHourFriday = 21;
}

//+------------------------------------------------------------------+
//| Initialization method                                            |
//+------------------------------------------------------------------+
bool CTradeManager::Init(string symbol, double riskPercent, double slPips, double tpPips, 
                        string lotType, double minLot, double maxLot)
{
   // Initialize symbol info
   if(!m_symbol.Name(symbol))
   {
      Print("Failed to set symbol: ", symbol);
      return false;
   }
   
   // Initialize trade object
   m_trade.SetExpertMagicNumber(12345);
   m_trade.SetDeviationInPoints(10);
   
   // Set risk parameters
   m_riskPercent = MathMax(0.1, MathMin(riskPercent, 5.0));
   m_slPips = MathMax(1.0, slPips);
   m_tpPips = MathMax(1.0, tpPips);
   m_lotType = lotType;
   m_minLot = MathMax(0.01, minLot);
   m_maxLot = MathMax(m_minLot, maxLot);
   
   // Reset daily tracking
   m_dailyResetTime = iTime(_Symbol, PERIOD_D1, 0);
   
   Print("TradeManager initialized for ", symbol, ", Risk: ", m_riskPercent, "%, SL: ", m_slPips, " pips, TP: ", m_tpPips, " pips");
   return true;
}

//+------------------------------------------------------------------+
//| Set daily drawdown protection                                    |
//+------------------------------------------------------------------+
void CTradeManager::SetDailyDDProtection(double maxDDPercent)
{
   m_maxDailyDDPercent = MathMax(1.0, MathMin(maxDDPercent, 20.0));
   Print("Daily DD protection set to: ", m_maxDailyDDPercent, "%");
}

//+------------------------------------------------------------------+
//| Set news filter                                                  |
//+------------------------------------------------------------------+
void CTradeManager::SetNewsFilter(bool enabled, datetime pauseStart, datetime pauseEnd)
{
   m_newsFilterEnabled = enabled;
   m_newsPauseStart = pauseStart;
   m_newsPauseEnd = pauseEnd;
   Print("News filter ", enabled ? "enabled" : "disabled");
}

//+------------------------------------------------------------------+
//| Set trend filter                                                 |
//+------------------------------------------------------------------+
void CTradeManager::SetTrendFilter(bool enabled, int emaPeriod, ENUM_TIMEFRAMES emaTF)
{
   m_trendFilterEnabled = enabled;
   m_emaPeriod = MathMax(10, emaPeriod);
   m_emaTF = emaTF;
   Print("Trend filter ", enabled ? "enabled" : "disabled", ", EMA", m_emaPeriod, " on TF: ", m_emaTF);
}

//+------------------------------------------------------------------+
//| Set volatility filter                                            |
//+------------------------------------------------------------------+
void CTradeManager::SetVolatilityFilter(bool enabled, double minATR, double maxATR)
{
   m_volFilterEnabled = enabled;
   m_minATRPips = MathMax(1.0, minATR);
   m_maxATRPips = MathMax(m_minATRPips, maxATR);
   Print("Volatility filter ", enabled ? "enabled" : "disabled", ", ATR range: ", m_minATRPips, "-", m_maxATRPips, " pips");
}

//+------------------------------------------------------------------+
//| Set volume confirmation                                          |
//+------------------------------------------------------------------+
void CTradeManager::SetVolumeConfirmation(bool enabled, int volPeriod, double volMultiplier)
{
   m_volumeConfirmEnabled = enabled;
   m_volumePeriod = MathMax(5, volPeriod);
   m_volumeMultiplier = MathMax(1.0, volMultiplier);
   Print("Volume confirmation ", enabled ? "enabled" : "disabled", ", Period: ", m_volumePeriod, ", Multiplier: ", m_volumeMultiplier);
}

//+------------------------------------------------------------------+
//| Set trailing stop                                                |
//+------------------------------------------------------------------+
void CTradeManager::SetTrailingStop(bool enabled, double activationPC, string trailType, double trailMult)
{
   m_trailingEnabled = enabled;
   m_trailActivationPC = MathMax(10.0, MathMin(activationPC, 90.0));
   m_trailType = trailType;
   m_trailMultiplier = MathMax(0.1, trailMult);
   Print("Trailing stop ", enabled ? "enabled" : "disabled", ", Activation: ", m_trailActivationPC, "%, Type: ", m_trailType, ", Mult: ", m_trailMultiplier);
}

//+------------------------------------------------------------------+
//| Set weekend close                                                |
//+------------------------------------------------------------------+
void CTradeManager::SetWeekendClose(bool enabled, int closeHourFriday)
{
   m_weekendCloseEnabled = enabled;
   m_closeHourFriday = MathMax(0, MathMin(closeHourFriday, 23));
   Print("Weekend close ", enabled ? "enabled" : "disabled", ", Close hour Friday: ", m_closeHourFriday);
}

//+------------------------------------------------------------------+
//| Set trade frequency limits                                       |
//+------------------------------------------------------------------+
void CTradeManager::SetTradeFrequency(int minTimeHours, int maxTradesPerDay)
{
   m_minTimeBetweenTrades = MathMax(0, minTimeHours);
   m_maxTradesPerDay = MathMax(1, maxTradesPerDay);
   Print("Trade frequency limits: Min time between trades: ", m_minTimeBetweenTrades, "h, Max trades/day: ", m_maxTradesPerDay);
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                 |
//+------------------------------------------------------------------+
double CTradeManager::CalculateLotSize(double slDistance)
{
   if(m_lotType != "percentage" || slDistance <= 0)
      return m_minLot;
   
   // Get account equity
   double equity = m_account.Equity();
   if(equity <= 0) equity = m_account.Balance();
   
   // Calculate risk amount
   double riskAmount = equity * (m_riskPercent / 100.0);
   
   // Calculate lot size
   double tickValue = m_symbol.TickValue();
   double tickSize = m_symbol.TickSize();
   double pointValue = m_symbol.Point();
   
   if(tickValue <= 0 || tickSize <= 0 || pointValue <= 0)
      return m_minLot;
   
   // Convert slDistance to points
   double slPoints = slDistance / pointValue;
   
   // Calculate lot size
   double lot = riskAmount / (slPoints * tickValue * m_symbol.LotsStep());
   
   // Normalize lot
   lot = NormalizeLot(lot);
   
   // Apply limits
   lot = MathMax(m_minLot, MathMin(lot, m_maxLot));
   
   return lot;
}

//+------------------------------------------------------------------+
//| Normalize lot size                                               |
//+------------------------------------------------------------------+
double CTradeManager::NormalizeLot(double lot)
{
   double step = m_symbol.LotsStep();
   if(step <= 0) step = 0.01;
   
   lot = MathRound(lot / step) * step;
   lot = MathMax(m_symbol.LotsMin(), MathMin(lot, m_symbol.LotsMax()));
   
   return lot;
}

//+------------------------------------------------------------------+
//| Check daily drawdown limit                                       |
//+------------------------------------------------------------------+
bool CTradeManager::CheckDailyDrawdown()
{
   // Reset daily PL at new day
   datetime currentDay = iTime(_Symbol, PERIOD_D1, 0);
   if(currentDay > m_dailyResetTime)
   {
      m_dailyPL = 0.0;
      m_dailyResetTime = currentDay;
      m_tradesToday = 0;
      m_tradingEnabled = true;
      Print("Daily PL reset");
   }
   
   // Check if daily drawdown limit reached
   double equity = m_account.Equity();
   double balance = m_account.Balance();
   
   if(balance > 0 && equity > 0)
   {
      double ddPercent = ((balance - equity) / balance) * 100.0;
      
      if(ddPercent >= m_maxDailyDDPercent)
      {
         if(m_tradingEnabled)
         {
            Print("Daily drawdown limit reached: ", ddPercent, "% >= ", m_maxDailyDDPercent, "%");
            CloseAllPositions();
            m_tradingEnabled = false;
         }
         return false;
      }
   }
   
   return m_tradingEnabled;
}

//+------------------------------------------------------------------+
//| Check news filter                                                |
//+------------------------------------------------------------------+
bool CTradeManager::CheckNewsFilter()
{
   if(!m_newsFilterEnabled)
      return true;
   
   datetime currentTime = TimeCurrent();
   
   // Check if current time is within news pause period
   if(currentTime >= m_newsPauseStart && currentTime <= m_newsPauseEnd)
   {
      Print("Trading paused due to news event");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check trend filter                                               |
//+------------------------------------------------------------------+
bool CTradeManager::CheckTrendFilter(ENUM_ORDER_TYPE orderType)
{
   if(!m_trendFilterEnabled)
      return true;
   
   // Get EMA value
   double emaValue = iMA(_Symbol, m_emaTF, m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double currentPrice = m_symbol.Ask();
   
   if(orderType == ORDER_TYPE_BUY)
   {
      if(currentPrice <= emaValue)
      {
         Print("Buy rejected: Price ", currentPrice, " <= EMA", m_emaPeriod, " ", emaValue);
         return false;
      }
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      if(currentPrice >= emaValue)
      {
         Print("Sell rejected: Price ", currentPrice, " >= EMA", m_emaPeriod, " ", emaValue);
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check volatility filter                                          |
//+------------------------------------------------------------------+
bool CTradeManager::CheckVolatilityFilter()
{
   if(!m_volFilterEnabled)
      return true;
   
   // Calculate ATR
   double atrValue = iATR(_Symbol, PERIOD_H1, 14, 0);
   double atrPips = atrValue / m_symbol.Point();
   
   if(atrPips < m_minATRPips || atrPips > m_maxATRPips)
   {
      Print("Volatility filter rejected: ATR ", atrPips, " pips outside range ", m_minATRPips, "-", m_maxATRPips, " pips");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check volume confirmation                                        |
//+------------------------------------------------------------------+
bool CTradeManager::CheckVolumeConfirmation()
{
   if(!m_volumeConfirmEnabled)
      return true;
   
   // Get current volume
   long currentVolume = iVolume(_Symbol, PERIOD_CURRENT, 0);
   
   // Calculate SMA of volume
   double volumeSMA = 0;
   for(int i = 0; i < m_volumePeriod; i++)
   {
      volumeSMA += iVolume(_Symbol, PERIOD_CURRENT, i);
   }
   volumeSMA /= m_volumePeriod;
   
   // Check if current volume exceeds threshold
   if(currentVolume < volumeSMA * m_volumeMultiplier)
   {
      Print("Volume confirmation failed: Current volume ", currentVolume, " < ", volumeSMA * m_volumeMultiplier);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check time between trades                                        |
//+------------------------------------------------------------------+
bool CTradeManager::CheckTimeBetweenTrades()
{
   if(m_minTimeBetweenTrades <= 0)
      return true;
   
   if(m_lastTradeTime == 0)
      return true;
   
   datetime currentTime = TimeCurrent();
   int hoursSinceLastTrade = (int)((currentTime - m_lastTradeTime) / 3600);
   
   if(hoursSinceLastTrade < m_minTimeBetweenTrades)
   {
      Print("Time between trades filter: ", hoursSinceLastTrade, "h since last trade < ", m_minTimeBetweenTrades, "h minimum");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check trades per day limit                                       |
//+------------------------------------------------------------------+
bool CTradeManager::CheckTradesPerDay()
{
   if(m_tradesToday >= m_maxTradesPerDay)
   {
      Print("Max trades per day reached: ", m_tradesToday, " >= ", m_maxTradesPerDay);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check weekend close                                              |
//+------------------------------------------------------------------+
bool CTradeManager::CheckWeekendClose()
{
   if(!m_weekendCloseEnabled)
      return true;
   
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   
   // Check if it's Friday and time to close
   if(timeStruct.day_of_week == 5 && timeStruct.hour >= m_closeHourFriday)
   {
      if(HasOpenPosition())
      {
         Print("Weekend close: Closing all positions before weekend");
         CloseAllPositions();
      }
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Update trailing stop                                             |
//+------------------------------------------------------------------+
void CTradeManager::UpdateTrailingStop()
{
   if(!m_trailingEnabled || !HasOpenPosition())
      return;
   
   // Get position information
   if(m_position.SelectByTicket(m_currentTicket))
   {
      double currentProfit = m_position.Profit();
      double openPrice = m_position.PriceOpen();
      double currentPrice = m_position.PriceCurrent();
      double sl = m_position.StopLoss();
      double tp = m_position.TakeProfit();
      
      // Calculate profit percentage
      double profitPips = MathAbs(currentPrice - openPrice) / m_symbol.Point();
      double tpPips = MathAbs(tp - openPrice) / m_symbol.Point();
      
      if(tpPips > 0 && profitPips >= tpPips * (m_trailActivationPC / 100.0))
      {
         double newSL = sl;
         
         if(m_trailType == "ATR")
         {
            // ATR-based trailing
            double atrValue = iATR(_Symbol, PERIOD_H1, 14, 0);
            double trailDistance = atrValue * m_trailMultiplier;
            
            if(m_position.PositionType() == POSITION_TYPE_BUY)
            {
               newSL = currentPrice - trailDistance;
               if(newSL > sl)  // Only move SL up
               {
                  m_trade.PositionModify(m_currentTicket, newSL, tp);
                  Print("Trailing stop updated for buy position: New SL = ", newSL);
               }
            }
            else if(m_position.PositionType() == POSITION_TYPE_SELL)
            {
               newSL = currentPrice + trailDistance;
               if(newSL < sl || sl == 0)  // Only move SL down
               {
                  m_trade.PositionModify(m_currentTicket, newSL, tp);
                  Print("Trailing stop updated for sell position: New SL = ", newSL);
               }
            }
         }
         else if(m_trailType == "Fixed")
         {
            // Fixed percentage trailing
            double trailDistance = (tp - openPrice) * (m_trailMultiplier / 100.0);
            
            if(m_position.PositionType() == POSITION_TYPE_BUY)
            {
               newSL = currentPrice - trailDistance;
               if(newSL > sl)
               {
                  m_trade.PositionModify(m_currentTicket, newSL, tp);
                  Print("Trailing stop updated for buy position: New SL = ", newSL);
               }
            }
            else if(m_position.PositionType() == POSITION_TYPE_SELL)
            {
               newSL = currentPrice + trailDistance;
               if(newSL < sl || sl == 0)
               {
                  m_trade.PositionModify(m_currentTicket, newSL, tp);
                  Print("Trailing stop updated for sell position: New SL = ", newSL);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CTradeManager::CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == m_symbol.Name())
         {
            m_trade.PositionClose(m_position.Ticket());
            Print("Position closed: Ticket ", m_position.Ticket());
         }
      }
   }
   m_currentTicket = -1;
}

//+------------------------------------------------------------------+
//| Open buy position                                                |
//+------------------------------------------------------------------+
bool CTradeManager::OpenBuy(double price, double sl, double tp, string comment)
{
   // Check all filters
   if(!IsTradingAllowed() || !CheckTrendFilter(ORDER_TYPE_BUY) || 
      !CheckVolatilityFilter() || !CheckVolumeConfirmation() || 
      !CheckTimeBetweenTrades() || !CheckTradesPerDay())
      return false;
   
   // Calculate lot size
   double slDistance = MathAbs(price - sl);
   double lotSize = CalculateLotSize(slDistance);
   
   // Execute trade
   if(m_trade.Buy(lotSize, m_symbol.Name(), price, sl, tp, comment))
   {
      m_currentTicket = m_trade.ResultOrder();
      m_lastTradeTime = TimeCurrent();
      m_tradesToday++;
      Print("Buy order executed: Lot = ", lotSize, ", Price = ", price, ", SL = ", sl, ", TP = ", tp);
      return true;
   }
   else
   {
      Print("Buy order failed: ", m_trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Open sell position                                               |
//+------------------------------------------------------------------+
bool CTradeManager::OpenSell(double price, double sl, double tp, string comment)
{
   // Check all filters
   if(!IsTradingAllowed() || !CheckTrendFilter(ORDER_TYPE_SELL) || 
      !CheckVolatilityFilter() || !CheckVolumeConfirmation() || 
      !CheckTimeBetweenTrades() || !CheckTradesPerDay())
      return false;
   
   // Calculate lot size
   double slDistance = MathAbs(price - sl);
   double lotSize = CalculateLotSize(slDistance);
   
   // Execute trade
   if(m_trade.Sell(lotSize, m_symbol.Name(), price, sl, tp, comment))
   {
      m_currentTicket = m_trade.ResultOrder();
      m_lastTradeTime = TimeCurrent();
      m_tradesToday++;
      Print("Sell order executed: Lot = ", lotSize, ", Price = ", price, ", SL = ", sl, ", TP = ", tp);
      return true;
   }
   else
   {
      Print("Sell order failed: ", m_trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Close position                                                   |
//+------------------------------------------------------------------+
bool CTradeManager::ClosePosition(int ticket)
{
   if(ticket == -1)
      ticket = m_currentTicket;
   
   if(m_trade.PositionClose(ticket))
   {
      Print("Position closed: Ticket ", ticket);
      if(ticket == m_currentTicket)
         m_currentTicket = -1;
      return true;
   }
   else
   {
      Print("Position close failed: ", m_trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Check if there's an open position                                |
//+------------------------------------------------------------------+
bool CTradeManager::HasOpenPosition()
{
   return (m_currentTicket != -1);
}

//+------------------------------------------------------------------+
//| Get open position ticket                                         |
//+------------------------------------------------------------------+
int CTradeManager::GetOpenPositionTicket()
{
   return m_currentTicket;
}

//+------------------------------------------------------------------+
//| Get position profit                                              |
//+------------------------------------------------------------------+
double CTradeManager::GetPositionProfit()
{
   if(m_currentTicket != -1 && m_position.SelectByTicket(m_currentTicket))
   {
      return m_position.Profit();
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Update daily profit/loss                                         |
//+------------------------------------------------------------------+
void CTradeManager::UpdateDailyPL()
{
   if(HasOpenPosition())
   {
      double positionProfit = GetPositionProfit();
      m_dailyPL += positionProfit;
   }
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool CTradeManager::IsTradingAllowed()
{
   return (CheckDailyDrawdown() && 
           CheckNewsFilter() && 
           CheckWeekendClose() && 
           m_tradingEnabled);
}

//+------------------------------------------------------------------+
//| Main processing method                                           |
//+------------------------------------------------------------------+
void CTradeManager::OnTick()
{
   // Update symbol rates
   m_symbol.RefreshRates();
   
   // Update daily PL
   UpdateDailyPL();
   
   // Update trailing stop if needed
   UpdateTrailingStop();
   
   // Check if position is still open
   if(m_currentTicket != -1)
   {
      if(!m_position.SelectByTicket(m_currentTicket))
      {
         m_currentTicket = -1;
         Print("Position no longer exists");
      }
   }
}
//+------------------------------------------------------------------+