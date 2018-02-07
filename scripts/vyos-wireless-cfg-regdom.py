#!/usr/bin/env python3
# vim: tabstop=4 shiftwidth=4 expandtab
#
# Copyright (C) 2018 VyOS maintainers and contributors
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 or later as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
#
# This script makes persistent changes to the regulatory domain settings
# which are kept in files /etc/default/crda and /etc/modprobe.d/cfg80211.conf.
# A reboot is needed to activate the changes.
# This script does not call 'iw reg set XX', so active settings remain stable.
#
# Usage:    vyos-wireless-cfg-regdom.py ( <country-code> | --delete )
# Examples: vyos-wireless-cfg-regdom.py DE
#           vyos-wireless-cfg-regdom.py --delete
#

import os
import re
import sys
import string
import subprocess


# Constants
CFG80211_FILE   = "/etc/modprobe.d/cfg80211.conf"
#CFG80211_FILE   = "/tmp/cfg80211.conf"
CFG80211_STR    = "options cfg80211 ieee80211_regdom="
CFG80211_PAT    = "^(" + CFG80211_STR + ").."
CRDA_FILE       = "/etc/default/crda"
#CRDA_FILE       = "/tmp/crda"
CRDA_STR        = "REGDOMAIN="
CRDA_PAT        = "^(" + CRDA_STR + ").."


# Python equivalent for Perl die()
def die(error_message):
    raise Exception(error_message)


# Generic replace function
def replace_in_file(fname = None, fstring = "", fpattern = "", code = ""):
    new_flist = []
    fout = ""
    # if fname does not exist, create an empty file
    if not os.path.isfile(fname):
        open(fname, 'w').close()
    # read input file, store as list of lines
    with open(fname, "r") as f:
        flist = f.readlines()
    # pattern does not exist yet
    if not any(re.search(fpattern, line) for line in flist):
        new_flist.extend(flist)
        if code:
            new_flist.append(fstring + code.upper() + "\n")
    # pattern exists
    else:
        for line in flist:
            # did we hit a regdom line?
            if re.search(fpattern, line):
                # only append regdom line if country code was valid
                if code:
                    new_line = re.sub(r'' + fpattern, r'\1' + code, line.rstrip())
                    new_flist.append(new_line + "\n")
                # this is the "--delete" case, do not append anything
                else:
                    pass
            # always append unchanged non-regdom lines
            else:
                new_flist.append(line)
    # write new file contents
    for l in new_flist:
        fout += l
    with open(fname, "w+") as f:
        f.writelines(fout)
    return


# void main(), this is where stuff happens
def main(code):
    # test if the regdom settings shall be deleted
    if code == '--delete':
        # remove the "REGDOM=XX" line from CRDA_FILE
        replace_in_file(CRDA_FILE, '', CRDA_PAT, '')
        # delete CFG80211_FILE
        if os.path.exists(CFG80211_FILE):
            os.remove(CFG80211_FILE)
    # test if this may be a country code
    elif not len(code) == 2:
        die("Invalid country code!")
    else:
        for c in code.upper():
            if c not in string.ascii_uppercase: die("Invalid country code!")
        # rewrite CRDA_FILE
        replace_in_file(CRDA_FILE, CRDA_STR, CRDA_PAT, code.upper())
        # rewrite CFG80211_FILE
        replace_in_file(CFG80211_FILE, CFG80211_STR, CFG80211_PAT, code.upper())
    return


# Python main()
if __name__ == '__main__':
    try:
        if len(sys.argv) != 2 or sys.argv[1] in ["-h", "--help"]:
            die("Give country code (ISO/IEC 3166-1) or \"--delete\" as argument!")
        main(sys.argv[1])
    except Exception as e:
        print(e)
        sys.exit(1)

# vim: tabstop=4 shiftwidth=4 expandtab
