//
//  kDFUUtil.m
//  kDFUApp
//
//  Created by tihmstar on 15.09.15.
//  Copyright (c) 2015 tihmstar. All rights reserved.
//

#import "kDFUUtil.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#import "libfragmentzip.h"
#include <xpwn/libxpwn.h>
#include <xpwn/pwnutil.h>
#include <xpwn/nor_files.h>


//#define DOCUMENTS_DIRECTORY [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
//#define iBSS_ORIG_PATH [[DOCUMENTS_DIRECTORY stringByAppendingString:@"/iBSS.orig"] UTF8String]
//#define iBSS_DEC_PATH [[DOCUMENTS_DIRECTORY stringByAppendingString:@"/iBSS.dec"] UTF8String]
#define iBSS_ORIG_PATH "/tmp/iBSS.orig"
#define iBSS_DEC_PATH "/tmp/iBSS.dec"

@implementation kDFUUtil


+(NSString*)getFirmwareBundlePath{
    
    //get modelIdentifier
    char *propertyName = "hw.machine";
    size_t size;
    sysctlbyname(propertyName, NULL, &size, NULL, 0);
    char *model = malloc(size);
    sysctlbyname(propertyName, model, &size, NULL, 0);
    NSString *modelIdentifier = [NSString stringWithCString:model encoding:NSUTF8StringEncoding];
    free(model);
    
    //find bundle
    NSString *bundledir = [[NSBundle mainBundle] bundlePath];
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:bundledir error:nil];
    
    
    for (NSString *file in contents) {
        if ([file hasPrefix:[@"Down_" stringByAppendingString:modelIdentifier]]) {
            return [[bundledir stringByAppendingString:@"/"] stringByAppendingString:file];
        }
    }
    return nil;
}

typedef void (*partialzip_progress_callback_t)(partialzip_t* info, partialzip_file_t* file, size_t progress);

void download_callback(partialzip_t* info, partialzip_file_t* file, size_t progress){
    printf("progress=%zu\n",progress);
    
    
    
}

+(NSString*)downloadiBSSFromBundleWithPath:(NSString*)bundlePath giveError:(NSError**)error{
    NSString *downloadPath = [NSString stringWithCString:iBSS_ORIG_PATH encoding:NSUTF8StringEncoding];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:downloadPath])  [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:nil];
    
    if (!bundlePath){
        *error = [NSError errorWithDomain:@"[Error] no bundlePath given" code:-1 userInfo:nil];
        NSLog(@"[Error] no bundlePath given");
        return nil;
    }
    NSDictionary *info = [[NSDictionary alloc] initWithContentsOfFile:[bundlePath stringByAppendingString:@"/Info.plist"]];
    NSString *firmwareUrl = [info valueForKey:@"DownloadUrl"];
    if (!firmwareUrl){
        *error = [NSError errorWithDomain:@"[Error] no DownloadUrl in Bundle" code:-1 userInfo:nil];
        NSLog(@"[Error] no DownloadUrl in Bundle");
        return nil;
    }
    
    
    NSString *ibssfile = [[[info valueForKey:@"FirmwarePatches"] valueForKey:@"iBSS"] valueForKey:@"File"];
    
    partialzip_t* pzo = partialzip_open([firmwareUrl UTF8String]);
    if (!pzo){
        *error = [NSError errorWithDomain:[@"[Error] could not open " stringByAppendingString:firmwareUrl] code:-1 userInfo:nil];
        NSLog(@"[Error] could not open %@",firmwareUrl);
        return nil;
    }
    partialzip_file_t* file = partialzip_find_file(pzo, [ibssfile UTF8String]);
    if (!file){
        *error = [NSError errorWithDomain:[NSString stringWithFormat:@"[Error] could not find %@ in ipsw", ibssfile] code:-1 userInfo:nil];
        NSLog(@"[Error] could not find %@ in ipsw",ibssfile);
        return nil;
    }
    
    partialzip_progress_callback_t callback = &download_callback;
    
    
    int fail = partialzip_download_file([firmwareUrl UTF8String], [ibssfile UTF8String], [downloadPath UTF8String], callback);
    if (fail) {
        *error = [NSError errorWithDomain:@"[Error] download failed" code:-1 userInfo:nil];
        NSLog(@"[Error] download failed");
        return nil;
    }
    
    return downloadPath;
}

