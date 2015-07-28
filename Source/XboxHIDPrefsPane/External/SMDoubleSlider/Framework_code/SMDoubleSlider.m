//
// SMDoubleSlider.m
// "Xbox HID"
//
// Copyright (c)2003-2010 Snowmint Creative Solutions LLC. All Rights Reserved.
// http://www.snowmintcs.com/
//
// Forked and Modified by Paige Marie DePol <pmd@fizzypopstudios.com>
// Copyright (c)2015 FizzyPop Studios. All Rights Reserved.
// http://xboxhid.fizzypopstudios.com
//
// ================================================================================================================================
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
// ================================================================================================================================
// Original License for SMDoubleSlider
//
// Redistribution and use in source and binary forms, with or without modification, are permitted under following conditions:
//
// ¥ Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// ¥ Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer
//	 in the documentation and/or other materials provided with the distribution.
// ¥ Neither the name of Snowmint Creative Solutions LLC nor the names of its contributors may be used to endorse or promote
//	 products derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
// BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
// SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// ================================================================================================================================


#import <AppKit/AppKit.h>

#import "SMDoubleSlider.h"
#import "SMDoubleSliderCell.h"


enum {
	kBindIdx_invalid = -1,
	kBindIdx_loValue = 0,
	kBindIdx_hiValue = 1
};

typedef intptr_t BindingIndex;


@implementation SMDoubleSlider

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_3

+ (void) exposeBindings
{
    [self exposeBinding: @"objectLoValue"];
    [self exposeBinding: @"objectHiValue"];
}

- (void) unbindAll
{
    [self unbind: @"objectLoValue"];
    [self unbind: @"objectHiValue"];
}

+ (void) initialize
{
    if (self == [SMDoubleSlider class]) {
	   // Expose all bindings so that the IB Plugin can make them available in IB
	   [self exposeBindings];
    }
}

// for IBPalette
- (Class) valueClassForBinding: (NSString *)bindingName
{
    if ([bindingName isEqualToString: @"objectLoValue"]) {
	   return [NSNumber class];
    } else if ([bindingName isEqualToString: @"objectHiValue"])    {
	   return [NSNumber class];
    } else {
	   return [super valueClassForBinding: bindingName];
    }
}

- (BindingIndex) bindingNameToIndex: (NSString *)bindingName
{
    BindingIndex idx = kBindIdx_invalid;

    if ([bindingName isEqualToString: @"objectLoValue"]) {
	   idx = kBindIdx_loValue;
    } else if ([bindingName isEqualToString: @"objectHiValue"])    {
	   idx = kBindIdx_hiValue;
    }

    return idx;
}

- (NSString *) bindingIndexToName: (BindingIndex)bindingIndex
{
    NSString* bindingName;

    switch (bindingIndex) {
	   case kBindIdx_loValue:
		  bindingName = @"objectLoValue";
		  break;
	   case kBindIdx_hiValue:
		  bindingName = @"objectHiValue";
		  break;
	   default:
		  bindingName = nil;
		  break;
    }

    return bindingName;
}

- (void) bind: (NSString*)bindingName toObject: (id)observableObject withKeyPath: (NSString*)observableKeyPath options: (NSDictionary*)options
{
    BindingIndex idx = [self bindingNameToIndex: bindingName];

    switch (idx) {
	   case kBindIdx_loValue:
	   case kBindIdx_hiValue: {
		  // register to receive notifications of changes
		  [observableObject addObserver: self forKeyPath: observableKeyPath options: 0 context: (void*)idx];
		  break;
	   }
    }

    [self setNeedsDisplay: YES];

    // must call super for the IBPalette to be enabled in IB
    [super bind: bindingName toObject: observableObject withKeyPath: observableKeyPath options: options];
}

