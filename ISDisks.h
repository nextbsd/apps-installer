/*
 * Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * ISDisks: what the text installer's probe-disks.sh says
 * (/usr/libexec/nextbsd-installer, or $NEXTBSD_INSTALLER_LIBEXEC as the
 * text installer reads it): the disks, which one the running system
 * started from, the smallest usable size, and whether this is the
 * install image or an installed system. Installer reads it as the user;
 * SettingsHelper reads it again as root before it erases anything.
 */

#import <Foundation/Foundation.h>

/* A partition on a disk, as the text installer lists it under the disk:
 * what choosing the disk erases. */
@interface ISVolume : NSObject
{
  NSString *_label;		/* the GPT label, or nil */
  NSString *_size;		/* gpart's "260M", "238G" */
  NSString *_type;		/* "zfs", "msdosfs", "freebsd-boot" */
  NSString *_note;		/* "(zpool: NextBSD)", or "" */
}

- (id)initWithLabel:(NSString *)label size:(NSString *)size
               type:(NSString *)type note:(NSString *)note;
/* "EFI", or "Partition" when it has no label. */
- (NSString *)name;
/* "260 MB": gpart's size with the unit spelled out. */
- (NSString *)sizeString;
/* What's on it, in words: "ZFS (pool NextBSD)", "FAT", "Boot code". */
- (NSString *)kindString;

@end

@interface ISDisk : NSObject
{
  NSString *_device;		/* "nvd0", "da0", "md0" */
  NSString *_model;
  unsigned long long _bytes;
  BOOL _isMedia;
  NSMutableArray *_volumes;	/* ISVolume, in disk order */
}

- (NSString *)device;
- (NSString *)model;
- (unsigned long long)bytes;
/* The disk the running system started from: the installer's own disk,
 * or the current system's. */
- (BOOL)isMedia;
/* A USB disk (da), drawn as a stick. */
- (BOOL)isUSB;
/* "1 TB", "32 GB": decimal, as disks are sold. */
- (NSString *)sizeString;
/* Its partitions (ISVolume); empty when it has none. */
- (NSArray *)volumes;
- (void)addVolume:(ISVolume *)volume;

@end

@interface ISProbe : NSObject
{
  NSArray *_disks;
  BOOL _installedSystem;
  unsigned long long _need;
  BOOL _valid;
}

/* probe-disks.sh, ready to launch; its output is for
 * +probeWithOutput:. */
+ (NSTask *)probeTask;
+ (ISProbe *)probeWithOutput:(NSData *)output;
/* Both at once, waiting for it. */
+ (ISProbe *)probe;

/* The probe ran and said what the system is. */
- (BOOL)isValid;
- (NSArray *)disks;
/* An installed NextBSD (Installer copies it), not the install image. */
- (BOOL)isInstalledSystem;
/* The smallest usable disk, in bytes. */
- (unsigned long long)need;

@end
