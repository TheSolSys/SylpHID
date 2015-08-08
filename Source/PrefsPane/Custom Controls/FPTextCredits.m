//
// FPTextCredits.m
// "SylpHID"
//
// Created by Paige Marie DePol <pmd@fizzypopstudios.com>
// Copyright (c)2015 FizzyPop Studios. All Rights Reserved.
// http://xboxhid.fizzypopstudios.com
//
// =========================================================================================================================
// This file is part of the SylpHID Driver, Daemon, and Preference Pane software (collectively known as "SylpHID").
//
// "SylpHID" is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
//
// "SylpHID" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
// of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along with "SylpHID";
// if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
// =========================================================================================================================

#import "FPTextCredits.h"


@implementation FPTextCredits

- (id) initWithCoder: (NSCoder*)coder
{
	self = [super initWithCoder: coder];
	if (self != nil) {
		CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
        CGFloat colors[] = { 0.925f, 0.925f, 0.925f, 1.0f,
							 0.925f, 0.925f, 0.925f, 0.0f };
        _gradient = CGGradientCreateWithColorComponents(rgb, colors, NULL, sizeof(colors) / (sizeof(colors[0]) * 4));
        CGColorSpaceRelease(rgb);
    }

    return self;
}


- (void) dealloc
{
	CGGradientRelease(_gradient);
}


- (void) drawRect:(CGRect)rect {
    [super drawRect:rect];

	CGPoint start, end;
    CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
	NSRect visible = [[self enclosingScrollView] documentVisibleRect];

	start = visible.origin;
    end = CGPointMake(start.x, start.y + 12.5);
    CGContextDrawLinearGradient(context, _gradient, start, end, 0);

	start = CGPointMake(start.x, visible.origin.y + visible.size.height - 12.5);
    end = CGPointMake(start.x, visible.origin.y + visible.size.height);
    CGContextDrawLinearGradient(context, _gradient, end, start, 0);
}
@end
