//
//  KZCache.m
//
//  Created by Kael Zhang on 5/29/16.
//  Copyright © 2016 kael.me. All rights reserved.
//


#import "KZCache.h"

@interface AutoPurgeCache : NSCache
@end

@implementation AutoPurgeCache

- (id)init {
    if (!(self = [super init])) {
        return self;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(removeAllObjects)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidReceiveMemoryWarningNotification
                                                  object:nil];
}

@end


static const NSInteger kDefaultCacheMaxCacheAge = 60 * 60 * 24 * 7;


@implementation KZCache {
    NSFileManager *_fileManager;
}

+ (KZCache *)sharedCache {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self init];
    });
    return instance;
}

- (id)init {
    if (!(self = [super init])) {
        return self;
    }
    
    _fileManager = [NSFileManager defaultManager];
    _cache = [[AutoPurgeCache alloc] init];
    _queue = dispatch_queue_create("me.kael.KZInsanceURLCache", DISPATCH_QUEUE_SERIAL);
    
    dispatch_sync(_queue, ^{
        _fileManager = [NSFileManager defaultManager];
    });

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSUInteger)memoryCountLimit {
    return _cache.countLimit;
}

- (NSUInteger)memoryTotalCostLimit {
    return _cache.totalCostLimit;
}

- (void)setMemoryCountLimit:(NSUInteger)limit {
    _cache.countLimit = limit;
}

- (void)setMemoryTotalCostLimit:(NSUInteger)limit {
    _cache.totalCostLimit = limit;
}

- (void)cleanMemoryCache {
    [_cache removeAllObjects];
}

- (void)cleanDiskCache {
    [self cleanDiskCacheWithCompletion:nil];
}

- (void)cleanDiskCacheWithCompletion:(KZIncaneURLCacheNoParamsBlock)completion {
    dispatch_async(_queue, ^{
        [_fileManager removeItemAtPath:_customDiskCachePath error:nil];
        [_fileManager createDirectoryAtPath:_customDiskCachePath
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:NULL];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion();
        });
    });
}

- (void)diskCacheSizeWithCompletion:(KZIncaneURLCacheSizeBlock)completion {
    if (!completion) {
        return;
    }
    
    NSURL *diskCacheURL = [NSURL fileURLWithPath:_customDiskCachePath isDirectory:YES];
    
    dispatch_async(_queue, ^{
        NSUInteger fileCount = 0;
        NSUInteger totalSize = 0;
        NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:@[NSFileSize]
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];
        
        for (NSURL *fileURL in fileEnumerator) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += [fileSize unsignedIntegerValue];
            fileCount += 1;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(totalSize, fileCount);
        });
    });
}

- (NSData *)retrieveFromMemoryByKey:(NSString *)key {
    return [_cache objectForKey:key];
}

- (void)retrieveFromDiskByKey:(NSString *)key
               withCompletion:(KZIncaneURLCacheDataBlock)completion{
    dispatch_async(_queue, ^{
        NSString *path = [self cachePathForKey:key];
        NSString *defaultPath = [self cachePathForKey:key isDefault:YES];
        NSData *data = nil;

        if ([_fileManager fileExistsAtPath:path]) {
            data = [NSData dataWithContentsOfFile:path];

        } else if ([_fileManager fileExistsAtPath:defaultPath]) {
            data = [NSData dataWithContentsOfFile:defaultPath];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(data);
        });
    });
}

- (void)store:(NSData *)data forKey:(NSString *)key {
    [self store:data forKey:key toDisk:YES];
}

- (void)store:(NSData *)data forKey:(NSString *)key toDisk:(BOOL)toDisk {
    [_cache setObject:data forKey:key];
    
    if (!toDisk) {
        return;
    }
    
    dispatch_async(_queue, ^{
        NSString *path = [self cachePathForKey:key];
        if (![_fileManager fileExistsAtPath:path]) {
            [data writeToFile:path atomically:YES];
        }
    });
}

- (void)removeForKey:(NSString *)key {
    [self removeForKey:key withCompletion:nil];
}

- (void)removeForKey:(NSString *)key
      withCompletion:(KZIncaneURLCacheNoParamsBlock)completion {
    [self removeForKey:key fromDisk:YES withCompletion:completion];
}

- (void)removeForKey:(NSString *)key fromDisk:(BOOL)fromDisk {
    [self removeForKey:key fromDisk:fromDisk withCompletion:nil];
}

- (void)removeForKey:(NSString *)key
            fromDisk:(BOOL)fromDisk
      withCompletion:(KZIncaneURLCacheNoParamsBlock)completion {
    if (key == nil) {
        return;
    }

    [_cache removeObjectForKey:key];

    if (fromDisk) {
        dispatch_async(_queue, ^{
            [_fileManager removeItemAtPath:[self cachePathForKey:key] error:nil];
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion();
                });
            }
        });
        return;
    }

    if (completion){
        completion();
    }
}

- (NSString *)cachePathForKey:(NSString *)key {
    return [self cachePathForKey:key isDefault:NO];
}

- (NSString *)cachePathForKey:(NSString *)key isDefault:(BOOL)isDefault {
    NSString *path = isDefault
    ? _defaultDiskCachePath
    : _customDiskCachePath;
    return [NSString stringWithFormat:@"%@/%@", path, key];
}

// Gets the cache key, ie filename
- (NSString *)cacheKeyFromRequest:(NSURLRequest *)request {
    NSString *urlString = [[request URL].resourceSpecifier stringByRemovingPercentEncoding];
    urlString = [urlString substringFromIndex:2];
    return [urlString stringByReplacingOccurrencesOfString:@"/" withString:@"~"];
}

@end
