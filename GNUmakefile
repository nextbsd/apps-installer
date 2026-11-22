# Copyright (C) 2026 Joseph Maloney <pkgdemonteam@gmail.com>
# SPDX-License-Identifier: BSD-2-Clause
#
# Installer.app: NextBSD installed on a disk, from the install image, or
# as a copy of the running system (nextbsd/nextbsd#670, epic #662). The
# install is the text installer's engine (nextbsd-userland
# src/nextbsd-installer: probe-disks.sh, do-install.sh), run as root by
# SettingsHelper; its client is Frameworks/NBSettings.

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES)
endif
include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = Installer
Installer_OBJC_FILES = main.m ISController.m ISDisks.m ISViews.m
Installer_HEADER_FILES = ISController.h ISDisks.h ISViews.h
Installer_RESOURCE_FILES = Resources/Installer.png
Installer_APPLICATION_ICON = Installer.png
Installer_OBJCFLAGS = -Wall -Wextra -Wno-unused-parameter
Installer_SUBPROJECTS = Frameworks/NBSettings
Installer_INCLUDE_DIRS = -IFrameworks/NBSettings -IFrameworks/NBSettings/mig

# NextBSD's system libraries live in /usr/lib/system: liblaunch and the
# Mach calls for the helper's client.
SYSTEM_LIBDIR = /usr/lib/system
ADDITIONAL_LDFLAGS += -L$(SYSTEM_LIBDIR) -Wl,-rpath,$(SYSTEM_LIBDIR)
Installer_GUI_LIBS += -llaunch -lsystem_kernel

include $(GNUSTEP_MAKEFILES)/application.make
