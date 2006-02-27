package Rose::WebApp::Server::Notes::Apache1;

use strict;

use Apache;

use Rose::Object;
our @ISA = qw(Rose::Object);

our $AUTOLOAD;

our($Notes, %Notes);

our $Debug = 1;

sub new
{
  return $Notes  if($Notes);

  $Notes = shift->SUPER::new(@_);

  $Debug && warn join(' line ', (caller)[0,2]), " - Getting new $Notes\n";

  Apache->request->register_cleanup(sub 
  {
    $Debug && warn "Cleaning up $Notes\n";
    $Notes = undef;
    %Notes = ();
  });

  return $Notes;
}

sub clear
{
  $Debug && warn "$$ $_[0] clearing notes.\n";
  %Notes = ();
}

sub AUTOLOAD
{
  my($self) = $_[0];

  CAREFULLY:
  {
    local($1);  # Fix an obscure variable suicide problem

    $AUTOLOAD =~ /.*::(\w+)$/;

    #confess "$self: No such method: $AUTOLOAD"  unless(exists $self->{$1});

    MAKE_METHOD:
    {
      no strict 'refs';

      my($param) = $1;

      *{$AUTOLOAD} = sub
      {
        $Notes{$param} = $_[1]  if(@_ > 1);
        return $Notes{$param}
      };
    }
  }

  goto &$AUTOLOAD;
}

sub DESTROY { }

1;
