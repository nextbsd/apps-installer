/*
 * Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * ISController: Installer's one window and its four screens, as the
 * mockup (mockups/installer.html) has them:
 *
 *   Welcome          Install
 *   Choose a disk    the disks, the one Installer runs from and those too
 *                    small shown but not choosable; Back, Next
 *   Installing       one progress bar, what it's doing, time remaining;
 *                    or, if it fails, Choose Another Disk and Try Again
 *   Installed        Restart
 *
 * From the install image it installs NextBSD; from an installed system it
 * copies that system onto another disk. The install is SettingsHelper's
 * InstallStart (right org.nextbsd.installer, an administrator every
 * time), which runs the text installer's engine as root.
 */

#import <AppKit/AppKit.h>

@class ISProbe, ISFlippedView, ISProgressBar, NBAuthorization;

typedef enum
{
  ISScreenWelcome = 0,
  ISScreenDisk,
  ISScreenInstalling,
  ISScreenFailed,
  ISScreenDone
} ISScreen;

@interface ISController : NSObject
{
  NSWindow *window;
  ISFlippedView *content;
  ISScreen screen;

  ISProbe *probe;		/* the last probe's answer */
  NSArray *disks;		/* what the list shows */
  NSString *chosen;		/* the chosen disk's device, or nil */
  NSTableView *table;
  NSTask *probeTask;		/* a re-probe in flight */
  NSTimer *refreshTimer;	/* re-probes while choosing a disk */

  ISProgressBar *bar;
  NSTextField *statusText;
  NSTextField *remainingText;
  NSTimer *progressTimer;
  int lastPercent;
  int misses;			/* progress calls the helper didn't answer */
  NSTimeInterval copyStart;	/* when the copy started to show progress */
  int copyStartPercent;
  /* When the install started, and how long it took (nextbsd/nextbsd#426). */
  NSTimeInterval installStart;
  NSTimeInterval installSeconds;
}

@end
