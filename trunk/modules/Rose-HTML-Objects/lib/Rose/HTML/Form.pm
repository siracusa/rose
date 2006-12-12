package Rose::HTML::Form;

use strict;

use Carp;

use Clone::PP;
use Rose::URI;
use Scalar::Util qw(refaddr);
use URI::Escape qw(uri_escape);

use Rose::HTML::Object::Errors qw(:form);

use Rose::HTML::Form::Field;
use Rose::HTML::Form::Field::Collection;
our @ISA = qw(Rose::HTML::Form::Field Rose::HTML::Form::Field::Collection);

our $VERSION = '0.546';

# Multiple inheritence never quite works out the way I want it to...
Rose::HTML::Form::Field::Collection->import_methods
(
  'children',
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

use Rose::HTML::Form::Constants qw(FF_SEPARATOR);

# Variable for use in regexes
our $FF_SEPARATOR_RE = quotemeta FF_SEPARATOR;

our $Debug = 0;

use Rose::Object::MakeMethods::Generic
(
  scalar =>
  [
    'uri_base',
    'rank',
  ],

  'scalar --get_set_init' => 
  [
    'uri_separator',
    'form_rank_counter',
  ],

  boolean => 
  [
    'coalesce_query_string_params' => { default => 1 },
    'build_on_init'                => { default => 1 },
  ],
);

#
# Class data
#

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar => '_delegate_to_subforms', 
);

__PACKAGE__->delegate_to_subforms('compile');

#
# Class methods
#

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

sub delegate_to_subforms
{
  my($class) = shift;

  $class = ref $class  if(ref $class);

  if(@_)
  {
    my $value = shift;

    # Dumb regex to avoid non-numeric comparison warning
    $value = 'runtime'  if($value =~ /\d/ && $value == 1);

    unless(!$value || $value eq 'compile' || $value eq 'runtime')
    {
      croak "Invalid delegate_to_subforms() value: '$value'";
    }

    return $class->_delegate_to_subforms($value);
  }

  return $class->_delegate_to_subforms;
}

#
# Object methods
#

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

sub params_from_cgi
{
  my($self, $cgi) = @_;

  croak "Missing CGI argument to params_from_cgi"  unless(@_ > 1);

  unless(UNIVERSAL::isa($cgi, 'CGI') || UNIVERSAL::can($cgi, 'param'))
  {
    croak "Argument to params_from_cgi() is not a CGI object and ",
          "does not have a param() method";
  }

  my %params;

  foreach my $param ($cgi->param)
  {
    my @values = $cgi->param($param);
    $params{$param} = @values > 1 ? \@values : $values[0];
  }

  $self->params(\%params);
}

# IIn a reasonably modern perl, the optimizer will eliminate the 
# blocks of code that are conditional upon these constants when the 
# value is zero.
use constant MP2 => exists $ENV{'MOD_PERL_API_VERSION'} && 
                    $ENV{'MOD_PERL_API_VERSION'} > 1 ? 1 : 0;

use constant MP1 => # Special environment variable for the test suite
  ($ENV{'MOD_PERL'} || $ENV{'RHTMLO_TEST_MOD_PERL'}) && 
  (!exists $ENV{'MOD_PERL_API_VERSION'} || $ENV{'MOD_PERL_API_VERSION'} == 1) ?
  1 : 0;

use constant MP0 => $ENV{'MOD_PERL'} ? 0 : 1;

my $Loaded_APR1 = 0;
my $Loaded_APR2 = 0;

sub params_from_apache
{
  my($self, $apr) = @_;

  croak "Missing apache request argument to params_from_apache"  unless(@_ > 1);

  if(MP0)
  {
    unless(UNIVERSAL::can($apr, 'param'))
    {
      croak "Argument to params_from_apache() does not have a param() method";
    }
  }
  elsif(MP1)
  {
    if(UNIVERSAL::isa($apr, 'Apache'))
    {
      unless($Loaded_APR1) # cheaper than require (really!)
      {
        require Apache::Request;
        $Loaded_APR1 = 1;
      }

      $apr = Apache::Request->instance($apr);
    }
    elsif(!UNIVERSAL::isa($apr, 'Apache::Request') && 
          !UNIVERSAL::can($apr, 'param'))
    {
      croak "Argument to params_from_apache() is not an Apache or ",
            "Apache::Request object and does not have a param() method";
    } 
  }
  elsif(MP2)
  {
    if(UNIVERSAL::isa($apr, 'Apache2::RequestRec'))
    {
      unless($Loaded_APR2) # cheaper than require (really!)
      {
        require Apache2::Request;
        $Loaded_APR2 = 1;
      }

      $apr = Apache2::Request->new($apr);
    }
    elsif(!UNIVERSAL::isa($apr, 'Apache2::Request') && 
          !UNIVERSAL::can($apr, 'param'))
    {
      croak "Argument to params_from_apache() is not an Apache2::RequestRec ",
            "or Apache2::Request object and does not have a param() method";
    }
  }

  my %params;

  foreach my $param ($apr->param)
  {
    my @values = $apr->param($param);
    $params{$param} = @values > 1 ? \@values : $values[0];
  }

  $self->params(\%params);
}

