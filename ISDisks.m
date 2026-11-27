/*
 * Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 */

#import "ISDisks.h"
#import <GNUstepBase/GNUstep.h>

#include <stdlib.h>

static NSString *const ISLibexecDefault = @"/usr/libexec/nextbsd-installer";

@implementation ISVolume

- (id)initWithLabel:(NSString *)label size:(NSString *)size
               type:(NSString *)type note:(NSString *)note
{
  if ((self = [super init]) == nil)
    return nil;
  if ([label length] > 0 && ![label isEqual:@"(unlabeled)"])
    ASSIGN (_label, label);
  ASSIGN (_size, size);
  ASSIGN (_type, type);
  ASSIGN (_note, note);
  return self;
}

- (void)dealloc
{
  RELEASE (_label);
  RELEASE (_size);
  RELEASE (_type);
  RELEASE (_note);
  [super dealloc];
}

- (NSString *)name
{
  return _label != nil ? _label : @"Partition";
}

- (NSString *)sizeString
{
  NSUInteger n = [_size length];
  unichar u = n > 0 ? [_size characterAtIndex:n - 1] : 0;
  NSString *unit = nil;

  switch (u)
    {
    case 'K': unit = @"KB"; break;
    case 'M': unit = @"MB"; break;
    case 'G': unit = @"GB"; break;
    case 'T': unit = @"TB"; break;
    case 'B': return [NSString stringWithFormat:@"%@ bytes",
                               [_size substringToIndex:n - 1]];
    }
  if (unit == nil)
    return _size;
  return [NSString stringWithFormat:@"%@ %@",
                   [_size substringToIndex:n - 1], unit];
}

- (NSString *)kindString
{
  NSDictionary *names = [NSDictionary dictionaryWithObjectsAndKeys:
    @"ZFS", @"zfs",
    @"UFS", @"ufs",
    @"FAT", @"msdosfs",
    @"Boot code", @"freebsd-boot",
    @"Swap", @"freebsd-swap",
    @"NTFS", @"ntfs",
    @"Windows recovery", @"ms-recovery",
    @"Windows reserved", @"ms-reserved",
    @"Linux", @"linux-data",
    @"Linux swap", @"linux-swap",
    @"APFS", @"apple-apfs",
    @"HFS+", @"apple-hfs",
    nil];
  NSString *kind = [names objectForKey:_type];
  NSRange r;

  if (kind == nil)
    kind = [_type length] > 0 ? _type : @"Unknown";
  /* "(zpool: NextBSD)" -> "ZFS (pool NextBSD)" */
  r = [_note rangeOfString:@"zpool: "];
  if (r.location != NSNotFound)
    {
      NSString *pool = [_note substringFromIndex:NSMaxRange (r)];

      if ([pool hasSuffix:@")"])
        pool = [pool substringToIndex:[pool length] - 1];
      return [NSString stringWithFormat:@"%@ (pool %@)", kind, pool];
    }
  return kind;
}

@end

@implementation ISDisk

- (id)initWithDevice:(NSString *)device model:(NSString *)model
               bytes:(unsigned long long)bytes isMedia:(BOOL)isMedia
{
  if ((self = [super init]) == nil)
    return nil;
  ASSIGN (_device, device);
  ASSIGN (_model, model);
  _bytes = bytes;
  _isMedia = isMedia;
  _volumes = [NSMutableArray new];
  return self;
}

- (void)dealloc
{
  RELEASE (_device);
  RELEASE (_model);
  RELEASE (_volumes);
  [super dealloc];
}

- (NSArray *)volumes
{
  return _volumes;
}

- (void)addVolume:(ISVolume *)volume
{
  [_volumes addObject:volume];
}

- (NSString *)device
{
  return _device;
}

- (NSString *)model
{
  return _model;
}

- (unsigned long long)bytes
{
  return _bytes;
}

- (BOOL)isMedia
{
  return _isMedia;
}

- (BOOL)isUSB
{
  return [_device hasPrefix:@"da"];
}

- (NSString *)sizeString
{
  double gb = _bytes / 1e9;

  if (gb >= 999.5)
    {
      double tb = gb / 1000;

      if (tb < 10 && tb - (long) tb >= 0.05 && tb - (long) tb < 0.95)
        return [NSString stringWithFormat:@"%.1f TB", tb];
      return [NSString stringWithFormat:@"%.0f TB", tb];
    }
  return [NSString stringWithFormat:@"%.0f GB", gb];
}

