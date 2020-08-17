//
//  UIBezierPath+Geometry.h
//  BrushDemo
//
//  Created by ming on 2018/5/7.
//  Copyright © 2018年 ming. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>



const static float LINE_WIDTH = 10.0f;


@interface UIBezierPath (Geometry)

- (CGFloat)length;
- (CGPoint)pointAtPercentOfLength:(CGFloat)percent;
- (UIBezierPath *)subpathFrom:(CGFloat)start to:(CGFloat)end;
- (void)newMaskPathFrame:(CGRect)frame;
@end
