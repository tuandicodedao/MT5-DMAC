//+------------------------------------------------------------------+
//|                                                      PairTrading |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property strict

//--- input parameters
input string Symbol1 = "EURUSD";
input string Symbol2 = "GBPUSD";
input string Symbol3 = "USDJPY";
input double RatioThreshold = 0.01; // Threshold for triggering a trade
input double LotSize = 0.01;         // Lot size for trading

//--- global variables
double Ratio1, Ratio2, Ratio3;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- initializations
   Print("Pair Trading Strategy Initialized");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- cleanup code
   Print("Pair Trading Strategy Deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- calculate the ratios
   Ratio1 = NormalizeDouble(iClose(Symbol1, PERIOD_M1, 0) / iClose(Symbol2, PERIOD_M1, 0), 5);
   Ratio2 = NormalizeDouble(iClose(Symbol2, PERIOD_M1, 0) / iClose(Symbol3, PERIOD_M1, 0), 5);
   Ratio3 = NormalizeDouble(iClose(Symbol1, PERIOD_M1, 0) / iClose(Symbol3, PERIOD_M1, 0), 5);

   //--- check for trading conditions
   if (Ratio1 > 1 + RatioThreshold)
   {
      //--- open buy order for Symbol1 and sell orders for Symbol2 and Symbol3
      OpenOrder(Symbol1, ORDER_TYPE_BUY, LotSize);
      OpenOrder(Symbol2, ORDER_TYPE_SELL, LotSize);
      OpenOrder(Symbol3, ORDER_TYPE_SELL, LotSize);
   }
   else if (Ratio1 < 1 - RatioThreshold)
   {
      //--- open sell order for Symbol1 and buy orders for Symbol2 and Symbol3
      OpenOrder(Symbol1, ORDER_TYPE_SELL, LotSize);
      OpenOrder(Symbol2, ORDER_TYPE_BUY, LotSize);
      OpenOrder(Symbol3, ORDER_TYPE_BUY, LotSize);
   }

   //--- Similar checks for Ratio2 and Ratio3 can be added here
}

//+------------------------------------------------------------------+
//| Function to open an order                                        |
//+------------------------------------------------------------------+
void OpenOrder(string symbol, int type, double lots)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   MqlTick tick;

   //--- Check if there are existing positions for this symbol
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (PositionGetSymbol(i) == symbol)
      {
         Print("There are already open positions for ", symbol);
         return;
      }
   }

   //--- fill the trade request structure
   ZeroMemory(request);
   request.action = TRADE_ACTION_DEAL;
   request.symbol = symbol;
   request.volume = lots;
   request.type = type;
   request.deviation = 10;  // Increased deviation
   request.magic = 123456;

   //--- get the current market price
   if (!SymbolInfoTick(symbol, tick))
   {
      Print("Error getting tick info for ", symbol);
      return;
   }

   //--- set the appropriate price for the order type
   if (type == ORDER_TYPE_BUY)
      request.price = tick.ask;
   else if (type == ORDER_TYPE_SELL)
      request.price = tick.bid;

   //--- send the order
   if (!OrderSend(request, result))
   {
      Print("Error opening order for ", symbol, ". Error: ", GetLastError());
   }
   else
   {
      Print("Order opened for ", symbol, ". Ticket: ", result.order);
   }
}
