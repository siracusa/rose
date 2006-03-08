require 5.006;

use ExtUtils::MakeMaker;

eval { require DateTime };

unless($@)
{
  if($DateTime::VERSION < 0.20)
  {
    warn<<"EOF";

##
## *** WARNING: Ancient version of DateTime detected ***
##
## You appear to have DateTime version $DateTime::VERSION installed.  This
## is very old.  You should have DateTime version 0.20 at least.  Some
## tests may fail unless you upgrade DateTime.  The latest stable version
## is recommended.
##
##

EOF
  }
}

WriteMakefile('NAME'         => 'Rose::HTML::Objects',
              'PMLIBDIRS'    => [ 'lib' ],
              'VERSION_FROM' => 'lib/Rose/HTML/Objects.pm',
              'PREREQ_PM' =>
              {
                'Carp'           => 0,
                'Clone::PP'      => 0,
                'Email::Valid'   => 0,
                'HTML::Entities' => 0,
                'Image::Size'    => 0,
                'Scalar::Util'   => 0,
                'URI::Escape'    => 0,
                'Rose::Object'   => '0.015',
                'Rose::DateTime' => '0.0133',
                'Rose::URI'      => '0.021',
              });
