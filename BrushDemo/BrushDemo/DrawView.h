//
//  DrawView.h
//  BrushDemo
//
//  Created by ming on 2018/5/7.
//  Copyright © 2018年 ming. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DrawView : UIView
- (void)changeDrawWidth:(CGFloat)width;

- (void)setBrushColor:(UIColor *)newColor;

- (void)changeBrushTexture:(NSString *)imgName;

- (void)erase;

@end
