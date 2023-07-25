#import "InAppUtils.h"
#import <StoreKit/StoreKit.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import "SKProduct+StringPrice.h"

@implementation InAppUtils
{
    NSArray *products;
    NSMutableDictionary *_callbacks;
    //RCTResponseSenderBlock _lostCallBack; // 丢单数据的重新监听回调
    //RCTResponseSenderBlock _lostCallBack1; // 丢单数据的重新监听回调
}

- (instancetype)init
{
    if ((self = [super init])) {
        _callbacks = [[NSMutableDictionary alloc] init];
        //[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

+ (BOOL)requiresMainQueueSetup {
    return NO;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE()
/**
 *  添加商品购买状态监听
 *  @params:
 *        callback 针对购买过程中，App意外退出的丢单数据的回调
 */
RCT_EXPORT_METHOD(addTransactionObserverWithCallback:(RCTResponseSenderBlock)callback) {
    //监听商品购买状态变化
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    //_lostCallBack = callback;
    //_lostCallBack1 = NULL;
    NSString *lostCallback = @"lostCallback";
    _callbacks[lostCallback] = callback;
#if RCT_DEV
        RCTLogWarn(@"======add observer=======");
#endif
}

RCT_EXPORT_METHOD(addCallback:(RCTResponseSenderBlock)callback) {
    //监听商品购买状态变化
    NSString *lostCallback = @"lostCallback";
    _callbacks[lostCallback] = callback;
#if RCT_DEV
        RCTLogWarn(@"======add callback=======");
#endif
}

RCT_EXPORT_METHOD(addCallback1:(RCTResponseSenderBlock)callback) {
    //监听商品购买状态变化
    NSString *lostCallback1 = @"lostCallback1";
    _callbacks[lostCallback1] = callback;
#if RCT_DEV
        RCTLogWarn(@"======add callback1=======");
#endif
}

RCT_EXPORT_METHOD(removeTransactionObserver) {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    //_lostCallBack = NULL;
    //_lostCallBack1 = NULL;
#if RCT_DEV
        RCTLogWarn(@"======remove observer0=======");
#endif
}

- (void)paymentQueue:(SKPaymentQueue *)queue
 updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStateFailed: {
                NSString *key = transaction.payment.productIdentifier;
                RCTResponseSenderBlock callback = _callbacks[key];
                if (callback) {
#if RCT_DEV
                    RCTLogWarn(@"callback registered for transaction with state failed.");
#endif
                    callback(@[RCTJSErrorFromNSError(transaction.error)]);
                    [_callbacks removeObjectForKey:key];
                } else {
#if RCT_DEV
                    RCTLogWarn(@"No callback registered for transaction with state failed.");
#endif
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            }
            case SKPaymentTransactionStatePurchased: {
                NSDictionary *purchase = [self getPurchaseData:transaction];
                NSString *key = transaction.payment.productIdentifier;
                RCTResponseSenderBlock callback = _callbacks[key];
                if (callback) {
#if RCT_DEV
                    RCTLogWarn(@"callback registered for transaction with state purchased.");
#endif
                    callback(@[[NSNull null], purchase]);
                    [_callbacks removeObjectForKey:key];
                }else
                {
                    //丢单，续费，未绑定信用卡
                    NSString *key = @"lostCallback";
                    RCTResponseSenderBlock lostCallback = _callbacks[key];
                    
                    NSString *key1 = @"lostCallback1";
                    RCTResponseSenderBlock lostCallback1 = _callbacks[key1];
                    
                    if (lostCallback) {
#if RCT_DEV
                        RCTLogWarn(@"callback registered for transaction with state purchased lost.");
#endif
                        lostCallback(@[[NSNull null], purchase]);
                        [_callbacks removeObjectForKey:key];
                    }
                    else if(lostCallback1){
#if RCT_DEV
                        RCTLogWarn(@"callback1 registered for transaction with state purchased lost.");
#endif
                        lostCallback1(@[[NSNull null], purchase]);
                        [_callbacks removeObjectForKey:key1];
                    }
                    else {
    #if RCT_DEV
                        RCTLogWarn(@"No callback registered for transaction with state purchased.");
    #endif
                        //[[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                    }
                    
                }
                //[[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            }
            case SKPaymentTransactionStateRestored:
#if RCT_DEV
                RCTLogWarn(@"No callback registered for transaction with state restored.");
#endif
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            case SKPaymentTransactionStatePurchasing:
#if RCT_DEV
                RCTLogWarn(@"purchasing");
#endif
                break;
            case SKPaymentTransactionStateDeferred:
#if RCT_DEV
                RCTLogWarn(@"deferred");
#endif
                break;
            default:
                break;
        }
    }
}

RCT_EXPORT_METHOD(purchaseProductForUser:(NSString *)productIdentifier
                  username:(NSString *)username
                  callback:(RCTResponseSenderBlock)callback)
{
    [self doPurchaseProduct:productIdentifier username:username callback:callback];
}

RCT_EXPORT_METHOD(purchaseProduct:(NSString *)productIdentifier
                  callback:(RCTResponseSenderBlock)callback)
{
    [self doPurchaseProduct:productIdentifier username:nil callback:callback];
}

- (void) doPurchaseProduct:(NSString *)productIdentifier
                  username:(NSString *)username
                  callback:(RCTResponseSenderBlock)callback
{
    SKProduct *product;
    for(SKProduct *p in products)
    {
        if([productIdentifier isEqualToString:p.productIdentifier]) {
            product = p;
            break;
        }
    }

    if(product) {
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        if(username) {
            payment.applicationUsername = username;
        }
        [[SKPaymentQueue defaultQueue] addPayment:payment];
        _callbacks[payment.productIdentifier] = callback;
    } else {
        callback(@[@"invalid_product"]);
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue
restoreCompletedTransactionsFailedWithError:(NSError *)error
{
    NSString *key = @"restoreRequest";
    RCTResponseSenderBlock callback = _callbacks[key];
    if (callback) {
        switch (error.code)
        {
            case SKErrorPaymentCancelled:
                callback(@[@"user_cancelled"]);
                break;
            default:
                callback(@[@"restore_failed"]);
                break;
        }

        [_callbacks removeObjectForKey:key];
    } else {
#if RCT_DEV
        RCTLogWarn(@"No callback registered for restore product request.");
#endif
    }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    NSString *key = @"restoreRequest";
    RCTResponseSenderBlock callback = _callbacks[key];
    if (callback) {
        NSMutableArray *productsArrayForJS = [NSMutableArray array];
        for(SKPaymentTransaction *transaction in queue.transactions){
            if(transaction.transactionState == SKPaymentTransactionStateRestored) {

                NSDictionary *purchase = [self getPurchaseData:transaction];

                [productsArrayForJS addObject:purchase];
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            }
        }
        callback(@[[NSNull null], productsArrayForJS]);
        [_callbacks removeObjectForKey:key];
    } else {
#if RCT_DEV
        RCTLogWarn(@"No callback registered for restore product request.");
#endif
    }
}

RCT_EXPORT_METHOD(restorePurchases:(RCTResponseSenderBlock)callback)
{
    NSString *restoreRequest = @"restoreRequest";
    _callbacks[restoreRequest] = callback;
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

RCT_EXPORT_METHOD(restorePurchasesForUser:(NSString *)username
                    callback:(RCTResponseSenderBlock)callback)
{
    NSString *restoreRequest = @"restoreRequest";
    _callbacks[restoreRequest] = callback;
    if(!username) {
        callback(@[@"username_required"]);
        return;
    }
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactionsWithApplicationUsername:username];
}

RCT_EXPORT_METHOD(loadProducts:(NSArray *)productIdentifiers
                  callback:(RCTResponseSenderBlock)callback)
{
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc]
                                          initWithProductIdentifiers:[NSSet setWithArray:productIdentifiers]];
    productsRequest.delegate = self;
    _callbacks[RCTKeyForInstance(productsRequest)] = callback;
    [productsRequest start];
}

RCT_EXPORT_METHOD(canMakePayments: (RCTResponseSenderBlock)callback)
{
    BOOL canMakePayments = [SKPaymentQueue canMakePayments];
    callback(@[@(canMakePayments)]);
}

RCT_EXPORT_METHOD(receiptData:(RCTResponseSenderBlock)callback)
{
    NSString *receipt = [self grandUnifiedReceipt];
    if (receipt == nil) {
        callback(@[@"not_available"]);
    } else {
        callback(@[[NSNull null], receipt]);
    }
}

RCT_EXPORT_METHOD(finishTransaction:(NSString *)productIdentifier){
    for (SKPaymentTransaction* transaction in [[SKPaymentQueue defaultQueue] transactions]){
        if ([transaction.payment.productIdentifier isEqualToString:productIdentifier]
            && transaction.transactionState == SKPaymentTransactionStatePurchased)
        {
#if RCT_DEV
            RCTLogWarn(@"======finishTransaction,id=%@",productIdentifier);
#endif
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        }
    }
}

// Fetch Grand Unified Receipt
- (NSString *)grandUnifiedReceipt
{
    NSURL *receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptUrl];
    if (!receiptData) {
        return nil;
    } else {
        return [receiptData base64EncodedStringWithOptions:0];
    }
}

// SKProductsRequestDelegate protocol method
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response
{
    NSString *key = RCTKeyForInstance(request);
    RCTResponseSenderBlock callback = _callbacks[key];
    if (callback) {
        products = [NSMutableArray arrayWithArray:response.products];
        NSMutableArray *productsArrayForJS = [NSMutableArray array];
        for(SKProduct *item in response.products) {
            NSDictionary *product = @{
                @"identifier": item.productIdentifier,
                @"price": item.price,
                @"currencySymbol": [item.priceLocale objectForKey:NSLocaleCurrencySymbol],
                @"currencyCode": [item.priceLocale objectForKey:NSLocaleCurrencyCode],
                @"priceString": item.priceString,
                @"countryCode": [item.priceLocale objectForKey: NSLocaleCountryCode],
                @"downloadable": item.isDownloadable ? @"true" : @"false" ,
                @"description": item.localizedDescription ? item.localizedDescription : @"",
                @"title": item.localizedTitle ? item.localizedTitle : @"",
            };
            [productsArrayForJS addObject:product];
        }
        callback(@[[NSNull null], productsArrayForJS]);
        [_callbacks removeObjectForKey:key];
    } else {
#if RCT_DEV
        RCTLogWarn(@"No callback registered for load product request.");
#endif
    }
}

// SKProductsRequestDelegate network error
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    NSString *key = RCTKeyForInstance(request);
    RCTResponseSenderBlock callback = _callbacks[key];
    if(callback) {
        callback(@[RCTJSErrorFromNSError(error)]);
        [_callbacks removeObjectForKey:key];
    }
}

- (NSDictionary *)getPurchaseData:(SKPaymentTransaction *)transaction {
    NSMutableDictionary *purchase = [NSMutableDictionary dictionaryWithDictionary: @{
        @"transactionDate": @(transaction.transactionDate.timeIntervalSince1970 * 1000),
        @"transactionIdentifier": transaction.transactionIdentifier,
        @"productIdentifier": transaction.payment.productIdentifier,
        @"transactionReceipt": [self grandUnifiedReceipt]
    }];
    // originalTransaction is available for restore purchase and purchase of cancelled/expired subscriptions
    SKPaymentTransaction *originalTransaction = transaction.originalTransaction;
    if (originalTransaction) {
        purchase[@"originalTransactionDate"] = @(originalTransaction.transactionDate.timeIntervalSince1970 * 1000);
        purchase[@"originalTransactionIdentifier"] = originalTransaction.transactionIdentifier;
#if RCT_DEV
                RCTLogWarn(@"getPurchaseData for originalTransaction.");
#endif
    }

    return purchase;
}

- (void)dealloc
{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
#if RCT_DEV
        RCTLogWarn(@"======remove observer dealloc======");
#endif
}

#pragma mark Private

static NSString *RCTKeyForInstance(id instance)
{
    return [NSString stringWithFormat:@"%p", instance];
}

@end
