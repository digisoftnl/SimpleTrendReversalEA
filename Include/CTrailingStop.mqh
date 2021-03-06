//+------------------------------------------------------------------+
//|                                                CTrailingStop.mqh |
//|                                    Copyright 2017, Erwin Beckers |
//|                                              www.erwinbeckers.nl |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Erwin Beckers"
#property link      "www.erwinbeckers.nl"
#property strict
// taken from https://www.forexfactory.com/showthread.php?t=446353

#include <CUtils.mqh>;
#include <COrders.mqh>;

enum TrailingMethods
{
   UseTrailingStops,
   UseRiskRewardRatios
};

enum TakeProfitRiskRewardRatios
{
   RR_1_1,
   RR_2_1,
   RR_3_1,
   RR_4_1,
   RR_5_1,
   RR_6_1
};

extern   string   __trailingStop__          = " ------- Trailing stoploss settings ------------";
extern   TrailingMethods            TrailingMethod = UseTrailingStops;   
extern   TakeProfitRiskRewardRatios TakeProfitAt   = RR_2_1;   
extern   double   OrderHiddenSL             = 50;   

extern   double   OrderTS1                  = 30;        
extern   double   OrderTS1Trigger           = 50;

extern   double   OrderTS2                  = 40;     
extern   double   OrderTS2Trigger           = 60; 

extern   double   OrderTS3                  = 50;       
extern   double   OrderTS3Trigger           = 70;
 
extern   double   OrderTS4                  = 60; 
extern   double   OrderTS4Trigger           = 80; 

extern   double   OrderTrail                = 10;

const int MAX_ORDERS = 500;

enum ORDER_STATE
{
   ORDER_OPENED,
   ORDER_OPENED_INITIAL_STOPLOSS,
   ORDER_LEVEL_1,
   ORDER_LEVEL_2,
   ORDER_LEVEL_3,
   ORDER_LEVEL_4,
   ORDER_TRAIL
};

//-------------------------------------------------------------------------
//-------------------------------------------------------------------------
class CTrailingStop
{
private:   
   COrders*    _orderMgnt;
   bool        IsBuy;
   int         Ticket;   
   double      OpenPrice;
   double      StopLoss;
   double      InitialStopLoss;
   double      RiskReward;
   ORDER_STATE State;
   string      _symbol;
   
public: 
   //-------------------------------------------------------------------------
   CTrailingStop(string symbol)
   {
      Ticket     = -1;
      _symbol    = symbol;
      _orderMgnt = new COrders(symbol);
   }
   
   //-------------------------------------------------------------------------
   ~CTrailingStop()
   {
      delete _orderMgnt;
   }
   
   //-------------------------------------------------------------------------
   void SetInitalStoploss(int ticket, double stoploss)
   {
      Ticket = -1;
      if (OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      {
         if (OrderSymbol() == _symbol)
         {
            Print(_symbol," Trail: Add order ticket:", ticket, " op:", DoubleToStr(OrderOpenPrice(),5),  " sl:",DoubleToStr(stoploss,5));
            IsBuy           = (OrderType()  == OP_BUY ||  OrderType()== OP_BUYLIMIT || OrderType()== OP_BUYSTOP);
            Ticket          = OrderTicket();
            OpenPrice       = OrderOpenPrice();
            InitialStopLoss = OrderStopLoss();
            StopLoss        = OrderStopLoss();
            RiskReward      = 0;
            State           = ORDER_OPENED;
            if (stoploss > 0)
            {
               StopLoss        = stoploss;
               InitialStopLoss = stoploss;
               State            = ORDER_OPENED_INITIAL_STOPLOSS;
            }
            
            Trail();
         }
         else
         {
           Print(_symbol," Trail: symbol wrong:", OrderSymbol());
         }
      }
      else
      {
        Print(_symbol," Trail: ticket wrong:", ticket);
      }
   }
   
   //-------------------------------------------------------------------------
   double GetRiskReward(int ticket)
   {
      if (Ticket != ticket) return 0;
      return RiskReward;
   }
   
   //-------------------------------------------------------------------------
   double GetStoploss(int ticket)
   {
      if (Ticket != ticket) return 0;
      return StopLoss;
   }
   
   //-------------------------------------------------------------------------
   void Trail()
   {
      if (Ticket < 0) return;
      if (!MarketInfo(_symbol, MODE_TRADEALLOWED)) return; 
      if (!OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES))
      {
         Print(_symbol," Trail: order was closed:", Ticket);
         Ticket     = -1;
         RiskReward = 0;
         InitialStopLoss = 0;
         StopLoss   = 0;
         OpenPrice  = 0;
         State      = ORDER_OPENED;
         return;
      }
      
      if ( OrderCloseTime() != 0 ) 
      {
         Print(_symbol," Trail: order was closed:", Ticket);
         Ticket     = -1;
         RiskReward = 0;
         InitialStopLoss = 0;
         StopLoss   = 0;
         OpenPrice  = 0;
         State      = ORDER_OPENED;
         return;
      }
      
      if (TrailingMethod == UseTrailingStops)
      {
         TrailFixed();
         return;
      }
      if (TrailingMethod == UseRiskRewardRatios)
      {
         TrailRiskReward();
         return;
      }
   }
   
