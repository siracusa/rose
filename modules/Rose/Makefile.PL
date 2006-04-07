require 5.006;

use ExtUtils::MakeMaker;

WriteMakefile(NAME         => 'Rose',
              PMLIBDIRS    => [ 'lib' ],
              VERSION_FROM => 'lib/Rose.pm',
              dist => { DIST_CP => 'cp' }, # Avoid Mac OS X ._* files
              PREREQ_PM =>
              {
                'Test::More'          => 0,
                'Rose::Object'        => '0.016',
                'Rose::DB'            => '0.032',
                'Rose::DB::Object'    => '0.50',
                'Rose::DateTime'      => '0.0134',
                'Rose::URI'           => '0.021',
                'Rose::HTML::Objects' => '0.30',
              });
