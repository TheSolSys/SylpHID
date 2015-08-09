//
//  NSBezierPath+String.h
//  Explorer
//
//  Created by Paige DePol on 1/2/14.
//  Copyright (c) 2014 FizzyPop Studios. All rights reserved.
//


@interface NSBezierPath (String)

+ (NSBezierPath*) bezierPathWithString: (NSString*)text inFont: (NSFont*)font;

- (void) appendBezierPathWithString: (NSString*)text inFont: (NSFont*)font;
- (void) appendBezierPathWithAttributedString: (NSAttributedString*)text;

- (CGPathRef) bezierPathToCGPath;

@end
