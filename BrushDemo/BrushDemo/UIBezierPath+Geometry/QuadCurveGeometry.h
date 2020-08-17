//
//  QuadCurveGeometry.h
//  BrushDemo
//
//  Created by ming on 2018/5/7.
//  Copyright © 2018年 ming. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

CGFloat QuadCurveGetLength(CGPoint p1, CGPoint p2, CGPoint p3);
BOOL QuadCurveIsLinear(CGPoint p1, CGPoint p2, CGPoint p3);
CGPoint QuadCurveGetPointAtParameter(CGPoint p1, CGPoint p2, CGPoint p3, double u);
CGFloat QuadCurveParameterForLength(CGPoint p1, CGPoint p2, CGPoint p3, CGFloat length);
void QuadCurveGetSubdivisionAtParameter(CGPoint p1, CGPoint p2, CGPoint p3, double u, BOOL first, CGPoint *sdp1, CGPoint *sdp2, CGPoint *sdp3);
CGFloat QuadCurveTerm1(CGFloat u);
CGFloat QuadCurveTerm2(CGFloat u);
CGFloat QuadCurveTerm3(CGFloat u);
