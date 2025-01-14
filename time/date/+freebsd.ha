// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

// The filepath of the system's "localtime" file, typically a symlink to a TZif
// file under [[TZDB_PATH]].
export def LOCALTIME_PATH: str = "/etc/localtime";

// The filepath of the system's TZDB (Timezone Database) directory, a filetree
// of TZif (Time Zone Information Format) files and other related files.
export def TZDB_PATH: str = "/usr/share/zoneinfo";
