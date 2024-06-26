//+------------------------------------------------------------------+
//|                                                      BollingerBandsEA.mq5 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                        https://www.metaquotes.net |
//+------------------------------------------------------------------+
#property strict

// Các tham số đầu vào
input double Lots = 0.1;  // Lots giao dịch
input int Period = 20;    // Chu kỳ Bollinger Bands
input double Deviation = 2.0;  // Độ lệch chuẩn
input double StopLoss = 50.0;  // Stop loss (đơn vị pip)
input double TakeProfit = 100.0;  // Take profit (đơn vị pip)
input int MagicNumber = 123456;  // Số đặc biệt cho các lệnh

// Khai báo biến toàn cục
double BollingerUpper[];
double BollingerLower[];
double BollingerMiddle[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Khởi tạo các mảng cho Bollinger Bands
    ArraySetAsSeries(BollingerUpper, true);
    ArraySetAsSeries(BollingerLower, true);
    ArraySetAsSeries(BollingerMiddle, true);

    // Tính toán Bollinger Bands ban đầu
    CalculateBollingerBands();

    return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Tính toán Bollinger Bands mới
    CalculateBollingerBands();

    // Lấy giá đóng cửa hiện tại
    double close = iClose(Symbol(), 0, 0);

    // Lấy giá trị Bollinger Bands
    double upper = BollingerUpper[0];
    double lower = BollingerLower[0];

    // Lấy giá Ask và Bid hiện tại
    double Ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double Bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);

    // Kiểm tra tín hiệu mua
    if (close > lower && PositionsTotal() == 0)
    {
        // Mở lệnh mua
        MqlTradeRequest request;
        MqlTradeResult result;
        double sl = Ask - StopLoss * _Point;
        double tp = Ask + TakeProfit * _Point;

        ZeroMemory(request);
        request.action = TRADE_ACTION_DEAL;
        request.symbol = Symbol();
        request.volume = Lots;
        request.type = ORDER_TYPE_BUY;
        request.price = Ask;
        request.sl = sl;
        request.tp = tp;
        request.deviation = 3;
        request.magic = MagicNumber;
        request.comment = "Buy order";

        if (!OrderSend(request, result))
        {
            Print("Error opening buy order: ", result.retcode);
        }
        else
        {
            LogTradeResults();  // Ghi lại kết quả giao dịch sau khi mở lệnh mua
        }
    }

    // Kiểm tra tín hiệu bán
    if (close < upper && PositionsTotal() == 0)
    {
        // Mở lệnh bán
        MqlTradeRequest request;
        MqlTradeResult result;
        double sl = Bid + StopLoss * _Point;
        double tp = Bid - TakeProfit * _Point;

        ZeroMemory(request);
        request.action = TRADE_ACTION_DEAL;
        request.symbol = Symbol();
        request.volume = Lots;
        request.type = ORDER_TYPE_SELL;
        request.price = Bid;
        request.sl = sl;
        request.tp = tp;
        request.deviation = 3;
        request.magic = MagicNumber;
        request.comment = "Sell order";

        if (!OrderSend(request, result))
        {
            Print("Error opening sell order: ", result.retcode);
        }
        else
        {
            LogTradeResults();  // Ghi lại kết quả giao dịch sau khi mở lệnh bán
        }
    }
}
//+------------------------------------------------------------------+
//| Tính toán Bollinger Bands                                        |
//+------------------------------------------------------------------+
void CalculateBollingerBands()
{
    int bars = iBars(Symbol(), 0);
    if (bars < Period)
    {
        Print("Not enough bars to calculate Bollinger Bands");
        return;
    }

    // Tính toán dải trên, dải giữa và dải dưới của Bollinger Bands
    if (!CopyBuffer(iBands(Symbol(), 0, Period, Deviation, 0, PRICE_CLOSE), 0, 0, 3, BollingerUpper) ||
        !CopyBuffer(iBands(Symbol(), 0, Period, Deviation, 0, PRICE_CLOSE), 1, 0, 3, BollingerMiddle) ||
        !CopyBuffer(iBands(Symbol(), 0, Period, Deviation, 0, PRICE_CLOSE), 2, 0, 3, BollingerLower))
    {
        Print("Failed to copy Bollinger Bands buffer, error code: ", GetLastError());
    }
}
//+------------------------------------------------------------------+
//| Ghi lại kết quả giao dịch                                        |

//+------------------------------------------------------------------+
void LogTradeResults()
{
    double profit = AccountInfoDouble(ACCOUNT_PROFIT);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);

    Print("Profit: ", profit);
    Print("Balance: ", balance);
    Print("Equity: ", equity);
}
//+------------------------------------------------------------------+
