require 5.006;

use ExtUtils::MakeMaker;

WriteMakefile(NAME         => 'Rose::DB::Object',
              VERSION_FROM => 'lib/Rose/DB/Object.pm',
              dist => { DIST_CP => 'cp' }, # Avoid Mac OS X ._* files
              PREREQ_PM =>
              {
                'Cwd'                   => 0,
                'File::Path'            => 0,
                'File::Spec'            => 0,
                'DBI'                   => 1.40,
                'DateTime'              => 0,
                'Time::Clock'           => 0,
                'Test::More'            => 0,
                'Bit::Vector::Overload' => 0,
                'Scalar::Util'          => 0,
                'Math::BigInt'          => 1.77,
                'Clone'                 => 0.20,
                #'Scalar::Util::Clone'  => 0.04,
                'Rose::DateTime::Util'  => 0.53,
                'Rose::Object'          => 0.82,
                'Rose::DB'              => 0.727,
              },
              clean => { FILES => "t/*.db" });
