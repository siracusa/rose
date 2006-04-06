require 5.006;

use ExtUtils::MakeMaker;

eval { require Rose::DateTime::Util };

if($@)
{
  warn<<"EOF";

##
## WARNING: You are missing Rose::DateTime
##
## There is a circular dependency between Rose::Object and Rose::DateTime.
## Rose::Object will simply skip all tests that require Rose::DateTime, but
## you should really re-run "make test" after installing Rose::DateTime
## just to make sure everything works correctly.
##

EOF
}

WriteMakefile(NAME         => 'Rose::Object',
              PMLIBDIRS    => [ 'lib' ],
              VERSION_FROM => 'lib/Rose/Object.pm',
              DIST_CP      => 'cp', # Avoid Mac OS X ._* files
              PREREQ_PM =>
              {
                # This is a circular dependency...
                #Rose::DateTime => 0,
                Test::Simple => 0,
                Test::More   => 0,
              });
