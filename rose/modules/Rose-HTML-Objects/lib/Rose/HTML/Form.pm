package Rose::HTML::Form;

use strict;

use Carp;

use Rose::URI;

use URI::Escape qw(uri_escape);

use Rose::HTML::Form::Field;
use Rose::HTML::Form::Collection;
use Rose::HTML::Form::Field::Collection;

our @ISA = 
  qw(Rose::HTML::Form::Field 
     Rose::HTML::Form::Field::Collection 
     Rose::HTML::Form::Collection);

our $VERSION = '0.35';

# Multiple inheritence never quite works out the way I want it to...
Rose::HTML::Form::Field::Collection->import_methods
(
  'hidden_field',
  'hidden_fields',
  'html_hidden_field',
  'xhtml_hidden_field',
  'html_hidden_fields',
  'xhtml_hidden_fields',
);

__PACKAGE__->add_valid_html_attrs
(
  'action',         # %URI;          #REQUIRED -- server-side form handler --
  'method',         # (GET|POST)     GET       -- HTTP method used to submit the form--
  'enctype',        # %ContentType;  "application/x-www-form-urlencoded"
  'accept',         # %ContentTypes; #IMPLIED  -- list of MIME types for file upload --
  'name',           # CDATA          #IMPLIED  -- name of form for scripting --
  'onsubmit',       # %Script;       #IMPLIED  -- the form was submitted --
  'onreset',        # %Script;       #IMPLIED  -- the form was reset --
  'accept-charset', # %Charsets;     #IMPLIED  -- list of supported charsets --
);

__PACKAGE__->add_required_html_attrs(
{
  action  => '',
  method  => 'get',
  enctype => 'application/x-www-form-urlencoded',
});

use constant UNSAFE_URI_CHARS => '^\w\d?\057=.:-';

our $Debug = 0;

use Rose::Object::MakeMethods::Generic
(
  scalar =>
  [
    'uri_base',
    'rank',
    'form_name',
  ],

  'scalar --get_set_init' => 'uri_separator',

  boolean => 
  [
    'coalesce_query_string_params' => { default => 1 },
    'build_on_init'                => { default => 1 },
  ],
);

sub new
{
  my($class) = shift;

  my $self =
  {
    params => {},
    fields => {},
    validate_field_html_attrs => 1,
  };

  bless $self, $class;

  $self->init(@_);

  return $self;
}

sub init_uri_separator { '&' }

sub init
{
  my($self) = shift;  

  $self->SUPER::init(@_);

  $self->build_form()  if($self->build_on_init);
}

sub html_element  { 'form' }
sub xhtml_element { 'form' }

sub action { shift->html_attr('action', @_) }
sub method { shift->html_attr('method', @_) }

sub build_form { }

sub parent_form
{
  my($self) = shift; 
  return Scalar::Util::weaken($self->{'parent_form'} = shift)  if(@_);
  return $self->{'parent_form'};
}

sub name
{
  my($self) = shift;

  if(@_)
  {
    return $self->html_attr('name', shift);
  }
  else
  {
    unless(defined $self->html_attr('name'))
    {
      return $self->form_name;
    }

    return $self->html_attr('name');
  }
}

# sub form_name
# {
#   my($self) = shift;
# 
#   if(@_)
#   {
#     $self->{'form_name'} = shift;
# 
#     unless(defined $self->name)
#     {
#       $self->html_attr(name => $self->{'form_name'})
#     }
# 
#     return $self->{'form_name'};
#   }
#   else
#   {
#     unless(defined $self->{'form_name'})
#     {
#       return $self->{'form_name'} = $self->html_attr('name');
#     }
# 
#     return $self->{'form_name'};
#   }
# }

sub validate_field_html_attrs
{
  my($self) = shift;

  if(@_)
  {
    foreach my $field ($self->fields)
    {
      $field->validate_html_attrs(@_);
    }

    return $self->{'validate_field_html_attrs'} = $_[0] ? 1 : 0;
  }

  return $self->{'validate_field_html_attrs'};
}

# Override inherited, non-public methods with fast-returning
# "don't care" versions.
sub _is_full  { 0 }
sub _set_input_value { }
sub is_full  { 0 }
sub is_empty { 0 }

sub delete_params { shift->{'params'} = {} }

sub params
{
  my($self) = shift;

  if(@_)
  {
    if(@_ == 1 && ref $_[0] eq 'HASH')
    {
      $self->{'params'} = { %{$_[0]} }; 
    }
    elsif(@_ % 2 == 0)
    {
      $self->{'params'} = { @_ };
    }
    else
    {
      croak(ref($self), '::params() - got odd number of arguments: ');
    }

    foreach my $param (keys %{$self->{'params'}})
    {
      if($param =~ /^(.+)\.[xy]$/)
      {
        delete $self->{'params'}{$param};
        $self->{'params'}{$1} = 1;
      }
    }
  }

  my $want = wantarray;
  return  unless(defined $want);

  return ($want) ? $self->{'params'} : %{$self->{'params'}};
}

