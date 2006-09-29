package Rose::HTML::Object::Message::Localizer;

use strict;

use Carp;
use Clone::PP();
use Scalar::Util();

use Rose::HTML::Object::Errors();
use Rose::HTML::Object::Messages();

use Rose::Object;
our @ISA = qw(Rose::Object);

#
# Object data
#

use Rose::Object::MakeMethods::Generic
(
  'hash --get_set_init' => 
  [
    'localized_messages_hash',
  ],
  
  'scalar --get_set_init' => 
  [
    'locale',
    'messages_class',
    'errors_class',
  ],
);

#
# Class data
#

use Rose::Class::MakeMethods::Set
(
  inheritable_set => [ 'default_locale_cascade' ],
);

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar => [ 'default_locale' ],
);

__PACKAGE__->default_locale('en');
__PACKAGE__->default_locale_cascades({ 'default' => [ 'en' ] });

#
# Class methods
#

sub default_locale_cascade { shift->default_locale_cascade_value(@_) }

#
# Object methods
#

sub init_localized_messages_hash { {} }

sub init_locale_cascade 
{
  my($self) = shift;
  my $class = ref($self) || $self;
  return $class->default_locale_cascades_hash;
}

sub locale_cascade
{
  my($self) = shift;
  
  my $hash = $self->{'locale_cascade'} ||= ref($self)->init_locale_cascade;
  
  if(@_)
  {
    if(@_ == 1)
    {
      return $hash->{$_[0]};
    }
    elsif(@_ % 2 == 0)
    {
      for(my $i = 0; $i < @_; $i += 2)
      {
        $hash->{$_[$i]} = $_[$i + 1];
      }
    }
    else { croak "Odd number of arguments passed to locale_cascade()" }
  }
  
  return wantarray ? %$hash : $hash;
}

sub init_locale
{
  my($self) = shift;
  my $class = ref($self) || $self;
  return $class->default_locale;
}

sub init_messages_class { 'Rose::HTML::Object::Messages' }
sub init_errors_class   { 'Rose::HTML::Object::Errors' }

sub clone { Clone::PP::clone(shift) }

sub parent
{
  my($self) = shift; 
  return Scalar::Util::weaken($self->{'parent'} = shift)  if(@_);
  return $self->{'parent'};
}

sub localize_message
{
  my($self, %args) = @_;

  my $msg = $args{'message'};

  return $msg  unless($msg->can('text') && $msg->can('id'));  
  return $msg->text  if($msg->is_custom);

  my $parent = $args{'parent'} || croak "Missing parent";
  my $args   = $args{'args'}   || $msg->args;
  my $locale = $args{'locale'} || $msg->locale || $self->locale;
  
  my $id = $msg->id;

  my $text = $parent->get_localized_message($id, $locale);

  return $self->process_placeholders($text, $args)  if(defined $text);  

  my $cascade = $self->locale_cascade($locale) ||
                $self->locale_cascade('default') || return undef;
  
  foreach my $other_locale (@$cascade)
  {
    $text = $parent->get_localized_message($id, $other_locale);
    return $self->process_placeholders($text, $args) if(defined $text);  
  }
  
  return undef;
}

