//+------------------------------------------------------------------+
//|                                               CombinedEA.mq5     |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property strict

#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

// Include Trade library
#include <Trade\Trade.mqh>

// Các tham số đầu vào
input double InpLotSize = 1.0;      // Lot size
input double InpStopLoss = 100;     // Stop Loss in points
input double InpTakeProfit = 200;   // Take Profit in points

input int InpFastPeriod = 14;       // Fast period for SMA
input int InpSlowPeriod = 21;       // Slow period for SMA

input int InpMagicNumber = 123456;  // Magic number

input int InpRSIPeriod = 21;        // RSI period
input int InpRSILevel = 70;         // RSI level (upper)
input bool InpCloseSignal = false;  // Close trades by opposite signal

input int InpBollingerPeriod = 20;  // Bollinger Bands period
input double InpDeviation = 2.0;    // Bollinger Bands deviation

// Khai báo biến toàn cục
double BollingerUpper[], BollingerLower[], BollingerMiddle[];
double fastBuffer[], slowBuffer[], rsiBuffer[];
datetime openTimeBuy = 0;
datetime openTimeSell = 0;
CTrade trade;

int fastHandle, slowHandle, rsiHandle;
MqlTick currentTick;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Validate inputs
    if (InpFastPeriod <= 0 || InpSlowPeriod <= 0 || InpFastPeriod >= InpSlowPeriod || 
        InpStopLoss <= 0 || InpTakeProfit <= 0 || InpLotSize <= 0 ||
        InpMagicNumber <= 0 || InpRSIPeriod <= 1 || InpRSILevel >= 100 || InpRSILevel <= 50)
    {
        Alert("Invalid input parameters");
        return INIT_PARAMETERS_INCORRECT;
    }

    // Set magic number
    trade.SetExpertMagicNumber(InpMagicNumber);

    // Create handles for SMA
    fastHandle = iMA(_Symbol, PERIOD_CURRENT, InpFastPeriod, 0, MODE_SMA, PRICE_CLOSE);
    if (fastHandle == INVALID_HANDLE)
    {
        Alert("Failed to create fast SMA handle");
        return INIT_FAILED;
    }
    slowHandle = iMA(_Symbol, PERIOD_CURRENT, InpSlowPeriod, 0, MODE_SMA, PRICE_CLOSE);
    if (slowHandle == INVALID_HANDLE)
    {
        Alert("Failed to create slow SMA handle");
        return INIT_FAILED;
    }

    // Create handle for RSI
    rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
    if (rsiHandle == INVALID_HANDLE)
    {
        Alert("Failed to create RSI handle");
        return INIT_FAILED;
    }

    // Set arrays as series
    ArraySetAsSeries(fastBuffer, true);
    ArraySetAsSeries(slowBuffer, true);
    ArraySetAsSeries(rsiBuffer, true);

    ArraySetAsSeries(BollingerUpper, true);
    ArraySetAsSeries(BollingerLower, true);
    ArraySetAsSeries(BollingerMiddle, true);

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if (fastHandle != INVALID_HANDLE)
        IndicatorRelease(fastHandle);
    if (slowHandle != INVALID_HANDLE)
        IndicatorRelease(slowHandle);
    if (rsiHandle != INVALID_HANDLE)
        IndicatorRelease(rsiHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if (!SymbolInfoTick(_Symbol, currentTick))
    {
        Print("Failed to get current tick");
        return;
    }

    // Tính toán các chỉ báo
    CalculateIndicators();

    // Kiểm tra tín hiệu giao dịch
    CheckTradeSignals();
}

//+------------------------------------------------------------------+
//| Tính toán các chỉ báo                                            |
//+------------------------------------------------------------------+
void CalculateIndicators()
{
    int bars = iBars(Symbol(), 0);
    if (bars < InpBollingerPeriod || CopyBuffer(fastHandle, 0, 0, 2, fastBuffer) != 2 ||
        CopyBuffer(slowHandle, 0, 0, 2, slowBuffer) != 2 || CopyBuffer(rsiHandle, 0, 0, 2, rsiBuffer) != 2)
    {
        Print("Not enough data to calculate indicators");
        return;
    }

    // Tính toán Bollinger Bands
    CopyBuffer(iBands(Symbol(), 0, InpBollingerPeriod, InpDeviation, 0, PRICE_CLOSE), 0, 0, 1, BollingerUpper);
    CopyBuffer(iBands(Symbol(), 0, InpBollingerPeriod, InpDeviation, 0, PRICE_CLOSE), 1, 0, 1, BollingerMiddle);
    CopyBuffer(iBands(Symbol(), 0, InpBollingerPeriod, InpDeviation, 0, PRICE_CLOSE), 2, 0, 1, BollingerLower);
}

