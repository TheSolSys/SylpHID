//
// FPImageView.h
// "Xbox HID"
//
// Created by Paige Marie DePol <pmd@fizzypopstudios.com>
// Copyright (c)2015 FizzyPop Studios. All Rights Reserved.
// http://xboxhid.fizzypopstudios.com
//
// =========================================================================================================================
// This file is part of the Xbox HID Driver, Daemon, and Preference Pane software (known as "Xbox HID").
//
// "Xbox HID" is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
//
// "Xbox HID" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
// of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along with "Xbox HID";
// if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
// =========================================================================================================================

#import "FPImageView.h"


@implementation FPImageView

- (id) initWithCoder: (NSCoder*)coder
{
	self = [super initWithCoder: coder];
	if (self != nil) {
		_round = [[NSBezierPath bezierPath] retain];
		[_round appendBezierPathWithRoundedRect: [self bounds] xRadius: 7.5 yRadius: 7.5];

		_hover = NO;
        [self addTrackingArea: [[NSTrackingArea alloc] initWithRect: [self bounds]
															options: (NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways)
															  owner: self
														   userInfo: nil]];
	}

	return self;
}


- (void) dealloc
{
	[_round release];

	if (_text != nil)
		[_text release];

	[super dealloc];
}


- (void) resetImage
{
	_hover = NO;
}


- (void) setTooltip: (NSString*)tooltip withTipControl: (NSTextField*)text andBaseControl: (NSTextField*)base
{
	if (_tooltip != nil)
		[_tooltip release];
	_tooltip = [tooltip retain];

	_text = text;
	_base = base;
}


- (void) mouseDown: (NSEvent*)event
{
	// mouseDown must be implemented for mouseUp to be called!
    // http://www.cocoabuilder.com/archive/cocoa/115981-nsimageview-subclass-and-mouseup.html
    if (event.type != NSLeftMouseDown)
        [super mouseDown: event];		// we only want to trap left mouse buttton clicks
}


- (void) mouseUp: (NSEvent*)event
{
    if (event.type == NSLeftMouseUp) {
        NSPoint mouse = [self convertPoint: [event locationInWindow] fromView: nil];
        if ([self isEnabled] && NSPointInRect(mouse, self.bounds)) {
            [NSApp sendAction: self.action to: self.target from: self];
			_hover = NO;
			[_text performSelector: @selector(setStringValue:) withObject: @"" afterDelay: 0.5];
			[_base performSelector: @selector(setHidden:) withObject: NO afterDelay: 0.5];
		}
    } else
        [super mouseUp: event];
}


- (void) mouseEntered: (NSEvent*)event
{
	_hover = YES;

	[_text setStringValue: _tooltip];
	[_base setHidden: YES];
	[NSApplication cancelPreviousPerformRequestsWithTarget: _base];

	[self setNeedsDisplay];
}


- (void) mouseExited: (NSEvent*)event
{
	_hover = NO;

	[_text setStringValue: @""];
	[_base performSelector: @selector(setHidden:) withObject: NO afterDelay: 0.125
				   inModes: [NSArray arrayWithObject: NSModalPanelRunLoopMode]];

	[self setNeedsDisplay];
}


- (BOOL) isOpaque
{
	return YES;
}


- (void) drawRect: (NSRect)dirty
{
	[[NSColor windowBackgroundColor] set];
	NSRectFill(dirty);

	if (_hover && [self isEnabled]) {
		[[NSColor alternateSelectedControlColor] set];
		[_round fill];
	}

	[[self cell] setBackgroundStyle: (_hover && [self isEnabled]) ? NSBackgroundStyleDark : NSBackgroundStyleLight];
    [super drawRect: dirty];
}

@end