@end

@implementation ISProbe

+ (NSString *)libexec
{
  NSString *dir = [[[NSProcessInfo processInfo] environment]
                    objectForKey:@"NEXTBSD_INSTALLER_LIBEXEC"];

  return [dir length] > 0 ? dir : ISLibexecDefault;
}

+ (NSTask *)probeTask
{
  NSTask *task = AUTORELEASE ([NSTask new]);
  NSMutableDictionary *env = [NSMutableDictionary
                               dictionaryWithDictionary:
                                 [[NSProcessInfo processInfo] environment]];

  /* The tools it calls live in /sbin and /usr/sbin. */
  [env setObject:@"/sbin:/usr/sbin:/bin:/usr/bin" forKey:@"PATH"];
  [task setLaunchPath:[[self libexec]
                        stringByAppendingPathComponent:@"probe-disks.sh"]];
  [task setArguments:[NSArray array]];
  [task setEnvironment:env];
  [task setStandardInput:[NSFileHandle fileHandleWithNullDevice]];
  [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
  [task setStandardOutput:[NSPipe pipe]];
  return task;
}

+ (ISProbe *)probe
{
  NSTask *task = [self probeTask];
  NSData *data;

  NS_DURING
    [task launch];
  NS_HANDLER
    return AUTORELEASE ([ISProbe new]);
  NS_ENDHANDLER
  data = [[[task standardOutput] fileHandleForReading] readDataToEndOfFile];
  [task waitUntilExit];
  return [self probeWithOutput:data];
}

+ (ISProbe *)probeWithOutput:(NSData *)output
{
  ISProbe *probe = AUTORELEASE ([ISProbe new]);
  NSString *text = AUTORELEASE ([[NSString alloc]
                                  initWithData:output
                                      encoding:NSUTF8StringEncoding]);
  NSMutableArray *disks = [NSMutableArray array];
  NSEnumerator *e = [[text componentsSeparatedByString:@"\n"]
                      objectEnumerator];
  NSString *line;
  BOOL system = NO;

  /* The records are documented in probe-disks.sh. */
  while ((line = [e nextObject]) != nil)
    {
      NSArray *f = [line componentsSeparatedByString:@"\t"];
      NSString *kind = [f objectAtIndex:0];

      if ([kind isEqual:@"SYSTEM"] && [f count] >= 2)
        {
          probe->_installedSystem = [[f objectAtIndex:1]
                                      isEqual:@"installed"];
          system = YES;
        }
      else if ([kind isEqual:@"NEED"] && [f count] >= 2)
        probe->_need = strtoull ([[f objectAtIndex:1] UTF8String], NULL, 10);
      else if ([kind isEqual:@"DISK"] && [f count] >= 6)
        {
          ISDisk *disk = [[ISDisk alloc]
                           initWithDevice:[f objectAtIndex:1]
                                    model:[f objectAtIndex:3]
                                    bytes:strtoull ([[f objectAtIndex:5]
                                                      UTF8String], NULL, 10)
                                  isMedia:![[f objectAtIndex:4]
                                             isEqual:@"0"]];
          [disks addObject:disk];
          RELEASE (disk);
        }
      else if ([kind isEqual:@"VOL"] && [f count] >= 5)
        {
          /* A partition of the disk named before it. */
          ISDisk *disk = [disks lastObject];
          ISVolume *volume;

          if (disk == nil
              || ![[disk device] isEqual:[f objectAtIndex:1]])
            continue;
          volume = [[ISVolume alloc]
                     initWithLabel:[f objectAtIndex:2]
                              size:[f objectAtIndex:3]
                              type:[f objectAtIndex:4]
                              note:[f count] >= 6 ? [f objectAtIndex:5]
                                                  : @""];
          [disk addVolume:volume];
          RELEASE (volume);
        }
    }
  ASSIGN (probe->_disks, disks);
  probe->_valid = system && probe->_need > 0;
  return probe;
}

- (void)dealloc
{
  RELEASE (_disks);
  [super dealloc];
}

- (BOOL)isValid
{
  return _valid;
}

- (NSArray *)disks
{
  return _disks != nil ? _disks : [NSArray array];
}

- (BOOL)isInstalledSystem
{
  return _installedSystem;
}

- (unsigned long long)need
{
  return _need;
}

@end
