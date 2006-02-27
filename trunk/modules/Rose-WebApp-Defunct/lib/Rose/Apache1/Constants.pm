package Rose::Apache1::Constants;

use strict;

use Carp();
use Apache::Constants(); 

our %EXPORT_TAGS = 
(
  common => 
  [ 
    'AUTH_REQUIRED',
    'DECLINED',
    'DONE',
    'FORBIDDEN',
    'NOT_FOUND',
    'OK',
    'REDIRECT',
    'SERVER_ERROR',
  ],
);

sub import
{
  my $class = shift;

  my $caller_class =  caller(0);
  my @to_export;

  foreach my $arg (@_)
  {
    if(index($arg, ':') == 0)
    {
      my $tag = substr($arg, 1);
      my $symbols = $EXPORT_TAGS{$tag} || Apache::Constants::EXPORT_TAGS{$tag}
        or Carp::croak "No such import tag '$arg'";

      no strict 'refs';
      foreach my $symbol (@$symbols)
      {
        *{"${caller_class}::$symbol"} = \&{"Apache::Constants::$symbol"};
      }
    }
    else
    {
      Carp::croak "No such apache constant: '$arg'"
        unless(defined &{"Apache::Constants::$arg"});

      no strict 'refs';
      *{"${caller_class}::$arg"} = \&{"Apache::Constants::$arg"};
    }
  }
}

1;
