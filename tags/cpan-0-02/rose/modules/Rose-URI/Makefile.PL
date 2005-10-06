require 5.006;

use ExtUtils::MakeMaker;

WriteMakefile(NAME         => 'Rose::URI',
              PMLIBDIRS    => [ 'lib' ],
              VERSION_FROM => 'lib/Rose/URI.pm',
              PREREQ_PM =>
              {
                Rose::Object => '0.015',
                overload     => 0,
                URI          => 0,
                URI::Escape  => 0,
              });
