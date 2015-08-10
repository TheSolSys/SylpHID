//
//  SplashGradientText.h
//  Explorer
//
//  Created by Paige DePol on 1/19/14.
//  Copyright (c) 2014 FizzyPop Studios. All rights reserved.
//


@interface FPInsetText : NSTextField {
	NSBezierPath* _path;
	NSShadow* _shadow;
	NSColor* _colorText;
	NSColor* _colorShadow;
	NSNumber* _kerning;
}

- (NSColor*) textColor;
- (void) setTextColor: (NSColor*)color;

- (NSColor*) shadowColor;
- (void) setShadowColor: (NSColor*)color;

- (NSNumber*) kerning;
- (void) setKerning: (NSNumber*)kern;

@end
