require 5.006;

use ExtUtils::MakeMaker;

use lib qw(../blib/lib lib );

use Apache::TestMM qw(test clean); # Enable 'make test'

# Accept the configs from command line
Apache::TestMM::filter_args();
Apache::TestMM::generate_script('t/TEST');

WriteMakefile(NAME         => 'Rose::WebApp',
              PMLIBDIRS    => [ 'lib' ],
              VERSION_FROM => 'lib/Rose/WebApp.pm',
              ($^O =~ /darwin/i ?
               (dist => { DIST_CP => 'cp' }) : ()), # Avoid Mac OS X ._* files
              clean =>
              {
                FILES => 't/TEST',
              },
              PREREQ_PM =>
              {
                'Rose::Object'     => 0,
                'Rose::URI'        => 0,
                'URI::Escape'      => 0,
                'Scalar::Util'     => 0,
                'Class::Delegator' => 0,
                'Apache::Test'     => 1.24,
                'Path::Class'      => 0,
                'HTML::Entities'   => 1.35,
              });
