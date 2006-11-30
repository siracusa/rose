require 5.006;

use ExtUtils::MakeMaker;

WriteMakefile(NAME         => 'Rose::DB',
              PMLIBDIRS    => [ 'lib' ],
              VERSION_FROM => 'lib/Rose/DB.pm',
              ($^O =~ /darwin/i ?
               (dist => { DIST_CP => 'cp' }) : ()), # Avoid Mac OS X ._* files
              PREREQ_PM =>
              {
                'DBI'                     => 0,
                'Clone::PP'               => 0,
                'Bit::Vector::Overload'   => 6.4,
                'DateTime::Format::Pg'    => 0.11,
                'DateTime::Format::MySQL' => 0,
                'DateTime::Duration'      => 0,
                'Test::More'              => 0,
                'Rose::Object'            => 0.82,
                'Rose::DateTime::Util'    => 0.532,
                'Time::Clock'             => 0,
                'SQL::ReservedWords'      => 0,
              },
              clean => { FILES => "t/*.db" });
