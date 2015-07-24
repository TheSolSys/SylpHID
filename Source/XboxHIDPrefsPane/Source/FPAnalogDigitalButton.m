//
// FPAnalogDigitalButton.m
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


#import "FPAnalogDigitalButton.h"

@implementation FPAnalogDigitalButton

- (id) initWithCoder: (NSCoder*)coder {
    self = [super initWithCoder:coder];
    if (self) {
	   NSBundle* bundle = [NSBundle bundleForClass: [self class]];
	   _analog = [[NSImage alloc] initWithContentsOfFile: [bundle pathForResource:@"toggleAnalog" ofType:@"png"]];
	   _digital = [[NSImage alloc] initWithContentsOfFile: [bundle pathForResource:@"toggleDigital" ofType:@"png"]];
	   _locked = false;
	   _isDigital = false;
	   _fromRect.origin = NSMakePoint(0, 0);
	   _fromRect.size = [_analog size];
    }
    return self;
}


- (void) dealloc {
    [super dealloc];
    [_analog release];
    [_digital release];
}


- (void) setLocked: (BOOL)locked
{
    _locked = locked;
    [self setNeedsDisplay];
}


- (BOOL) isLocked
{
    return _locked;
}


- (void) toggleMode
{
	_isDigital = !_isDigital;
}


- (BOOL) isDigital
{
	return (_isDigital == YES);
}


- (void) setIsDigital: (BOOL)mode
{
	_isDigital = mode;
    [self setNeedsDisplay];
}


- (BOOL) isAnalog
{
	return (_isDigital == NO);
}


- (void) drawRect: (NSRect)dirty {
    dirty = [self bounds];
    [self setEnabled: YES];
    [super drawRect:dirty];
    [self setEnabled: !_locked];

    dirty = NSInsetRect(dirty, 7, 7);
    dirty.origin.y -= 1;

    if (_isDigital)
	   [_digital drawInRect: dirty fromRect: _fromRect operation: NSCompositeSourceOver fraction: (_locked ? 0.5 : 0.75) respectFlipped: YES hints: NULL];
    else
	   [_analog drawInRect: dirty fromRect: _fromRect operation: NSCompositeSourceOver fraction: (_locked ? 0.5 : 0.75) respectFlipped: YES hints: NULL];
}

@end