sub param_exists
{
  my($self, $param) = @_;

  no warnings;

  return exists $self->{'params'}{$param};
}

sub params_exist { (keys %{$_[0]->{'params'}}) ? 1 : 0 }

sub param_value_exists
{
  my($self, $param, $value) = @_;

  croak(ref($self), '::param_value_exists() requires a param name plus a value')
    unless(@_ == 3);

  $param = $self->param($param);

  return 0  unless($param);

  foreach my $existing_value ((ref $param) ? @$param : $param)
  {
    return 1  if($existing_value eq $value);
  }

  return 0;
}

sub param
{
  my($self, $param, $value) = @_;

  if(@_ == 2)
  {
    if(exists $self->{'params'}{$param})
    {
      if(wantarray)
      {
        if(ref $self->{'params'}{$param})
        {
          return @{$self->{'params'}{$param}};
        }

        return ($self->{'params'}{$param});
      }

      return $self->{'params'}{$param};
    }

    return;
  }
  elsif(@_ == 3)
  {
    return $self->{'params'}{$param} = $value;
  }

  croak(ref($self), '::param() requires a param name plus an optional value');
}

sub delete_param
{
  my($self, $param, @values) = @_;

  croak(ref($self), '::delete_param() requires a param name')
    unless(@_ >= 2);

  @values = @{$values[0]}  if(@values == 1 && ref $values[0] eq 'ARRAY');

  if(@values)
  {
    my %values = map { $_ => 1 } @values;

    my $current = $self->{'params'}{$param};

    if(ref $current)
    {
      my @new;

      foreach my $val (@$current)
      {
        push(@new, $val)  unless(exists $values{$val});
      }

      if(@new)
      {
        $self->{'params'}{$param} = @new > 1 ? \@new : $new[0];
      }
      else
      {
        delete $self->{'params'}{$param};
      }
    }
    elsif(exists $values{$self->{'params'}{$param}})
    {
      delete $self->{'params'}{$param};
    }
  }
  else
  {
    delete $self->{'params'}{$param};
  }
}

sub add_param_value
{
  my($self, $param, $value) = @_;

  croak(ref($self), '::add_param() requires a param name plus a value')
    unless(@_ == 3);

  my $current = $self->{'params'}{$param};

  if(ref $current)
  {
    push(@$current, ((ref $value) ? @$value : $value));
  }
  elsif(defined $current)
  {
    $current = [ $current, ((ref $value) ? @$value : $value) ];
  }
  else
  {
    $current = [ ((ref $value) ? @$value : $value) ];
  }

  $self->{'params'}{$param} = $current;
}

sub self_uri
{
  my($self) = shift;

  my $uri_root = $self->uri_base . $self->html_attr('action');

  my $self_uri = $uri_root;

  if(keys %{$self->{'params'}})
  {
    $self_uri .= '?'  unless($self_uri =~ /\?$/);    
    $self_uri .= $self->query_string;
  }

  return Rose::URI->new($self_uri);
}

# XXX: To document or not to document, that is the question...
sub query_hash { Rose::URI->new(query => shift->query_string)->query_hash }

sub query_string
{
  my($self) = shift;

  my $coalesce = $self->coalesce_query_string_params;

  my %params;

  my @fields = $self->fields;

  while(my $field = shift(@fields))
  {
    unless($coalesce)
    {
      if($field->isa('Rose::HTML::Form::Field::Compound'))
      {
        unshift(@fields, $field->fields);
        next;
      }
    }

    my $value = $field->output_value;
    next  unless(defined $value);
    push(@{$params{$field->name}}, ref $value ? @$value : $value);
  }

  my $qs = '';
  my $sep = $self->uri_separator;

  no warnings;

  foreach my $param (sort keys(%params))
  {
    my $values = $params{$param};

    $qs .= $sep  if($qs);
    $qs .= join($sep, map { $param . '=' . uri_escape($_, UNSAFE_URI_CHARS) } @$values);
  }

  return $qs;
}

sub validate
{
  my($self) = shift;

  my $fail = 0;

  foreach my $field ($self->fields)
  {
    $Debug && warn "Validating ", $field->name, "\n";
    $fail++  unless($field->validate);
  }

  return 0  if($fail);
  return 1;
}

sub init_fields
{
  my($self, %args) = @_;

  $self->clear()  unless($args{'no_clear'});

  foreach my $field ($self->fields)
  {
    $self->_init_field($field);
  }
}

