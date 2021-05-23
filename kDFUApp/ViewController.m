//
//  ViewController.m
//  kDFUApp
//
//  Created by tihmstar on 13.09.15.
//  Copyright (c) 2015 tihmstar. All rights reserved.
//

#import "ViewController.h"
#import "kDFUUtil.h"

#define ALTERNATIVE_IBSS_PATH @"/var/mobile/Media/iBSS"

@interface ViewController ()

@end

@implementation ViewController{
    NSArray *allSwitches;
    NSArray *allLabels;
    NSMutableArray *labelNames;
    
    NSString *bundlePath;
    NSString *iBSSPath;
    BOOL readyForKDFU;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    allSwitches = [NSArray arrayWithObjects:self.switchFindBundle,self.switchDownloadiBSS,self.switchFindiBSS,self.switchPwniBSS, nil];
    allLabels = [NSArray arrayWithObjects:self.labelFindBundle,self.labelDownloadiBSS,self.labelFindiBSS,self.labelPwniBSS, nil];
    labelNames = [NSMutableArray new];
    
    self.statusLabel.numberOfLines = 0;
    
    //prepare
    for (UISwitch *sw in allSwitches) {
        [sw addTarget:self action:@selector(didChangeSwitchvalue:) forControlEvents:UIControlEventValueChanged];
        sw.enabled = NO;
    }
    self.switchFindBundle.enabled = YES;
    for (UILabel *lb in allLabels) {
        [labelNames addObject:lb.text];
    }
    [labelNames addObject:self.statusLabel.text];
    
    
    if (!(setuid(0) == 0 && setgid(0) == 0)){
        NSLog(@"Can't get root");
        self.statusLabel.text = @"Error: can't get root";
        self.switchFindBundle.enabled = NO;
    }
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)didChangeSwitchvalue:(id)sender {
    UISwitch *sw = sender;
    
    if (!sw.on) {
        //reset text
        for (int i=0; i<[allSwitches count]; i++) {
            if ([[allSwitches objectAtIndex:i] isEqual:sw]) {
                [[allLabels objectAtIndex:i] setText:[labelNames objectAtIndex:i]];
                break;
            }
        }
        
        if ([sw isEqual:self.switchFindBundle]) {
            for (UISwitch *sw in allSwitches) {
                [sw addTarget:self action:@selector(didChangeSwitchvalue:) forControlEvents:UIControlEventValueChanged];
                sw.enabled = NO;
                sw.on = NO;
            }
            for (int i=0;i<[allLabels count]; i++) {
                [[allLabels objectAtIndex:i] setText:[labelNames objectAtIndex:i]];
            }
            self.switchFindBundle.enabled = YES;
            self.statusLabel.text = [labelNames lastObject];
        }else if ([sw isEqual:self.switchDownloadiBSS]) {
        
        }else if ([sw isEqual:self.switchFindiBSS]) {
            if (self.switchPwniBSS.on) [labelNames removeLastObject];
            self.statusLabel.text = [labelNames lastObject];
            [labelNames removeLastObject];
            self.switchPwniBSS.enabled = NO;
            self.switchPwniBSS.on = NO;
            
        }else if ([sw isEqual:self.switchPwniBSS]) {
            self.statusLabel.text = [labelNames lastObject];
            [labelNames removeLastObject];
        }
        
    }else{
        if ([sw isEqual:self.switchFindBundle]) {
            NSLog(@"Find bundle");
            
            if ((bundlePath = [kDFUUtil getFirmwareBundlePath])) {
                NSLog(@"Found bundle=%@",bundlePath);
                NSArray *split = [bundlePath componentsSeparatedByString:@"_"];
                self.labelFindBundle.text = [NSString stringWithFormat:@"Bundle: %@_%@",[split objectAtIndex:1],[split objectAtIndex:2]];
                self.switchDownloadiBSS.enabled = YES;
                self.switchFindiBSS.enabled = YES;
                self.statusLabel.text = [@"Find iBSS\ndownload or put in \n" stringByAppendingString:ALTERNATIVE_IBSS_PATH];
            }else{
                self.statusLabel.text = @"ERROR: No bundle for this device!";
                self.labelFindBundle.text = @"Error: No bundle for this device";
                self.switchFindBundle.on = NO;
            }
            
        }else if ([sw isEqual:self.switchDownloadiBSS]) {
            NSLog(@"Download iBSS");
            self.labelDownloadiBSS.text = @"Downloading iBSS...";
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
                NSError *myError;
                iBSSPath = [kDFUUtil downloadiBSSFromBundleWithPath:bundlePath giveError:&myError];
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    if (iBSSPath) {
                        self.labelDownloadiBSS.text = @"iBSS downloaded";
                        self.statusLabel.text = @"Find iBSS";
                    }else{
                        self.labelDownloadiBSS.text = @"Error: download failed";
                        self.statusLabel.text = myError.domain;
                        sw.on = NO;
                    }
                });
            });
            
        }else if ([sw isEqual:self.switchFindiBSS]) {
            NSLog(@"Find iBSS");
            
            if (!self.switchDownloadiBSS.on) iBSSPath = ALTERNATIVE_IBSS_PATH;
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:iBSSPath]) {
                self.labelFindiBSS.text = @"Found iBSS";
                [labelNames addObject:self.statusLabel.text];
                self.statusLabel.text = @"Pwn iBSS";
                self.switchPwniBSS.enabled = YES;
            }else{
                self.labelFindiBSS.text = @"Error: couldn't find iBSS";
                sw.on = NO;
            }
            
        }else if ([sw isEqual:self.switchPwniBSS]) {
            NSLog(@"Pwn iBSS");
            NSError *myError;
            if ([kDFUUtil decryptFileWithBundlePath:bundlePath andIBSSPath:iBSSPath giveError:&myError]) {
                [labelNames addObject:self.statusLabel.text];
                self.statusLabel.text = @"ready to enter kDFU mode";
                self.labelPwniBSS.text = @"Pwned iBSS successful";
                
                self.buttonEnterkDFU.backgroundColor = [UIColor greenColor];
                readyForKDFU = YES;
                
            }else{
                self.labelPwniBSS.text = @"Error: Pwn iBSS failed";
                self.statusLabel.text = myError.description;
                self.switchPwniBSS.on = NO;
            }
            
        }
    }
}

- (IBAction)enterkDFUPressed:(id)sender {
    if (readyForKDFU) {
        self.statusLabel.text = @"Entering kDFU mode, bye bye system";
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            sleep(1);
            dispatch_async(dispatch_get_main_queue(), ^(void){
                self.statusLabel.text = @"Entering kDFU mode, bye bye system.";
            });
            sleep(1);
            dispatch_async(dispatch_get_main_queue(), ^(void){
                self.statusLabel.text = @"Entering kDFU mode, bye bye system..";
            });
            sleep(1);
            dispatch_async(dispatch_get_main_queue(), ^(void){
                self.statusLabel.text = @"Entering kDFU mode, bye bye system...";
            });
            NSString *errormsg = [kDFUUtil enterkDFUMode];
            dispatch_async(dispatch_get_main_queue(), ^(void){
                self.statusLabel.text =  errormsg;
            });
        });
    }
}
@end
