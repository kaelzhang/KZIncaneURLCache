//
//  KZIncaneURLCache.m
//
//  Created by Kael Zhang on 5/31/16.
//  Copyright © 2016 kael.me. All rights reserved.
//

@import Foundation;

#import "KZCache.h"


@interface TBSWebViewCacheProtocol()<NSURLConnectionDataDelegate>
@property (nonatomic, strong) NSURLConnection *connection;
@property (strong, nonatomic) NSMutableData *responseData;

@end
static NSString * const URLProtocolHandledKey = @"URLProtocolHandledKey";

@implementation TBSWebViewCacheProtocol
static NSString *cacheDirect = nil;
NSArray *supportExt = nil;

//替换请求的web文件为资源包里的相对应的文件
static NSDictionary *replaceRequestFileWithLocalFile = nil;

- (NSCache *)memoryCache {
    if (!_memoryCache) {
        // Init the memory cache
        _memoryCache = [[AppDelegate getAppDelegate] memoryCache];
    }
    return _memoryCache;
}
#pragma ---mark  memory cache

- (id)dataFromMemoryCacheForKey:(NSString *)key {
    id data = [self.memoryCache objectForKey:key];
    return data;
}
#pragma ---mark  memory cache  end

#pragma ---mark  defaultDisk cache
- (id)dataFromDefaultDiskCacheForPath:(NSString *)path {
    NSString *resourePath = [[NSBundle mainBundle] pathForResource:path ofType:nil];
    return [NSData dataWithContentsOfFile:resourePath];
}


#pragma ---mark  defaultDisk cache  end


+ (void)proxyWebview:(UIWebView *)webview {
    
}


+ (void)initialize
{
    supportExt = @[@"jpg", @"jpeg", @"png", @"gif", @"css", @"js",@"html",@"webp"];
}
+ (void)setCacheDirectPath:(NSString *)directPath
{
    @synchronized(cacheDirect)
    {
        cacheDirect = directPath;
    }
}
- (NSString *)getExtFromUrl:(NSString *)absoluteUrl
{
    NSString *pathString = absoluteUrl;
    NSString *ext = [pathString lastPathComponent];
    ext = [ext lowercaseString];
    NSRange rang = [ext rangeOfString:@"?"];
    if (rang.location != NSNotFound)
    {
        ext = [ext substringToIndex:rang.location];
    }
    rang = [ext rangeOfString:@"!"];
    if (rang.location != NSNotFound)
    {
        ext = [ext substringToIndex:rang.location];
    }
    ext = [ext pathExtension];
    return ext;
}
- (NSData *)dataForURL:(NSString *)url
{
    NSString *cacheDirect = [self webCacheDirectPath];
    NSString *ext = [self getExtFromUrl:url];
    ext = ext ? [NSString stringWithFormat:@".%@", ext] : nil;
    NSString *cachePath = [NSString stringWithFormat:@"%@/%@%@", cacheDirect, url, ext ? ext : @""];
    
    NSData *cacheData = [NSData dataWithContentsOfFile:cachePath];
    
#ifdef DEBUG
    NSLog(@"look for %@ local cache", url);
    if (cacheData)
    {
        NSLog(@"exist cachePath %@", cachePath);
    }
#endif
    return cacheData;
}

- (NSString *)webCacheDirectPath
{
    NSString *direct = nil;
    @synchronized(cacheDirect)
    {
        if (!cacheDirect)
        {
            cacheDirect = [NSString stringWithFormat:@"%@/Documents/%@/", NSHomeDirectory(), @"diskCachePath"];
        }
        direct = cacheDirect;
    }
    
    BOOL isDirect = NO;
    NSError *err = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:direct isDirectory:&isDirect] || !isDirect)
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:direct withIntermediateDirectories:NO attributes:nil error:&err];
    }
    
    if (err)
    {
        NSLog(@"创建webcache目录失败%@", err);
    }
    return direct;
}


- (NSString *)loadLocalWebSourcePathWithUrl:(NSString *)key
{
    if (replaceRequestFileWithLocalFile && [replaceRequestFileWithLocalFile count])
    {
        if ([replaceRequestFileWithLocalFile.allKeys containsObject:key])
        {
            NSString *localWebSourceFileName = replaceRequestFileWithLocalFile[key];
            NSString *path = [NSString stringWithFormat:@"%@/Documents/%@/%@", NSHomeDirectory(), @"diskCachePath", localWebSourceFileName];
            return path;
        }
    }
    return nil;
}