sub _init_field
{
  my($self, $field) = @_;

  my $on_off = $field->isa('Rose::HTML::Form::Field::OnOff');

  my $field_name = $field->name;
  my $name_attr  = $field->html_attr('name');

  $Debug && warn "INIT FIELD $field_name ($name_attr)\n";

  my $field_name_exists = $self->param_exists($field_name);
  my $name_attr_exists  = $self->param_exists($name_attr);

  if(!$field_name_exists && $field->isa('Rose::HTML::Form::Field::Compound'))
  {
    foreach my $field_name ($field->field_names)
    {
      $self->_init_field($field->field($field_name));
    }
  }
  else
  {
    return  unless((($field_name_exists || $name_attr_exists) &&
		          !$field->isa('Rose::HTML::Form::Field::Submit')) || $on_off);

    if($field->isa('Rose::HTML::Form::Field::Group'))
    {
      if($field_name_exists)
      {
        $Debug && warn "$field->input_value(", $self->param($field_name), ")\n";
        $field->input_value($self->param($field_name));
      }
      else
      {
        $Debug && warn "$field->input_value(", $self->param($name_attr), ")\n";
        $field->input_value($self->param($name_attr));
      }
    }
    else
    {
      # Must handle lone checkboxes and radio buttons here
      if($on_off)
      {
        if($self->param($field->name) eq $field->html_attr('value'))
        {
          $Debug && warn "$self->param($field->{'name'}) = checked\n";
          $field->checked(1);
        }
        else
        {
          if($self->params_exist)
          {
            $field->checked(0);
          }
          else
          {
            # Didn't set anything, so avoid doing pareant un-clearing below
            return;
          } 
        }
      }
      else
      {
        if($field_name_exists)
        {
          $Debug && warn "$field->input_value(", $self->param($field_name), ")\n";
          $field->input_value($self->param($field_name));
        }
        else
        {
          $Debug && warn "$field->input_value(", $self->param($name_attr), ")\n";
          $field->input_value($self->param($name_attr));
        }
      }
    }
  }

  my $parent = $field->parent_field;

  # Ensure that setting the value of a child field makes all its 
  # parent fields "not cleared"
  while($parent)
  {
    $parent->is_cleared(0);
    $parent = $parent->parent_field;
  }
}

sub start_html
{
  my($self) = shift;
  return '<' . ref($self)->html_element . $self->html_attrs_string() . '>';
}

*start_xhtml = \&start_html;

sub start_multipart_html
{
  my($self) = shift;
  $self->html_attr(enctype => 'multipart/form-data');
  return $self->start_html;
}

*start_multipart_xhtml = \&start_multipart_html;

sub end_html { '</form>' }
sub end_multipart_html { '</form>' }

*end_xhtml = \&end_html;
*end_multipart_xhtml = \&end_multipart_html;

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

  $object ||= $class->new();

  foreach my $field ($self->fields)
  {
    my $name = $field->name;

    if($object->can($name))
    {
      #$Debug && warn "$class object $name(", $field->internal_value, ")";
      $object->$name($field->internal_value);
    }
  }

  return $object;
}

*init_object_with_form = \&object_from_form;

sub init_with_object
{
  my($self, $object) = @_;

  croak "Missing required object argument"  unless($object);

  $self->clear();

  foreach my $field ($self->fields)
  {
    my $name = $field->name;

    if($object->can($name))
    {
      #$Debug && warn "field($name) = $object->$name = ", $object->$name();
      $field->input_value(scalar $object->$name());
    }
  }
}

sub clear
{
  $_[0]->clear_fields;
  $_[0]->error(undef);
}

sub reset
{
  $_[0]->reset_fields;
  $_[0]->error(undef);
}

1;

__END__

=head1 NAME

Rose::HTML::Form - HTML form base class.

=head1 SYNOPSIS

  package RegistrationForm;

  use Rose::HTML::Form;
  our @ISA = qw(Rose::HTML::Form);

  use Person;
  use Rose::HTML::Form::Field::Text;
  use Rose::HTML::Form::Field::Email;
  use Rose::HTML::Form::Field::PhoneNumber::US;

  sub build_form 
  {
    my($self) = shift;

    my %fields;

    $fields{'name'} = 
      Rose::HTML::Form::Field::Text->new(name => 'name',
                                         size => 25);

    $fields{'email'} = 
      Rose::HTML::Form::Field::Email->new(name => 'email',
                                          size  => 50);

    $fields{'phone'} = 
      Rose::HTML::Form::Field::PhoneNumber::US->new(name => 'phone');

    ...
    $self->add_fields(%fields);
  }

  sub validate
  {
    my($self) = shift;

    my $ok = $self->SUPER::validate(@_);
    return $ok  unless($ok);

    if($self->field('name')->internal_value =~ /foo/ && 
       $self->field('phone')->internal_value =~ /123/)
    {
      $self->error('...');
      return 0;
    }      
    ...
    return 1;
  }

  sub init_with_person 
  {
    my($self, $person) = @_;

    $self->init_with_object($person);

    $self->field('phone2')->input_value($person->alt_phone);
    $self->field('is_new')->input_value(1);
    ...
  }

  sub person_from_form
  {
    my($self) = shift;

    my $person = $self->object_from_form(class => 'Person');

    $person->alt_phone($self->field('phone2')->internal_value);
    ...
    return $person;
  }

  ...

  my $form = RegistrationForm->new;

  if(...)
  {
    my $params = MyWebServer->get_query_params();

    $form->params($params);
    $form->init_fields();

    unless($form->validate) 
    {
      return error_page(error => $form->error);
    }

    $person = $form->person_from_form();

    do_something_with($person);
    ...
  }
  else
  {
    $person = get_person(...);
    $form->init_with_person($person);
    display_page(form => $form);
  }
  ...

