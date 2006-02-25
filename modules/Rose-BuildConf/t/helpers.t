#!/usr/bin/perl -w

use strict;

use Test::More tests => 18;

use FindBin qw($Bin);
use Rose::BuildConf::Helpers qw(:all);

BEGIN
{
  use_ok('Rose::BuildConf');
}

my $test_file = "$Bin/build/test";

foreach my $file ("$Bin/build/test", "$Bin/install/test")
{
  rmdir($test_file) or die "Cannot rmdir $test_file - $!"
    if(-d $test_file);

  unlink($test_file) or die "Cannot unlink $test_file - $!"
    if(-e $test_file);
}

my $bc = Rose::BuildConf->new(install_root => "$Bin/install",
                              build_root   => "$Bin/build");

#
# helper_make_path
#

helper_make_path($bc, $test_file);
ok(-d $test_file, 'helper_make_path 1');
rmdir($test_file);
ok(!-e $test_file, 'helper_make_path 2');

helper_make_path($bc, path => $test_file, mode => 0700);
ok(-d $test_file, 'helper_make_path 3');
my $mode = (stat($test_file))[2] & 07777;
is($mode, 0700, 'helper_make_path 4');
rmdir($test_file);
ok(!-e $test_file, 'helper_make_path 5');

#
# helper_check_executable
#

$test_file = "$Bin/install/test";

is(helper_check_executable($bc, value => $test_file), 0, 'helper_check_executable 1');

open(TEST, ">$test_file") or die "Could not create $test_file - $!";
is(helper_check_executable($bc, value => $test_file), 0, 'helper_check_executable 2');

chmod(0700, $test_file) or die "Could not chmod $test_file - $!";
is(helper_check_executable($bc, value => $test_file), 1, 'helper_check_executable 3');

unlink($test_file) or die "Could not unlink $test_file - $!";

$test_file = "$Bin/build/test";

is(helper_check_executable($bc, value => $test_file), 0, 'helper_check_executable 4');

open(TEST, ">$test_file") or die "Could not create $test_file - $!";
is(helper_check_executable($bc, value => $test_file), 0, 'helper_check_executable 5');

chmod(0700, $test_file) or die "Could not chmod $test_file - $!";
is(helper_check_executable($bc, value => $test_file), 1, 'helper_check_executable 6');

unlink($test_file) or die "Could not unlink $test_file - $!";

#
# helper_check_directory
#

$test_file = "$Bin/install/test";

is(helper_check_directory($bc, value => $test_file), 0, 'helper_check_directory 1');

mkdir($test_file) or die "Could not create $test_file - $!";
is(helper_check_directory($bc, value => $test_file), 1, 'helper_check_directory 2');

rmdir($test_file) or die "Could not rmdir $test_file - $!";

$test_file = "$Bin/build/test";

is(helper_check_directory($bc, value => $test_file), 0, 'helper_check_directory 3');

mkdir($test_file) or die "Could not create $test_file - $!";
is(helper_check_directory($bc, value => $test_file), 1, 'helper_check_directory 4');

rmdir($test_file) or die "Could not rmdir $test_file - $!";

#
# helper_host_ip
#

my($name, $aliases, $type, $length, $address) = gethostbyname('www.apple.com');

my @octets = unpack('CCCC', $address);
my $ip = join('.', @octets);

is(helper_host_ip('www.apple.com'), $ip, 'helper_host_ip 1');

is(helper_host_ip('17.112.152.32'), '17.112.152.32', 'helper_host_ip 1');
