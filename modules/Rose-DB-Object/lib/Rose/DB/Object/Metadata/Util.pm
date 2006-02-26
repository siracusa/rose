package Rose::DB::Object::Metadata::Util;

use strict;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK   = qw(perl_hashref perl_quote_key perl_quote_value);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

our $DEFAULT_PERL_INDENT = 4;
our $DEFAULT_PERL_BRACES = 'k&r';

our $VERSION = '0.01';

sub perl_hashref
{
  my(%args) = (@_ == 1 ? (hash => $_[0]) : @_);

  my $inline = defined $args{'inline'} ? $args{'inline'} : 1;
  my $indent = defined $args{'indent'} ? $args{'indent'} : $DEFAULT_PERL_INDENT;
  my $braces = defined $args{'braces'} ? $args{'braces'} : $DEFAULT_PERL_BRACES;
  my $sort_keys = $args{'sort_keys'} || sub { lc $_[0] cmp lc $_[1] };

  my $hash = $args{'hash'};

  $indent = ' ' x $indent;    

  my @pairs;

  foreach my $key (sort { $sort_keys->($a, $b) } keys %$hash)
  {
    push(@pairs, perl_quote_key($key) . ' => ' . 
                 perl_quote_value($hash->{$key}));
  }

  return $inline ?
    '{ ' . join(', ', @pairs) . ' }' :
    "{\n" . join(",\n", map { "$indent$_" } @pairs) . ",\n}";
}

sub perl_quote_key
{
  my($key) = shift;

  for($key)
  {
    s/'/\\'/g    if(/'/);    
    $_ = "'$_'"  if(/\W/);
  }

  return $key;
}

sub perl_quote_value
{
  my($val) = shift;

  for($val)
  {
    s/'/\\'/g    if(/'/);
    $_ = "'$_'"  unless(/^(?:[1-9]\d*\.?\d*|\.\d+)$/);
  }

  return $val;
}

1;
