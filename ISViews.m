/*
 * Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import "ISViews.h"
#import <GNUstepBase/GNUstep.h>

static NSColor *
ISRGB (int rgb)
{
  return [NSColor colorWithCalibratedRed:((rgb >> 16) & 0xff) / 255.0
                                   green:((rgb >> 8) & 0xff) / 255.0
                                    blue:(rgb & 0xff) / 255.0
                                   alpha:1.0];
}

@implementation ISFlippedView
- (BOOL)isFlipped
{
  return YES;
}
@end

@implementation ISCenteredCell
- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)view
{
  CGFloat h = [self cellSize].height;

  if (h < NSHeight (frame))
    {
      frame.origin.y += floor ((NSHeight (frame) - h) / 2);
      frame.size.height = h;
    }
  [super drawInteriorWithFrame:frame inView:view];
}
@end

@implementation ISIconView

- (void)setBadge:(ISBadge)badge
{
  _badge = badge;
  [self setNeedsDisplay:YES];
}

/* The mockup's corner badges, in a 24-point box with y down. */
- (void)drawBadgeInRect:(NSRect)r
{
  NSBezierPath *p;
  CGFloat s = NSWidth (r) / 24.0;
#define P(x, y) NSMakePoint (NSMinX (r) + (x) * s, NSMaxY (r) - (y) * s)

  if (_badge == ISBadgeDone)
    {
      p = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect (r, 1.5 * s,
                                                              1.5 * s)];
      [ISRGB (0x1d3a26) set];
      [p fill];
      [ISRGB (0x6fd38a) set];
      [p setLineWidth:1.5 * s];
      [p stroke];
      p = [NSBezierPath bezierPath];
      [p moveToPoint:P (7.5, 12.3)];
      [p lineToPoint:P (10.5, 15.3)];
      [p lineToPoint:P (16.5, 9.0)];
      [p setLineWidth:2.2 * s];
      [p setLineCapStyle:NSRoundLineCapStyle];
      [p setLineJoinStyle:NSRoundLineJoinStyle];
      [p stroke];
    }
  else if (_badge == ISBadgeWarning)
    {
      p = [NSBezierPath bezierPath];
      [p moveToPoint:P (12, 2.5)];
      [p lineToPoint:P (22, 20.5)];
      [p lineToPoint:P (2, 20.5)];
      [p closePath];
      [ISRGB (0x3b2a12) set];
      [p fill];
      [ISRGB (0xffb454) set];
      [p setLineWidth:1.5 * s];
      [p setLineJoinStyle:NSRoundLineJoinStyle];
      [p stroke];
      p = [NSBezierPath bezierPath];
      [p moveToPoint:P (12, 9)];
      [p lineToPoint:P (12, 14.5)];
      [p setLineWidth:2.2 * s];
      [p setLineCapStyle:NSRoundLineCapStyle];
      [p stroke];
      [[NSBezierPath bezierPathWithOvalInRect:
          NSMakeRect (NSMinX (r) + 10.7 * s, NSMaxY (r) - 18.9 * s,
                      2.6 * s, 2.6 * s)] fill];
    }
#undef P
}

/* The icon fills the view but for 4 points at the right and bottom,
   which the badge overhangs, as the mockup's corner does. */
- (void)drawRect:(NSRect)rect
{
  NSRect b = [self bounds];
  CGFloat side = NSWidth (b) - 4;
  CGFloat badge = floor (side * 24.0 / 64.0);

  [[NSApp applicationIconImage]
      drawInRect:NSMakeRect (0, NSHeight (b) - side, side, side)
        fromRect:NSZeroRect
       operation:NSCompositeSourceOver
        fraction:1.0];
  if (_badge != ISBadgeNone)
    [self drawBadgeInRect:NSMakeRect (NSWidth (b) - badge, 0, badge, badge)];
}

@end

@implementation ISProgressBar

