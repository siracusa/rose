require 5.006;

use ExtUtils::MakeMaker;

WriteMakefile(NAME         => 'Rose',
              PMLIBDIRS    => [ 'lib' ],
              VERSION_FROM => 'lib/Rose.pm',
              PREREQ_PM =>
              {
                'Test::More'          => 0,
                'Rose::Object'        => '0.013',
                'Rose::DB'            => '0.025',
                'Rose::DB::Object'    => '0.067',
                'Rose::DateTime'      => '0.0131',
                'Rose::URI'           => '0.012',
                'Rose::HTML::Objects' => '0.021',
              });
