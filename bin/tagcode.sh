#!/bin/bash

## This is a little helper to tag the source code for easy browsing in vim et al.

ctags -f tags --recurse --totals --exclude=blib --exclude=.svn --exclude=.git --exclude=.gitignore --exclude='*~' --exclude='*swp' --languages='Perl' --langmap='Perl:+.t'
