/*
 * Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * ISViews: the little Installer draws itself, as in the mockup
 * (mockups/installer.html): its icon with a corner badge, the progress
 * bar, the disk and USB stick glyphs of the disk list, and the warning
 * glyph.
 */

#import <AppKit/AppKit.h>

/* A view laid out from the top down. */
@interface ISFlippedView : NSView
@end

/* A table cell whose text sits in the middle of its row. */
@interface ISCenteredCell : NSTextFieldCell
@end

typedef enum
{
  ISBadgeNone = 0,
  ISBadgeDone,			/* a green check */
  ISBadgeWarning		/* an amber triangle */
} ISBadge;

/* The app's icon, with a badge at its bottom right. */
@interface ISIconView : NSView
{
  ISBadge _badge;
}
- (void)setBadge:(ISBadge)badge;
@end

/* The install's one progress bar: a sunken black well, filled in the
   selection blue. (The theme's NSProgressIndicator draws its fill near
   black, which on the dark window doesn't read.) */
@interface ISProgressBar : NSView
{
  double _value;		/* 0 to 100 */
}
- (void)setDoubleValue:(double)value;
@end

/* A disk's glyph for the list, 22 points, in `color`. */
NSImage *ISDiskImage (BOOL usb, NSColor *color);

/* The warning triangle, 18 points. */
NSImage *ISWarningImage (void);
