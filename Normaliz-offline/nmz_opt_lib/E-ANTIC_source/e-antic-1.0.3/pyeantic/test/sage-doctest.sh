#!/usr/bin/env bash

######################################################################
#  This file is part of e-antic.
#
#        Copyright (C)      2019 Vincent Delecroix
#        Copyright (C) 2019-2021 Julian Rüth
#
#  e-antic is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or (at your
#  option) any later version.
#
#  e-antic is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with e-antic. If not, see <https://www.gnu.org/licenses/>.
#####################################################################

set -ex

# On macOS we cannot run `sage -tp` directly to run tests since that's a shell
# script and macOS will sanitize our DYLD_LIBRARY_PATH then. So we need to
# invoke the Python script `sage-runtests` with our `bin/python` script that
# sets up that variable properly.

# `sage-runtests` assumes that `sage-env-config` and `sage-env` have been
# sourced by the `sage` script already. However, not all systems (ArchLinux)
# ship `sage-env` and `sage-env-config`. So instead, we start sage directly,
# record the set environment variables and set them locally. This is a hack,
# but we could not find any better way to work around the paranoic measures in
# macOS.
OLD_PATH=$PATH
source <(sage -c 'import os;print("\n".join(["export %s='"'"%s"'"'"%(key, value) for (key, value) in os.environ.items()]))')
export PATH=$OLD_PATH

python `which sage-runtests` -p --long --force-lib /home/jule/proj/eskin/e-antic/pyeantic/test/../src/pyeantic
