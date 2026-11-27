/*
 * Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import "ISController.h"
#import "ISDisks.h"
#import "ISViews.h"
#import "NBAuthorization.h"
#import "NBAuthorizationPanel.h"
#import <GNUstepBase/GNUstep.h>

#include "NBHelperClient.h"
#include "settingshelper_types.h"

#include <math.h>

/* Layout, in points, as the mockup's. */
#define ISWindowWidth 560.0
#define ISBodyHeight 350.0
#define ISFootHeight 50.0
#define ISMarginX 24.0
#define ISMarginTop 22.0
#define ISButtonHeight 26.0
#define ISButtonMinWidth 96.0
#define ISListTall 236.0
#define ISListShort 168.0

static NSString *const ISRight = @"org.nextbsd.installer";
static NSString *const ISTitle = @"Installer";

/* How often the disk list is read again while it shows, and how often
   the install is asked how it's going. */
#define ISRefreshSeconds 3.0
#define ISProgressSeconds 0.5
/* The helper not answering this many times in a row is a failure. */
#define ISMaxMisses 20

/* Where the copy's progress ends (do-install.sh), and roughly how long
   the rest takes. */
#define ISCopyEnd 86
#define ISAfterCopySeconds 20.0

static NSColor *
ISSecondaryColor (void)
{
  return [NSColor colorWithCalibratedRed:0.72 green:0.72 blue:0.75 alpha:1];
}

static NSColor *
ISDisabledColor (void)
{
  return [NSColor colorWithCalibratedRed:0.55 green:0.55 blue:0.58 alpha:1];
}

static NSTextField *
ISLabel (NSRect frame, NSString *text, NSFont *font)
{
  NSTextField *label = AUTORELEASE ([[NSTextField alloc] initWithFrame:frame]);

  [label setStringValue:(text != nil ? text : @"")];
  [label setEditable:NO];
  [label setSelectable:NO];
  [label setBordered:NO];
  [label setBezeled:NO];
  [label setDrawsBackground:NO];
  if (font != nil)
    [label setFont:font];
  return label;
}

/* The smallest disk as sold: the probe's 30,000,000,000 bytes is what a
   "32 GB" stick holds. */
static long
ISNeedGB (unsigned long long need)
{
  long gb = (long) ceil (need / 1e9);

  return gb < 32 ? 32 : gb;
}

static NSFont *
ISTitleFont (void)
{
  return [NSFont boldSystemFontOfSize:18];
}

@interface ISController (Private)
- (void)buildMenu;
- (void)showScreen:(ISScreen)which;
- (NSView *)welcomeView;
- (NSView *)diskView;
- (NSView *)installingView;
- (NSView *)failedView;
- (NSView *)doneView;
- (NSView *)headerWithTitle:(NSString *)title subtitle:(NSString *)subtitle
                      badge:(ISBadge)badge width:(CGFloat)width;
- (NSView *)footWithButtons:(NSArray *)buttons;
- (NSButton *)button:(NSString *)title action:(SEL)action
             primary:(BOOL)primary;
- (BOOL)isUsable:(ISDisk *)disk;
- (NSString *)noteForDisk:(ISDisk *)disk;
- (ISDisk *)chosenDisk;
- (void)takeProbe:(ISProbe *)answer;
- (void)refresh:(NSTimer *)timer;
- (void)probeDone:(NSNotification *)note;
- (void)stopRefreshing;
- (void)updateNext;
- (void)welcomeInstall:(id)sender;
- (void)back:(id)sender;
- (void)next:(id)sender;
- (void)chooseAnotherDisk:(id)sender;
- (void)restart:(id)sender;
- (void)shutDown:(id)sender;
- (void)finish:(int)status;
- (void)poll:(NSTimer *)timer;
- (NSString *)remainingFor:(int)percent phase:(int)phase;
@end