sub params
{
  my($self) = shift;

  if(@_)
  {
    if(@_ == 1 && ref $_[0] eq 'HASH')
    {
      $self->{'params'} = $_[0]; 
    }
    elsif(@_ % 2 == 0)
    {
      $self->{'params'} = Clone::PP::clone({ @_ });
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

  return ($want) ? %{ Clone::PP::clone($self->{'params'}) } : $self->{'params'};
}

sub param_exists
{
  my($self, $param) = @_;

  no warnings;

  return exists $self->{'params'}{$param};
}

sub params_exist { (keys %{$_[0]->{'params'}}) ? 1 : 0 }

sub param_exists_for_field
{
  my($self, $name) = @_;

  $name = $name->name  if(UNIVERSAL::isa($name, 'Rose::HTML::Form::Field'));

  return 0  unless($self->field($name));

  my $nibble = $name;
  my $found_form = 0;

  while(length $nibble)
  {
    if($self->form($nibble) && !$self->field($nibble))
    {
      $found_form = 1;
      last;
    }

    return 1  if($self->param_exists($nibble));
    $nibble =~ s/\.[^.]+$// || last;
  }

  foreach my $field ($found_form ? $self->form($nibble)->fields : 
                                   $self->field($name))
  {
    if($field->can('subfield_names'))
    {
      foreach my $subname ($field->subfield_names)
      {
        # Skip unrelated subfields
        next unless(index($name, $subname) == 0 || 
                    index($subname, $name) == 0);

        return 1  if($self->param_exists($subname));
      }
    }
  }

  return 0;
}

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
  my($self, %args) = @_;

  $args{'cascade'} = 1  unless(exists $args{'cascade'});

  my $fail = 0;

  if($args{'cascade'})
  {
    foreach my $form ($self->forms)
    {
      $Debug && warn "Validating sub-form ", $form->form_name, "\n";

      local $args{'form_only'} = 1;

      unless($form->validate(%args))
      {
        $self->add_error($form->error)  if($form->error);
        $fail++;
      }
    }
  }

  unless($args{'form_only'})
  {
    foreach my $field ($self->fields)
    {
      $Debug && warn "Validating ", $field->name, "\n";
      $fail++  unless($field->validate);
    }
  }

  if($fail)
  {
    unless($self->has_errors)
    {
      $self->add_error_id(FORM_HAS_ERRORS);
    }

    return 0;
  }

  return 1;
}

sub init_fields_with_cgi
{
  my($self) = shift;  

  $self->params_from_cgi(shift);
  $self->init_fields(@_);
}

sub init_fields_with_apache
{
  my($self) = shift;  

  $self->params_from_apache(shift);
  $self->init_fields(@_);
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

  my $name       = $field->name;
  my $moniker    = $field->moniker;
  my $name_attr  = $field->html_attr('name');

  $Debug && warn "INIT FIELD $name ($name_attr)\n";

  my $name_exists       = $self->param_exists($name);
  my $moniker_exists = $self->param_exists($moniker);
  my $name_attr_exists  = $self->param_exists($name_attr);

  if(!$name_exists && $field->isa('Rose::HTML::Form::Field::Compound'))
  {
    foreach my $moniker ($field->field_monikers)
    {
      $self->_init_field($field->field($moniker));
    }
  }
  else
  {
    return  unless((($name_exists || $name_attr_exists || $moniker_exists) &&
                  !$field->isa('Rose::HTML::Form::Field::Submit')) || $on_off);

    if($field->isa('Rose::HTML::Form::Field::Group'))
    {
      if($name_exists)
      {
        $Debug && warn "$field->input_value(", $self->param($name), ")\n";
        $field->input_value($self->param($name));
      }
      elsif($moniker_exists)
      {
        $Debug && warn "$field->input_value(", $self->param($moniker), ")\n";
        $field->input_value($self->param($moniker));
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
        if($self->param($name) eq $field->html_attr('value'))
        {
          $Debug && warn "$self->param($name) = checked\n";
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
        if($name_exists)
        {
          $Debug && warn "$field->input_value(", $self->param($name), ")\n";
          $field->input_value($self->param($name));
        }
        elsif($moniker_exists)
        {
          $Debug && warn "$field->input_value(", $self->param($moniker), ")\n";
          $field->input_value($self->param($moniker));
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

  # Special handling of boolean columns for RDBO
  if($object->isa('Rose::DB::Object'))
  {
    my $meta = $object->meta;

    foreach my $field ($self->fields)
    {
      my $name = $field->local_name;

      if($object->can($name))
      {
        # Checkboxes setting boolean columns
        if($field->isa('Rose::HTML::Form::Field::Checkbox') &&
           $meta->column($name) && $meta->column($name)->type eq 'boolean')
        {
          #$Debug && warn "$class object $name(", $field->is_on, ")";
          $object->$name($field->is_on);        
        }
        else # everything else
        {
          #$Debug && warn "$class object $name(", $field->internal_value, ")";
          $object->$name($field->internal_value);
        }
      }
    }
  }
  else
  {
    foreach my $field ($self->fields)
    {
      my $name = $field->local_name;

      if($object->can($name))
      {
        #$Debug && warn "$class object $name(", $field->internal_value, ")";
        $object->$name($field->internal_value);
      }
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
    my $name = $field->local_name;

    if($object->can($name))
    {
      #$Debug && warn "field($name) = $object->$name = ", $object->$name();
      $field->input_value(scalar $object->$name());
    }
  }
}

sub clear
{
  my($self) = shift;
  $self->clear_fields;
  $self->clear_forms;
  $self->error(undef);
}

sub reset
{
  my($self) = shift;
  $self->reset_fields;
  $self->reset_forms;
  $self->error(undef);
}

sub init_form_rank_counter { 1 }

sub increment_form_rank_counter
{
  my($self) = shift;
  my $rank = $self->form_rank_counter;
  $self->form_rank_counter($rank + 1);
  return $rank;
}

sub add_forms
{
  my($self) = shift;

  my @added_forms;

  while(@_)
  {
    my $arg = shift;

    my($name, $form);

    if(UNIVERSAL::isa($arg, 'Rose::HTML::Form'))
    {
      $form = $arg;

      if(refaddr($form) eq refaddr($self))
      {
        croak "Cannot nest a form within itself";
      }

      $name = $form->form_name;

      croak "Cannot add form with the same name as an existing field: $name"
        if($self->field($name));

      unless(defined $form->rank)
      {
        $form->rank($self->increment_form_rank_counter);
      }
    }
    else
    {
      $name = $arg;
      $form = shift;

      croak "Cannot add form with the same name as an existing field: $name"
        if($self->field($name));

      if(UNIVERSAL::isa($form, 'Rose::HTML::Form'))
      {
        if(refaddr($form) eq refaddr($self))
        {
          croak "Cannot nest a form within itself";
        }
      }
      else
      {
        Carp::croak "Not a Rose::HTML::Form object: $form";
      }

      $form->form_name($name);

      unless(defined $form->rank)
      {
        $form->rank($self->increment_form_rank_counter);
      }
    }

    if(index($name, FF_SEPARATOR) >= 0)
    {
      my($parent_form, $local_name) = $self->choose_parent_form($name);
      $form->form_name($local_name);
      $form->parent_form($parent_form);
      $parent_form->add_form($local_name => $form);
    }
    else
    {
      $form->parent_form($self);
      $self->{'forms'}{$name} = $form;
    }

    push(@added_forms, $form);
  }

  foreach my $form (@added_forms)
  {
    $form->resync_field_names;
  }

  $self->_clear_form_generated_values;
  $self->resync_fields_by_name;

  return  unless(defined wantarray);
  return @added_forms;
}

*add_form = \&add_forms;

sub resync_field_names
{
  my($self) = shift;

  foreach my $field ($self->fields)
  {
    $field->resync_name;
  }

  foreach my $form ($self->forms)
  {
    $form->resync_field_names;
  }
}

sub resync_fields_by_name
{
  my($self) = shift;

  $self->{'fields_by_name'} = {};

  foreach my $field ($self->fields)
  {
    $self->{'fields_by_name'}{$field->name} = $field;
  }
}

sub compare_forms { no warnings 'uninitialized'; $_[1]->rank <=> $_[2]->rank }

sub forms
{
  my($self) = shift;

  if(my $forms = $self->{'form_list'})
  {
    return wantarray ? @$forms : $forms;
  }

  my $forms = $self->{'forms'};

  $self->{'form_list'} = [ grep { defined } map { $forms->{$_} } $self->form_names ];

  return wantarray ? @{$self->{'form_list'}} : $self->{'form_list'};
}

sub form_names
{
  my($self) = shift;

  if(my $names = $self->{'form_names'})
  {
    return wantarray ? @$names : $names;
  }

  my @info;

  while(my($name, $form) = each %{$self->{'forms'}})
  {
    push(@info, [ $name, $form ]);
  }

  $self->{'form_names'} = 
    [ map { $_->[0] } sort { $self->compare_forms($a->[1], $b->[1]) } @info ];

  return wantarray ? @{$self->{'form_names'}} : $self->{'form_names'};
}

sub delete_forms 
{
  my($self) = shift;
  $self->{'forms'} = {};
  $self->form_rank_counter(undef);
  $self->_clear_form_generated_values;
  return;
}

sub delete_form
{
  my($self, $name) = @_;

  $name = $name->form_name  if(UNIVERSAL::isa($name, 'Rose::HTML::Form'));

  if(exists $self->{'forms'}{$name})
  {
    $self->_clear_form_generated_values;
    return delete $self->{'forms'}{$name};
  }

  return undef;
}

sub clear_forms
{
  my($self) = shift;

  foreach my $form ($self->forms)
  {
    $form->clear();
  }
}

sub reset_forms
{
  my($self) = shift;

  foreach my $form ($self->forms)
  {
    $form->reset();
  }
}

sub _clear_form_generated_values
{
  my($self) = shift;
  $self->{'form_list'}   = undef;
  $self->{'form_names'}  = undef;
  $self->_clear_field_generated_values;
}

sub form_name
{
  my($self) = shift;

  return $self->{'form_name'}  unless(@_);
  my $old_name = $self->{'form_name'};
  my $name     = $self->{'form_name'} = shift;
  my %forms;

  if(my $parent_form = $self->parent_form)
  {
    if(defined $old_name && defined $name && $name ne $old_name)
    {
      $parent_form->delete_form($old_name);
      $parent_form->add_form($name => $self);
    }
  }

  return $name;
}

sub local_field
{
  my($self, $name) = (shift, shift);

  if(my $field = shift)
  {
    $field = $self->make_field($name, $field);

    $field->parent_form($self);
    no warnings 'uninitialized';
    $field->name($name)  unless(length $field->name);
    $field->moniker($name);
    $self->{'fields_by_name'}{$field->name} = $field;
    return $self->{'fields'}{$name} = $field;
  }

  return $self->{'fields'}{$name} || $self->{'fields_by_name'}{$name};
}

sub delete_fields 
{
  my($self) = shift;
  $self->_clear_field_generated_values;
  $self->{'fields'} = {};
  $self->{'fields_by_name'} = {};
  $self->field_rank_counter(undef);
  return;
}

sub delete_field
{
  my($self, $name) = @_;

  $name = $name->name  if(UNIVERSAL::isa($name, 'Rose::HTML::Form::Field'));

  $self->_clear_field_generated_values;

  my $field1 = delete $self->{'fields'}{$name};
  my $field2 = delete $self->{'fields_by_name'}{$name};
  return $field1 || $field2;
}

sub field
{
  my($self, $name) = (shift, shift);

  return $self->{'field_cache'}{$name}  if($self->{'field_cache'}{$name});

  my $sep_pos;

  # Non-hierarchical name
  if(($sep_pos = index($name, FF_SEPARATOR)) < 0)
  {
    return $self->{'field_cache'}{$name} = $self->local_field($name, @_);
  }

  # First check if it's a local compound field  
  my $prefix = substr($name, 0, $sep_pos);
  my $rest   = substr($name, $sep_pos + 1);
  my $field  = $self->field($prefix);

  if(UNIVERSAL::isa($field, 'Rose::HTML::Form::Field::Compound'))
  {
    $field = $field->field($rest);
    return ($self->{'field_cache'}{$name} = $field) if($field);
  }

  my($parent_form, $local_name) = $self->find_parent_form($name);

  return $self->{'field_cache'}{$name} = $parent_form->field($local_name, @_);
}

sub fields
{
  my($self) = shift;

  if(my $fields = $self->{'field_list'})
  {
    return wantarray ? @$fields : $fields;
  }

  my $fields = $self->{'fields'};
  my $fields_by_name = $self->{'fields_by_name'};

  $self->{'field_list'} = 
  [
    grep { defined } 
    map 
    {       
      if(/$FF_SEPARATOR_RE([^$FF_SEPARATOR_RE]+)/o)
      {
        $self->field($_) || $fields->{$1} || $fields_by_name->{$1};
      }
      else
      {
        $fields->{$_} || $fields_by_name->{$_} || $self->field($_);
      }
    } 
    $self->field_monikers 
  ];

  return wantarray ? @{$self->{'field_list'}} : $self->{'field_list'};
}

sub field_monikers
{
  my($self) = shift;

  if(my $names = $self->{'field_monikers'})
  {
    return wantarray ? @$names : $names;
  }

  my @info; 

  $self->_find_field_info($self, \@info);

  $self->{'field_monikers'} = 
    [ map { $_->[2] } sort { $self->compare_forms($a->[0], $b->[0]) || $self->compare_fields($a->[1], $b->[1]) } @info ];

  return wantarray ? @{$self->{'field_monikers'}} : $self->{'field_monikers'};
}

sub field_names { shift->field_monikers(@_) }

sub _find_field_info
{
  my($self, $form, $list) = @_;

  while(my($name, $field) = each %{$form->{'fields'}})
  {
    push(@$list, [ $form, $field, $field->fq_moniker ]);
  }

  foreach my $sub_form ($form->forms)
  {
    $form->_find_field_info($sub_form, $list);
  }
}

sub find_parent_form
{
  my($self, $name) = @_;

  # Non-hierarchical name
  if(index($name, FF_SEPARATOR) < 0)
  {
    return $self->local_form($name) ? ($self, $name) : undef;
  }

  my $parent_form;

  while($name =~ s/^([^$FF_SEPARATOR_RE]+)$FF_SEPARATOR_RE//o)
  {
    my $parent_name = $1;
    last  if($parent_form = $self->local_form($parent_name));
  }

  unless(defined $parent_form)
  {
    # Maybe this form ($self) is the parent?
    return ($self, $name)  if($self->local_field($name));
    return undef;
  }

  return wantarray ? ($parent_form, $name) : $parent_form;
}

sub choose_parent_form
{
  my($self, $name) = @_;

  # Non-hierarchical name
  if(index($name, FF_SEPARATOR) < 0)
  {
    return wantarray ? ($self, $name) : $self;
  }

  my($parent_form, $local_name);

  while($name =~ s/^(.+)$FF_SEPARATOR_RE([^$FF_SEPARATOR_RE]+)$//o)
  {
    $local_name = $2;
    last  if($parent_form = $self->form($1));
  }

  return wantarray ? ($parent_form, $local_name) : $parent_form;
}

sub fq_form_name
{
  my($self) = shift;

  return $self->form_name  unless($self->parent_form);

  my @parts;
  my $form = $self;

  while(my $parent_form = $form->parent_form)
  {
    unshift(@parts, $form->form_name);
    $form = $parent_form;
  }

  return @parts ? join(FF_SEPARATOR, @parts) : '';
}

sub local_form
{
  my($self, $name) = @_;
  return $self->{'forms'}{$name}  if(exists $self->{'forms'}{$name});
  return undef;
}

sub form
{
  my($self, $name) = (shift, shift);

  # Set form
  if(@_)
  {
    my $form = shift;
    $self->delete_form($name);
    return $self->add_form($name => $form);
  }

  # Local form?
  if(my $form = $self->local_form($name))
  {
    return $form;
  }

  # Look up nested form
  my($parent_form, $local_name) = $self->find_parent_form($name);
  return undef  unless(defined $parent_form);
  return $parent_form->form($local_name);
}

our $AUTOLOAD;

sub AUTOLOAD
{
  my($self) = $_[0];

  my $class = ref($self) or croak "$self is not an object";

  my $delegate = $class->delegate_to_subforms;

  unless($delegate)
  {
    goto &Rose::HTML::Object::AUTOLOAD;
  }

  my $method = $AUTOLOAD;
  $method =~ s/.*://;

  my $to_form;

  foreach my $form ($self->forms)
  {
    if($form->can($method))
    {
      $to_form = $form;
      last;
    }
  }

  unless($to_form)
  {
    goto &Rose::HTML::Object::AUTOLOAD;
  }

  if($delegate eq 'compile')
  {
    my $form_name = $to_form->form_name;

    no strict 'refs';
    *$AUTOLOAD = sub { shift->form($form_name)->$method(@_) };
    ${$class . '::__AUTODELEGATED'}{$method} = 1;
    goto &$AUTOLOAD;
  }
  elsif($delegate eq 'runtime')
  {
    $to_form->$method(@_);
  }

  goto &Rose::HTML::Object::AUTOLOAD;
}

if(__PACKAGE__->localizer->auto_load_messages)
{
  __PACKAGE__->localizer->load_all_messages;
}

1;

__DATA__
[% LOCALE en %]

FORM_HAS_ERRORS = "One or more fields have errors."

[% LOCALE de %]

# oder "Es sind Fehler aufgetreten."
FORM_HAS_ERRORS = "Ein oder mehrere Felder sind fehlerhaft."

[% LOCALE fr %]

FORM_HAS_ERRORS = "Erreurs dans un ou plusieurs champs."

__END__

=head1 NAME

Rose::HTML::Form - HTML form base class.

=head1 SYNOPSIS

  package PersonForm;

  use Rose::HTML::Form;
  our @ISA = qw(Rose::HTML::Form);

  use Person;

  sub build_form 
  {
    my($self) = shift;

    $self->add_fields
    (
      name  => { type => 'text',  size => 25, required => 1 },
      email => { type => 'email', size => 50, required => 1 },
      phone => { type => 'phone' },
    );
  }

  sub validate
  {
    my($self) = shift;

    # Base class will validate individual fields in isolation,
    # confirming that all required fields are filled in, and that
    # the email address and phone number are formatted correctly.
    my $ok = $self->SUPER::validate(@_);
    return $ok  unless($ok);

    # Inter-field validation goes here
    if($self->field('name')->internal_value ne 'John Doe' &&
       $self->field('phone')->internal_value =~ /^555/)
    {
      $self->error('Only John Doe can have a 555 phone number.');
      return 0;
    }

    return 1;
  }

  sub init_with_person # give a friendlier name to a base-class method
  {
    my($self, $person) = @_;
    $self->init_with_object($person);
  }

  sub person_from_form
  {
    my($self) = shift;

    # Base class method does most of the work
    my $person = $self->object_from_form(class => 'Person');

    # Now fill in the non-obvious details...
    # e.g., set alt phone to be the same as the regular phone
    $person->alt_phone($self->field('phone')->internal_value);

    return $person;
  }

  ...

  #
  # Sample usage in a hypothetical web application
  #

  $form = PersonForm->new;

  if(...)
  {
    # Get query parameters in a hash ref and pass to the form
    my $params = MyWebServer->get_query_params();
    $form->params($params);

    # ...or  initialize form params from a CGI object
    # $form->params_from_cgi($cgi); # $cgi "isa" CGI

    # ...or initialize params from an Apache request object
    # (mod_perl 1 and 2 both supported)
    # $form->params_from_apache($r);

    # Initialize the fields based on params
    $form->init_fields();

    unless($form->validate) 
    {
      return error_page(error => $form->error);
    }

    $person = $form->person_from_form; # $person is a Person object

    do_something_with($person);
    ...
  }
  else
  {
    $person = ...; # Get or create a Person object somehow

    # Initialize the form with the Person object
    $form->init_with_person($person);

    # Pass the initialized form object to the template
    display_page(form => $form);
  }
  ...

=head1 DESCRIPTION

L<Rose::HTML::Form> is more than just an object representation of the E<lt>formE<gt> HTML tag.  It is meant to be a base class for custom form classes that can be initialized with and return "rich" values such as objects, or collections of objects.

Building up a reusable library of form classes is extremely helpful when building large web applications with forms that may appear in many different places.  Similar forms can inherit from a common subclass, and forms may be nested.

This class inherits from, and follows the conventions of, L<Rose::HTML::Object>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::HTML::Object> documentation for more information.

=head1 OVERVIEW

L<Rose::HTML::Form> objects are meant to encapsulate an entire HTML form, including all fields within the form.  While individual fields may be queried and manipulated, the intended purpose of this class is to treat the form as a "black box" as much as possible.

For example, instead of asking a form object for the values of the "name", "email", and "phone" fields, the user would ask the form object to return a new "Person" object that encapsulates those values.

Form objects should also accept initialization through the same kinds of objects that they return.  Subclasses are encouraged to create methods such as (to use the example described above) C<init_with_person()> and C<person_from_form()> in order to do this.  The generic methods L<init_with_object()|/init_with_object> and L<object_from_form()|/object_from_form> are meant to ease the implementation of such custom methods.

Form objects can also take input through a hash.  Each hash key correspond to a field (or subfield) name, and each value is either a scalar or a reference to an array of scalars (for multiple-value fields).  This hash of parameters can be queried and manipulated before finally calling L<init_fields()|/init_fields> in order to initialize the fields based on the current state of the parameters.

Compound fields (fields consisting of more than one HTML field, such as a month/day/year date field with separate text fields for each element of the date) may be "addressed" by hash arguments using both top-level names (e.g., "birthday") or by subfield names (e.g., "birthday.month", "birthday.day", "birthday.year").  If the top-level name exists in the hash, then subfield names are ignored.  See L<Rose::HTML::Form::Field::Compound> for more information on compound fields.

Each form has a list of field objects.  Each field object is stored under a name, which may or may not be the same as the field name, which may or may not be the same as the "name" HTML attribute for any of the HTML tags that make up that field.

Forms are validated by calling L<validate()|Rose::HTML::Form::Field/validate> on each field object.  If any individual field does not validate, then the form is invalid.  Inter-field validation is the responsibility of the form object.

=head1 NESTED FORMS

Each form can have zero or more fields as well as zero or more sub-forms.  Since E<lt>formE<gt> HTML tags cannot be nested, this nesting of form objects appears "flattened" in the external interfaces such as HTML generation or field addressing.

Here's a simple example of a nested form made up of a C<PersonForm> and an C<AddressForm>.  (Assume C<PersonForm> is constructed as per the L<synopsis|/SYNOPSIS> above, and C<AddressForm> is similar, with street, city, state, and zip code fields.)

    package PersonAddressForm;

    use PersonForm;
    use AddressForm;

    sub build_field
    {
      my($self) = shift;

      $self->add_forms
      (
        person  => PersonForm->new,
        address => AddressForm->new,
      );
    }

Each sub-form is given a name.  Sub-field addressing incorporates that name in much the same way as L<compound field|Rose::HTML::Form::Field::Compound> addressing, with dots (".") used to delimit the hierarchy.  Here are two different ways to get at the person's email field.

    $form = PersonAddressForm->new;

    # These are equivalent
    $email_field = $form->field('person.email');
    $email_field = $form->form('person')->field('email');

Methods on the sub-forms maybe accessed in a similar manner.

    $person = $form->form('person')->person_from_form();

By default, methods are delegated to sub-forms automatically, so this works too.

    $person = $form->person_from_form();

(See the L<delegate_to_subforms()|/delegate_to_subforms> method to learn how to alter this behavior.)

Nested forms may have their own fields as well, and the nesting may continue to an arbitrary depth.  Here's a form that contains a C<PersonAddressForm> as well as two fields of its own.

    package PersonAddressPetsForm;

    use PersonAddressForm;

    sub build_field
    {
      my($self) = shift;

      $self->add_form(pa => PersonAddressForm->new);

      $self->add_fields
      (
        dog => { type => 'text', size => 30 },
        cat => { type => 'text', size => 30 },
      );
    }

Sub-form and field addressing works as expected.  Here are several equivalent ways to get at the person's email field.

    $form = PersonAddressPetsForm->new;

    # These are all equivalent
    $email_field = $form->field('pa.person.email');
    $email_field = $form->form('pa.person')->field('email');
    $email_field = $form->form('pa')->form('person')->field('email');

Sub-form method calls and delegation also works as expected.

    # Call method on the PersonForm, two different ways
    $person = $form->form('pa')->form('person')->person_from_form();
    $person = $form->form('pa.person')->person_from_form();

    # Rely on delegation instead
    $person = $form->form('pa')->person_from_form();
    $person = $form->person_from_form();

Nested forms are a great way to build on top of past work.  When combined with traditional subclassing, form generation can be entirely cleansed of duplicated code.

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

=head1 CLASS METHODS

=over 4

=item B<delegate_to_subforms [SETTING]>

Get or set the value that determines how (or if) forms of this class delegate unresolved method calls to L<sub-forms|/"NESTED FORMS">.  If a method is called on a form of this class, and that method does not exist in this class or any other class in its inheritance hierarchy, then the method may optionally be delegated to a L<sub-forms|/"NESTED FORMS">.  Valid values for SETTING are:

=over 4

=item "B<0>"

A value of "0" (or undef or any other false value) means that no sub-form delegation will be attempted.

=item "B<1>"

A value of "1" means the same thing as a value of "runtime" (see below).

=item "B<compile>"

For each unresolved method call, each sub-form is is considered in the order that they are returned from the L<forms|/forms> method until one is found that L<can|perlobj/can> handle this method.  If one is found, then a new proxy method is added to this class that calls the requested method on the sub-form, passing all arguments unmodified.  That proxy method is then called.

Subsequent invocations of this method will no longer trigger the search process.  Instead, they will be handled by the newly-compiled proxy method.  This is more efficient than repeating the sub-form search each time, but it also means that a change in the list of sub-forms could render the newly compiled method useless (e.g., if the sub-form it delegates to is removed).

If no sub-form can handle the method, then a fatal "unknown method" error occurs.

=item "B<runtime>"

For each unresolved method call, each sub-form is is considered in the order that they are returned from the L<forms|/forms> method until one is found that L<can|perlobj/can> handle this method.  If one is found, then the method is called on that sub-form, passing all arguments unmodified.  

Subsequent invocations of this method will trigger the same search process, again looking for a a sub-form that can handle it.  This is less efficient than compiling a new proxy method as described in the documentation for the "compile" setting above, but it does mean that any changes in the list of sub-forms will be handled correctly.

If no sub-form can handle the method, then a fatal "unknown method" error occurs.

=back

The default value for SETTING is B<compile>.  See the  L<nested forms|/"NESTED FORMS"> section for some examples of sub-form delegation.

=back

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

Add the fields specified by ARGS to the list of fields contained in this form.  Valid formats for elements of ARGS are:

=over 4 

=item B<Field objects>

If an argument is "isa" L<Rose::HTML::Form::Field>, then it is added to the list of fields, stored under the name returned by the field's L<name|Rose::HTML::Form::Field/name> method.

=item B<Field name/type pairs>

A pair of simple scalars is taken as a field name and type.  The class that corresponds to the specified field type is determined by calling the L<field_type_class|/field_type_class> method.  Then a new object of that class is constructed and added to the form.

=item B<Field name/hashref pairs>

A simple scalar followed by a reference to a hash it taken as a field name and a collection of object attributes.  The referenced hash must contain a value for the C<type> key.  The field class that corresponds to the specified field type is determined by calling the L<field_type_class|/field_type_class> method.  Then a new object of that class is constructed, with the remaining key/value pairs in the hash are passed to the constructor.  The completed field object is then added to the form.

=item B<Field name/object pairs>

A simple scalar followed by an object that "isa" L<Rose::HTML::Form::Field> is stored as-is, under the specified name.

=back

Each field's L<parent_form|Rose::HTML::Form::Field/parent_form> is set to the form object.  If the field's L<rank|Rose::HTML::Form::Field/rank> is undefined, it's set to the value of the form's L<field_rank_counter|/field_rank_counter> attribute and the rank counter is incremented.

Adding a field with the same name as an existing L<sub-form|/"NESTED FORMS"> will cause a fatal error.

Examples:

    # Name/hashref pairs
    $form->add_fields(name  => { type => 'text',  size => 20 },
                      email => { type => 'email', size => 30 });

    # Name/type pairs
    $form->add_fields(name  => 'text',
                      email => 'email');

    $name_field = 
      Rose::HTML::Form::Field::Text->new(name => 'name',
                                         size => 25);

    $email_field = 
      Rose::HTML::Form::Field::Text->new(name => 'email',
                                         size => 50);

    # Object arguments
    $form->add_fields($name_field, $email_field);

    # Name/object pairs
    $form->add_fields(name  => $name_field, 
                      email => $email_field);

    # Mixed
    $form->add_fields($name_field, 
                      email => $email_field,
                      nick  => { type => 'text', size => 15 },
                      age   => 'text');

=item B<add_form ARGS>

This is an alias for the L<add_forms()|/add_forms> method.

=item B<add_forms ARGS>

Add the forms specified by ARGS to the list of sub-forms contained in this form.  See the L<nested forms|/"NESTED FORMS"> section for more information.

Valid formats for elements of ARGS are:

=over 4 

=item B<Form objects>

If an argument is "isa" L<Rose::HTML::Form>, then it is added to the list of forms, stored under the name returned by the form's L<form_name|/form_name> method.

=item B<Form name/object pairs>

A simple scalar followed by an object that "isa" L<Rose::HTML::Form> has its L<form_name|/form_name> set to the specified name and then is stored under that name.

If the name contains any dots (".") it will be taken as a hierarchical name and the form will be added to the specified sub-form under an unqualified name consisting of the final part of the name.  (See examples below.)

=back

Each form's L<parent_form|/parent_form> is set to the form object it was added to.  If the form's L<rank|/rank> is undefined, it's set to the value of the form's L<form_rank_counter|/field_rank_counter> attribute and the rank counter is incremented.

Adding a form with the same name as an existing field will cause a fatal error.

Examples:

    $a_form = Rose::HTML::Form->new(...);
    $b_form = Rose::HTML::Form->new(...);

    # Object arguments
    $form->add_forms($a_form, $b_form);

    # Name/object pairs
    $form->add_forms(a => $a_form, b => $b_form);

    # Mixed
    $form->add_forms($a_form, b => $b_form);

    # Set nested form from the top-level
    $w_form = Rose::HTML::Form->new(...);
    $x_form = Rose::HTML::Form->new(...);
    $y_form = Rose::HTML::Form->new(...);
    $z_form = Rose::HTML::Form->new(...);

    $w_form->add_form('x' => $x_form);
    $x_form->add_form('y' => $y_form);

    # Add $z_form to $w_form->form('x')->form('y') under the name 'z'
    $w_form->add_form('x.y.z' => $z_form);

=item B<add_param_value NAME, VALUE>

Add VALUE to the parameter named NAME.  Example:

    $form->param(a => 1);
    print $form->param('a'); # 1

    $form->add_param_value(a => 2);

    print join(',', $form->param('a')); # 1,2

=item B<build_on_init [BOOL]>

Get or set a boolean flag that indicates whether or not L<build_form()|/build_form> should be called from within the L<init()|Rose::Object/init> method.  See L<build_form()|/build_form> for more information.

=item B<build_form>

This default implementation of this method is a no-op.  It is meant to be overridden by subclasses.  It is called at the end of the L<init()|Rose::Object/init> method if L<build_on_init()|/build_on_init> is true. (Remember that this class inherits from L<Rose::HTML::Object>, which inherits from L<Rose::Object>, which defines the L<init()|Rose::Object/init> method, which is called from the constructor.  See the L<Rose::Object> documentation for more information.)

If L<build_on_init()|/build_on_init> is false, then you must remember to call L<build_form()|/build_form> manually.

Subclasses should populate the field list in their overridden versions of L<build_form()|/build_form>.  Example:

  sub build_form 
  {
    my($self) = shift;

    $self->add_fields
    (
      name  => { type => 'text',  size => 25, required => 1 },
      email => { type => 'email', size => 50, required => 1 },
      phone => { type => 'phone' },
    );
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

The default implementation performs a string comparison on the L<name|Rose::HTML::Form::Field/name>s of the fields.

=item B<compare_forms [FORM1, FORM2]>

Compare two forms, returning 1 if FORM1 should come before FORM2, -1 if FORM2 should come before FORM1, or 0 if neither form should come before the other.  This method is called from within the L<form_names|/form_names> and L<field_monikers|/field_monikers> methods to determine the order of the sub-forms nested within this form.

The default implementation compares the L<rank|/rank> of the forms in numeric context.

=item B<delete_field NAME>

Delete the form stored under the name NAME.  If NAME "isa" L<Rose::HTML::Form::Field>, then the L<name|Rose::HTML::Form::Field/name> method is called on it and the return value is used as NAME.

=item B<delete_fields>

Delete all fields, leaving the list of fields empty.  The L<field_rank_counter|/field_rank_counter> is also reset to 1.

=item B<delete_field_type_class TYPE>

Delete the type/class L<mapping|/field_type_classes> entry for the field type TYPE.

=item B<delete_form NAME>

Delete the form stored under the name NAME.  If NAME "isa" L<Rose::HTML::Form>, then the L<form_name|/form_name> method is called on it and the return value is used as NAME.

=item B<delete_forms>

Delete all sub-forms, leaving the list of sub-forms empty.  The L<form_rank_counter|/form_rank_counter> is also reset to 1.

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

If both NAME and VALUE arguments are passed, then the VALUE must be a L<Rose::HTML::Form::Field> or a reference to a hash whose contents are as described in the documentation for the L<add_fields|/add_fields> method. 

=item B<fields>

Returns an ordered list of this form's field objects in list context, or a reference to this list in scalar context.  The order of the fields matches the order of the field names returned by the L<field_monikers|/field_monikers> method.

=item B<field_monikers>

Returns an ordered list of field monikers in list context, or a reference to this list in scalar context.  A "moniker" is a fully qualified name, including any sub-form or sub-field prefixes  (e.g., "pa.person.email" as seen in the L<nested forms|/"NESTED FORMS"> section above).

The order is determined by the L<compare_forms|/compare_forms> and L<compare_fields|/compare_fields> methods.  The L<compare_forms|/compare_forms> method is passed the parent form of each field.  If it returns a true value, then that value is used to sort the two fields being compared.  If it returns false, then the L<compare_fields|/compare_fields> method is called with the two field objects as arguments and its return value is used to determine the order.  See the documentation for the L<compare_forms|/compare_forms> and L<compare_fields|/compare_fields> methods for more information.

=item B<field_names>

This method simply calls L<field_monikers|/field_monikers>.

=item B<field_rank_counter [INT]>

Get or set the value of the counter used to set the L<rank|Rose::HTML::Form::Field/rank> of fields as they're L<added|/add_fields> to the form.  The counter starts at 1 by default.

=item B<field_type_class TYPE [, CLASS]>

Given the field type string TYPE, return the name of the L<Rose::HTML::Form::Field>-derived class mapped to that name.  If a CLASS is passed, the field type TYPE is mapped to CLASS.  In both cases, the TYPE argument is automatically converted to lowercase.

=item B<field_type_classes [MAP]>

Get or set the hash that maps field type strings to the names of the L<Rose::HTML::Form::Field>-derived classes.

This hash is class data.  If you want to modify it, I suggest making your own subclass of L<Rose::HTML::Form> and then calling this method on your derived class.

If passed MAP (a list of type/class pairs or a reference to a hash of the same) then MAP replaces the current field type mapping.  Returns a list of type/class pairs (in list context) or a reference to the hash of type/class mappings (in scalar context).

The default mapping of type names to class names is:

  'text'               => Rose::HTML::Form::Field::Text
  'scalar'             => Rose::HTML::Form::Field::Text
  'char'               => Rose::HTML::Form::Field::Text
  'character'          => Rose::HTML::Form::Field::Text
  'varchar'            => Rose::HTML::Form::Field::Text
  'string'             => Rose::HTML::Form::Field::Text

  'text area'          => Rose::HTML::Form::Field::TextArea
  'textarea'           => Rose::HTML::Form::Field::TextArea
  'blob'               => Rose::HTML::Form::Field::TextArea

  'checkbox'           => Rose::HTML::Form::Field::Checkbox
  'check'              => Rose::HTML::Form::Field::Checkbox

  'radio button'       => Rose::HTML::Form::Field::RadioButton
  'radio'              => Rose::HTML::Form::Field::RadioButton

  'checkboxes'         => Rose::HTML::Form::Field::CheckboxGroup
  'checks'             => Rose::HTML::Form::Field::CheckboxGroup
  'checkbox group'     => Rose::HTML::Form::Field::CheckboxGroup
  'check group'        => Rose::HTML::Form::Field::CheckboxGroup

  'radio buttons'      => Rose::HTML::Form::Field::RadioButton
  'radios'             => Rose::HTML::Form::Field::RadioButtonGroup
  'radio button group' => Rose::HTML::Form::Field::RadioButtonGroup
  'radio group'        => Rose::HTML::Form::Field::RadioButtonGroup

  'pop-up menu'        => Rose::HTML::Form::Field::PopUpMenu
  'popup menu'         => Rose::HTML::Form::Field::PopUpMenu
  'menu'               => Rose::HTML::Form::Field::PopUpMenu

  'select box'         => Rose::HTML::Form::Field::SelectBox
  'selectbox'          => Rose::HTML::Form::Field::SelectBox
  'select'             => Rose::HTML::Form::Field::SelectBox

  'submit'             => Rose::HTML::Form::Field::Submit
  'submit button'      => Rose::HTML::Form::Field::Submit

  'reset'              => Rose::HTML::Form::Field::Reset
  'reset button'       => Rose::HTML::Form::Field::Reset

  'file'               => Rose::HTML::Form::Field::File
  'upload'             => Rose::HTML::Form::Field::File

  'password'           => Rose::HTML::Form::Field::Password

  'hidden'             => Rose::HTML::Form::Field::Hidden

  'int'                => Rose::HTML::Form::Field::Integer,
  'integer'            => Rose::HTML::Form::Field::Integer,

  'email'              => Rose::HTML::Form::Field::Email

  'phone'              => Rose::HTML::Form::Field::PhoneNumber::US
  'phone us'           => Rose::HTML::Form::Field::PhoneNumber::US

  'phone us split' =>
    Rose::HTML::Form::Field::PhoneNumber::US::Split

  'set'  => Rose::HTML::Form::Field::Set

  'time' => Rose::HTML::Form::Field::Time

  'time split hms' => 
    Rose::HTML::Form::Field::Time::Split::HourMinuteSecond

  'time hours'       => Rose::HTML::Form::Field::Time::Hours
  'time minutes'     => Rose::HTML::Form::Field::Time::Minutes
  'time seconds'     => Rose::HTML::Form::Field::Time::Seconds

  'date'             => Rose::HTML::Form::Field::Date
  'datetime'         => Rose::HTML::Form::Field::DateTime

  'datetime range'   => Rose::HTML::Form::Field::DateTime::Range

  'datetime start'   => Rose::HTML::Form::Field::DateTime::StartDate
  'datetime end'     => Rose::HTML::Form::Field::DateTime::EndDate

  'datetime split mdy' => 
    Rose::HTML::Form::Field::DateTime::Split::MonthDayYear

  'datetime split mdyhms' => 
    Rose::HTML::Form::Field::DateTime::Split::MDYHMS

=item B<field_value NAME>

Returns the L<internal_value|Rose::HTML::Form::Field/internal_value> of the field named NAME.  In other words, this:

    $val = $form->field_value('zip_code');

is just a shorter way to write this:

    $val = $form->field('zip_code')->internal_value;

=item B<form NAME [, OBJECT]>

Get or set the sub-form named NAME.  If just NAME is passed, the specified sub-form object is returned.  If no such sub-form exists, undef is returnend.

If both NAME and OBJECT are passed, a new sub-form is added under NAME.

NAME is a fully-qualified sub-form name.  Components of the hierarchy are separated by dots (".").  OBJECT must be an object that inherits from L<Rose::HTML::Form>.

=item B<forms>

Returns an ordered list of this form's sub-form objects (if any) in list context, or a reference to this list in scalar context.  The order of the form matches the order of the form names returned by the L<form_names|/form_names> method.

See the L<nested forms|/"NESTED FORMS"> section to learn more about nested forms.

=item B<form_name [NAME]>

Get or set the name of this form.  This name may or may not have any connection with the value of the "name" HTML attribute on the E<lt>formE<gt> tag.  See the documentation for the L<name|/name> method for details.

=item B<form_names>

Returns an ordered list of form names in list context, or a reference to this list in scalar context.  The order is determined by the L<compare_forms|/compare_forms> method.  Note that this only lists the forms that are direct children of the current form.  Forms that are nested more than one level deep are not listed.

=item B<form_rank_counter [INT]>

Get or set the value of the counter used to set the L<rank|/rank> of sub-forms as they're L<added|/add_forms> to the form.  The counter starts at 1 by default.

=item B<hidden_fields>

Returns one or more L<Rose::HTML::Form::Field::Hidden> objects that represent the hidden fields needed to encode all of the field values in this form.

If L<coalesce_hidden_fields()|/coalesce_hidden_fields> is true, then each compound field is encoded as a single hidden field.  Otherwise, each subfield of a compound field will be have its own hidden field.

=item B<html_hidden_fields>

Returns the HTML serialization of the fields returned by L<hidden_fields()|/hidden_fields>, joined by newlines.

=item B<init_fields [ARGS]>

Initialize the fields based on L<params()|/params>.  In general, this works as you'd expect, but the details are a bit complicated.

The intention of L<init_fields()|/init_fields> is to set field values based solely and entirely on L<params()|/params>.  That means that default values for fields should not be considered unless they are explicitly part of L<params()|/params>.

In general, default values for fields exist for the purpose of displaying the HTML form with certain items pre-selected or filled in.  In a typical usage scenario, those default values will end up in the web browser form submission and, eventually, as as an explicit part of part L<params()|/params>, so they are not really ignored.

But to preserve the intended functionality of L<init_fields()|/init_fields>, the first thing this method does is L<clear()|/clear> the form. If a C<no_clear> parameter with a true value is passed as part of ARGS, then this step is skipped.

If a parameter name exactly matches a field's name (note: the field's L<name|Rose::HTML::Form::Field/name>, which is not necessarily the the same as the name that the field is stored under in the form), then the (list context) value of that parameter is passed as the L<input_value()|Rose::HTML::Form::Field/input_value> for that field.

If a field "isa" L<Rose::HTML::Form::Field::Compound>, and if no parameter exactly matches the L<name|Rose::HTML::Form::Field/name> of the compound field, then each subfield may be initialized by a parameter name that matches the subfield's L<name|Rose::HTML::Form::Field/name>.

If a field is an "on/off" type of field (e.g., a radio button or checkbox), then the field is turned "on" only if the value of the parameter that matches the field's L<name|Rose::HTML::Form::Field/name> exactly matches (string comparison) the "value" HTML attribute of the field.  If not, and if L<params_exist()|/params_exist>, then the field is set to "off".  Otherwise, the field is not modified at all.

Examples:

    package RegistrationForm;
    ...
    sub build_form 
    {
      my($self) = shift;

      $self->add_fields
      (
        name => { type => 'text', size => 25 },

        gender => 
        {
          type    => 'radio group',
          choices => { 'm' => 'Male', 'f' => 'Female' },
          default => 'm'
        },

        hobbies =>
        {
          type    => 'checkbox group',
          name    => 'hobbies',
          choices => [ 'Chess', 'Checkers', 'Knitting' ],
          default => 'Chess'
        },

        bday = => { type => 'date split mdy' }
      );
    }

    ...

    $form = RegistrationForm->new();

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
    $form->params('name'       => 'John',
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
    #
    # No name, Male, no hobbies, no birthday
    $form->init_fields(no_clear => 1);

=item B<init_fields_with_cgi CGI [, ARGS]>

This method is a shortcut for initializing the form's L<params|/params> with a CGI object and then calling L<init_fields|/init_fields>.  The CGI argument is passed to the L<params_from_cgi|/params_from_cgi> method and ARGS are passed to the L<init_fields|/init_fields> method.

For example, this:

    $form->init_fields_with_cgi($cgi, no_clear => 1);

Is equivalent to this:

    $form->params_from_cgi($cgi);
    $form->init_fields(no_clear => 1);

See the documentation for the L<params_from_cgi|/params_from_cgi> and L<init_fields|/init_fields> methods for more information.

=item B<init_fields_with_apache APR [, ARGS]>

This method is a shortcut for initializing the form's L<params|/params> with an apache request object and then calling L<init_fields|/init_fields>.  The APR argument is passed to the L<params_from_apache|/params_from_apache> method and ARGS are passed to the L<init_fields|/init_fields> method.

For example, this:

    $form->init_fields_with_apache($r, no_clear => 1);

Is equivalent to this:

    $form->params_from_apache($r);
    $form->init_fields(no_clear => 1);

See the documentation for the L<params_from_apache|/params_from_apache> and L<init_fields|/init_fields> methods for more information.

=item B<init_with_object OBJECT>

Initialize the form based on OBJECT.  First, the form is L<clear()|/clear>ed.  Next, for each field L<name()|Rose::HTML::Form::Field/name>, if the object has a method with the same name, then the return value of that method (called in scalar context) is passed as the L<input_value()|Rose::HTML::Form::Field/input_value> for the form field of the same name.

The actual code for the L<init_with_object()|/init_with_object> method may be more clear than the description above.  Essentially, it does this:

    sub init_with_object
    {
      my($self, $object) = @_;

      $self->clear();

      foreach my $field ($self->fields)
      {
        my $name = $field->local_name;

        if($object->can($name))
        {
          $field->input_value(scalar $object->$name());
        }
      }
    }

Use this method as a "helper" when writing your own methods such as C<init_with_person()>, as described in the example in the L<overview|/OVERVIEW>. L<init_with_object()|/init_with_object> should be called in the code for subclasses of L<Rose::HTML::Form>, but never by an end-user of such classes.

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

=item B<local_field NAME [, VALUE]>

Get or set a field that is an immediate child of the current form.  That is, it does not belong to a L<nested form|/"NESTED FORMS">.  If the field specified by NAME does not meet these criteria, then undef is returned.  In all other respects, this method behaves like the L<field|/field> method.

Note that NAME should be the name as seen from the perspective of the form object upon which this method is called.  So a nested form can always address its local fields using their "short" (unqualified) names even if the form is actually nested within another form.

=item B<local_form NAME [, OBJECT]>

Get or set a form that is an immediate child of the current form.  That is, it does not belong to a L<nested form|/"NESTED FORMS">.  If the form specified by NAME does not meet these criteria, then undef is returned.  In all other respects, this method behaves like the L<form|/form> method.

Note that NAME should be the name as seen from the perspective of the form object upon which this method is called.  So a nested form can always address its local sub-forms using their "short" (unqualified) names even if the parent form itself is actually nested within another form.

=item B<name [NAME]>

If passed a NAME argument, then the "name" HTML attribute is set to NAME.

If called without any arguments, and if the "name" HTML attribute is empty, then the "name" HTML attribute is set to the L<form_name|/form_name>.

Returns the value of the "name" HTML attribute.

=item B<object_from_form OBJECT | CLASS | PARAMS>

Returns an object built based on the contents of the form.  

For each field L<name()|Rose::HTML::Form::Field/name>, if the object has a method with the same name, then the L<internal_value()|Rose::HTML::Form::Field/internal_value> of the field is passed to the object method of that name.  The actual code is just about as concise as my description:

  foreach my $field ($self->fields)
  {
    my $name = $field->local_name;

    if($object->can($name))
    {
      $object->$name($field->internal_value);
    }
  }

To do this, the method needs an object.  If passed an OBJECT argument, then that's the object that's used.  If passed a CLASS name, then a new object is constructed by calling L<new()|/new> on that class.  OBJECT or CLASS may alternately be passed as a name/value pair in PARAMS.

Use this method as a "helper" when writing your own methods such as C<person_from_form()>, as described in the example in the L<overview|/OVERVIEW>. L<object_from_form()|/object_from_form> should be called in the code for subclasses of L<Rose::HTML::Form>, but never by an end-user of such classes.

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

PARAMS can be a reference to a hash or a list of name/value pairs.  If a parameter has multiple values, those values should be provided in the form of a reference to an array of scalar values.  If the list of name/value pairs has an odd number of items, a fatal error occurs.

If PARAMS is a reference to a hash, then it is accepted as-is.  That is, no copying of values is done; the actual hash references is stored.  If PARAMS is a list of name/value pairs, then a deep copy is made during assignment.

Regardless of the arguments, this method returns the complete set of parameters in the form of a hash (in list context) or a reference to a hash (in scalar context).

In scalar context, the hash reference returned is a reference to the actual hash used to store parameter names and values in the object.  It should be treated as read-only.

The hash returned in list context is a deep copy of the actual hash used to store parameter names and values in the object.  It may be treated as read/write.

=item B<params_exist>

Returns true if any parameters exist, false otherwise.

=item B<param_exists NAME>

Returns true if a parameter named NAME exists, false otherwise.

=item B<param_exists_for_field [ NAME | FIELD ]>

Returns true if a L<param|/param> exists that addresses the field named NAME or the L<Rose::HTML::Form::Field>-derived object FIELD, false otherwise.

This method is useful for determining if any query parameters exist that address a compound field.  For example, a compound field named C<a.b.c.d> could be addressed by any one of the following query parameters: C<a>, C<a.b>, C<a.b.c>, or C<a.b.c.d>.  This method also works with fields inside L<sub-form|/"NESTED FORMS">.  Examples:

    $form = Rose::HTML::Form->new;
    $form->add_field(when => { type => 'datetime split mdyhms' });

    $form->params({ 'when.date' => '2004-01-02' });

    $form->param_exists_for_field('when');            # true
    $form->param_exists_for_field('when.date');       # true
    $form->param_exists_for_field('when.date.month'); # true
    $form->param_exists_for_field('when.time.hour');  # false

    $subform = Rose::HTML::Form->new;
    $subform->add_field(subwhen => { type => 'datetime split mdyhms' });
    $form->add_form(subform => $subform);

    $form->params({ 'subform.subwhen.date' => '2004-01-02' });

    $form->param_exists_for_field('subform.subwhen');            # true
    $form->param_exists_for_field('subform.subwhen.date');       # true
    $form->param_exists_for_field('subform.subwhen.date.month'); # true
    $form->param_exists_for_field('subform.subwhen.time.hour');  # false

    $form->param_exists_for_field('when');            # false
    $form->param_exists_for_field('when.date');       # false
    $form->param_exists_for_field('when.date.month'); # false
    $form->param_exists_for_field('when.time.hour');  # false

=item B<params_from_apache APR>

Set L<params|/params> by extracting parameter names and values from an apache request object.  Calling this method entirely replaces the previous L<params|/params>.

If running under L<mod_perl> 1.x, the APR argument may be:

=over 4

=item * An L<Apache> object.  In this case, the L<Apache::Request> module must also be installed.

=item * An L<Apache::Request> object.

=back

If running under L<mod_perl> 2.x, the APR may be:

=over 4

=item * An L<Apache2::RequestRec> object.  In this case, the L<Apache2::Request> module must also be installed.

=item * An L<Apache2::Request> object.

=back

In all cases, APR may be an object that has a C<param()> method that behaves in the following way:

=over 4

=item * When called in list context with no arguments, it returns a list of parameter names.

=item * When called in list context with a single parameter name argument, it returns a list of values for that parameter.

=back

=item B<params_from_cgi CGI>

Set L<params|/params> by extracting parameter names and values from a L<CGI> object.  Calling this method entirely replaces the previous L<params|/params>.  The CGI argument must be either a L<CGI> object or must have a C<param()> method that behaves in the following way:

=over 4

=item * When called in list context with no arguments, it returns a list of parameter names.

=item * When called in list context with a single parameter name argument, it returns a list of values for that parameter.

=back

=item B<param_value_exists NAME, VALUE>

Determines if a parameter of a particular name exists and has a particular value. This method returns true if the parameter named NAME exists and also has a value that is equal to (string comparison) VALUE. Otherwise, it returns false.

A fatal error occurs unless both NAME and VALUE arguments are passed.

=item B<parent_form [FORM]>

Get or set the parent form, if any.  The reference to the parent form is "weakened" using L<Scalar::Util::weaken()|Scalar::Util/weaken> in order to avoid memory leaks caused by circular references.

=item B<query_string>

Returns a URI-escaped (but I<not> HTML-escaped) query string that corresponds to the current state of the form.  If L<coalesce_query_string_params()|/coalesce_query_string_params> is true (which is the default), then compound fields are represented by a single query parameter.  Otherwise, the subfields of each compound field appear as separate query parameters.

=item B<rank [INT]>

Get or set the form's rank.  This value can be used for any purpose that suits you, but by default it's used by the L<compare_forms|/compare_forms> method to sort sub-forms.

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

=item B<validate [PARAMS]>

Validate the form by calling L<validate()|Rose::HTML::Form::Field/validate> on each field and L<validate()|/validate> on each each L<sub-form|/"NESTED FORMS">.  If any field or form returns false from its C<validate()> method call, then this method returns false.  Otherwise, it returns true.

If this method returns false and an L<error|Rose::HTML::Object/error> is not defined on any invalid field or form, then the L<error|Rose::HTML::Object/error> attribute of this form is set to a generic error message.  Otherwise, this form's error attribute is set to the error attribute of the last invalid field or form.

PARAMS are name/value pairs.  Valid parameters are:

=over 4

=item C<cascade BOOL>

If true, then the L<validate()|/validate> method of each sub-form is called, passing PARAMS, with a C<form_only> parameter set to true.  The default value of the C<cascade> parameter is true.  Note that all fields in all nested forms are validated regardless of the value of this parameter.

=item C<form_only BOOL>

If true, then the  L<validate|Rose::HTML::Form::Field/validate> method is not called on the fields of this form and its sub-forms.  Defaults to false, but is set to true when calling  L<validate()|/validate> on sub-forms in response to the C<cascade> parameter.

=back

Examples:

    $form = Rose::HTML::Form->new;
    $form->add_field(foo => { type => 'text' });

    $subform = Rose::HTML::Form->new;
    $subform->add_field(bar => { type => 'text' });

    $form->add_form(sub => $subform);

    # Call validate() on fields "foo" and "sub.bar" and
    # call validate(form_only => 1) on the sub-form "sub"
    $form->validate;

    # Same as above
    $form->validate(cascade => 1);

    # Call validate() on fields "foo" and "sub.bar"
    $form->validate(cascade => 0);

    # Call validate(form_only => 1) on the sub-form "sub"
    $form->validate(form_only => 1);

    # Don't call validate() on any fields or sub-forms
    $form->validate(form_only => 1, cascade => 0);

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

Copyright (c) 2006 by John C. Siracusa.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
