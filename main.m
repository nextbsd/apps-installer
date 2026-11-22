/*
 * Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Installer.app: NextBSD installed on a disk, from the install image or
 * as a copy of the running system. Four screens: Welcome, Choose a disk,
 * Installing, Installed.
 */

#import <AppKit/AppKit.h>
#import "ISController.h"

int
main (int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL (pool);
  [NSApplication sharedApplication];
  ISController *controller = [[ISController alloc] init];
  [NSApp setDelegate:controller];
  [NSApp run];
  RELEASE (controller);
  RELEASE (pool);
  return 0;
}