sub process_placeholders
{
  my($self, $text, $args) = @_;

  for($text)
  {
    # Process [123] and [foo] placeholders
    s{ ( (?:\\.|[^\[]*)* ) \[ (\d+ | [a-zA-Z]\w* ) \] }{$1$args->{$2}}gx;

    # Unescape escaped opening square brackets
    s/\\\[/[/g;
  }

  return $text;
}

sub get_message_name { shift->messages_class->get_message_name(@_) }
sub get_message_id   { shift->messages_class->get_message_id(@_) }

sub get_error_name { shift->errors_class->get_error_name(@_) }
sub get_error_id   { shift->errors_class->get_error_id(@_) }

sub message_for_error_id
{
  my($self, %args) = @_;

  my $error_id  = $args{'error_id'};
  my $msg_class = $args{'msg_class'};
  my $args      = $args{'args'} || [];

  my $messages_class = $self->messages_class;

  if(defined $messages_class->get_message_name($error_id))
  {
    return $msg_class->new(id => $error_id, args => $args);
  }
  elsif($error_id !~ /^\d+$/)
  {
    croak "Unknown error id: $error_id";
  }

  return $msg_class->new(args => $args);
}

sub localized_message_exists
{
  my($self, $name, $locale) = @_;

  my $msgs = $self->localized_messages_hash;

  if(exists $msgs->{$name} && exists $msgs->{$name}{$locale})
  {
    return 1;
  }
  
  return 0;
}

sub get_localized_message
{
  my($self, $name, $locale) = @_;

  my $msgs = $self->localized_messages_hash;

  if(exists $msgs->{$name} && exists $msgs->{$name}{$locale})
  {
    return $msgs->{$name}{$locale};
  }

  return undef;
}

sub add_localized_message_text
{
  my($self, %args) = @_;

  my $id     = $args{'id'};
  my $name   = $args{'name'};
  my $locale = $args{'locale'} || $self->locale;
  my $text   = $args{'text'};
  
  croak "Missing new localized message text"  unless(defined $text);

  if($name =~ /[^A-Z0-9_]/)
  {
    croak "Message names must be uppercase and may contain only ",
          "letters, numbers, and underscores";
  }

  if($id && $name)
  {
    unless($name eq $self->messages_class->get_message_name($id))
    {
      croak "The message id '$id' does not match the name '$name'";
    }
  }
  elsif(!defined $name)
  {
    croak "Missing message id"  unless(defined $id);
    $name = $self->messages_class->get_message_name($id) 
      or croak "No such message id - '$id'";
  }
  elsif(!defined $id)
  {
    croak "Missing message name"  unless(defined $name);
    $id = $self->messages_class->get_message_id($name) 
      or croak "No such message name - '$name'";
  }

  unless(ref $text eq 'HASH')
  {
    $text = { $locale => $text };
  }

  my $msgs = $self->localized_messages_hash;

  while(my($l, $t) = each(%$text))
  {
    $msgs->{$name}{$l} = "$t"; # force stringification
  }

  return $id;
}

*set_localized_message_text = \&add_localized_message_text;

sub import_message_ids
{
  my($self) = shift;
  
  if($Rose::HTML::Object::Exporter::Target_Class)
  {
    $self->messages_class->import(@_);
  }
  else
  {
    local $Rose::HTML::Object::Exporter::Target_Class = (caller)[0];
    $self->messages_class->import(@_);
  }
}

sub import_error_ids
{
  my($self) = shift;

  @_ = (':all')  unless(@_);

  if($Rose::HTML::Object::Exporter::Target_Class)
  {
    $self->errors_class->import(@_);
  }
  else
  {
    local $Rose::HTML::Object::Exporter::Target_Class = (caller)[0];
    $self->errors_class->import(@_);
  }
}

sub add_localized_message
{
  my($self, %args) = @_;

  my $id     = $args{'id'} || $self->generate_message_id;
  my $name   = $args{'name'} || croak "Missing name for new localized message";
  my $locale = $args{'locale'} || $self->locale;
  my $text   = $args{'text'};

  croak "Missing new localized message text"  unless(defined $text);

  if($name =~ /[^A-Z0-9_]/)
  {
    croak "Message names must be uppercase and may contain only ",
          "letters, numbers, and underscores";
  }
  
  unless(ref $text eq 'HASH')
  {
    $text = { $locale => $text };
  }

  my $msgs = $self->localized_messages_hash;
  my $msgs_class = $self->messages_class;

  my $const = "${msgs_class}::$name";

  if(defined &$const)
  {
    croak "A constant or subroutine named $name already exists in the class $msgs_class";
  }
  
  $msgs_class->add_message($name, $id);

  eval "package $msgs_class; use constant $name => $id;";
  croak "Could not eval new constant message - $@"  if($@);

  while(my($l, $t) = each(%$text))
  {
    $msgs->{$name}{$l} = "$t"; # force stringification
  }

  return $id;
}

use constant NEW_MESSAGE_ID_OFFSET => 16_000;

sub generate_message_id
{
  my($self) = shift;

  my $messages_class = $self->messages_class;

  my $new_id = NEW_MESSAGE_ID_OFFSET;
  $new_id++  while($messages_class->message_id_exists($new_id));

  return $new_id;
}

use constant NEW_ERROR_ID_OFFSET => 16_000;

sub generate_error_id
{
  my($self) = shift;

  my $errors_class = $self->errors_class;

  my $new_id = NEW_ERROR_ID_OFFSET;
  $new_id++  while($errors_class->error_id_exists($new_id));

  return $new_id;
}

sub add_localized_error
{
  my($self, %args) = @_;
  
  my $id   = $args{'id'} || $self->generate_error_id;
  my $name = $args{'name'} or croak "Missing localized error name";

  my $errors_class = $self->errors_class;

  my $const = "${errors_class}::$name";

  if(defined &$const)
  {
    croak "A constant or subroutine named $name already exists in the class $errors_class";
  }

  $errors_class->add_error($name, $id);

  eval "package $errors_class; use constant $name => $id;";
  croak "Could not eval new error constant - $@"  if($@);
  
  return $id;
}

1;