=head1 DESCRIPTION

L<Rose::HTML::Form> is more than just an object representation of the E<lt>formE<gt> HTML tag.  It is meant to be a base class for custom form classes that can be initialized with and return "rich" values such as objects, or collections of objects.

Building up a reusable library of form classes is extremely helpful when building large web applications with forms that may appear in many different places.  Similar forms can inherit from a common subclass.

This class inherits from, and follows the conventions of, L<Rose::HTML::Object>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::HTML::Object> documentation for more information.

=head1 OVERVIEW

L<Rose::HTML::Form> objects are meant to encapsulate an entire HTML form, including all fields within the form. While individual fields may be queried and manipulated, the intended purpose of this class is to treat the form as a "black box" as much as possible.

For example, instead of asking a form object for the values of the "name", "email", and "phone" fields, the user would ask the form object to return a new "Person" object that encapsulates those values.

Form objects should also accept initialization through the same kinds of objects that they return.  Subclasses are encouraged to create methods such as (to use the example described above) C<init_with_person()> and C<person_from_form()> in order to do this.  The generic methods L<init_with_object()|/init_with_object> and L<object_from_form()|/object_from_form> are meant to ease the implementation of such custom methods.

Form objects can also take input through a hash.  Each hash key correspond to a field (or subfield) name, and each value is either a scalar or a reference to an array of scalars (for multiple-value fields).  This hash of parameters can be queried and manipulated before finally calling L<init_fields()|/init_fields> in order to initialize the fields based on the current state of the parameters.

Compound fields (fields consisting of more than one HTML field, such as a month/day/year date field with separate text fields for each element of the date) may be "addressed" by hash arguments using both top-level names (e.g., "birthday") or by subfield names (e.g., "birthday.month", "birthday.day", "birthday.year").  If the top-level name exists in the hash, then subfield names are ignored.

(See L<Rose::HTML::Form::Field::Compound> for more information on compound fields.)

Each form has a list of field objects.  Each field object is stored under a name, which may or may not be the same as the field name, which may or may not be the same as the "name" HTML attribute for any of the HTML tags that make up that field.

Forms are validated by calling L<validate()|Rose::HTML::Form::Field/validate> on each field object.  If any individual field does not validate, then the form is invalid. Inter-field validation is the responsibility of the form object.

=head1 HTML ATTRIBUTES

Valid attributes:

    accept
    accept-charset
    accesskey
    action
    class
    dir
    enctype
    id
    lang
    method
    name
    onblur
    onclick
    ondblclick
    onfocus
    onkeydown
    onkeypress
    onkeyup
    onmousedown
    onmousemove
    onmouseout
    onmouseover
    onmouseup
    onreset
    onsubmit
    style
    tabindex
    title
    value
    xml:lang

Required attributes (default values in parentheses):

    action
    enctype (application/x-www-form-urlencoded)
    method  (get)

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a new L<Rose::HTML::Form> object based on PARAMS, where PARAMS are name/value pairs.  Any object method is a valid parameter name.

=back

=head1 OBJECT METHODS

=over 4

=item B<add_field ARGS>

Convenience alias for L<add_fields()|/add_fields>.

=item B<add_fields ARGS>

Add the fields specified by ARGS to the list of fields contained in this form.

If an argument is "isa" L<Rose::HTML::Form::Field>, then it is added to the list of fields, stored under the name returned by the field's L<name()|Rose::HTML::Form::Field/name> method.

If an argument is anything else, it is used as the field name, and the next argument is used as the field object to store under that name.  If the next argument is not an object derived from L<Rose::HTML::Form::Field>, then a fatal error occurs.

The field object's L<name()|Rose::HTML::Form::Field/name> is set to the name that it is stored under, and its L<parent_field()|Rose::HTML::Form::Field/parent_field> is set to the form object.  If the field's L<rank|Rose::HTML::Form::Field/rank> is undefined, it's set to the value of the form's L<rank_counter|/rank_counter> attribute and the rank counter is incremented.

