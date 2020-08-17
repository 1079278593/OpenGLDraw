//
//  OpenGLViewController.m
//  BrushDraw
//
//  Created by lyy on 2017/8/10.
//  Copyright © 2017年 LVY. All rights reserved.
//

#import "OpenGLViewController.h"
#import "PenEffectView.h"
@interface OpenGLViewController ()
@property (nonatomic, strong) PenEffectView *penView;

@end

@implementation OpenGLViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    PenEffectView *penView  = [[PenEffectView alloc]initWithFrame:self.view.bounds];
    penView.strokeColor = [UIColor redColor];
    self.penView = penView;
    [self.view addSubview:penView];

    UIBarButtonItem *rightBtn = [[UIBarButtonItem alloc] initWithTitle:@"截图" style:UIBarButtonItemStyleDone target:self action:@selector(test)];
    self.navigationItem.rightBarButtonItem = rightBtn;

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.backgroundColor = [UIColor blueColor];
    btn.frame = CGRectMake(100, 100, 40, 30);
    [self.view addSubview:btn];
    [btn addTarget:self action:@selector(test) forControlEvents:UIControlEventTouchUpInside];
}

- (void)test {
    self.penView.strokeColor = [UIColor blueColor];
}


@end
