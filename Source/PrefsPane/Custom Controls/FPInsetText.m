//
//  SplashGradientText.m
//  Explorer
//
//  Created by Paige DePol on 1/19/14.
//  Copyright (c) 2014 FizzyPop Studios. All rights reserved.
//

#import "NSBezierPath+String.h"

#import "FPInsetText.h"


@implementation FPInsetText

- (id) initWithCoder: (NSCoder*)coder
{
	self = [super initWithCoder: coder];
    if (self != nil) {
		_kerning = nil;
		_colorText = [NSColor colorWithCalibratedWhite: 0.65 alpha: 1.0];
		_colorShadow = [NSColor colorWithCalibratedWhite: 0.05 alpha: 1.0];
    }

    return self;
}


- (BOOL) isFlipped
{
	return NO;
}


- (NSColor*) textColor
{
	return _colorText;
}


- (void) setTextColor: (NSColor*)color
{
	_colorText = color;
	_path = nil;
}


- (NSColor*) shadowColor
{
	return _colorShadow;
}


- (void) setShadowColor: (NSColor*)color
{
	_colorShadow = color;
	_path = nil;
}


- (NSNumber*) kerning
{
	return _kerning;
}


- (void) setKerning: (NSNumber*)kern
{
	_kerning = kern;
	_path = nil;
}


- (void) setStringValue: (NSString*)string
{
	[super setStringValue: string];
	_path = nil;
}


- (void) makeStringPath
{
	NSMutableDictionary* attribs = [NSMutableDictionary dictionaryWithDictionary: [self.attributedStringValue attributesAtIndex: 0 effectiveRange: nil]];
	if (_kerning != nil) [attribs setObject: _kerning forKey: NSKernAttributeName];
	NSAttributedString* text = [[NSAttributedString alloc] initWithString: self.stringValue attributes: attribs];
	NSFont* font = [attribs objectForKey: NSFontAttributeName];

	NSRect rect = self.frame;
	NSSize size = [text size];
	CGFloat yoff = (self.isFlipped ? 0 : floor(rect.size.height - [font ascender]) - 1);
	CGFloat xoff = (self.alignment == NSCenterTextAlignment) ? floor((rect.size.width / 2.0) - (size.width / 2.0)) :
				   (self.alignment == NSRightTextAlignment)  ? floor(rect.size.width - size.width)
								   /* NSLeftTextAlignment */ : 0;

	_path = [NSBezierPath bezierPath];
	[_path moveToPoint: NSMakePoint(xoff, yoff)];
	[_path appendBezierPathWithAttributedString: text];
	[_path setLineWidth: 1.0];
	[_path setLineJoinStyle: NSBevelLineJoinStyle];

	_shadow = [[NSShadow alloc] init];
	[_shadow setShadowOffset: NSMakeSize(1.0, -1.5)];
	[_shadow setShadowColor: _colorShadow];
	[_shadow setShadowBlurRadius: 3.0];
}


- (void) fillPath: (NSBezierPath*)path withInnerShadow: (NSShadow*)shadow
{
	[NSGraphicsContext saveGraphicsState];
	
	NSSize offset = shadow.shadowOffset;
	NSSize originalOffset = offset;
	CGFloat radius = [shadow shadowBlurRadius];
	NSRect bounds = NSInsetRect(path.bounds, -(ABS(offset.width) + radius), -(ABS(offset.height) + radius));
	offset.height += bounds.size.height;
	shadow.shadowOffset = offset;
	NSAffineTransform *transform = [NSAffineTransform transform];
	if ([[NSGraphicsContext currentContext] isFlipped])
		[transform translateXBy:0 yBy:bounds.size.height];
	else
		[transform translateXBy:0 yBy:-bounds.size.height];
	
	NSBezierPath *drawingPath = [NSBezierPath bezierPathWithRect:bounds];
	[drawingPath setWindingRule:NSEvenOddWindingRule];
	[drawingPath appendBezierPath: path];
	[drawingPath transformUsingAffineTransform:transform];
	
	[path addClip];
	[shadow set];
	[[NSColor blackColor] set];
	[drawingPath fill];
	
	shadow.shadowOffset = originalOffset;
	
	[NSGraphicsContext restoreGraphicsState];
}


// [super drawRect:] is NOT called here as we do all the drawing
- (void) drawRect: (NSRect)rect
{
	if (_path == nil) [self makeStringPath];
	[_colorText set];
	[_path fill];
	[self fillPath: _path withInnerShadow: _shadow];
}

@end
