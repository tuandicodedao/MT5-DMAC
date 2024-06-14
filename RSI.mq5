//+------------------------------------------------------------------+
//|                                                          RSI.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"


#include <Trade\Trade.mqh>

//--- input parameters
static input int InpMagicnumber = 546812;      // Magic number
static input double InpLotSize = 0.01;         // Lot size
static input int InpRSIPeriod = 21;            // RSI period
static input int InpRSILevel = 70;             // RSI level (upper)
static input int InpStopLoss = 200;            // Stop loss in points (0=off)
static input int InpTakeProfit = 100;          // Take profit in points (0=off)
static input bool InpCloseSignal = false;      // Close trades by opposite signal

//--- global variables
int handle;
double buffer[];
MqlTick currentTick;
CTrade trade;
datetime openTimeBuy = 0;
datetime openTimeSell = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // check user inputs
    if (InpMagicnumber <= 0) {
        Alert("Magicnumber <= 0");
        return(INIT_PARAMETERS_INCORRECT);
    }
    if (InpLotSize <= 0 || InpLotSize > 10) {
        Alert("Lot size <= 0 or > 10");
        return(INIT_PARAMETERS_INCORRECT);
    }
    if (InpRSIPeriod <= 1) {
        Alert("RSI period <= 1");
        return(INIT_PARAMETERS_INCORRECT);
    }
    if (InpRSILevel >= 100 || InpRSILevel <= 50) {
        Alert("RSI level >= 100 or <= 50");
        return(INIT_PARAMETERS_INCORRECT);
    }
    if (InpStopLoss < 0) {
        Alert("Stop loss < 0");
        return(INIT_PARAMETERS_INCORRECT);
    }
    if (InpTakeProfit < 0) {
        Alert("Take profit < 0");
        return(INIT_PARAMETERS_INCORRECT);
    }
    
    // set magic number to trade object
    trade.SetExpertMagicNumber(InpMagicnumber);
    
    // create RSI handle
    handle = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
    if (handle == INVALID_HANDLE) {
        Alert("Failed to create indicator handle");
        return(INIT_FAILED);
    }
    
    // set buffer as series
    ArraySetAsSeries(buffer, true);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // release indicator handle
    if (handle != INVALID_HANDLE) {
        IndicatorRelease(handle);
    }
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // get current tick
    if (!SymbolInfoTick(_Symbol, currentTick)) {
        Print("Failed to get current tick");
        return;
    }
    
    // get RSI values
    int values = CopyBuffer(handle, 0, 0, 2, buffer);
    if (values != 2) {
        Print("Failed to get indicator values");
        return;
    }
    
    // display RSI values
    Comment("buffer[0]: ", buffer[0], "\nbuffer[1]: ", buffer[1]);
    
    // count open positions
    int cntBuy, cntSell;
    if (!CountOpenPositions(cntBuy, cntSell)) {
        return;
    }

    // check for buy position
    if (cntBuy == 0 && buffer[1] >= (100 - InpRSILevel) && buffer[0] < (100 - InpRSILevel) && openTimeBuy != iTime(_Symbol, PERIOD_CURRENT, 0)) {
        openTimeBuy = iTime(_Symbol, PERIOD_CURRENT, 0);
        if (InpCloseSignal) {
            if (!ClosePositions(2)) {
                return;
            }
        }

        double sl = InpStopLoss == 0 ? 0 : currentTick.bid - InpStopLoss * _Point;
        double tp = InpTakeProfit == 0 ? 0 : currentTick.bid + InpTakeProfit * _Point;

        sl = NormalizeDouble(sl, _Digits);
        tp = NormalizeDouble(tp, _Digits);

        trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, InpLotSize, currentTick.ask, sl, tp, "RSI EA");
    }
    
    // check for sell position
    if (cntSell == 0 && buffer[1] <= InpRSILevel && buffer[0] > InpRSILevel && openTimeSell != iTime(_Symbol, PERIOD_CURRENT, 0)) {
        openTimeSell = iTime(_Symbol, PERIOD_CURRENT, 0);
        if (InpCloseSignal) {
            if (!ClosePositions(1)) { // Should close BUY positions
                return;
            }
        }

        double sl = InpStopLoss == 0 ? 0 : currentTick.ask + InpStopLoss * _Point; // stop loss for sell position
        double tp = InpTakeProfit == 0 ? 0 : currentTick.ask - InpTakeProfit * _Point; // take profit for sell position

        sl = NormalizeDouble(sl, _Digits);
        tp = NormalizeDouble(tp, _Digits);

        trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, InpLotSize, currentTick.bid, sl, tp, "RSI EA");
    }
}



// count open positions
bool CountOpenPositions(int &cntBuy, int &cntSell)
{
    cntBuy = 0;
    cntSell = 0;
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0) {
            Print("Failed to get position ticket");
            return false;
        }
        if (!PositionSelectByTicket(ticket)) {
            Print("Failed to select position");
            return false;
        }
        long magic;
        if (!PositionGetInteger(POSITION_MAGIC, magic)) {
            Print("Failed to get position magic number");
            return false;
        }
        if (magic == InpMagicnumber) {
            long type;
            if (!PositionGetInteger(POSITION_TYPE, type)) {
                Print("Failed to get position type");
                return false;
            }
            if (type == POSITION_TYPE_BUY) {
                cntBuy++;
            }
            if (type == POSITION_TYPE_SELL) {
                cntSell++;
            }
        }
    }
    return true;
}


// close positions
bool ClosePositions(int all_buy_sell)
{
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0) {
            Print("Failed to get position ticket");
            return false;
        }
        if (!PositionSelectByTicket(ticket)) {
            Print("Failed to select position");
            return false;
        }
        long magic;
        if (!PositionGetInteger(POSITION_MAGIC, magic)) {
            Print("Failed to get position magic number");
            return false;
        }
        if (magic == InpMagicnumber)
        {
            long type;
            if (!PositionGetInteger(POSITION_TYPE, type)) {
                Print("Failed to get position type");
                return false;
            }
            if (all_buy_sell == 1 && type == POSITION_TYPE_SELL) {
                continue;
            }
            if (all_buy_sell == 2 && type == POSITION_TYPE_BUY) {
                continue;
            }
            trade.PositionClose(ticket);
            if (trade.ResultRetcode() != TRADE_RETCODE_DONE) {
                Print("Failed to close position. ticket: ", (string)ticket, " result: ", (string)trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
            }
        }
    }
    return true;
}
