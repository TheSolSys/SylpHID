//
// NSBezierPath+String.m
// Class Extension
//
// Created by Paige Marie DePol <pmd@fizzypopstudios.com>
// Copyright (c)2015 FizzyPop Studios. All Rights Reserved.
// http://sylphid.fizzypopstudios.com
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

#import "NSBezierPath+String.h"


@implementation NSBezierPath (String)

+ (NSBezierPath*) bezierPathWithString: (NSString*)text inFont: (NSFont*)font
{
	NSBezierPath* path = [self bezierPath];
	[path appendBezierPathWithString: text inFont: font];
	return path;
}


- (void) appendBezierPathWithString: (NSString*)text inFont: (NSFont*)font
{
	[self appendBezierPathWithAttributedString: [[NSAttributedString alloc] initWithString: text
																		        attributes: @{ NSFontAttributeName : font }]];
}


- (void) appendBezierPathWithAttributedString: (NSAttributedString*)text
{
	if ([self isEmpty]) [self moveToPoint: NSZeroPoint];

	NSMutableAttributedString* string = [[NSMutableAttributedString alloc] initWithAttributedString: text];
	// Setting NSLigatureAttributeName to 0 ensures no ligatures (fi and fl) are used so all strings will render correctly
	[string addAttributes: @{ NSLigatureAttributeName : [NSNumber numberWithInt: 0] } range: NSMakeRange(0, text.length)];
	CGFloat kern = [[text attribute: NSKernAttributeName atIndex: 0 effectiveRange: nil] floatValue];
	NSFont* font = [text attribute: NSFontAttributeName atIndex: 0 effectiveRange: nil];
	CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)string);

	CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
	CFIndex count = CFArrayGetCount(glyphRuns);
        
	for (CFIndex index = 0; index < count; index++) {
		CTRunRef currentRun = CFArrayGetValueAtIndex(glyphRuns, index);
                
		CFIndex glyphCount = CTRunGetGlyphCount(currentRun);
                
		CGGlyph glyphs[glyphCount];
		CTRunGetGlyphs(currentRun, CTRunGetStringRange(currentRun), glyphs);

		for (CFIndex glyphIndex = 0; glyphIndex < glyphCount; glyphIndex++) {
			[self appendBezierPathWithGlyph: glyphs[glyphIndex] inFont: font];
			if (kern > 0 && glyphIndex < glyphCount - 1)
				[self relativeMoveToPoint: NSMakePoint(kern, 0)];
		}
	}
        
	CFRelease(line);
}


- (CGPathRef) bezierPathToCGPath
{
    CGMutablePathRef path = CGPathCreateMutable();
    NSPoint p[3];
    BOOL closed = NO;

    NSInteger elementCount = [self elementCount];
    for (NSInteger i = 0; i < elementCount; i++) {
        switch ([self elementAtIndex:i associatedPoints:p]) {
        case NSMoveToBezierPathElement:
            CGPathMoveToPoint(path, NULL, p[0].x, p[0].y);
            break;

        case NSLineToBezierPathElement:
            CGPathAddLineToPoint(path, NULL, p[0].x, p[0].y);
            closed = NO;
            break;

        case NSCurveToBezierPathElement:
            CGPathAddCurveToPoint(path, NULL, p[0].x, p[0].y, p[1].x, p[1].y, p[2].x, p[2].y);
            closed = NO;
            break;

        case NSClosePathBezierPathElement:
            CGPathCloseSubpath(path);
            closed = YES;
            break;
        }
    }

    if (!closed)  CGPathCloseSubpath(path);

    CGPathRef immutablePath = CGPathCreateCopy(path);
    CGPathRelease(path);
	return immutablePath;
}

@end
