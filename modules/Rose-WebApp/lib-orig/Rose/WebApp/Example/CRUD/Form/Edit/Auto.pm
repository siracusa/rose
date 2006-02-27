package Rose::WebApp::Example::CRUD::Form::Edit::Auto;

use strict;

use Carp;

use Rose::HTML::Form::Field::Text;
use Rose::HTML::Form::Field::Submit;

use Rose::HTML::Form::Field::Set;
use Rose::HTML::Form::Field::DateTime;

use Rose::WebApp::Example::CRUD::Form::Edit;
our @ISA = qw(Rose::WebApp::Example::CRUD::Form::Edit);

use Rose::Object::MakeMethods::Generic
(
  array => 
  [
    'hidden_field_names',
    'add_hidden_field_name' => 
    {
      interface => 'push', hash_key => 'hidden_field_names' 
    },

    'write_once_field_names',
    'add_write_once_field_names' => 
    {
      interface => 'push', hash_key => 'write_once_field_names'
    },

    'auto_populated_field_names',
    'add_auto_populated_field_names' => 
    {
      interface => 'push', hash_key => 'auto_populated_field_names' 
    },
  ],
);

our $Debug = 0;

sub build_form
{
  my($self) = shift;

  my %fields;

  my $app = $self->app;

  $fields{'create_button'} = 
    Rose::HTML::Form::Field::Submit->new(
      name  => 'create', 
      value => 'Create ' . _make_label($app->object_name_singular));

  $fields{'update_button'} = 
    Rose::HTML::Form::Field::Submit->new(
      name  => 'update', 
      value => 'Update ' . _make_label($app->object_name_singular));

  my $object_class = $app->object_class 
    or croak "Missing object_class()";

  my $meta = $object_class->meta 
    or croak "No metadata found for $object_class";

  foreach my $name ($meta->columns)
  {
    my $col_meta = $meta->column($name)
      or croak "No field column named $name found in $self";

    my $default = $col_meta->can('default') ? $col_meta->default : undef;

    my $type = $col_meta->type;
    #print STDERR "$name = $type\n";

    if($type =~ /^date(?:time year to day)?$/)
    {
      $fields{$name} = 
         Rose::HTML::Form::Field::DateTime->new(
          name          => $name,
          label         => _make_label($name),
          output_format => '%m/%d/%Y',
          size          => 10,
          maxlength     => 25,
          default       => $default);
    }
    elsif($type =~ /^datetime(?: year to minute)?$/)
    {
      $fields{$name} = 
         Rose::HTML::Form::Field::DateTime->new(
          name          => $name,
          label         => _make_label($name),
          output_format => '%Y-%m-%d %I:%M %p',
          size          => 18,
          maxlength     => 25,
          default       => $default);
    }
    elsif($type =~ /^(?:datetime(?: year to second)?|timestamp)$/)
    {
      $fields{$name} = 
         Rose::HTML::Form::Field::DateTime->new(
          name          => $name,
          label         => _make_label($name),
          output_format => '%Y-%m-%d %I:%M:%S %p',
          size          => 21,
          maxlength     => 30,
          default       => $default);
    }
    elsif($type =~ /^(?:int(eger)?|float|decimal)$/)
    {
      $fields{$name} = 
        Rose::HTML::Form::Field::Text->new(
          name      => $name,
          label     => _make_label($name),
          size      => 10,
          maxlength => 15,
          default   => $default);
    }
    elsif($type eq 'set')
    {
      $fields{$name} = 
        Rose::HTML::Form::Field::Set->new(
          name  => $name,
          label => _make_label($name),
          rows  => 2,
          cols  => 50,
          default => $default);
    }
    else # if($type =~ /^(?:(?:var)?char(?:acter)?$/)
    {
      my $maxlen = $col_meta->can('length') ? $col_meta->length : 255;

      $fields{$name} = 
        Rose::HTML::Form::Field::Text->new(
          name      => $name,
          label     => _make_label($name),
          size      => ($maxlen > 70 ? 70 : $maxlen),
          maxlength => $maxlen,
          default   => $default);
    }

    $fields{$name}->required($col_meta->not_null);
  }

  unless($self->is_edit_form)
  {
    my %hide = map { $_ => 1 } $self->hidden_field_names;

    foreach my $name ($self->auto_populated_field_names)
    {
      delete $fields{$name}  unless($hide{$name});
    }
  }

  $self->add_fields(%fields);
}

sub _make_label
{
  my($str) = shift;

  for($str)
  {
    tr/_/ /;
    s/(\S+)/\u$1/g;
  }

  return $str;
}

sub object_from_form
{
  my($self) = shift;

  my($class, $object);

  if(@_ == 1)
  {
    $class = shift;

    if(ref $class)
    {
      $object = $class;
      $class = ref $object;
    }
  }
  elsif(@_)
  {
    my %args = @_;

    $class  = $args{'class'};
    $object = $args{'object'};
  }
  else
  {
    croak "Missing required object class argument";
  }

  my %skip = $self->is_edit_form ? (map { $_ => 1 } $self->write_once_field_names) : ();

  $object ||= $class->new();
print STDERR "FIELDS = ", join(', ', $self->fields), "\n";
  foreach my $field ($self->fields)
  {
    my $name = $field->name;
print STDERR "FIELD: $name\n";
    next  if($skip{$name});

    if($object->can($name))
    {
      #$Debug && 
      warn "$class object $name(", $field->internal_value, ")";
      $object->$name($field->internal_value);
    }
  }

  return $object;
}

1;
