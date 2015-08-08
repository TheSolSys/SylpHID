//
// FPAxisPairView.h
// "SylpHID"
//
// Created by Darrell Walisser <walisser@mac.com>
// Copyright (c)2007 Darrell Walisser. All Rights Reserved.
// http://sourceforge.net/projects/xhd
//
// Forked and Modifed by macman860 <email address unknown>
// https://macman860.wordpress.com
//
// Forked and Modified by Paige Marie DePol <pmd@fizzypopstudios.com>
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


#import <AppKit/AppKit.h>


@interface FPAxisPairView : NSImageView {
	NSPoint _home;
    float _x, _y;
	float _livex, _livey;
    float _minx, _miny;
    float _maxx, _maxy;
    BOOL _pressed;
}

- (void) setPressed: (BOOL)pressed;

- (void) setX: (float)x;
- (void) setY: (float)y;

- (void) setLiveX: (float)x;
- (void) setLiveY: (float)y;

@end