//+------------------------------------------------------------------+
//| Kiểm tra tín hiệu giao dịch                                      |
//+------------------------------------------------------------------+
void CheckTradeSignals()
{
    // Lấy giá trị Bollinger Bands
    double upper = BollingerUpper[0];
    double lower = BollingerLower[0];
    double close = iClose(Symbol(), 0, 0);

    // Đếm số vị thế mở
    int cntBuy, cntSell;
    if (!CountOpenPositions(cntBuy, cntSell))
        return;

    // Kiểm tra điều kiện giao dịch theo Bollinger Bands
    if (close > lower && cntBuy == 0)
    {
        OpenBuyOrder();
    }
    if (close < upper && cntSell == 0)
    {
        OpenSellOrder();
    }

    // Kiểm tra điều kiện giao dịch theo SMA Crossover
    if (fastBuffer[1] <= slowBuffer[1] && fastBuffer[0] > slowBuffer[0] && openTimeBuy != iTime(_Symbol, PERIOD_CURRENT, 0))
    {
        if (InpCloseSignal && cntSell > 0)
            ClosePositions(1);

        OpenBuyOrder();
        openTimeBuy = iTime(_Symbol, PERIOD_CURRENT, 0);
    }

    if (fastBuffer[1] >= slowBuffer[1] && fastBuffer[0] < slowBuffer[0] && openTimeSell != iTime(_Symbol, PERIOD_CURRENT, 0))
    {
        if (InpCloseSignal && cntBuy > 0)
            ClosePositions(2);

        OpenSellOrder();
        openTimeSell = iTime(_Symbol, PERIOD_CURRENT, 0);
    }

    // Kiểm tra điều kiện giao dịch theo RSI
    if (cntBuy == 0 && rsiBuffer[1] >= (100 - InpRSILevel) && rsiBuffer[0] < (100 - InpRSILevel) && openTimeBuy != iTime(_Symbol, PERIOD_CURRENT, 0))
    {
        if (InpCloseSignal && cntSell > 0)
            ClosePositions(1);

        OpenBuyOrder();
        openTimeBuy = iTime(_Symbol, PERIOD_CURRENT, 0);
    }

    if (cntSell == 0 && rsiBuffer[1] <= InpRSILevel && rsiBuffer[0] > InpRSILevel && openTimeSell != iTime(_Symbol, PERIOD_CURRENT, 0))
    {
        if (InpCloseSignal && cntBuy > 0)
            ClosePositions(2);

        OpenSellOrder();
        openTimeSell = iTime(_Symbol, PERIOD_CURRENT, 0);
    }
}

//+------------------------------------------------------------------+
//| Mở lệnh mua                                                      |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
    double ask = currentTick.ask;
    double sl = ask - InpStopLoss * _Point;
    double tp = ask + InpTakeProfit * _Point;

    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.symbol = Symbol();
    request.volume = InpLotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = ask;
    request.sl = NormalizeDouble(sl, _Digits);
    request.tp = NormalizeDouble(tp, _Digits);
    request.deviation = 3;
    request.magic = InpMagicNumber;
    request.comment = "Buy order";

    if (!OrderSend(request, result))
    {
        Print("Error opening buy order: ", result.retcode);
    }
}

//+------------------------------------------------------------------+
//| Mở lệnh bán                                                      |
//+------------------------------------------------------------------+
void OpenSellOrder()
{
    double bid = currentTick.bid;
    double sl = bid + InpStopLoss * _Point;
    double tp = bid - InpTakeProfit * _Point;

    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.symbol = Symbol();
    request.volume = InpLotSize;
    request.type = ORDER_TYPE_SELL;
    request.price = bid;
    request.sl = NormalizeDouble(sl, _Digits);
    request.tp = NormalizeDouble(tp, _Digits);
    request.deviation = 3;
    request.magic = InpMagicNumber;
    request.comment = "Sell order";

    if (!OrderSend(request, result))
    {
        Print("Error opening sell order: ", result.retcode);
    }
}

//+------------------------------------------------------------------+
//| Đếm số vị thế mở                                                 |
//+------------------------------------------------------------------+
bool CountOpenPositions(int &cntBuy, int &cntSell)
{
    cntBuy = 0;
    cntSell = 0;
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0 || !PositionSelectByTicket(ticket))
        {
            Print("Failed to get position ticket");
            return false;
        }

        long magic;
        if (!PositionGetInteger(POSITION_MAGIC, magic) || magic != InpMagicNumber)
            continue;

        long type;
        if (!PositionGetInteger(POSITION_TYPE, type))
            continue;

        if (type == POSITION_TYPE_BUY)
            cntBuy++;
        if (type == POSITION_TYPE_SELL)
            cntSell++;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Đóng các vị thế                                                  |
//+------------------------------------------------------------------+
bool ClosePositions(int all_buy_sell)
{
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0 || !PositionSelectByTicket(ticket))
        {
            Print("Failed to get position ticket");
            return false;
        }

        long magic;
        if (!PositionGetInteger(POSITION_MAGIC, magic) || magic != InpMagicNumber)
            continue;

        long type;
        if (!PositionGetInteger(POSITION_TYPE, type))
            continue;

        if (all_buy_sell == 1 && type == POSITION_TYPE_SELL)
            continue;
        if (all_buy_sell == 2 && type == POSITION_TYPE_BUY)
            continue;

        trade.PositionClose(ticket);
        if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
        {
            Print("Failed to close position. Ticket: ", ticket, " Result: ", trade.ResultRetcodeDescription());
        }
    }
    return true;
}
