package Rose::Apache::Notes;

use strict;

use Rose::Object;
our @ISA = qw(Rose::Object);

our $AUTOLOAD;

our($Notes, %Notes);

our $Debug = 0;

sub new { ($Notes) ? $Notes : shift->_new(@_) }

sub _new
{
  my($class) = shift;

  my $self =
  {
    _notes  => \%Notes,
    request => undef,
  };

  bless $self, $class;

  $self->init(@_);

  return $self;
}

sub clear
{
  $Debug && 
  warn "$$ $_[0] clearing notes.\n";
  %Notes = ();
}

sub AUTOLOAD
{
  my($self) = $_[0];

  FIX_ME: # Fix an obscure variable suicide problem
  {
    local($1); 

    $AUTOLOAD =~ /.*::(\w+)$/;

    #confess "$self: No such method: $AUTOLOAD"  unless(exists $self->{$1});

    MAKE_METHOD:
    {
      no strict 'refs';

      my($param) = $1;

      *{$AUTOLOAD} = sub
      {
        $_[0]->{'_notes'}{$param} = $_[1]  if(@_ > 1);
        return $_[0]->{'_notes'}{$param}
      };
    }
  }

  goto &$AUTOLOAD;
}

sub DESTROY { }

1;
