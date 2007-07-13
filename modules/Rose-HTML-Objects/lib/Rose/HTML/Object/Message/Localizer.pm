package Rose::HTML::Object::Message::Localizer;

use strict;

use Carp;
use Clone::PP();
use Scalar::Util();

use Rose::HTML::Object::Errors();
use Rose::HTML::Object::Messages();

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.542';

our $Debug = 0;

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
  inheritable_scalar => 
  [
    'default_locale',
    '_auto_load_messages',
    '_auto_load_locales',
  ],
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

  my $child = $msg;

  if($child->can('parent'))
  {
    $child = $child->parent;
  }

  if($child && $child->isa('Rose::HTML::Object::Error'))
  {
    $child = $child->parent;
  }

  my $calling_class = $child ? ref($child) : $args{'caller'} || (caller)[0];

  my $args   = $args{'args'}   || $msg->args;
  my $locale = $args{'locale'} || $msg->locale || $self->locale;

  my $id = $msg->id;

  my $text = $self->get_localized_message($id, $locale, $calling_class);

  # Look for messages in parent fields
  while(!defined $text && $child && $child->can('parent_field'))
  {
    if($child = $child->parent_field)
    {
      $text = $self->get_localized_message($id, $locale, ref($child));
    }
  }

  return $self->process_placeholders($text, $args)  if(defined $text);  

  my $cascade = $self->locale_cascade($locale) ||
                $self->locale_cascade('default') || return undef;

  foreach my $other_locale (@$cascade)
  {
    $text = $self->get_localized_message($id, $other_locale, $calling_class);
    return $self->process_placeholders($text, $args) if(defined $text);  
  }

  return undef;
}

# All this to avoid making Scalar::Defer a prerequisite....sight.
sub _evaluate
{  
  no warnings 'uninitialized';
  return $_[0]  unless(ref $_[0] eq 'CODE');
  return $_[0]->();
}

