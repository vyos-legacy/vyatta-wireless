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

import os
import sys
import string
import subprocess


# Python equivalent for Perl die()
def die(error_message):
    raise Exception(error_message)


# A nicer version of os.system('iw reg get')
def get_iw():
    iw_cmd_get = ["iw", "reg", "get"]
    try:
        output = subprocess.check_output(iw_cmd_get)
        print('\n' + output.decode('UTF-8'))
    except subprocess.CalledProcessError as e:
        die(e)
    return


# A nicer version of os.system('iw reg set ' + code)
def set_iw(cmd = None):
    output = b''
    iw_cmd_set = ["iw", "reg", "set"]
    if cmd and type(cmd) is str:
        iw_cmd_set.append(cmd)
        try:
            output = subprocess.check_output(iw_cmd_set)
            get_iw()
        except subprocess.CalledProcessError as e:
            die(e)
    else:
        die("Invalid country code!")
    return


# void main(), this is where stuff happens
def main(code, mode):
    if mode is "set":
        # test if this may be a country code
        if not len(code) == 2: die("Invalid country code!")
        for c in code.upper():
            if c not in string.ascii_uppercase: die("Invalid country code!")
        # try to set regdom via 'iw reg set XX'
        set_iw(code.upper())
    elif mode is "get":
        get_iw()
    else:
        die(sys.argv[0] + ": Invalid mode: " + sys.argv[1])
    return


# Python main()
if __name__ == '__main__':
    try:
        if len(sys.argv) == 3 and sys.argv[1] == '--set':
            main(sys.argv[2], "set")
        else:
            main(None, "get")
    except Exception as e:
        print(e)
        sys.exit(1)


# vim: tabstop=4 shiftwidth=4 expandtab

