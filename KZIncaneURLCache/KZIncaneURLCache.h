//
//  KZIncaneURLCache.h
//
//  Created by Kael Zhang on 5/31/16.
//  Copyright © 2016 kael.me. All rights reserved.
//

#ifndef KZIncaneURLCache_h
#define KZIncaneURLCache_h


#endif /* KZIncaneURLCache_h */

@interface KZIncaneURLCache : NSURLProtocol

+ (void)proxyWebView:(UIWebView *)webview withDomainWhitelist:(nullable NSArray *)whitelist;

@end