- (void) unbind: (NSString*)bindingName
{
    BindingIndex idx = [self bindingNameToIndex: bindingName];

    switch (idx) {
	   case kBindIdx_loValue: {
		  NSDictionary *bindingInfo = [self infoForBinding: @"objectLoValue"];
		  id observedObject = [bindingInfo objectForKey: NSObservedObjectKey];
		  NSString *observedKeyPath = [bindingInfo objectForKey: NSObservedKeyPathKey];
		  [observedObject removeObserver: self forKeyPath: observedKeyPath];
		  break;
	   }
	   case kBindIdx_hiValue: {
		  NSDictionary *bindingInfo = [self infoForBinding: @"objectHiValue"];
		  id observedObject = [bindingInfo objectForKey: NSObservedObjectKey];
		  NSString *observedKeyPath = [bindingInfo objectForKey: NSObservedKeyPathKey];
		  [observedObject removeObserver: self forKeyPath: observedKeyPath];
		  break;
	   }
    }

    [self setNeedsDisplay: YES];

    [super unbind: bindingName];
}

// This is called when the NSController wants to change values
- (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary*)change context: (void*)context
{
//	NSLog (@"observeValueForKeyPath %@", keyPath);

	(void)change;

	BindingIndex idx = (BindingIndex)context;

	if (idx == kBindIdx_loValue) {
	   NSDictionary *bindingInfo = [self infoForBinding: @"objectLoValue"];
	   id observedObject = [bindingInfo objectForKey: NSObservedObjectKey];
	   NSString *observedKeyPath = [bindingInfo objectForKey: NSObservedKeyPathKey];

	   id newLoValue = [observedObject valueForKeyPath: observedKeyPath];
	   [self setObjectLoValue: newLoValue];
    } else if (idx == kBindIdx_hiValue)   {
	   NSDictionary *bindingInfo = [self infoForBinding: @"objectHiValue"];
	   id observedObject = [bindingInfo objectForKey: NSObservedObjectKey];
	   NSString *observedKeyPath = [bindingInfo objectForKey: NSObservedKeyPathKey];

	   id newHiValue = [observedObject valueForKeyPath: observedKeyPath];
	   [self setObjectHiValue: newHiValue];
    } else {
	   [super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
    }

    [self setNeedsDisplay: YES];
}

- (void) setNilValueForKey: (NSString *)key
{
    BindingIndex idx = [self bindingNameToIndex: key];

    if (idx == kBindIdx_loValue) {
	   [self setDoubleLoValue: 0.0];
    } else if (idx == kBindIdx_hiValue)   {
	   [self setDoubleHiValue: 0.0];
    }
}

- (void) updateBoundControllerHiValue: (double)val
{
    NSDictionary *bindingInfo = [self infoForBinding: @"objectHiValue"];
    id observedObject = [bindingInfo objectForKey: NSObservedObjectKey];
    NSString *observedKeyPath = [bindingInfo objectForKey: NSObservedKeyPathKey];
    [observedObject setValue: [NSNumber numberWithDouble: val] forKeyPath: observedKeyPath];
}

- (void) updateBoundControllerLoValue: (double)val
{
    NSDictionary *bindingInfo = [self infoForBinding: @"objectLoValue"];
    id observedObject = [bindingInfo objectForKey: NSObservedObjectKey];
    NSString *observedKeyPath = [bindingInfo objectForKey: NSObservedKeyPathKey];
    [observedObject setValue: [NSNumber numberWithDouble: val] forKeyPath: observedKeyPath];
}

- (void) viewWillMoveToSuperview: (NSView*)newSuperview
{
    [super viewWillMoveToSuperview: newSuperview];

    // Disconnect all bindings when the view is disconnected from the view hierarchy
    if (newSuperview == nil)
	   [self unbindAll];
}

#endif

#pragma mark -

// ---------------------------------------------------------------------------------------------------------------
// A view must know how to archive and unarchive itself in order to be placed in a custom
// Interface Builder palette.
- (void) encodeWithCoder: (NSCoder*)coder
{
    [super encodeWithCoder: coder];
    // Write attributes, none currently
}

// ---------------------------------------------------------------------------------------------------------------
- (id) initWithCoder: (NSCoder*)decoder
{
    self = [super initWithCoder: decoder];
    if (self) {
	   // Read archived attributes, none currently
	   _triPath = [NSBezierPath bezierPath];
	   #define kCosine60 0.5
	   #define kSine60 0.8660254037844386
	   float triBase = 5;
	   [_triPath moveToPoint: NSMakePoint(0, 0)];
	   [_triPath lineToPoint: NSMakePoint(triBase, 0)];
	   [_triPath lineToPoint: NSMakePoint(triBase*kCosine60, triBase*kSine60)];
	   [_triPath closePath];
	   _liveValue = 0;
	}
	return self;
}


#pragma mark -

- (void) setLiveValue: (double)aDouble
{
    _liveValue = aDouble;
    [self setNeedsDisplay];
}

- (void) drawRect: (NSRect)dirty
{
    [super drawRect: dirty];
    dirty = [self bounds];
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    NSAffineTransform *transform = [NSAffineTransform transform];
    [context saveGraphicsState];
    [transform translateXBy: 4 + ((dirty.size.width - 13) * _liveValue) yBy: 0];
    [transform concat];
    if ( ([self isDeadzoneSlider] && _liveValue >= (([self doubleLoValue]+6.5)/[self maxValue]) && _liveValue <= (([self doubleHiValue]-5.5)/[self maxValue])) ||
	   (![self isDeadzoneSlider] && (_liveValue <= (([self doubleLoValue]-1.5)/[self maxValue]) || _liveValue >= (([self doubleHiValue]+1.5)/[self maxValue]))) )
	   [[NSColor colorWithCalibratedRed: 0.5 green: 0.000 blue: 0.000 alpha: 1.000] set];
    else
	   [[NSColor colorWithCalibratedWhite: 0.150 alpha: 1.000] set];
    [_triPath fill];
    [context restoreGraphicsState];
}

#pragma mark -

+ (Class) cellClass
{
    return [SMDoubleSliderCell class];
}

- (void) keyDown: (NSEvent*)theEvent
{
    [self interpretKeyEvents: [NSArray arrayWithObject: theEvent]];
}

- (void) insertTab: (id)sender
{
    (void)sender;

    // Tab forwards...Switch from low to high knob tracking, or switch to the next control.
    if ([[self cell] trackingLoKnob])
	   [[self cell] setTrackingLoKnob: NO];
    else {
	   [[self cell] setTrackingLoKnob: YES];
	   [[self window] selectNextKeyView: self];
    }

    [self setNeedsDisplay: YES];
}

- (void) insertBacktab: (id)sender
{
    (void)sender;

    // Tab backwards...Switch from high knob to low knob tracking, or switch to the next control.
    if (![[self cell] trackingLoKnob])
	   [[self cell] setTrackingLoKnob: YES];
    else
	   [[self window] selectPreviousKeyView: self];

    [self setNeedsDisplay: YES];
}

- (BOOL) becomeFirstResponder
{
    BOOL result = [super becomeFirstResponder];

    // Depending on which way we're going through the key loop, select either the hi knob or the lo knob.
    if ( result && [[self window] keyViewSelectionDirection] != NSDirectSelection)
	   [self setTrackingLoKnob: ([[self window] keyViewSelectionDirection] == NSSelectingNext)];

    return result;
}

#pragma mark -

- (void) setMaxLoValue: (double)aDouble
{
    [[self cell] setMaxLoValue: aDouble];
}

- (double) maxLoValue
{
    return [[self cell] maxLoValue];
}

- (void) setMinHiValue: (double)aDouble
{
    [[self cell] setMinHiValue: aDouble];
}

- (double) minHiValue
{
    return [[self cell] minHiValue];
}

- (void) setMaxLoValue: (double)loMax andMinHiValue: (double)hiMin
{
    [self setMaxLoValue: loMax];
    [self setMinHiValue: hiMin];
}

#pragma mark -

- (BOOL)trackingLoKnob
{
    return [[self cell] trackingLoKnob];
}

- (void)setTrackingLoKnob:(BOOL)inValue
{
    [[self cell] setTrackingLoKnob: inValue];
}

- (BOOL)lockedSliders
{
    return [[self cell] lockedSliders];
}

- (void)setLockedSliders:(BOOL)inLocked
{
    [[self cell] setLockedSliders: inLocked];
}

#pragma mark -

- (BOOL)isDeadzoneSlider
{
    return [[self cell] isDeadzoneSlider];
}

- (void)setDeadzoneSlider:(id)output
{
    [[self cell] setDeadzoneSlider: output];
}


#define DEADZONE_MAX    95.0

// Converts current slider positions into a deadzone value (between 0 and 95%)
- (int) deadzoneValue
{
    if ([[self cell] isDeadzoneSlider]) {
	   NSRect knob = NSInsetRect([[self cell] knobRectFlipped: [self isFlipped]], 1, 1);  // Inset as knob radius is also inset
	   double value = [self doubleLoValue];
	   double range = ([self maxValue] - knob.size.width) / 2.0;
	   return DEADZONE_MAX - ((value / range) * DEADZONE_MAX);
    }

    return 0;
}

// Set slider positions based on deadzone percentage (between 0 and 95%)
- (void) setDeadzoneValue: (int)value
{
    if ([[self cell] isDeadzoneSlider]) {
	   NSRect knob = NSInsetRect([[self cell] knobRectFlipped: [self isFlipped]], 1, 1);  // Inset as knob radius is also inset
	   if (value < 0) value = 0;
	   if (value > DEADZONE_MAX) value = DEADZONE_MAX;
	   double range = ([self maxValue] - knob.size.width) / 2.0;
	   double pcent = 1.0 - (value / DEADZONE_MAX);
	   [self setDoubleLoValue: (range * pcent)];
	   [self setDoubleHiValue: [self maxValue] - (range * pcent) - 1];
    }
}

#pragma mark -

- (void)setObjectHiValue:(id)obj
{
    if (obj && !NSIsControllerMarker(obj)) {
	   [self setEnabled: YES];
	   [[self cell] setObjectHiValue: obj];
    } else {
	   [self setEnabled:NO];
	   [[self cell] setObjectHiValue: nil];
    }
}

- (void) setStringHiValue: (NSString *)aString
{
    [[self cell] setStringHiValue: aString];
}

- (void) setIntHiValue: (int)anInt
{
    [[self cell] setIntHiValue: anInt];
}

- (void) setFloatHiValue: (float)aFloat
{
    [[self cell] setFloatHiValue: aFloat];
}

- (void) setDoubleHiValue: (double)aDouble
{
    [[self cell] setDoubleHiValue: aDouble];
}

- (id) objectHiValue
{
    return [[self cell] objectHiValue];
}

- (NSString *) stringHiValue
{
    return [[self cell] stringHiValue];
}

- (int) intHiValue
{
    return [[self cell] intHiValue];
}

- (float) floatHiValue
{
    return [[self cell] floatHiValue];
}

- (double) doubleHiValue
{
    return [[self cell] doubleHiValue];
}

#pragma mark -

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5
- (void) setIntegerHiValue: (NSInteger)anInt;
{
    [[self cell] setIntegerHiValue: anInt];
}

- (NSInteger) integerHiValue;
{
    return [[self cell] integerHiValue];
}

- (void) setIntegerLoValue: (NSInteger)anInt;
{
    [[self cell] setIntegerLoValue: anInt];
}

- (NSInteger) integerLoValue;
{
    return [[self cell] integerLoValue];
}
#endif

- (void) setDoubleLoValue: (double)lo andHiValue: (double)hi
{
	[self setDoubleLoValue: lo];
	[self setDoubleHiValue: hi];
}

#pragma mark -

- (void) setObjectLoValue: (id)obj
{
    if (obj && !NSIsControllerMarker(obj)) {
	   [self setEnabled: YES];
	   [[self cell] setObjectLoValue: obj];
    } else {
	   [self setEnabled: NO];
	   [[self cell] setObjectLoValue: nil];
    }
}

- (void) setStringLoValue: (NSString *)aString
{
    [[self cell] setStringLoValue: aString];
}

- (void) setIntLoValue: (int)anInt
{
    [[self cell] setIntLoValue: anInt];
}

- (void) setFloatLoValue: (float)aFloat
{
    [[self cell] setFloatLoValue: aFloat];
}

- (void) setDoubleLoValue: (double)aDouble
{
    [[self cell] setDoubleLoValue: aDouble];
}

- (id) objectLoValue
{
    return [[self cell] objectLoValue];
}

- (NSString *) stringLoValue
{
    return [[self cell] stringLoValue];
}

- (int) intLoValue
{
    return [[self cell] intLoValue];
}

- (float) floatLoValue
{
    return [[self cell] floatLoValue];
}

- (double) doubleLoValue
{
    return [[self cell] doubleLoValue];
}

@end
