require 5.006;

use ExtUtils::MakeMaker;

WriteMakefile(NAME         => 'Time::Clock',
              ($^O =~ /darwin/i ?
               (dist => { DIST_CP => 'cp' }) : ()), # Avoid Mac OS X ._* files
              PMLIBDIRS    => [ 'lib' ],
              VERSION_FROM => 'lib/Time/Clock.pm');
