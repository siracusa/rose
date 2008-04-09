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

WriteMakefile(NAME         => 'Rose::HTML::Objects',
              PMLIBDIRS    => [ 'lib' ],
              VERSION_FROM => 'lib/Rose/HTML/Objects.pm',
              ($^O =~ /darwin/i ?
               (dist => { DIST_CP => 'cp' }) : ()), # Avoid Mac OS X ._* files
              PREREQ_PM =>
              {
                'DateTime'       => '0.20',
                'Carp'           => 0,
                'Clone::PP'      => 0,
                'Encode'         => 0,
                'Email::Valid'   => 0,
                'HTML::Entities' => 0,
                'Image::Size'    => 0,
                'URI::Escape'    => 0,
                'Scalar::Util'   => 0,
                # XXX: Can't use Scalar::Defer 0.11 (or possibly later) until some things
                # XXX: are sorted out.  See: http://rt.cpan.org/Ticket/Display.html?id=31039
                #'Scalar::Defer'  => 0,
                'Rose::Object'   => '0.85',
                'Rose::DateTime' => '0.532',
                'Rose::URI'      => '0.021',
              });
