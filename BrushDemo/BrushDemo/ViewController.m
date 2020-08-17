//
//  ViewController.m
//  BrushDemo
//
//  Created by ming on 2018/5/7.
//  Copyright © 2018年 ming. All rights reserved.
//

#import "ViewController.h"
#import "DrawView.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *blackBtn;

@end

@implementation ViewController

#define kPaletteHeight            30
#define kPaletteSize            5
#define kMinEraseInterval        0.5

#define kBrightness             1.0
#define kSaturation             0.45

- (void)viewDidLoad {
    [super viewDidLoad];
}
- (IBAction)qingpingClick:(id)sender {
    DrawView *paitingView = (DrawView *)self.view;
    [paitingView erase];
}

- (IBAction)maoshuaClick:(id)sender {
    DrawView *paitingView = (DrawView *)self.view;
    [paitingView changeBrushTexture:@"brush_fang_64"];
    
}
- (IBAction)mohuClick:(id)sender {
    DrawView *paitingView = (DrawView *)self.view;
    [paitingView changeBrushTexture:@"brush_20"];
}
- (IBAction)makebiClick:(id)sender {
    DrawView *paitingView = (DrawView *)self.view;
    [paitingView changeBrushTexture:@"brush"];
}
- (IBAction)penqianClick:(id)sender {
    DrawView *paitingView = (DrawView *)self.view;
    [paitingView changeBrushTexture:@"circle"];//brush_69_64
}


- (IBAction)blackClick:(id)sender {
    [self setBrushColor:[UIColor blackColor]];
}

- (IBAction)blueClick:(id)sender {
    [self setBrushColor:[UIColor blueColor]];
    
}
- (IBAction)greenClick:(id)sender {
    [self setBrushColor:[UIColor greenColor]];
    self.blackBtn.transform = CGAffineTransformRotate(self.blackBtn.transform, M_PI/10);
}

- (IBAction)redClick:(id)sender {
    [self setBrushColor:[UIColor redColor]];
}
- (IBAction)sliderValueChange:(UISlider *)sender {
    DrawView *paitingView = (DrawView *)self.view;
    [paitingView changeDrawWidth:sender.value];
}

- (void)setBrushColor:(UIColor *)color{    
    DrawView *paitingView = (DrawView *)self.view;
    [paitingView setBrushColor:color];
}

@end