Returns the full list of field objects, sorted by field name, in list context, or a reference to a list of the same in scalar context.

Examples:

    $name_field = 
      Rose::HTML::Form::Field::Text->new(name => 'name',
                                         size => 25);

    $email_field = 
      Rose::HTML::Form::Field::Text->new(name => 'email',
                                         size => 50);

    # Field arguments
    $form1->add_fields($name_field, $email_field);

    # Name/field pairs
    $form2->add_fields(name  => $name_field, 
                       email => $email_field);

    # Mixed
    $form3->add_fields($name_field, 
                       email => $email_field);

=item B<add_param_value NAME, VALUE>

Add VALUE to the parameter named NAME.  Example:

    $form->param(a => 1);
    print $form->param('a'); # 1

    $form->add_param_value(a => 2);

    print join(',', $form->param('a')); # 1,2

=item B<build_on_init [BOOL]>

Get or set a boolean flag that indicates whether or not L<build_form()|/build_form> should be called from within the L<init()|Rose::Object/init> method.  See L<build_form()|/build_form> for more information.

=item B<build_form>

This method is a no-op in this class.  It is meant to be overridden by subclasses.  It is called at the end of the L<init()|Rose::Object/init> method if L<build_on_init()|/build_on_init> is true. (Remember that this class inherits from L<Rose::HTML::Object>, which inherits from L<Rose::Object>, which defines the L<init()|Rose::Object/init> method, which is called from the constructor.  See the L<Rose::Object> documentation for more information.)

If L<build_on_init()|/build_on_init> is false, then you must remember to call L<build_form()|/build_form> manually.

Subclasses should populate the field list in their overridden versions of L<build_form()|/build_form>.  Example:

  sub build_form 
  {
    my($self) = shift;

    my %fields;

    $fields{'name'} = 
      Rose::HTML::Form::Field::Text->new(name => 'name',
                                         size => 25);

    $fields{'email'} = 
      Rose::HTML::Form::Field::Email->new(name => 'email',
                                          size  => 50);

    $fields{'phone'} = 
      Rose::HTML::Form::Field::PhoneNumber::US->new(name => 'phone');

    ...
    $self->add_fields(%fields);
  }

=item B<clear>

Call L<clear()|Rose::HTML::Form::Field/clear> on each field object and set L<error()|Rose::HTML::Object/error> to undef.

=item B<clear_fields>

Call L<clear()|Rose::HTML::Form::Field/clear> on each field object.

=item B<coalesce_hidden_fields [BOOL]>

Get or set the boolean flag that controls how compound field values are encoded in hidden fields.  If this flag is true, then each compound field is encoded as a single hidden field.  If the flag is false (the default), then each subfield of a compound field will have its own hidden field.

=item B<coalesce_query_string_params [BOOL]>

Get or set the boolean flag that controls how compound field values are encoded in the query string. If this flag is true (the default), then compound fields are represented by a single query parameter. Otherwise, the subfields of each compound field appear as separate query parameters.

=item B<compare_fields [FIELD1, FIELD2]>

Compare two fields, returning 1 if FIELD1 should come before FIELD2, -1 if FIELD2 should come before FIELD1, or 0 if neither field should come before the other.  This method is called from within the L<field_names|/field_names> method to determine the order of the fields in this form.

=item B<delete_field NAME>

Delete the field stored under the name NAME.  If NAME "isa" L<Rose::HTML::Form::Field>, then the L<name()|Rose::HTML::Form::Field/name> method is called on it and the return value is used as NAME.

=item B<delete_fields>

Delete all fields, leaving the list of fields empty.  The L<rank_counter|/rank_counter> is also reset to 1.

=item B<delete_param NAME [, VALUES]>

If just the NAME argument is passed, the parameter named NAME is deleted.

If VALUES are also passed, then VALUES are deleted from the set of values held by the parameter name NAME.  If only one value remains, then it is the new value for the NAME parameter (i.e., the value is no longer an array reference, but a scalar instead).  If every value is deleted, then the NAME parameter is deleted as well.  Example:

    $form->param(a => [ 1, 2, 3, 4 ]);

    $form->delete_param(a => 1);
    $vals = $form->param('a'); # [ 2, 3, 4 ]

    $form->delete_param(a => [ 2, 3 ]);
    $vals = $form->param('a'); # 4

    $form->delete_param(a => 4);
    $vals = $form->param('a'); # undef
    $form->param_exists('a');  # false

=item B<delete_params>

Delete all parameters.

=item B<end_html>

Returns the HTML required to end the form.

=item B<end_xhtml>

Returns the XHTML required to end the form.

