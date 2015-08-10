//
// FPImageView.h
// "SylpHID"
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

#import "FPAlertView.h"


@implementation FPAlertView

- (id) initWithCoder: (NSCoder*)coder
{
	self = [super initWithCoder: coder];
	if (self != nil) {
		_hover = NO;
        _track = [[NSTrackingArea alloc] initWithRect: [self bounds]
											  options: (NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow)
											    owner: self
											 userInfo: nil];
		[self addTrackingArea: _track];
	}

	return self;
}


- (void) setAlertView: (NSView*)view
{
	// copy the view by archiving and unarchiving it
	_view = [NSKeyedUnarchiver unarchiveObjectWithData: [NSKeyedArchiver archivedDataWithRootObject: view]];
}


- (NSPoint) pointInWindow: (NSPoint)buttonPoint
{
	NSView* parent = [self superview];
	while (parent != nil) {
		buttonPoint.x += [parent frame].origin.x;
		buttonPoint.y += [parent frame].origin.y;
		parent = [parent superview];
	}
	return buttonPoint;
}


- (void) createAlertWindow
{
	if (_popup == nil) {
		NSPoint buttonPoint = NSMakePoint(NSMidX([self frame]), NSMidY([self frame]));

		_popup = [[MAAttachedWindow alloc] initWithView: _view
										attachedToPoint: [self pointInWindow: buttonPoint]
											   inWindow: [self window]
												 onSide: MAPositionTop
											 atDistance: 4];

		[_popup setBorderColor: [NSColor windowFrameColor]];
		[_popup setBackgroundColor: [NSColor controlColor]];
		[_popup setViewMargin: 0.0];
		[_popup setBorderWidth: 0.0];
		[_popup setHasArrow: NSOnState];
		[_popup setArrowBaseWidth: 17];
		[_popup setArrowHeight: 12];
	}
}


- (void) fadeInAlertWindow
{
	[self createAlertWindow];
	[_popup setAlphaValue: 0.0];
	[[self window] addChildWindow: _popup ordered: NSWindowAbove];
	[[_popup animator] setAlphaValue: 1.0];
}


- (void) fadeOutAlertWindow
{
	[[self window] removeChildWindow: _popup];
	[_popup orderOut: nil];
	_popup = nil;
	_hover = NO;
}


- (void) mouseEntered: (NSEvent*)event
{
	if (_hover == NO) {
		_hover = YES;
		[self fadeInAlertWindow];
	}
}


- (void) mouseExited: (NSEvent*)event
{
	if (_hover == YES) {
		NSTimeInterval delay = [[NSAnimationContext currentContext] duration] + 0.1;
		[self performSelector: @selector(fadeOutAlertWindow) withObject: nil afterDelay: delay];
		[[_popup animator] setAlphaValue: 0.0];
	}
}


- (BOOL) isOpaque
{
	return NO;
}

@end
