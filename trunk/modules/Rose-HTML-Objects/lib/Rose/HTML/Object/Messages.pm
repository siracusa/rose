package Rose::HTML::Object::Messages;

use strict;

use Carp;

use base 'Rose::HTML::Object::Exporter';

our $VERSION = '0.550';

our $Debug = 0;

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar =>
  [
    'message_names_list',
    'message_id_to_name_map',
    'message_name_to_id_map',
  ],
);

BEGIN
{
  __PACKAGE__->message_names_list([]);
  __PACKAGE__->message_id_to_name_map({});
  __PACKAGE__->message_name_to_id_map({});
}

sub init_export_tags
{
  my($class) = shift;

  $class->export_tags
  (
    all    => $class->message_names_list,
    field  => [ grep { /^FIELD_/ } @{$class->message_names_list} ],
    form   => [ grep { /^FORM_/ } @{$class->message_names_list} ],
    date   => [ grep { /^DATE_|_(?:YEAR|MONTH|DAY)$/ }
                @{$class->message_names_list} ],
    time   => [ grep { /^TIME_|_(?:HOUR|MINUTE|SECOND)$/ } 
                @{$class->message_names_list} ],
    email  => [ grep { /^EMAIL_/ } @{$class->message_names_list} ],
    phone  => [ grep { /^PHONE_/ } @{$class->message_names_list} ],
    number => [ grep { /^NUM_/ } @{$class->message_names_list} ],
    set    => [ grep { /^SET_/ } @{$class->message_names_list} ],
    string => [ grep { /^STRING_/ } @{$class->message_names_list} ],
  );
}

sub import
{
  my($class) = shift;

  $class->use_private_messages;
  $class->init_export_tags;

  if($Rose::HTML::Object::Exporter::Target_Class)
  {
    $class->SUPER::import(@_);
  }
  else
  {
    local $Rose::HTML::Object::Exporter::Target_Class = (caller)[0];
    $class->SUPER::import(@_);
  }
}

our %Private;

sub use_private_messages
{
  my($class) = shift;

  unless($Private{$class})
  {
    $Private{$class} = 1;

    # Make private copies of inherited data structures 
    # (shallow copy is sufficient)
    $class->message_names_list([ @{$class->message_names_list} ]);
    $class->message_id_to_name_map({ %{$class->message_id_to_name_map} });
    $class->message_name_to_id_map({ %{$class->message_name_to_id_map} });
  }
}

sub message_id_exists   { defined $_[0]->message_id_to_name_map->{$_[1]} }
sub message_name_exists { defined $_[0]->message_name_to_id_map->{$_[1]} }

sub get_message_id
{
  my($class, $symbol) = @_;
  no strict 'refs';
  my $const = "${class}::$symbol";
  return &$const  if(defined &$const);
  return undef;
}

sub message_ids
{
  my($class) = shift;
  my $map = $class->message_id_to_name_map;

  return wantarray ? 
    (sort { $a <=> $b } keys %$map) : 
    [ sort { $a <=> $b } keys %$map ];
}

sub get_message_name { $_[0]->message_id_to_name_map->{$_[1]} }

sub add_message
{
  my($class, $name, $id) = @_;

  $class->use_private_messages;

  unless($class->imported($name))
  {
    if(exists $class->message_name_to_id_map->{$name} && 
       $class->message_name_to_id_map->{$name} != $id)
    {
      croak "Could not add message '$name' - a message with that name already exists ",
            '(', $class->message_name_to_id_map->{$name}, ')';
    }

    if(exists $class->message_id_to_name_map->{$id} &&
       $class->message_id_to_name_map->{$id} ne $name)
    {
      croak "Could not add message '$name' - a message with the id $id already exists ",
            '(', $class->message_id_to_name_map->{$id}, ')';
    }
  }

  unless(exists $class->message_name_to_id_map->{$name})
  {
    push(@{$class->message_names_list}, $name);
  }

  $class->message_id_to_name_map->{$id}   = $name;
  $class->message_name_to_id_map->{$name} = $id;

  return;
}

