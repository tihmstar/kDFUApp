//
//  kDFUUtil.h
//  kDFUApp
//
//  Created by tihmstar on 15.09.15.
//  Copyright (c) 2015 tihmstar. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface kDFUUtil : NSObject

+(NSString*)getFirmwareBundlePath;
+(NSString*)downloadiBSSFromBundleWithPath:(NSString*)bundlePath giveError:(NSError**)error;
+(BOOL)decryptFileWithBundlePath:(NSString*)bundlePath andIBSSPath:(NSString*)iBSSPath giveError:(NSError**)error;

+(NSString*)enterkDFUMode;

@end