=item B<end_multipart_html>

Returns the HTML required to end a multipart form.

=item B<end_multipart_xhtml>

Returns the XHTML required to end a multipart form.

=item B<field NAME [, VALUE]>

Get or set the field specified by NAME.  If only a NAME argument is passed, then the field stored under the name NAME is returned.  If no field exists under that name exists, then undef is returned.

If both NAME and VALUE arguments are passed, then the field VALUE is stored under the name NAME.  If VALUE is not an object derived from L<Rose::HTML::Form::Field>, then a fatal error occurs.

=item B<fields>

Returns an ordered list of this form's field objects in list context, or a reference to this list in scalar context.  The order of the fields matches the order of the field names returned by the L<field_names|/field_names> method.

=item B<field_names>

Returns an ordered list of field names in list context, or a reference to this list in scalar context.  The order is determined by the L<compare_fields|/compare_fields> method by default.

You can override the L<compare_fields|/compare_fields> method in your subclass to provide a custom sort order, or you can override the L<field_names|/field_names> method itself to provide an arbitrary  order, ignoring the L<compare_fields|/compare_fields> method entirely.

=item B<hidden_fields>

Returns one or more L<Rose::HTML::Form::Field::Hidden> objects that represent the hidden fields needed to encode all of the field values in this form.

If L<coalesce_hidden_fields()|/coalesce_hidden_fields> is true, then each compound field is encoded as a single hidden field.  Otherwise, each subfield of a compound field will be have its own hidden field.

=item B<html_hidden_fields>

Returns the HTML serialization of the fields returned by L<hidden_fields()|/hidden_fields>, joined by newlines.

=item B<init_fields [ARGS]>

Initialize the fields based on L<params()|/params>.  In general, this works as you'd expect, but the details are a bit complicated.

The intention of L<init_fields()|/init_fields> is to set field values based solely and entirely on L<params()|/params>.  That means that default values for fields should not be considered unless they are explicitly part of L<params()|/params>.

In  general, default values for fields exist for the purpose of displaying the HTML form with certain items pre-selected or filled in.  In a typical usage scenario, those default values will end up in the web browser form submission and, eventually, as as an explicit part of part L<params()|/params>, so they are not really ignored.

But to preserve the intended functionality of L<init_fields()|/init_fields>, the first thing this method does is L<clear()|/clear> the form. If a C<no_clear> parameter with a true value is passed as part of ARGS, then this step is skipped.

If a parameter name exactly matches a field's name (note: the field's L<name()|Rose::HTML::Form::Field/name>, I<not> the name that the field is stored under in the form, which may be different), then the (list context) value of that parameter is passed as the L<input_value()|Rose::HTML::Form::Field/input_value> for that field.

If a field "isa" L<Rose::HTML::Form::Field::Compound>, and if no parameter exactly matches the L<name()|Rose::HTML::Form::Field/name> of the compound field, then each subfields may be initialized by a parameter name that matches the subfield's L<name()|Rose::HTML::Form::Field/name>.

If a field is an "on/off" type of field (e.g., a radio button or checkbox), then the field is turned "on" only if the value of the parameter that matches the field's L<name()|Rose::HTML::Form::Field/name> exactly matches (string comparison) the "value" HTML attribute of the field.  If not, and if L<params_exist()|/params_exist>, then the field is set to "off".  Otherwise, the field is not modified at all.

Examples:

    package RegistrationForm;
    ...
    sub build_form 
    {
      my($self) = shift;

      my %fields;

      $fields{'name'} = 
        Rose::HTML::Form::Field::Text->new(
          name => 'your_name',
          size => 25);

      $fields{'gender'} = 
        Rose::HTML::Form::Field::RadioButtonGroup->new(
          name          => 'gender',
          radio_buttons => { 'm' => 'Male', 'f' => 'Female' },
          default       => 'm');

      $fields{'hobbies'} = 
        Rose::HTML::Form::Field::CheckBoxGroup->new(
          name       => 'hobbies',
          checkboxes => [ 'Chess', 'Checkers', 'Knitting' ],
          default    => 'Chess');

      $fields{'bday'} = 
        Rose::HTML::Form::Field::DateTime::Split::MonthDayYear->new(
          name => 'bday');

      $self->add_fields(%fields);

      # Set a different "name" HTML attribute for this field.
      # Has to be done after the call to add_fields() because
      # add_fields() sets the name() of each field to match the
      # name that it is stored under.
      $self->field('name')->html_attr(name => 'your_name');
    }

    ...

    my $form = RegistrationForm->new();

    $form->params(name    => 'John', 
                  gender  => 'm',
                  hobbies => undef,
                  bday    => '1/24/1984');

    # John, Male, no hobbies, 1/24/1984
    $form->init_fields;

    $form->reset;
    $form->params(name  => 'John', 
                  bday  => '1/24/1984');

    # No name, Male, Chess, 1/24/1984
    $form->init_fields(no_clear => 1);

    $form->reset;
    # Set using subfield names for "bday" compound field
    $form->params('your_name'  => 'John',
                  'bday.month' => 1,
                  'bday.day'   => 24,
                  'bday.year'  => 1984);

    # John, Male, no hobbies, 1/24/1984
    $form->init_fields();

    $form->reset;
    $form->params('bday'       => '1/24/1984',
                  'bday.month' => 12,
                  'bday.day'   => 25,
                  'bday.year'  => 1975);

    # No name, no gender, no hobbies, but 1/24/1984 because
    # the "bday" param trumps any and all subfield params.
    $form->init_fields();

    $form->reset;

    # Explicitly set hobbies field to Knitting...
    $form->field('hobbies')->input_value('Knitting');

    # ...but then provide a hobbies param with no value
    $form->params('hobbies' => undef);

    # Fields are not cleared, but the existence of the hobbies
    # param with an empty value causes the hobbies list to be
    # empty, instead of the default Chess.  Thus:
    # No name, Male, no hobbies, no birthday
    $form->init_fields(no_clear => 1);

