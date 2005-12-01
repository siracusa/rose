package Rose::DB::Object::Metadata::Column::Enum;

use strict;

use Rose::DB::Object::Metadata::Column::Integer;
our @ISA = qw(Rose::DB::Object::Metadata::Column::Integer);

our $VERSION = '0.55';

__PACKAGE__->add_common_method_maker_argument_names
(
  qw(allow_numbers)
);

foreach my $type (__PACKAGE__->available_method_types)
{
  __PACKAGE__->method_maker_type($type => 'enum');
}

sub type { 'enum' }

sub init_with_dbi_column_info
{
  my($self, $col_info) = @_;

  $self->SUPER::init_with_dbi_column_info($col_info);

  # XXX: extract valid values
  #if(defined $col_info->{'CHAR_OCTET_LENGTH'})
  #{
  #  $self->length($col_info->{'CHAR_OCTET_LENGTH'});
  #}

  return;
}

1;