+(BOOL)decryptFileWithBundlePath:(NSString*)bundlePath andIBSSPath:(NSString*)iBSSPath giveError:(NSError**)error{
#define DEFAULT_BUFFER_SIZE (1 * 1024 * 1024)
    int argc = 0;
    char argv[1];
    NSString *errordesc = nil;
    

    if (errordesc) {
myexit:
        *error = [NSError errorWithDomain:errordesc code:-1 userInfo:nil];
        NSLog(@"%@",errordesc);
        return FALSE;
    }
    
    init_libxpwn(&argc, (char**)&argv);
    
    unsigned int *key;
    unsigned int *iv;
    char* inData;
    size_t inDataSize;
    
    NSDictionary *info = [[NSDictionary alloc] initWithContentsOfFile:[bundlePath stringByAppendingString:@"/Info.plist"]];
    NSDictionary *ibssfile = [[info valueForKey:@"FirmwarePatches"] valueForKey:@"iBSS"];
    
    NSString *keyValue = [ibssfile valueForKey:@"Key"];
    NSString *ivValue = [ibssfile valueForKey:@"IV"];
    if (!keyValue || ! ivValue) {
        errordesc = @"Error, can't decrypt iBSS. No keys found!";
        goto myexit;
    }
 
    size_t bytes;
    hexToInts([ivValue UTF8String], (unsigned int **)&iv, &bytes);
    hexToInts([keyValue UTF8String], (unsigned int **)&key, &bytes);
    
    
    AbstractFile* inFile = openAbstractFile2(createAbstractFileFromFile(fopen([iBSSPath UTF8String], "rb")), key, iv);
    AbstractFile* outFile = createAbstractFileFromFile(fopen(iBSS_DEC_PATH, "wb"));
    free(iv);
    free(key);
    inDataSize = (size_t) inFile->getLength(inFile);
    inData = (char*) malloc(inDataSize);
    inFile->read(inFile, inData, inDataSize);
    
    BOOL success = FALSE;
    for (char *ptr = inData; ptr< inData+inDataSize; ptr++) {
        if (strncmp(ptr, "Apple Certification Authority", strlen("Apple Certification Authority")) == 0){
            success = TRUE;
            break;
        }
    }
    free(inData);

    if (!success){
        inFile->close(inFile);
        outFile->close(outFile);
        errordesc = @"[Error] decryption failed";
        goto myexit;
    }
    
    
    //patch
    NSString *patchfilePath = [NSString stringWithFormat:@"%@/%@",bundlePath,[ibssfile valueForKey:@"Patch"]];
    AbstractFile* patchFile = createAbstractFileFromFile(fopen([patchfilePath UTF8String], "rb"));
    
    inFile->seek(inFile,0);
    
    if(patch(inFile, outFile, patchFile) != 0) {
        free(inData);
        patchFile->close(patchFile);
        outFile->close(outFile);
        errordesc = @"[Error] patching failed";
        goto myexit;
    }

    NSLog(@"iBSS.dec ready in %s",iBSS_DEC_PATH);
    return TRUE;
}

+(NSString*)enterkDFUMode{
    char kl[] = "kloader ";
    
    size_t bufsize = strlen(iBSS_DEC_PATH) + strlen(kl) + 1;
    char *cmdbuf = malloc(bufsize);
    memset(cmdbuf, 0, bufsize);
    cmdbuf = strncat(cmdbuf, kl, strlen(kl));
    cmdbuf = strncat(cmdbuf, iBSS_DEC_PATH, strlen(iBSS_DEC_PATH));
    
    NSLog(@"entering kDFU mode");
    
    system(cmdbuf);
    
    return @"ERROR";
}

@end