   //-------------------------------------------------------------------------
   void TrailRiskReward()
   {
      double askPrice = MarketInfo(_symbol, MODE_ASK);
      double bidPrice = MarketInfo(_symbol, MODE_BID);
      double points   = MarketInfo(_symbol, MODE_POINT);
      double digits   = MarketInfo(_symbol, MODE_DIGITS);
      double mult = 1;
      if (digits ==3 || digits==5) mult = 10;
      
      if (IsBuy)
      {
         RiskReward = (bidPrice - OpenPrice) / MathAbs( OpenPrice - InitialStopLoss);
         if (bidPrice <= InitialStopLoss)
         {
            Print(_symbol," Trail: Order:", Ticket, " close SL hit");
            if ( _orderMgnt.CloseOrderByTicket(Ticket) ) Ticket=-1;
            
            return;
         }
      }
      else 
      {
         RiskReward = (OpenPrice - askPrice) / MathAbs( InitialStopLoss - OpenPrice);
         
         if (askPrice >= InitialStopLoss)
         {
            Print(_symbol," Trail: Order:", Ticket, " close SL hit");
            if ( _orderMgnt.CloseOrderByTicket(Ticket) ) Ticket=-1;
            return;
         }
      }
      
      if (RiskReward >= 1 && TakeProfitAt == RR_1_1)
      {  
          Print(_symbol," Trail: Order:", Ticket, " close at 1:1 RR");
         if ( _orderMgnt.CloseOrderByTicket(Ticket) ) Ticket=-1;
         return;
      }
      
      if (RiskReward >= 2 && TakeProfitAt == RR_2_1)
      {  
          Print(_symbol," Trail: Order:", Ticket, " close at 2:1 RR");
         if ( _orderMgnt.CloseOrderByTicket(Ticket) ) Ticket=-1;
         return;
      }
      
      if (RiskReward >= 3 && TakeProfitAt == RR_3_1)
      {  
          Print(_symbol," Trail: Order:", Ticket, " close at 3:1 RR");
          if ( _orderMgnt.CloseOrderByTicket(Ticket) ) Ticket=-1;
         return;
      }
      if (RiskReward >= 4 && TakeProfitAt == RR_4_1)
      {  
          Print(_symbol," Trail: Order:", Ticket, " close at 4:1 RR");
          if ( _orderMgnt.CloseOrderByTicket(Ticket) ) Ticket=-1;
         return;
      }
      if (RiskReward >= 5 && TakeProfitAt == RR_5_1)
      {  
          Print(_symbol," Trail: Order:", Ticket, " close at 5:1 RR");
          if ( _orderMgnt.CloseOrderByTicket(Ticket) ) Ticket=-1;
         return;
      }
      if (RiskReward >= 6 && TakeProfitAt == RR_6_1)
      {  
          Print(_symbol," Trail: Order:", Ticket, " close at 6:1 RR");
          if ( _orderMgnt.CloseOrderByTicket(Ticket) ) Ticket=-1;
         return;
      }
   }
   
