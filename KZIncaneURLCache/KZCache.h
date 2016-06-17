//
//  KZCache.h
//
//  Created by Kael Zhang on 5/29/16.
//  Copyright © 2016 kael.me. All rights reserved.
//

@import Foundation;
@import UIKit;


typedef NS_ENUM(NSInteger, KZIncaneURLCacheType) {
    KZIncaneURLCacheNoneType,
    KZIncaneURLCacheMemory,
    KZIncaneURLCacheDisk
};


typedef void(^KZIncaneURLCacheNoParamsBlock)();
typedef void(^KZIncaneURLCacheSizeBlock)(NSUInteger size, NSUInteger count);
typedef void(^KZIncaneURLCacheDataBlock)(NSData *data);


@interface KZCache : NSObject

@property (strong, nonatomic) NSCache *cache;
@property (strong, nonatomic) NSString *defaultDiskCachePath;
@property (strong, nonatomic) NSString *customDiskCachePath;
@property (strong, nonatomic) dispatch_queue_t queue;

+ (KZCache *)sharedCache;

- (id)init;
- (void)dealloc;

- (NSUInteger)memoryCountLimit;
- (NSUInteger)memoryTotalCostLimit;
- (void)setMemoryCountLimit:(NSUInteger)limit;
- (void)setMemoryTotalCostLimit:(NSUInteger)limit;


// Removes all disk cache
- (void)cleanMemoryCache;

- (void)cleanDiskCache;
- (void)cleanDiskCacheWithCompletion:(KZIncaneURLCacheNoParamsBlock)completion;

- (void)diskCacheSizeWithCompletion:(KZIncaneURLCacheSizeBlock)completion;

// Gets cache by key
// It will first look up in-memory cache, then disk cache
- (NSData *)retrieveFromMemoryByKey:(NSString *)key;
- (void)retrieveFromDiskByKey:(NSString *)key
               withCompletion:(KZIncaneURLCacheDataBlock)completion;

- (void)store:(NSData *)data forKey:(NSString *)key;
- (void)store:(NSData *)data forKey:(NSString *)key toDisk:(BOOL)toDisk;

// remove from memory and disk
- (void)removeForKey:(NSString *)key;
- (void)removeForKey:(NSString *)key
      withCompletion:(KZIncaneURLCacheNoParamsBlock)completion;
- (void)removeForKey:(NSString *)key fromDisk:(BOOL)fromDisk;
- (void)removeForKey:(NSString *)key fromDisk:(BOOL)fromDisk
      withCompletion:(KZIncaneURLCacheNoParamsBlock) completion;

- (NSString *)cachePathForKey:(NSString *)key;
- (NSString *)cachePathForKey:(NSString *)key isDefault:(BOOL)isDefault;

// Assume that the url pathname does not contain tile symbol(`~`)
// '/app/a/*/a.js' -> '~app~a~*~a.js'
- (NSString *)cacheKeyFromRequest:(NSURLRequest *)request;

@end