#pragma ---mark NSCacheProtocol method

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    //看看是否已经处理过了，防止无限循环
    if ([NSURLProtocol propertyForKey:URLProtocolHandledKey inRequest:request]) {
        return NO;
    }
    if ([TBRequestHeaderManager containWithWebviewDomainWhitelist:request]) {
        return YES;
    } else {
        return YES;
    }
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableRequest = [NSMutableURLRequest requestWithURL:request.URL];
    [[TBRequestHeaderManager shareManager] setDefaultHeader:mutableRequest webViewHeader:request.allHTTPHeaderFields];
    if ([request.URL.absoluteString isEqualToString:@"http://192.168.1.148:8080/cart"]) {
        NSLog(@"headers :%@",mutableRequest.allHTTPHeaderFields);
    }
    return mutableRequest;
}
+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b
{
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (void)startLoading {
    if ([TBRequestHeaderManager containWebviewCacheDomains:self.request.URL]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSString *strRequest = [[self.request URL].resourceSpecifier stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];//去掉http://
            strRequest = [strRequest substringFromIndex:2];
            NSString *pathString = [strRequest stringByReplacingOccurrencesOfString:@"/" withString:@"~"];
            NSString *ext = [self getExtFromUrl:pathString];
            
            NSData *data = nil;
            if ([self dataFromMemoryCacheForKey:pathString]) {
                data = [self dataFromMemoryCacheForKey:pathString];
            } else {
                if ([self hasDataForURL:pathString]) {//有缓存直接加载缓存
                    data = [self dataForURL:pathString];
                    [self.memoryCache setObject:data forKey:pathString];//diskCache 存在， memory cache 不存在  则加入memory cache中
                } else {
                    if ([self dataFromDefaultDiskCacheForPath:pathString]) {
                        data = [self dataFromDefaultDiskCacheForPath:pathString];
                        [self.memoryCache setObject:data forKey:pathString];//defaultDiskCache 存在,则加入memory cache中
                        
                    } else {
                        [self loadRequest];
                        return;
                    }
                    
                }
            }
            
            NSURLResponse *response = [[NSURLResponse alloc] initWithURL:[self.request URL]
                                                                MIMEType:ext
                                                   expectedContentLength:-1
                                                        textEncodingName:nil];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
                [[self client] URLProtocol:self didLoadData:data];
                [[self client] URLProtocolDidFinishLoading:self];
                [self stopLoading];
            });
            
        });
    } else {
        [self loadRequest];
    }
    
}
- (void)loadRequest {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableURLRequest *mutableReqeust = [[self request] mutableCopy];
        //打标签，防止无限循环
        [NSURLProtocol setProperty:@YES forKey:URLProtocolHandledKey inRequest:mutableReqeust];
        self.connection = [NSURLConnection connectionWithRequest:mutableReqeust delegate:self];
        self.responseData = [[NSMutableData alloc] init];
    });
    
}
- (void)stopLoading {
    [self.connection cancel];
    self.connection = nil;
    
}

#pragma mark - NSURLConnectionDelegate

- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
    [self.client URLProtocol:self didLoadData:data];
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection {
    if ([TBRequestHeaderManager containWebviewCacheDomains:self.request.URL]) {
        NSString *strRequest = [[self.request URL].resourceSpecifier stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];//去掉http://
        strRequest = [strRequest substringFromIndex:2];
        NSString *pathString = [strRequest stringByReplacingOccurrencesOfString:@"/" withString:@"~"];
        NSString *ext = [self getExtFromUrl:pathString];
        if ([self hasDataForURL:pathString])
        {
            return;
        }
        if (![supportExt containsObject:ext])
        {
            return;
        }
        
        [self storeData:self.responseData forURL:pathString];
    }
    [self.client URLProtocolDidFinishLoading:self];
    if ([self.request.URL.absoluteString isEqualToString:@"http://192.168.1.148:8080/cart"]) {
        NSLog(@"response message :%@",[self.responseData wp_objectFromJSONData][@"message"]);
    }
    
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
}

@end

