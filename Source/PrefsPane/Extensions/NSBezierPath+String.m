//
//  NSBezierPath+String.m
//  Explorer
//
//  Created by Paige DePol on 1/2/14.
//  Copyright (c) 2014 FizzyPop Studios. All rights reserved.
//

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