   //-------------------------------------------------------------------------
   void TrailFixed()
   {
      double      sl=0;
      double      nextLevel = 0;
      ORDER_STATE nextState = State;
      
      double askPrice = MarketInfo(_symbol, MODE_ASK);
      double bidPrice = MarketInfo(_symbol, MODE_BID);
      double points   = MarketInfo(_symbol, MODE_POINT);
      double digits   = MarketInfo(_symbol, MODE_DIGITS);
      double mult = 1;
      if (digits ==3 || digits==5) mult = 10;
      
      if (!_orderMgnt.IsSpreadOk()) return;
      
      if (IsBuy)
      {
         RiskReward= (bidPrice - OpenPrice) / MathAbs( OpenPrice - InitialStopLoss);
         switch (State)
         {
            case ORDER_OPENED:
               StopLoss  = OpenPrice - OrderHiddenSL * mult * points;
               nextLevel = OpenPrice + OrderTS1Trigger * mult * points;
               nextState = ORDER_LEVEL_1;
            break;
            
            case ORDER_OPENED_INITIAL_STOPLOSS:
               // stoploss already set..
               nextLevel = OpenPrice + OrderTS1Trigger * mult *  points;
               nextState = ORDER_LEVEL_1;
            break;
            
            case ORDER_LEVEL_1:
               StopLoss  = OpenPrice + OrderTS1 * mult *  points;
               nextLevel = OpenPrice + OrderTS2Trigger * mult *  points;
               nextState = ORDER_LEVEL_2;
            break;
            
            case ORDER_LEVEL_2:
               StopLoss  = OpenPrice + OrderTS2 * mult *  points;
               nextLevel = OpenPrice + OrderTS3Trigger * mult *  points;
               nextState = ORDER_LEVEL_3;
            break;
            
            case ORDER_LEVEL_3:
               StopLoss  = OpenPrice + OrderTS3 * mult *  points;
               nextLevel = OpenPrice + OrderTS4Trigger * mult *  points;
               nextState = ORDER_LEVEL_4;
            break;
            
            case ORDER_LEVEL_4:
               StopLoss  = OpenPrice + OrderTS4 * mult *  points;
               nextLevel = OpenPrice + (OrderTS4Trigger + OrderTrail) * mult *  points;
               nextState = ORDER_TRAIL;
            break;
            
            case ORDER_TRAIL:
               sl=askPrice - OrderTrail * mult *  points;
               if (sl > StopLoss) StopLoss = sl;
            break;
         }
         
         if (bidPrice <= StopLoss)
         {
            Print(_symbol," Trail: Order:", Ticket," Close SL hit profit:", DoubleToStr(OrderProfit() + OrderSwap() + OrderCommission(),2));
            _orderMgnt.CloseOrderByTicket(Ticket);
         }
         else if (bidPrice >= nextLevel)
         {
            Print(_symbol," Trail: Order:", Ticket," op:", DoubleToStr(OpenPrice,5), "  bid:", DoubleToStr(bidPrice,5), " next level reached:", nextLevel, " nextstate:", nextState);
            State = nextState;
         }
      }
      else // of buy orders
      {
         RiskReward= (OpenPrice - askPrice) / MathAbs( InitialStopLoss - OpenPrice);
         // handle sell orders
         switch (State)
         {
            case ORDER_OPENED:
               StopLoss  = OpenPrice + OrderHiddenSL * mult *  points;
               nextLevel = OpenPrice - OrderTS1Trigger * mult *  points;
               nextState = ORDER_LEVEL_1;
            break;
            
            case ORDER_OPENED_INITIAL_STOPLOSS:
               // stoploss already set
               nextLevel = OpenPrice - OrderTS1Trigger * mult *  points;
               nextState = ORDER_LEVEL_1;
            break;
            
            case ORDER_LEVEL_1:
               StopLoss  = OpenPrice - OrderTS1 * mult *  points;
               nextLevel = OpenPrice - OrderTS2Trigger * mult *  points;
               nextState = ORDER_LEVEL_2;
            break;
            
            case ORDER_LEVEL_2:
               StopLoss  = OpenPrice - OrderTS2 * mult *  points;
               nextLevel = OpenPrice - OrderTS3Trigger * mult *  points;
               nextState = ORDER_LEVEL_3;
            break;
            
            case ORDER_LEVEL_3:
               StopLoss  = OpenPrice - OrderTS3 * mult *  points;
               nextLevel = OpenPrice - OrderTS4Trigger * mult *  points;
               nextState = ORDER_LEVEL_4;
            break;
            
            case ORDER_LEVEL_4:
               StopLoss  = OpenPrice - OrderTS4 * mult *  points;
               nextLevel = OpenPrice - (OrderTS4Trigger + OrderTrail) * mult *  points;
               nextState = ORDER_TRAIL;
            break;
            
            case ORDER_TRAIL:
               sl = bidPrice + OrderTrail * mult *  points;
               if (sl < StopLoss) StopLoss = sl;
            break;
         }
         //Print(" trailing sorder:", Ticket, " op:", OpenPrice, " ask:", askPrice, " bid:", bidPrice, " next:", NormalizeDouble(nextLevel,5), "  State:",State);
         if (askPrice >= StopLoss)
         {
            Print(_symbol," Trail: Order:", Ticket," Close SL hit profit:", DoubleToStr(OrderProfit() + OrderSwap() + OrderCommission(),2));
            _orderMgnt.CloseOrderByTicket(Ticket);
         }
         else if (askPrice <= nextLevel)
         {
            Print(_symbol," Trail: Order:", Ticket," op:", DoubleToStr(OpenPrice,5), "  ask:", DoubleToStr(askPrice,5), " next level reached:", nextLevel, " nextstate:", nextState);
            State = nextState;
         }
      }
   }
}; // class