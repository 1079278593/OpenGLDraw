//
//  LineGeometry.h
//  BrushDemo
//
//  Created by ming on 2018/5/7.
//  Copyright © 2018年 ming. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

CGPoint LineGetMidPoint(CGPoint p1, CGPoint p2);
CGFloat LineGetLength(CGPoint p1, CGPoint p2);
CGPoint LineGetPointAtParameter(CGPoint p1, CGPoint p2, double u);
CGPoint LineGetPointAtMid(CGPoint p1, CGPoint p2);

CGPoint GetTwoLineIntersection(CGPoint p1, CGPoint p2,CGPoint p3, CGPoint p4);
BOOL IsPointOnSegment(CGPoint p,CGPoint p1,CGPoint p2);


CGPoint rotatePoint(CGPoint point, CGPoint anchorPoint, CGFloat angle);