sub process_placeholders
{
  my($self, $text, $args) = @_;

  my %args = $args ? %$args : ();

   # Values will be modified in-place
  foreach my $value (values %args)
  {
    if(my $ref = ref($value))
    {
      if($ref eq 'ARRAY')
      {
        $value = [ map { _evaluate($_) } @$value ];
      }
      else
      {
        $value = _evaluate($value);
      }
    }
  }

  for($text)
  {
    # Process [@123(...)] and [@foo(...)] placeholders
    s{ ( (?:\\.|[^\[]*)* ) \[ \@ (\d+ | [a-zA-Z]\w* ) (?: \( (.*) \) )? \] }
     { $1 . join(defined $3 ? $3 : ', ', ref $args{$2} ? @{$args{$2}} : $args{$2}) }gex;

    # Process [123] and [foo] placeholders
    s{ ( (?:\\.|[^\[]*)* ) \[ (\d+ | [a-zA-Z]\w* ) \] }{$1$args{$2}}gx;

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

sub locales_for_message_name
{
  my($self, $name) = @_;

  my $msgs = $self->localized_messages_hash;

  return wantarray ? () : []  unless(ref $msgs->{$name});

  return wantarray ? (sort keys %{$msgs->{$name}}) :
                     [ sort keys %{$msgs->{$name}} ];
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
    $Debug && warn qq($self - Adding text $name ($l) - "$t"\n);
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
    $Debug && warn qq($self - Adding message $name ($l) = "$t"\n);
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

sub dump_messages
{
  my($self, $code) = @_;
  my $msgs = $self->localized_messages_hash;
  return $code->($msgs)  if($code);
  require Data::Dumper;
  return Data::Dumper::Dumper($msgs);
}

sub get_localized_message
{
  my($self, $id_or_name, $locale, $load_from_class) = @_;

  $load_from_class ||= (caller)[0];

  my $name = $self->get_message_name($id_or_name) || $id_or_name;

  $locale = lc $locale;

  my $msgs = $self->localized_messages_hash;

  if(exists $msgs->{$name} && exists $msgs->{$name}{$locale})
  {
    return $msgs->{$name}{$locale};
  }

  my $msg = $self->_get_localized_message($name, $locale, $load_from_class);
  return $msg  if(defined $msg);

  return undef;
}

my $Locale_Declaration = qr(^\s* \[% \s* LOCALE \s* (\S+) \s* %\] \s* (?: \#.*)?$)x;
my $Start_Message = qr(^\s* \[% \s* START \s+ ([A-Z0-9_]+) \s* %\] \s* (?: \#.*)?$)x;
my $End_Message = qr(^\s* \[% \s* END \s+ ([A-Z0-9_]+)? \s* %\] \s* (?: \#.*)?$)x;
my $Message_Spec = qr(^ \s* ([A-Z0-9_]+) \s* = \s* "((?:[^"\\]+|\\.)*)" \s* (?: \#.*)? $)x;
my $Comment_Or_Blank = qr(^ \s* \# | ^ \s* $)x;
my $End_Messages = qr(^=\w|^\s*__END__);

my %Data_Pos;

sub _get_localized_message
{
  my($self, $name, $locale, $load_from_class) = @_;

  $load_from_class ||= $self->messages_class;

  if($self->localized_message_exists($name, $locale))
  {
    return $self->get_localized_message($name, $locale);
  }

  no strict 'refs';
  my $fh = \*{"${load_from_class}::DATA"};

  if(fileno($fh))
  {
    local $/ = "\n";

    if($Data_Pos{$load_from_class})
    {
      # Rewind to the start of the __DATA__ section
      seek($fh, $Data_Pos{$load_from_class}, 0);
    }
    else
    {
      $Data_Pos{$load_from_class} = tell($fh);
    }

    my $text = $self->load_messages_from_fh(fh      => $fh, 
                                            locales => $locale,
                                            names   => $name);
    return $text  if(defined $text);
  }

  no strict 'refs';

  my @classes = @{"${load_from_class}::ISA"};
  my %seen;

  while(@classes)
  {
    my $class = pop(@classes);
    next  if($seen{$class}++);
    #$Debug && warn "$self SEARCHING $class FOR $name ($locale)\n";
    my $msg = $self->_get_localized_message($name, $locale, $class);
    return $msg  if(defined $msg);
    push(@classes, grep { !$seen{$_} } @{"${class}::ISA"});
  }

  return undef;
}

sub auto_load_locales
{
  my($self_or_class) = shift;

  my $class = ref($self_or_class) || $self_or_class;

  if(@_)
  {
    my $locales = (@_ == 1 && ref $_[0] eq 'ARRAY') ? [ @{$_[0]} ] : [ @_ ];
    return $class->_auto_load_locales($locales);
  }

  my $locales = $class->_auto_load_locales;
  return wantarray ? @$locales : $locales  if(defined $locales);

  if(my $locales = $ENV{'RHTMLO_LOCALES'})
  {
    $locales = [ split(/\s*,\s*/, $locales) ]  unless(ref $locales);
    $class->_auto_load_locales($locales);
    return wantarray ? @$locales : $locales;
  }

  return wantarray ? () : [];
}

sub auto_load_messages
{
  my($self_or_class) = shift;

  my $class = ref($self_or_class) || $self_or_class;

  if(@_)
  {
    return $class->_auto_load_messages(@_);
  }

  my $ret = $class->_auto_load_messages;
  return $ret  if(defined $ret);

  if(($ENV{'MOD_PERL'} && (!defined($ENV{'RHTMLO_PRIME_CACHES'}) || $ENV{'RHTMLO_PRIME_CACHES'})) ||
     $ENV{'RHTMLO_PRIME_CACHES'})
  {
    return $class->_auto_load_messages(1);
  }

  return undef;
}

sub load_all_messages
{
  my($class) = shift;

  my $load_from_class = @_ ? $_[0] : (caller)[0];

  no strict 'refs';
  my $fh = \*{"${load_from_class}::DATA"};

  if(fileno($fh))
  {
    local $/ = "\n";

    if($Data_Pos{$load_from_class})
    {
      # Rewind to the start of the __DATA__ section
      seek($fh, $Data_Pos{$load_from_class}, 0);
    }
    else
    {
      $Data_Pos{$load_from_class} = tell($fh);
    }

    my $locales = $class->auto_load_locales;

    $Debug && warn "$class - Loading messages from DATA section of $load_from_class\n";
    $class->load_messages_from_fh(fh => $fh, locales => $locales);
  }
}

sub load_messages_from_file
{
  my($self) = shift;

  my %args;
  if(@_ == 1)
  {
    $args{'file'} = shift;
  }
  elsif(@_ > 1)
  {
    croak "Odd number of arguments passed to load_messages_from_file()"
      if(@_ % 2 != 0);
    %args = @_;
  }

  my $file = delete $args{'file'} or croak "Missing file argument";

  open($args{'fh'}, $file) or croak "Could no open messages file '$file' - $!";
  $self->load_messages_from_fh(%args);
  close($args{'fh'});
}

sub load_messages_from_fh
{
  my($self, %args) = @_;

  my($fh, $locales, $msg_names) = @args{qw(fh locales names)};

  if(ref $locales eq 'ARRAY')
  {
    $locales = @$locales ? { map { $_ => 1} @$locales } : undef;
  }
  elsif($locales && !ref $locales)
  {
    $locales = { $locales => 1 };
  }

  $msg_names = { $msg_names => 1 }  if($msg_names && !ref $msg_names);

  my @text;
  my $in_locale = '';
  my $in_msg    = '';
  my $text      = '';

  my $pos = tell($fh);;

  no strict 'refs';

  local $_;

  while(<$fh>)
  {
    last  if(/$End_Messages/);

    #$Debug && warn "PROC: $_";

    if(/$End_Message/ && (!$2 || $2 eq $in_msg))
    {
      if(!$msg_names || $msg_names->{$in_msg})
      {
        for($text)
        {
          s/\A(\s*\n)+//;
          s/(\s*\n)+\z//;
        }

        $self->add_localized_message_text(name   => $in_msg,
                                          locale => $in_locale,
                                          text   => $text);
      }

      $text = '';
      $in_msg = '';
    }
    elsif($in_msg)
    {
      $text .= $_;
    }
    elsif(/$Locale_Declaration/)
    {
      $in_locale = $1;
    }
    elsif(/$Message_Spec/)
    {
      if((!$locales || $locales->{$in_locale}) && (!$msg_names || $msg_names->{$1}))
      {
        my $name = $1;
        my $text = $2;

        for($text)
        {
          s/\\n/\n/g;
          s/\\(.)/$1/g;
        }

        $self->add_localized_message_text(name   => $name,
                                          locale => $in_locale,
                                          text   => $text);
        push(@text, $text)  if($msg_names);
      }
    }
    elsif(/$Start_Message/)
    {
      $in_msg = $1;
    }
    elsif(!/$Comment_Or_Blank/)
    {
      chomp;
      carp "WARNING: Localized message line not understood: $_";
    }
  }

  # Rewind to the starting position
  seek($fh, $pos, 0);

  return wantarray ? @text : $text[0];
  return;
}

1;
