require 5.006;

use ExtUtils::MakeMaker;

WriteMakefile(NAME         => 'Rose::DB',
              PMLIBDIRS    => [ 'lib' ],
              VERSION_FROM => 'lib/Rose/DB.pm',
              PREREQ_PM =>
              {
                DBI                     => 0,
                Bit::Vector::Overload   => '6.4',
                DateTime::Format::Pg    => 0.11,
                DateTime::Format::MySQL => 0,
                DateTime::Duration      => 0,
                Test::More              => 0,
                Rose::Object            => 0,
                Rose::DateTime::Util    => '0.52',
              },
              clean => { FILES => "t/*.db" });
