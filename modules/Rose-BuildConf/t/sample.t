#!/usr/bin/perl -w

use strict;

use File::Compare;
use FindBin qw($Bin);

use Test::More tests => 19;

BEGIN
{
  use_ok('Rose::BuildConf');
}

my $configure = "$Bin/configure";

Run_Command($configure, '--quiet', '--load-preset', 'dev');
ok(!compare("$Bin/perl/conf/presets/dev.conf", "$Bin/perl/conf/local.conf"), 'load dev');
ok(!compare("$Bin/build/one", "$Bin/compare/dev/one"), 'dev one');
ok(!compare("$Bin/build/other/two", "$Bin/compare/dev/two"), 'dev two');

Run_Command($configure, '--quiet', '--load-preset', 'john');
ok(!compare("$Bin/perl/conf/presets/john.conf", "$Bin/perl/conf/local.conf"), 'load john');
ok(!compare("$Bin/build/one", "$Bin/compare/john/one"), 'john one');
ok(!compare("$Bin/build/other/two", "$Bin/compare/john/two"), 'john two');

Run_Command($configure, '--quiet', '--install', '--force');
ok(!-e "$Bin/install/one.tmpl", 'install 1');
ok(!-e "$Bin/install/other/two.tmpl", 'install 2');
ok(!compare("$Bin/build/one", "$Bin/install/one"), 'install 3');
ok(!compare("$Bin/build/other/two", "$Bin/install/other/two"), 'install 4');
ok(!compare("$Bin/build/t2/t2.html", "$Bin/install/other/t2.html"), 'install 5');
ok(!compare("$Bin/build/t2/other/ot2.html", "$Bin/install/other/other/ot2.html"), 'install 6');

Run_Command($configure, '--quiet', '--load-preset', 'dev');
Run_Command($configure, '--quiet', '--install', '--force');
ok(!-e "$Bin/install/one.tmpl", 'install 2.1');
ok(!-e "$Bin/install/other/two.tmpl", 'install 2.2');
ok(!compare("$Bin/build/one", "$Bin/install/one"), 'install 2.3');
ok(!compare("$Bin/build/other/two", "$Bin/install/other/two"), 'install 2.4');
ok(!compare("$Bin/build/t2/t2.html", "$Bin/install/other/t2.html"), 'install 2.5');
ok(!compare("$Bin/build/t2/other/ot2.html", "$Bin/install/other/other/ot2.html"), 'install 2.6');

sub Run_Command
{
  my $ret = system(@_);
  $ret /= 256;
  die "Command '@_' failed and returned $ret\n"  unless($ret == 0);
}