- (void)setDoubleValue:(double)value
{
  _value = value < 0 ? 0 : value > 100 ? 100 : value;
  [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
  NSRect b = [self bounds], fill;

  [ISRGB (0x000000) set];
  NSRectFill (b);
  /* Sunken: dark above and left, light below and right (y is up). */
  [ISRGB (0x55555f) set];
  NSRectFill (NSMakeRect (0, 0, NSWidth (b), 1));
  NSRectFill (NSMakeRect (NSWidth (b) - 1, 0, 1, NSHeight (b)));
  [ISRGB (0x0a0a0a) set];
  NSRectFill (NSMakeRect (0, NSHeight (b) - 1, NSWidth (b), 1));
  NSRectFill (NSMakeRect (0, 0, 1, NSHeight (b)));
  fill = NSInsetRect (b, 1, 1);
  fill.size.width = floor (NSWidth (fill) * _value / 100.0);
  [ISRGB (0x0a5fd1) set];
  NSRectFill (fill);
}

@end

NSImage *
ISDiskImage (BOOL usb, NSColor *color)
{
  NSImage *image = AUTORELEASE ([[NSImage alloc]
                                  initWithSize:NSMakeSize (22, 22)]);
  NSBezierPath *p;
  CGFloat s = 22.0 / 24.0;
#define R(x, y, w, h) NSMakeRect ((x) * s, (24 - (y) - (h)) * s, (w) * s, (h) * s)

  [image lockFocus];
  [color set];
  if (usb)
    {
      p = [NSBezierPath bezierPathWithRoundedRect:R (4, 9, 13, 6)
                                          xRadius:1.2 * s yRadius:1.2 * s];
      [p setLineWidth:1.6 * s];
      [p stroke];
      p = [NSBezierPath bezierPath];
      [p moveToPoint:NSMakePoint (17 * s, 14 * s)];
      [p lineToPoint:NSMakePoint (20.5 * s, 14 * s)];
      [p lineToPoint:NSMakePoint (20.5 * s, 10 * s)];
      [p lineToPoint:NSMakePoint (17 * s, 10 * s)];
      [p setLineWidth:1.6 * s];
      [p setLineJoinStyle:NSRoundLineJoinStyle];
      [p stroke];
    }
  else
    {
      p = [NSBezierPath bezierPathWithRoundedRect:R (2.5, 8, 19, 8)
                                          xRadius:1.6 * s yRadius:1.6 * s];
      [p setLineWidth:1.6 * s];
      [p stroke];
      p = [NSBezierPath bezierPath];
      [p moveToPoint:NSMakePoint (5.5 * s, 12 * s)];
      [p lineToPoint:NSMakePoint (11.5 * s, 12 * s)];
      [p setLineWidth:1.6 * s];
      [p setLineCapStyle:NSRoundLineCapStyle];
      [p stroke];
      [[NSBezierPath bezierPathWithOvalInRect:
          NSMakeRect (17.2 * s, 11.2 * s, 1.6 * s, 1.6 * s)] fill];
    }
  [image unlockFocus];
#undef R
  return image;
}

NSImage *
ISWarningImage (void)
{
  NSImage *image = AUTORELEASE ([[NSImage alloc]
                                  initWithSize:NSMakeSize (18, 18)]);
  NSBezierPath *p;
  CGFloat s = 18.0 / 24.0;

  [image lockFocus];
  [ISRGB (0xffb454) set];
  p = [NSBezierPath bezierPath];
  [p moveToPoint:NSMakePoint (12 * s, 20.5 * s)];
  [p lineToPoint:NSMakePoint (21 * s, 4.5 * s)];
  [p lineToPoint:NSMakePoint (3 * s, 4.5 * s)];
  [p closePath];
  [p setLineWidth:1.8 * s];
  [p setLineJoinStyle:NSRoundLineJoinStyle];
  [p stroke];
  p = [NSBezierPath bezierPath];
  [p moveToPoint:NSMakePoint (12 * s, 14 * s)];
  [p lineToPoint:NSMakePoint (12 * s, 9.5 * s)];
  [p moveToPoint:NSMakePoint (12 * s, 6.8 * s)];
  [p lineToPoint:NSMakePoint (12 * s, 6.7 * s)];
  [p setLineWidth:1.8 * s];
  [p setLineCapStyle:NSRoundLineCapStyle];
  [p stroke];
  [image unlockFocus];
  return image;
}