=item B<init_with_object OBJECT>

Initialize the form based on OBJECT.  First, the form is L<clear()|/clear>ed.  Next, for each field L<name()|Rose::HTML::Form::Field/name>, if the object has a method with the same name, then the return value of that method (called in scalar context) is passed as the L<input_value()|Rose::HTML::Form::Field/input_value> for the form field of the same name.

Heck, at this point, the actual code for the L<init_with_object()|/init_with_object> method is shorter and more clear than my description.  Basically, it does this:

    sub init_with_object
    {
      my($self, $object) = @_;

      $self->clear();

      foreach my $field ($self->fields)
      {
        my $name = $field->name;

        if($object->can($name))
        {
          $field->input_value(scalar $object->$name());
        }
      }
    }

Use this method as a "helper" when writing your own methods such as C<init_with_person()>, as described in the example in the L<OVERVIEW>. L<init_with_object()|/init_with_object> should be called in the code for subclasses of L<Rose::HTML::Form>, but never by an end-user of such classes.

The convention for naming such methods is "init_with_foo", where "foo" is a (lowercase, underscore-separated, please) description of the object (or objects) used to initialize the form.  You are free to accept and handle any kind or number of arguments in your "init_with_foo()"-style methods (all which you'll carefully document, of course).

The field names may not match up exactly with the object method names. In such cases, you can use L<init_with_object()|/init_with_object> to handle all the fields that do match up with method names, and then handle the others manually.  Example:

    sub init_with_person 
    {
      my($self, $person) = @_;

      # Handle field names that match method names
      $self->init_with_object($person); 

      # Manually set the non-matching or other fields
      $self->field('phone2')->input_value($person->alt_phone);
      $self->field('is_new')->input_value(1);
      ...
    }

=item B<object_from_form OBJECT | CLASS | PARAMS>

Returns an object built based on the contents of the form.  

For each field L<name()|Rose::HTML::Form::Field/name>, if the object has a method with the same name, then the L<internal_value()|Rose::HTML::Form::Field/internal_value> of the field is passed to the object method of that name.  The actual code is just about as concise as my description:

  foreach my $field ($self->fields)
  {
    my $name = $field->name;

    if($object->can($name))
    {
      $object->$name($field->internal_value);
    }
  }

To do this, the method needs an object.  If passed an OBJECT argument, then that's the object that's used.  If passed a CLASS name, then a new object is constructed by calling L<new()|/new> on that class.  OBJECT or CLASS may alternately be passed as a name/value pair in PARAMS.

Use this method as a "helper" when writing your own methods such as C<person_from_form()>, as described in the example in the L<OVERVIEW>. L<object_from_form()|/object_from_form> should be called in the code for subclasses of L<Rose::HTML::Form>, but never by an end-user of such classes.

The convention for naming such methods is "foo_from_form", where "foo" is a (lowercase, underscore-separated, please) description of the object constructed based on the values in the form's fields.

The field names may not match up exactly with the object method names. In such cases, you can use L<object_from_form()|/object_from_form> to handle all the fields that do match up with method names, and then handle the others manually.  Example:

  sub person_from_form
  {
    my($self) = shift;

    my $person = $self->object_from_form(class => 'Person');

    $person->alt_phone($self->field('phone2')->internal_value);
    ...
    return $person;
  }

It is the caller's responsibility to ensure that the object class (C<Person> in the example above) is loaded prior to calling this method.

=item B<param NAME [, VALUE]>

Get or set the value of a named parameter.  If just NAME is passed, then the value of the parameter of that name is returned.  If VALUE is also passed, then the parameter value is set and then returned.

If a parameter has multiple values, the values are returned as a reference to an array in scalar context, or as a list in list context.  Multiple values are set by passing a VALUE that is a reference to an array of scalars.

Failure to pass at least a NAME argument results in a fatal error.

=item B<params [PARAMS]>

Get or set all parameters at once.

PARAMS can be a reference to a hash or a list of name/value pairs.  If a parameter has multiple values, those values should be provided in the form of a references to an array of scalar values.  If the list of name/value pairs has an odd number of items, a fatal error occurs.

Regardless of the arguments, this method returns the complete set of parameters in the form of a hash (in list context) or a reference to a hash (in scalar context).

In scalar context, the hash reference returned is a reference to the actual hash used to store parameter names and values in the object.  It should be treated as read-only.

The hash returned in list context is a shallow copy of the actual hash used to store parameter names and values in the object.  It should also be treated as read-only.

If you want a read/write copy, make a deep copy of the hash reference return value and then modify the copy.

=item B<params_exist>

Returns true if any parameters exist, false otherwise.

=item B<param_exists NAME>

Returns true if a parameter named NAME exists, false otherwise.

=item B<param_value_exists NAME, VALUE>

Determines if a parameter of a particular name exists and has a particular value. This method returns true if the parameter named NAME exists and also has a value that is equal to (string comparison) VALUE. Otherwise, it returns false.

A fatal error occurs unless both NAME and VALUE arguments are passed.

=item B<query_string>

Returns a URI-escaped (but I<not> HTML-escaped) query string that corresponds to the current state of the form.  If L<coalesce_query_string_params()|/coalesce_query_string_params> is true (which is the default), then compound fields are represented by a single query parameter.  Otherwise, the subfields of each compound field appear as separate query parameters.

=item B<rank_counter [INT]>

Get or set the value of the counter used to set the L<rank|Rose::HTML::Form::Field/rank> of fields as they're L<added|/add_fields> to the form.  The counter starts at 1 by default.

=item B<reset>

Call L<reset()|Rose::HTML::Form::Field/reset> on each field object and set L<error()|Rose::HTML::Object/error> to undef.

=item B<reset_fields>

Call L<reset()|/reset> on each field object.

=item B<self_uri>

Returns a L<Rose::URI> object corresponding to the current state of the form. If L<uri_base()|/uri_base> is set, then it is included in front of what would otherwise be the start of the URI (i.e., the value of the form's "action" HTML attribute).

=item B<start_html>

Returns the HTML that will begin the form tag.

=item B<start_xhtml>

Returns the XHTML that will begin the form tag.

=item B<start_multipart_html>

Sets the "enctype" HTML attribute to "multipart/form-data", then returns the HTML that will begin the form tag.

=item B<start_multipart_xhtml>

Sets the "enctype" HTML attribute to "multipart/form-data", then returns the XHTML that will begin the form tag.

=item B<uri_base [STRING]>

Get or set the URI of the form, minus the value of the "action" HTML attribute.  Although the form action can be a relative URI, I suggest that it be an absolute path at the very least, leaving the L<uri_base()|/uri_base> to be the initial part of the full URI returned by L<self_uri()|/self_uri>.  Example:

    $form->action('/foo/bar');
    $form->uri_base('http://www.foo.com');

    # http://www.foo.com/foo/bar
    $uri = $form->self_uri;

=item B<uri_separator [CHAR]>

Get or set the character used to separate parameter name/value pairs in the return value of L<query_string()|/query_string> (which is in turn used to construct the return value of L<self_uri()|/self_uri>).  The default is "&".

=item B<validate>

Validate the form by calling L<validate()|Rose::HTML::Form::Field/validate> on each field.  If any field returns false from its L<validate()|Rose::HTML::Form::Field/validate> call, then this method returns false. Otherwise, it returns true.

=item B<validate_field_html_attrs [BOOL]>

Get or set a boolean flag that indicates whether or not the fields of this form will validate their HTML attributes.  If a BOOL argument is passed, then it is passed as the argument to a call to L<validate_html_attrs()|Rose::HTML::Object/validate_html_attrs> on each field.  In either case, the current value of this flag is returned.

=item B<xhtml_hidden_fields>

Returns the XHTML serialization of the fields returned by L<hidden_fields()|/hidden_fields>, joined by newlines.

=back

=head1 SUPPORT

Any L<Rose::HTML::Objects> questions or problems can be posted to the L<Rose::HTML::Objects> mailing list.  To subscribe to the list or view the archives, go here:

L<http://lists.sourceforge.net/lists/listinfo/rose-html-objects>

Although the mailing list is the preferred support mechanism, you can also email the author (see below) or file bugs using the CPAN bug tracking system:

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Rose-HTML-Objects>

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
