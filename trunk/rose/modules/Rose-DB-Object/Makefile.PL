require 5.006;

use ExtUtils::MakeMaker;

WriteMakefile(NAME         => 'Rose::DB::Object',
              VERSION_FROM => 'lib/Rose/DB/Object.pm',
              dist => { 'COMPRESS' => 'gzip' },
              PREREQ_PM =>
              {
                DateTime              => 0,
                Test::More            => 0,
                Bit::Vector::Overload => 0,
                Scalar::Util          => 0,
                Rose::DateTime::Util  => 0,
                Rose::Object          => '0.015',
                Rose::DB              => '0.0262',
              });
