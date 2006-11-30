require 5.006;

use ExtUtils::MakeMaker;

WriteMakefile(NAME         => 'Rose::BuildConf',
              PMLIBDIRS    => [ 'lib' ],
              VERSION_FROM => 'lib/Rose/BuildConf.pm',
              ($^O =~ /darwin/i ?
               (dist => { DIST_CP => 'cp' }) : ()), # Avoid Mac OS X ._* files
              PREREQ_PM =>
              {
                'Rose::Object'   => 0,
                'Tie::Hash'      => 0,
                'File::Spec'     => 0,                
                'File::Copy'     => 0,
                'File::Path'     => 0,
                'File::Basename' => 0,
                'File::Find'     => 0,
                'File::Compare'  => 0,
                'Getopt::Long'   => 0,
                'FindBin'        => 0,
                'Carp'           => 0,
              },
              clean => 
              {
                FILES => 't/build/one t/build/other/two t/install/[a-z]*' 
              });
