#!/usr/bin/perl

use Dancer;
use lib 'lib';
use Twarchiver::Routes::Home;
use Twarchiver::Routes::TweetAnalysis;
use Twarchiver::Routes::Graph;

set show_errors => 1;
dance;