@implementation ISController

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [refreshTimer invalidate];
  [progressTimer invalidate];
  RELEASE (window);
  RELEASE (probe);
  RELEASE (disks);
  RELEASE (chosen);
  RELEASE (probeTask);
  [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
  NSImage *icon = [NSImage imageNamed:@"Installer.png"];

  if (icon != nil)
    [NSApp setApplicationIconImage:icon];
  [self buildMenu];

  ASSIGN (probe, [ISProbe probe]);
  if (![probe isValid])
    {
      NSRunAlertPanel (ISTitle,
                       @"Installer can't find the install engine "
                       @"(/usr/libexec/nextbsd-installer).",
                       @"Quit", nil, nil);
      [NSApp terminate:self];
      return;
    }
  [self takeProbe:probe];

  window = [[NSWindow alloc]
      initWithContentRect:NSMakeRect (0, 0, ISWindowWidth,
                                      ISBodyHeight + ISFootHeight)
                styleMask:NSTitledWindowMask | NSClosableWindowMask
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [window setTitle:ISTitle];
  [window setReleasedWhenClosed:NO];
  [window setDelegate:(id)self];
  content = AUTORELEASE ([[ISFlippedView alloc]
                           initWithFrame:NSMakeRect (0, 0, ISWindowWidth,
                                                     ISBodyHeight
                                                     + ISFootHeight)]);
  [window setContentView:content];
  [self showScreen:ISScreenWelcome];
  [window center];
  [window makeKeyAndOrderFront:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app
{
  return YES;
}

/* Quitting is harmless only before the disk is erased, and after. */
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app
{
  return screen == ISScreenInstalling ? NSTerminateCancel : NSTerminateNow;
}

- (BOOL)windowShouldClose:(id)sender
{
  return screen == ISScreenWelcome || screen == ISScreenDisk;
}

/* ---- the disk list ---- */

- (NSInteger)numberOfRowsInTableView:(NSTableView *)view
{
  return [disks count];
}

- (id)tableView:(NSTableView *)view
    objectValueForTableColumn:(NSTableColumn *)column
                          row:(NSInteger)row
{
  ISDisk *disk = [disks objectAtIndex:row];
  NSString *which = [column identifier];

  if ([which isEqual:@"icon"])
    return ISDiskImage ([disk isUSB], [self isUsable:disk]
                        ? ISSecondaryColor () : ISDisabledColor ());
  if ([which isEqual:@"note"])
    return [self noteForDisk:disk];
  return [NSString stringWithFormat:@"%@ · %@", [disk model],
                   [disk sizeString]];
}

- (void)tableView:(NSTableView *)view
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)column
              row:(NSInteger)row
{
  ISDisk *disk = [disks objectAtIndex:row];

  if (![[column identifier] isEqual:@"icon"]
      && [cell respondsToSelector:@selector (setTextColor:)])
    [cell setTextColor:([self isUsable:disk] && ![[column identifier]
                                                    isEqual:@"note"])
          ? [NSColor controlTextColor] : ISDisabledColor ()];
}

/* The installer's own disk, the current system's and those too small
   are shown, but can't be chosen. */
- (BOOL)tableView:(NSTableView *)view shouldSelectRow:(NSInteger)row
{
  return [self isUsable:[disks objectAtIndex:row]];
}

- (void)tableViewSelectionDidChange:(NSNotification *)note
{
  NSInteger row = [table selectedRow];

  if (row >= 0 && row < (NSInteger) [disks count])
    ASSIGN (chosen, [[disks objectAtIndex:row] device]);
  [self updateNext];
}

@end

@implementation ISController (Private)

- (void)buildMenu
{
  NSMenu *menu = AUTORELEASE ([[NSMenu alloc] initWithTitle:ISTitle]);
  NSMenu *edit = AUTORELEASE ([[NSMenu alloc] initWithTitle:@"Edit"]);
  id<NSMenuItem> item;

  [menu addItemWithTitle:@"About Installer"
                  action:@selector (orderFrontStandardAboutPanel:)
           keyEquivalent:@""];
  /* The authorization panel's password field takes typing. */
  item = [menu addItemWithTitle:@"Edit" action:NULL keyEquivalent:@""];
  [edit addItemWithTitle:@"Cut" action:@selector (cut:) keyEquivalent:@"x"];
  [edit addItemWithTitle:@"Copy" action:@selector (copy:) keyEquivalent:@"c"];
  [edit addItemWithTitle:@"Paste" action:@selector (paste:)
           keyEquivalent:@"v"];
  [edit addItemWithTitle:@"Select All" action:@selector (selectAll:)
           keyEquivalent:@"a"];
  [menu setSubmenu:edit forItem:item];
  [menu addItemWithTitle:@"Hide" action:@selector (hide:) keyEquivalent:@"h"];
  [menu addItemWithTitle:@"Quit" action:@selector (terminate:)
           keyEquivalent:@"q"];
  [NSApp setMainMenu:menu];
}

- (void)showScreen:(ISScreen)which
{
  NSView *body;
  NSEnumerator *e;
  NSView *old;

  screen = which;
  table = nil;
  bar = nil;
  statusText = nil;
  remainingText = nil;
  e = [[NSArray arrayWithArray:[content subviews]] objectEnumerator];
  while ((old = [e nextObject]) != nil)
    [old removeFromSuperview];
  [window setDefaultButtonCell:nil];

  switch (which)
    {
    case ISScreenWelcome:
      body = [self welcomeView];
      break;
    case ISScreenDisk:
      body = [self diskView];
      break;
    case ISScreenInstalling:
      body = [self installingView];
      break;
    case ISScreenFailed:
      body = [self failedView];
      break;
    case ISScreenDone:
    default:
      body = [self doneView];
      break;
    }
  [content addSubview:body];

  if (which == ISScreenDisk)
    {
      if (refreshTimer == nil)
        refreshTimer = [NSTimer scheduledTimerWithTimeInterval:
                                  ISRefreshSeconds
                                                        target:self
                                                      selector:@selector
                                                        (refresh:)
                                                      userInfo:nil
                                                       repeats:YES];
    }
  else
    [self stopRefreshing];

  /* The close button only while closing is harmless. */
  if ([window respondsToSelector:@selector (standardWindowButton:)])
    [[window standardWindowButton:NSWindowCloseButton]
        setEnabled:(which == ISScreenWelcome || which == ISScreenDisk)];
  [content setNeedsDisplay:YES];
}

- (NSButton *)button:(NSString *)title action:(SEL)action
             primary:(BOOL)primary
{
  NSButton *b = AUTORELEASE ([[NSButton alloc]
                               initWithFrame:NSMakeRect (0, 0,
                                                         ISButtonMinWidth,
                                                         ISButtonHeight)]);
  NSRect f;

  [b setTitle:title];
  [b setTarget:self];
  [b setAction:action];
  [b sizeToFit];
  f = [b frame];
  f.size.width = MAX (ISButtonMinWidth, NSWidth (f) + 24);
  f.size.height = ISButtonHeight;
  [b setFrame:f];
  if (primary)
    {
      [b setKeyEquivalent:@"\r"];
      [window setDefaultButtonCell:[b cell]];
    }
  return b;
}

/* The bar along the bottom: a line, then the buttons from the right. */
- (NSView *)footWithButtons:(NSArray *)buttons
{
  ISFlippedView *foot = AUTORELEASE ([[ISFlippedView alloc]
                                       initWithFrame:NSMakeRect
                                         (0, ISBodyHeight, ISWindowWidth,
                                          ISFootHeight)]);
  NSBox *line = AUTORELEASE ([[NSBox alloc]
                               initWithFrame:NSMakeRect (0, 0, ISWindowWidth,
                                                         1)]);
  NSEnumerator *e = [buttons reverseObjectEnumerator];
  NSButton *b;
  CGFloat x = ISWindowWidth - ISMarginX;

  [line setBoxType:NSBoxSeparator];
  [line setTitlePosition:NSNoTitle];
  [foot addSubview:line];
  while ((b = [e nextObject]) != nil)
    {
      x -= NSWidth ([b frame]);
      [b setFrameOrigin:NSMakePoint (x, floor ((ISFootHeight
                                                - ISButtonHeight) / 2) + 2)];
      [foot addSubview:b];
      x -= 12;
    }
  return foot;
}

/* The app's icon beside a title and a line under it (Installing, and
   the screens after it). */
- (NSView *)headerWithTitle:(NSString *)title subtitle:(NSString *)subtitle
                      badge:(ISBadge)badge width:(CGFloat)width
{
  ISFlippedView *head = AUTORELEASE ([[ISFlippedView alloc]
                                       initWithFrame:NSMakeRect
                                         (ISMarginX, ISMarginTop, width,
                                          68)]);
  ISIconView *icon = AUTORELEASE ([[ISIconView alloc]
                                    initWithFrame:NSMakeRect (0, 0, 68,
                                                              68)]);
  CGFloat x = 68 + 18;
  NSTextField *label;

  [icon setBadge:badge];
  [head addSubview:icon];
  [head addSubview:ISLabel (NSMakeRect (x, 4, width - x, 26), title,
                            ISTitleFont ())];
  if (subtitle != nil)
    {
      label = ISLabel (NSMakeRect (x, 32, width - x, 36), subtitle, nil);
      [[label cell] setWraps:YES];
      [label setTextColor:ISSecondaryColor ()];
      [head addSubview:label];
    }
  return head;
}

/* ---- the screens ---- */

- (NSView *)welcomeView
{
  ISFlippedView *view = AUTORELEASE ([[ISFlippedView alloc]
                                       initWithFrame:[content bounds]]);
  CGFloat width = ISWindowWidth - 2 * ISMarginX, y = ISMarginTop + 6;
  NSImageView *icon;
  NSTextField *label;

  icon = AUTORELEASE ([[NSImageView alloc]
                        initWithFrame:NSMakeRect (floor ((ISWindowWidth
                                                          - 72) / 2),
                                                  y, 72, 72)]);
  [icon setImage:[NSApp applicationIconImage]];
  [icon setImageScaling:NSScaleProportionally];
  [icon setEditable:NO];
  [view addSubview:icon];
  y += 72 + 14;
  label = ISLabel (NSMakeRect (ISMarginX, y, width, 26),
                   @"Welcome to NextBSD", ISTitleFont ());
  [label setAlignment:NSCenterTextAlignment];
  [view addSubview:label];
  y += 30;
  label = ISLabel (NSMakeRect (ISMarginX, y, width, 40),
                   [probe isInstalledSystem]
                   ? @"NextBSD is already installed. Install it on another "
                     @"disk to make a copy of this system."
                   : @"Install NextBSD on this computer.", nil);
  [label setAlignment:NSCenterTextAlignment];
  [[label cell] setWraps:YES];
  [label setTextColor:ISSecondaryColor ()];
  [view addSubview:label];

  [view addSubview:[self footWithButtons:
      [NSArray arrayWithObject:[self button:@"Install"
                                     action:@selector (welcomeInstall:)
                                    primary:YES]]]];
  return view;
}

- (NSView *)diskView
{
  ISFlippedView *view = AUTORELEASE ([[ISFlippedView alloc]
                                       initWithFrame:[content bounds]]);
  CGFloat width = ISWindowWidth - 2 * ISMarginX, y = ISMarginTop;
  NSEnumerator *e = [disks objectEnumerator];
  ISDisk *disk;
  BOOL any = NO;
  NSScrollView *scroll;
  NSTableColumn *column;
  NSTextField *label;
  NSButton *next;

  while ((disk = [e nextObject]) != nil)
    any |= [self isUsable:disk];

  [view addSubview:ISLabel (NSMakeRect (ISMarginX, y, width, 26),
                            @"Choose a disk", ISTitleFont ())];
  y += 26;
  label = ISLabel (NSMakeRect (ISMarginX, y, width, 20),
                   @"Everything on the selected disk will be erased.", nil);
  [label setTextColor:ISSecondaryColor ()];
  [view addSubview:label];
  y += 20 + 14;

  scroll = AUTORELEASE ([[NSScrollView alloc]
                          initWithFrame:NSMakeRect (ISMarginX, y, width,
                                                    any ? ISListTall
                                                        : ISListShort)]);
  [scroll setHasVerticalScroller:YES];
  [scroll setBorderType:NSBezelBorder];
  table = AUTORELEASE ([[NSTableView alloc]
                         initWithFrame:[[scroll contentView] bounds]]);
  [table setHeaderView:nil];
  [table setCornerView:nil];
  [table setRowHeight:30];
  if ([table respondsToSelector:@selector (setGridStyleMask:)])
    [table setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
  else
    [table setDrawsGrid:NO];
  [table setAllowsEmptySelection:YES];
  [table setAllowsMultipleSelection:NO];
  column = AUTORELEASE ([[NSTableColumn alloc] initWithIdentifier:@"icon"]);
  [column setWidth:34];
  [column setMinWidth:34];
  [column setMaxWidth:34];
  [column setDataCell:AUTORELEASE ([[NSImageCell alloc] init])];
  [column setEditable:NO];
  [table addTableColumn:column];
  column = AUTORELEASE ([[NSTableColumn alloc] initWithIdentifier:@"name"]);
  [column setWidth:width - 34 - 170 - 24];
  [column setEditable:NO];
  [column setDataCell:AUTORELEASE ([[ISCenteredCell alloc] init])];
  [table addTableColumn:column];
  column = AUTORELEASE ([[NSTableColumn alloc] initWithIdentifier:@"note"]);
  [column setWidth:170];
  [column setEditable:NO];
  [column setDataCell:AUTORELEASE ([[ISCenteredCell alloc] init])];
  [[column dataCell] setAlignment:NSRightTextAlignment];
  [[column dataCell] setFont:[NSFont systemFontOfSize:11.5]];
  [table addTableColumn:column];
  [table setDataSource:(id)self];
  [table setDelegate:(id)self];
  [scroll setDocumentView:table];
  [view addSubview:scroll];
  y += NSHeight ([scroll frame]) + 16;

  if (!any)
    {
      NSBox *box = AUTORELEASE ([[NSBox alloc]
                                  initWithFrame:NSMakeRect (ISMarginX, y,
                                                            width, 44)]);
      NSImageView *warn;
      NSView *inside;

      [box setTitlePosition:NSNoTitle];
      [box setBorderType:NSBezelBorder];
      [box setContentViewMargins:NSZeroSize];
      inside = [box contentView];
      warn = AUTORELEASE ([[NSImageView alloc]
                            initWithFrame:NSMakeRect (12, floor ((NSHeight
                                                                  ([inside frame])
                                                                  - 18) / 2),
                                                      18, 18)]);
      [warn setImage:ISWarningImage ()];
      [warn setEditable:NO];
      [inside addSubview:warn];
      label = ISLabel (NSMakeRect (40, floor ((NSHeight ([inside frame])
                                               - 20) / 2), width - 52, 20),
                       [probe isInstalledSystem]
                       ? @"Connect another disk to install NextBSD on it."
                       : [NSString stringWithFormat:
                            @"No disk is big enough. NextBSD needs a disk "
                            @"of at least %ld GB.", ISNeedGB ([probe need])],
                       nil);
      [inside addSubview:label];
      [view addSubview:box];
    }

  next = [self button:@"Next" action:@selector (next:) primary:YES];
  [view addSubview:[self footWithButtons:
      [NSArray arrayWithObjects:[self button:@"Back"
                                      action:@selector (back:)
                                     primary:NO], next, nil]]];
  [table reloadData];
  [self updateNext];
  return view;
}

- (NSView *)installingView
{
  ISFlippedView *view = AUTORELEASE ([[ISFlippedView alloc]
                                       initWithFrame:[content bounds]]);
  CGFloat width = ISWindowWidth - 2 * ISMarginX, y;

  [view addSubview:[self headerWithTitle:@"Installing NextBSD"
                                subtitle:@"This takes a few minutes."
                                   badge:ISBadgeNone
                                   width:width]];
  y = ISMarginTop + 68 + 26;
  bar = AUTORELEASE ([[ISProgressBar alloc]
                       initWithFrame:NSMakeRect (ISMarginX, y, width, 14)]);
  [bar setDoubleValue:1];
  [view addSubview:bar];
  y += 14 + 6;
  statusText = ISLabel (NSMakeRect (ISMarginX, y, width / 2, 18),
                        @"Preparing the disk…",
                        [NSFont systemFontOfSize:12]);
  [statusText setTextColor:ISSecondaryColor ()];
  [view addSubview:statusText];
  remainingText = ISLabel (NSMakeRect (ISMarginX + width / 2, y, width / 2,
                                       18),
                           @"Calculating time remaining…",
                           [NSFont systemFontOfSize:12]);
  [remainingText setAlignment:NSRightTextAlignment];
  [remainingText setTextColor:ISSecondaryColor ()];
  [view addSubview:remainingText];
  return view;
}

- (NSView *)failedView
{
  ISFlippedView *view = AUTORELEASE ([[ISFlippedView alloc]
                                       initWithFrame:[content bounds]]);

  [view addSubview:[self headerWithTitle:@"NextBSD couldn’t be installed"
                                subtitle:@"Nothing on the disk can be used. "
                                         @"Try again, or choose another disk."
                                   badge:ISBadgeWarning
                                   width:ISWindowWidth - 2 * ISMarginX]];
  [view addSubview:[self footWithButtons:
      [NSArray arrayWithObjects:
                 [self button:@"Choose Another Disk"
                       action:@selector (chooseAnotherDisk:)
                      primary:NO],
                 [self button:@"Try Again" action:@selector (next:)
                      primary:YES], nil]]];
  return view;
}

- (NSView *)doneView
{
  ISFlippedView *view = AUTORELEASE ([[ISFlippedView alloc]
                                       initWithFrame:[content bounds]]);

  NSString *took = nil;
  long secs = (long) round (installSeconds);

  /* How long it took (nextbsd/nextbsd#426), measured here from the start
     to the helper reporting it done. */
  if (installSeconds >= 0)
    took = secs < 60
      ? [NSString stringWithFormat:@"The installation took %ld second%s.",
                  secs, secs == 1 ? "" : "s"]
      : [NSString stringWithFormat:@"The installation took %ld min %ld s.",
                  secs / 60, secs % 60];
  [view addSubview:[self headerWithTitle:@"NextBSD is installed"
                                subtitle:took
                                   badge:ISBadgeDone
                                   width:ISWindowWidth - 2 * ISMarginX]];
  /* As nextbsd-installer: restart into it, or turn the computer off. */
  [view addSubview:[self footWithButtons:
      [NSArray arrayWithObjects:
        [self button:@"Shut Down" action:@selector (shutDown:) primary:NO],
        [self button:@"Restart" action:@selector (restart:) primary:YES],
        nil]]];
  return view;
}

/* ---- disks ---- */

- (BOOL)isUsable:(ISDisk *)disk
{
  return ![disk isMedia] && [disk bytes] >= [probe need];
}

- (NSString *)noteForDisk:(ISDisk *)disk
{
  if ([disk isMedia])
    return [probe isInstalledSystem] ? @"This is the current system"
                                     : @"This is the installer";
  if ([disk bytes] < [probe need])
    return @"Too small";
  return @"";
}

- (ISDisk *)chosenDisk
{
  NSEnumerator *e = [disks objectEnumerator];
  ISDisk *disk;

  while ((disk = [e nextObject]) != nil)
    if ([[disk device] isEqual:chosen] && [self isUsable:disk])
      return disk;
  return nil;
}

/* A new answer from the probe: the list follows the disks as they come
   and go, keeping the choice while its disk is there. */
- (void)takeProbe:(ISProbe *)answer
{
  NSEnumerator *e;
  ISDisk *disk;
  NSUInteger i;

  if (![answer isValid])
    return;
  ASSIGN (probe, answer);
  ASSIGN (disks, [answer disks]);
  if ([self chosenDisk] == nil)
    {
      DESTROY (chosen);
      e = [disks objectEnumerator];
      while ((disk = [e nextObject]) != nil)
        if ([self isUsable:disk])
          {
            ASSIGN (chosen, [disk device]);
            break;
          }
    }
  if (table != nil)
    {
      BOOL any = NO;

      e = [disks objectEnumerator];
      while ((disk = [e nextObject]) != nil)
        any |= [self isUsable:disk];
      /* Whether the warning shows changes the layout. */
      if (any != (NSHeight ([[table enclosingScrollView] frame])
                  == ISListTall))
        {
          [self showScreen:ISScreenDisk];
          return;
        }
      [table reloadData];
      for (i = 0; i < [disks count]; i++)
        if ([[[disks objectAtIndex:i] device] isEqual:chosen])
          [table selectRowIndexes:[NSIndexSet indexSetWithIndex:i]
             byExtendingSelection:NO];
      if (chosen == nil)
        [table deselectAll:self];
      [self updateNext];
    }
}

- (void)refresh:(NSTimer *)timer
{
  if (probeTask != nil)
    return;
  ASSIGN (probeTask, [ISProbe probeTask]);
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector (probeDone:)
             name:NSFileHandleReadToEndOfFileCompletionNotification
           object:[[probeTask standardOutput] fileHandleForReading]];
  NS_DURING
    [probeTask launch];
    [[[probeTask standardOutput] fileHandleForReading]
        readToEndOfFileInBackgroundAndNotify];
  NS_HANDLER
    [[NSNotificationCenter defaultCenter]
        removeObserver:self
                  name:NSFileHandleReadToEndOfFileCompletionNotification
                object:nil];
    DESTROY (probeTask);
  NS_ENDHANDLER
}

- (void)probeDone:(NSNotification *)note
{
  NSData *data = [[note userInfo] objectForKey:NSFileHandleNotificationDataItem];

  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:NSFileHandleReadToEndOfFileCompletionNotification
              object:[note object]];
  [probeTask waitUntilExit];
  DESTROY (probeTask);
  if (screen == ISScreenDisk && data != nil)
    [self takeProbe:[ISProbe probeWithOutput:data]];
}

- (void)stopRefreshing
{
  [refreshTimer invalidate];
  refreshTimer = nil;
}

- (void)updateNext
{
  NSButtonCell *next = [window defaultButtonCell];

  if (screen == ISScreenDisk && next != nil)
    [next setEnabled:[self chosenDisk] != nil];
}

/* ---- actions ---- */

- (void)welcomeInstall:(id)sender
{
  [self takeProbe:[ISProbe probe]];
  [self showScreen:ISScreenDisk];
  [self takeProbe:probe];
}

- (void)back:(id)sender
{
  [self showScreen:ISScreenWelcome];
}

- (void)chooseAnotherDisk:(id)sender
{
  [self showScreen:ISScreenDisk];
  [self refresh:nil];
}

/* Next, and Try Again: an administrator allows it, then the helper
   erases the disk and installs. */
- (void)next:(id)sender
{
  ISDisk *disk = [self chosenDisk];
  BOOL copy = [probe isInstalledSystem];
  NBAuthorization *auth;
  NSString *reason;
  int status;

  if (disk == nil)
    {
      [self showScreen:ISScreenDisk];
      return;
    }
  reason = [NSString stringWithFormat:
               copy ? @"erase “%@” and copy this system onto it"
                    : @"erase “%@” and install NextBSD on it",
               [disk model]];
  auth = [NBAuthorization authorizationWithRight:ISRight];
  if (![NBAuthorizationPanel obtainAuthorization:auth reason:reason
                                       forWindow:window])
    return;
  status = NBHelperInstallStart ([[auth externalForm] bytes],
                                 [[disk device] UTF8String],
                                 copy ? SH_INSTALL_COPY : SH_INSTALL_IMAGE);
  if (status != NBAuthorizationOK)
    {
      NSRunAlertPanel (ISTitle, @"%@", @"OK", nil, nil,
                       status == NBAuthorizationInvalid
                       ? @"This disk can't be used. Choose another disk."
                       : [NBAuthorization messageForStatus:status]);
      [self showScreen:ISScreenDisk];
      [self refresh:nil];
      return;
    }

  lastPercent = 0;
  misses = 0;
  copyStart = 0;
  installStart = [NSDate timeIntervalSinceReferenceDate];
  installSeconds = -1;
  [self showScreen:ISScreenInstalling];
  progressTimer = [NSTimer scheduledTimerWithTimeInterval:ISProgressSeconds
                                                   target:self
                                                 selector:@selector (poll:)
                                                 userInfo:nil
                                                  repeats:YES];
}

- (void)poll:(NSTimer *)timer
{
  static NSString *const phases[] = {
    @"Preparing the disk…", @"Copying NextBSD…",
    @"Setting up…", @"Finishing…"
  };
  int state, percent, phase, status;

  status = NBHelperInstallProgress (&state, &percent, &phase);
  if (status != NBAuthorizationOK || state == SH_INSTALL_IDLE)
    {
      /* The helper gone, or it no longer knows the install. */
      if (++misses < ISMaxMisses)
        return;
      state = SH_INSTALL_FAILED;
    }
  else
    misses = 0;

  if (state == SH_INSTALL_DONE || state == SH_INSTALL_FAILED)
    {
      [progressTimer invalidate];
      progressTimer = nil;
      installSeconds = [NSDate timeIntervalSinceReferenceDate] - installStart;
      [self showScreen:state == SH_INSTALL_DONE ? ISScreenDone
                                                : ISScreenFailed];
      return;
    }
  if (percent > lastPercent)
    lastPercent = percent;
  [bar setDoubleValue:MAX (1, lastPercent)];
  if (phase >= 0 && phase <= SH_INSTALL_FINISH
      && ![[statusText stringValue] isEqual:phases[phase]])
    [statusText setStringValue:phases[phase]];
  [remainingText setStringValue:[self remainingFor:lastPercent phase:phase]];
}

/* The copy is nearly all of it, and do-install.sh reports it by what has
   reached the disk, so the rate since the copy started says the rest. */
- (NSString *)remainingFor:(int)percent phase:(int)phase
{
  NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate], left;
  double rate;
  long minutes;

  if (phase > SH_INSTALL_COPYING)
    return @"Less than a minute remaining";
  if (phase < SH_INSTALL_COPYING)
    return @"Calculating time remaining…";
  if (copyStart == 0)
    {
      copyStart = now;
      copyStartPercent = percent;
    }
  if (now - copyStart < 8 || percent <= copyStartPercent)
    return @"Calculating time remaining…";
  rate = (percent - copyStartPercent) / (now - copyStart);
  left = MAX (0, ISCopyEnd - percent) / rate + ISAfterCopySeconds;
  if (left < 60)
    return @"Less than a minute remaining";
  minutes = (long) ceil (left / 60);
  return [NSString stringWithFormat:@"About %ld minute%@ remaining", minutes,
                   minutes > 1 ? @"s" : @""];
}

- (void)restart:(id)sender
{
  [self finish:NBHelperInstallRestart ()];
}

- (void)shutDown:(id)sender
{
  [self finish:NBHelperInstallShutdown ()];
}

/* The helper restarts or turns off the computer; Installer just quits. */
- (void)finish:(int)status
{
  if (status != NBAuthorizationOK)
    {
      NSRunAlertPanel (ISTitle, @"%@", @"OK", nil, nil,
                       [NBAuthorization messageForStatus:status]);
      return;
    }
  [NSApp terminate:self];
}

@end
