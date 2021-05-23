//
//  ViewController.h
//  kDFUApp
//
//  Created by tihmstar on 13.09.15.
//  Copyright (c) 2015 tihmstar. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController
@property (weak, nonatomic) IBOutlet UISwitch *switchFindBundle;
@property (weak, nonatomic) IBOutlet UISwitch *switchDownloadiBSS;
@property (weak, nonatomic) IBOutlet UISwitch *switchFindiBSS;
@property (weak, nonatomic) IBOutlet UISwitch *switchPwniBSS;

@property (weak, nonatomic) IBOutlet UILabel *statusLabel;

@property (weak, nonatomic) IBOutlet UIButton *buttonEnterkDFU;

@property (weak, nonatomic) IBOutlet UILabel *labelFindBundle;
@property (weak, nonatomic) IBOutlet UILabel *labelDownloadiBSS;
@property (weak, nonatomic) IBOutlet UILabel *labelFindiBSS;
@property (weak, nonatomic) IBOutlet UILabel *labelPwniBSS;

- (IBAction)enterkDFUPressed:(id)sender;

@end

