//
//  WiFiSSIDHelper.m
//  WiFi Check (tvOS)
//
//  Uses pure ObjC runtime (NSClassFromString + objc_msgSend) to call
//  NEHotspotNetwork.fetchCurrentWithCompletionHandler: at runtime, bypassing
//  the compile-time API_UNAVAILABLE(tvos) restriction in the SDK headers.
//  The class and method exist in the tvOS runtime when the wifi-info entitlement
//  and CoreLocation authorization are granted.

#import "WiFiSSIDHelper.h"
#import <objc/message.h>

@implementation WiFiSSIDHelper

+ (void)fetchCurrentSSIDWithCompletion:(void (^)(NSString * _Nullable ssid,
                                                  NSString * _Nullable bssid))completion {
    Class networkClass = NSClassFromString(@"NEHotspotNetwork");
    if (!networkClass) {
        completion(nil, nil);
        return;
    }

    SEL sel = NSSelectorFromString(@"fetchCurrentWithCompletionHandler:");
    if (![networkClass respondsToSelector:sel]) {
        completion(nil, nil);
        return;
    }

    // Cast objc_msgSend to the correct function signature to avoid strict-cast warnings.
    // This calls [NEHotspotNetwork fetchCurrentWithCompletionHandler:^(id network) { ... }]
    // entirely through the ObjC runtime — no compile-time availability check applies.
    typedef void (*FetchCurrentIMP)(id, SEL, void (^)(id));
    FetchCurrentIMP imp = (FetchCurrentIMP)objc_msgSend;

    imp((id)networkClass, sel, ^(id network) {
        NSString *ssid = nil;
        NSString *bssid = nil;
        if (network) {
            ssid  = [network valueForKey:@"SSID"];
            bssid = [network valueForKey:@"BSSID"];
        }
        completion(ssid, bssid);
    });
}

@end
