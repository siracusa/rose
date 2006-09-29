package Rose::HTML::Object::Messages;

use strict;

use Carp;

use base 'Rose::HTML::Object::Exporter';

our $VERSION = '0.531';

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

__PACKAGE__->export_tags
(
  all   => __PACKAGE__->message_names_list,
  field => [ grep { /^FIELD_/ } @{__PACKAGE__->message_names_list} ],
  form  => [ grep { /^FORM_/ } @{__PACKAGE__->message_names_list} ],
);

sub import
{
  my($class) = shift;

  $class->use_private_messages;
  
  $class->export_tags
  (
    all => $class->message_names_list,
    field => [ grep { /^FIELD_/ } @{$class->message_names_list} ],
    form  => [ grep { /^FORM_/ } @{$class->message_names_list} ],
  );

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

  unless($Private{$class}++)
  {
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
      my $fq_sub = $thing;
      my $sub    = $thing;

      $sub =~ s/.*:://;
      $fq_sub =~ s/^\*//;

      next  unless(defined *{$fq_sub}{'CODE'} && $name =~ /^[A-Z0-9_]+$/);
      next  if($thing =~ /^(BEGIN|DESTROY|AUTOLOAD|TIE.*)$/);

      $Debug && warn "$class ADD $name = ", &$fq_sub, "\n";
      $class->add_message($name, &$fq_sub);
    }
  }
}

#
# Messages
#

use constant CUSTOM_MESSAGE          => -1;
use constant FIELD_LABEL             => 1;
use constant FIELD_DESCRIPTION       => 2;
use constant FIELD_REQUIRED_GENERIC  => 4;
use constant FIELD_REQUIRED_LABELLED => 5;
use constant FIELD_REQUIRED_SUBFIELD => 6;

use constant FORM_HAS_ERRORS => 100;

BEGIN { __PACKAGE__->add_messages }

1;
