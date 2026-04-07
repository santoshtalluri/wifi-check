//
//  WiFiSSIDHelper.h
//  WiFi Check (tvOS)
//
//  ObjC shim to call NEHotspotNetwork.fetchCurrent(), which is marked
//  API_UNAVAILABLE(tvos) in the Swift overlay but works at runtime on tvOS
//  when the wifi-info entitlement + CoreLocation authorization are present.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WiFiSSIDHelper : NSObject

+ (void)fetchCurrentSSIDWithCompletion:(void (^)(NSString * _Nullable ssid,
                                                  NSString * _Nullable bssid))completion;

@end

NS_ASSUME_NONNULL_END