sub add_messages
{
  my($class) = shift;

  $class->use_private_messages;

  no strict 'refs';

  if(@_)
  {
    foreach my $name (@_)
    {
      $class->add_message($name, "${class}::$name"->());
    }
  }
  else
  {
    while(my($name, $thing) = each(%{"${class}::"}))
    {
      my $fq_name = "${class}::$name";

      next  unless(defined *{$fq_name}{'CODE'} && $name =~ /^[A-Z0-9_]+$/);

      my $code = $class->can($name);

      # Skip it if it's not a constant
      next  unless(defined prototype($code) && !length(prototype($code)));

      # Should not need this check?
      next  if($name =~ /^(BEGIN|DESTROY|AUTOLOAD|TIE.*)$/);

      $Debug && warn "$class ADD $name = ", $code->(), "\n";
      $class->add_message($name, $code->());
    }
  }
}

#
# Messages
#

use constant CUSTOM_MESSAGE => -1;

# Fields and labels
use constant FIELD_LABEL              => 1;
use constant FIELD_DESCRIPTION        => 2;
use constant FIELD_REQUIRED_GENERIC   => 4;
use constant FIELD_REQUIRED_LABELLED  => 5;
use constant FIELD_REQUIRED_SUBFIELD  => 6;
use constant FIELD_REQUIRED_SUBFIELDS => 7;
use constant FIELD_PARTIAL_VALUE      => 8;
use constant FIELD_INVALID_GENERIC    => 10;
use constant FIELD_INVALID_LABELLED   => 11;

use constant FIELD_LABEL_YEAR   => 10_000;
use constant FIELD_LABEL_MONTH  => 10_001;
use constant FIELD_LABEL_DAY    => 10_002;
use constant FIELD_LABEL_HOUR   => 10_003;
use constant FIELD_LABEL_MINUTE => 10_004;
use constant FIELD_LABEL_SECOND => 10_005;

use constant FIELD_ERROR_LABEL_YEAR   => 11_000;
use constant FIELD_ERROR_LABEL_MONTH  => 11_001;
use constant FIELD_ERROR_LABEL_DAY    => 11_002;
use constant FIELD_ERROR_LABEL_HOUR   => 11_003;
use constant FIELD_ERROR_LABEL_MINUTE => 11_004;
use constant FIELD_ERROR_LABEL_SECOND => 11_005;

use constant FIELD_ERROR_LABEL_MINIMUM_DATE => 11_006;
use constant FIELD_ERROR_LABEL_MAXIMUM_DATE => 11_007;

# Forms
use constant FORM_HAS_ERRORS => 100;

# Numerical messages
use constant NUM_INVALID_INTEGER          => 1300;
use constant NUM_INVALID_INTEGER_POSITIVE => 1301;
use constant NUM_NOT_POSITIVE_INTEGER     => 1302;
use constant NUM_BELOW_MIN                => 1303;
use constant NUM_ABOVE_MAX                => 1304;
use constant NUM_INVALID_NUMBER           => 1305;
use constant NUM_INVALID_NUMBER_POSITIVE  => 1306;
use constant NUM_NOT_POSITIVE_NUMBER      => 1307;

# String messages
use constant STRING_OVERFLOW => 1400;

# Date messages
use constant DATE_INVALID              => 1500;
use constant DATE_MIN_GREATER_THAN_MAX => 1501;

# Time messages
use constant TIME_INVALID         => 1550;
use constant TIME_INVALID_HOUR    => 1551;
use constant TIME_INVALID_MINUTE  => 1552;
use constant TIME_INVALID_SECONDS => 1553;
use constant TIME_INVALID_AMPM    => 1554;

# Email messages
use constant EMAIL_INVALID => 1600;

# Phone messages
use constant PHONE_INVALID => 1650;

# Set messages
use constant SET_INVALID_QUOTED_STRING => 1700;
use constant SET_PARSE_ERROR           => 1701;

BEGIN { __PACKAGE__->add_messages }

1;
