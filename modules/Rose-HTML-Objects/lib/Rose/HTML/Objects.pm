package Rose::HTML::Objects;

use strict;

use Carp;
use File::Spec();
use File::Path();
use File::Basename();

our $VERSION = '0.555_05';

our $Debug = 0;

sub make_private_library
{
  my($class) = shift;

  my %args = @_;

  my($packages, $perl) = 
    Rose::HTML::Objects->private_library_perl(@_);

  my $debug = exists $args{'debug'} ? $args{'debug'} : $Debug;

  if($args{'in_memory'})
  {
    foreach my $pkg (@$packages)
    {
      my $code = $perl->{$pkg};
      $debug > 2 && warn $code, "\n";
      eval $code;
      die "Could not eval $pkg - $@"  if($@);
    }
  }
  else
  {
    my $dir = $args{'modules_dir'} or croak "Missing modules_dir parameter";    
    mkdir($dir)  unless(-d $dir);
    croak "Could not create modules_dir '$dir' - $!"  unless(-d $dir);

    foreach my $pkg (@$packages)
    {
      my @file_parts = split('::', $pkg);
      $file_parts[-1] .= '.pm';
      my $file = File::Spec->catfile($dir, @file_parts);
      
      my $file_dir = File::Basename::dirname($file);

      File::Path::mkpath($file_dir); # spews errors to STDERR
      croak "Could not make directory '$file_dir'"  unless(-d $file_dir);

      if(-e $file && !$args{'overwrite'})
      {
        $debug && warn "Refusing to overwrite '$file'";
        next;
      }

      open(my $fh, '>', $file) or croak "Could not create '$file' - $!";
      print $fh $perl->{$pkg};
      close($fh) or croak "Could not write '$file' - $!";

      $debug > 2 && warn $perl->{$pkg}, "\n";
    }
  }

  return wantarray ? @$packages : $packages;
}

sub private_library_perl
{
  my($class, %args) = @_;

  my $prefix = $args{'prefix'} or croak "Missing 'prefix' parameter";
  my $trim_prefix = $args{'trim_prefix'} || 'Rose::';
  my $in_memory = $args{'in_memory'} || 0;

  my $prefix_regex = qr(^$trim_prefix);

  my $rename = sub 
  {
    my($name) = shift;
    $name =~ s/$prefix_regex/$prefix/;
    return $name;
  };

  my $class_filter = $args{'class_filter'};

  my(%perl, %isa, @packages);

  require Rose::HTML::Object;

  my $base_object_type = Rose::HTML::Object->object_type_classes;
  my %base_type_object = reverse %$base_object_type;

  my %object_type;

  my $max_type_len = 0;

  while(my($type, $base_class) = each(%$base_object_type))
  {
    $object_type{$type} = $rename->($base_class);
    $max_type_len = length($type)  if(length($type) > $max_type_len);
  }

  my $object_map_perl =<<"EOF";
__PACKAGE__->object_type_classes
(
EOF

  foreach my $type (sort keys %object_type)
  {
    my $class = $object_type{$type};
    $object_map_perl .= sprintf("  %-*s => '$class',\n", $max_type_len + 2, qq('$type'));
  }

  $object_map_perl .=<<"EOF";
);
EOF

  my $object_package    = $rename->('Rose::HTML::Object');
  my $message_package   = $rename->('Rose::HTML::Object::Message::Localized');
  my $messages_package  = $rename->('Rose::HTML::Object::Messages');
  my $error_package     = $rename->('Rose::HTML::Object::Error');
  my $errors_package    = $rename->('Rose::HTML::Object::Errors');
  my $localizer_package = $rename->('Rose::HTML::Object::Message::Localizer');
  my $custom_package    = $rename->('Rose::HTML::Object::Custom');

  my $load_message_and_errors_perl = '';
  
  unless($in_memory)
  {
    $load_message_and_errors_perl=<<"EOF";
use $error_package;
use $errors_package();
use $message_package;
use $messages_package();
EOF
  }

  my $std_messages=<<"EOF";
# Import the standard set of message ids
use Rose::HTML::Object::Messages qw(:all);
EOF

  my $std_errors=<<"EOF";
# Import the standard set of error ids
use Rose::HTML::Object::Errors qw(:all);
EOF

  my %code =
  (
    $message_package =><<"EOF",
sub generic_object_class { '$object_package' }
EOF

    $messages_package =>
    {
      filter => sub
      {
        s/^(use base.+)/$std_messages$1/m;
      },

      code =><<"EOF",
##
## Define your new message ids below
##

# Message ids from 0 to 29,999 are reserved for built-in messages.  Negative
# message ids are reserved for internal use.  Please use message ids 30,000
# or higher for your messages.  Suggested message id ranges and naming
# conventions for various message types are shown below.

# Field labels

#use constant FIELD_LABEL_LOGIN_NAME         => 100_000;
#use constant FIELD_LABEL_PASSWORD           => 100_001;
#...

# Field error messages

#use constant FIELD_ERROR_PASSWORD_TOO_SHORT => 101_000;
#use constant FIELD_ERROR_USERNAME_INVALID   => 101_001;
#...

# Generic messages

#use constant LOGIN_NO_SUCH_USER             => 200_000;
#use constant LOGIN_USER_EXISTS_ERROR        => 200_001;
#...

### %CODE% ###

# This line must be below all the "use constant ..." declarations
BEGIN { __PACKAGE__->add_messages }
EOF
    },

    $errors_package =>
    {
      filter => sub
      {
        s/^(use base.+)/$std_errors$1/m;
      },

      code =><<"EOF",
##
## Define your new error ids below
##

# Error ids from 0 to 29,999 are reserved for built-in errors.  Negative
# error ids are reserved for internal use.  Please use error ids 30,000
# or higher for your errors.  Suggested error id ranges and naming
# conventions for various error types are shown below.

# Field errors

#use constant FIELD_ERROR_PASSWORD_TOO_SHORT => 101_000;
#use constant FIELD_ERROR_USERNAME_INVALID   => 101_001;
#...

# Generic errors

#use constant LOGIN_NO_SUCH_USER             => 200_000;
#use constant LOGIN_USER_EXISTS_ERROR        => 200_001;
#...

### %CODE% ###

# This line must be below all the "use constant ..." declarations
BEGIN { __PACKAGE__->add_errors }
EOF
    },

    $localizer_package =><<"EOF",
$load_message_and_errors_perl
sub init_message_class  { '$message_package' }
sub init_messages_class { '$messages_package' }
sub init_error_class    { '$error_package' }
sub init_errors_class   { '$errors_package' }
EOF

    $custom_package =><<"EOF",
@{[ $in_memory ? "Rose::HTML::Object->import(':customize');" : "use Rose::HTML::Object qw(:customize);" ]}
@{[ $in_memory ? '' : "\nuse $localizer_package;\n" ]}
__PACKAGE__->default_localizer($localizer_package->new);

$object_map_perl
EOF

    $object_package =><<"EOF",
sub generic_object_class { '$object_package' }
EOF
  );

  #
  # Rose::HTML::Object
  #

  require Rose::HTML::Object;

  foreach my $base_class (qw(Rose::HTML::Object))
  {
    my $package = $rename->($base_class);
  
    push(@packages, $package);

    if($args{'in_memory'})
    {
      # Prevent "Base class package "..." is empty" errors from base.pm
      no strict 'refs';
      ${"${custom_package}::VERSION"} = $Rose::HTML::Object::VERSION;

      # XXX" Don't need to do this
      #(my $path = $custom_package) =~ s{::}{/}g;
      #$INC{"$path.pm"} = 123;
    }

    $isa{$package} = [ $custom_package, $base_class ];

    $perl{$package} = $class->subclass_perl(package      => $package, 
                                            isa          => $isa{$package},
                                            in_memory    => 0,
                                            default_code => \%code,
                                            code         => $args{'code'},
                                            code_filter  => $args{'code_filter'});
  }

  #
  # Rose::HTML::Object::Errors
  # Rose::HTML::Object::Messages
  # Rose::HTML::Object::Message::Localizer
  #

  require Rose::HTML::Object::Errors;
  require Rose::HTML::Object::Messages;
  require Rose::HTML::Object::Message::Localizer;
  
  foreach my $base_class (qw(Rose::HTML::Object::Error
                             Rose::HTML::Object::Errors
                             Rose::HTML::Object::Messages
                             Rose::HTML::Object::Message::Localized
                             Rose::HTML::Object::Message::Localizer))
  {
    my $package = $rename->($base_class);
  
    push(@packages, $package);
  
    $isa{$package} = $base_class;

    $perl{$package} = $class->subclass_perl(package      => $package, 
                                            isa          => $isa{$package},
                                            in_memory    => 0,
                                            default_code => \%code,
                                            code         => $args{'code'},
                                            code_filter  => $args{'code_filter'});
  }

  #
  # Rose::HTML::Object::Customized
  #

  $perl{$custom_package} =
    $class->subclass_perl(package      => $custom_package, 
                          in_memory    => $in_memory,
                          default_code => \%code,
                          code         => $args{'code'},
                          code_filter  => $args{'code_filter'});

  push(@packages, $custom_package);

  #
  # All other classes
  #

  foreach my $base_class (sort values %$base_object_type)
  {
    if($class_filter)
    {
      local $_ = $base_class;
      next  unless($class_filter->($base_class));
    }

    if($in_memory)
    {
      eval "require $base_class";
      croak "Could not load '$base_class' - $@"  if($@);
    }

    my $package = $rename->($base_class);

    push(@packages, $package);

    unless($isa{$package})
    {
      $isa{$package} = 
      [
        $custom_package,
        $base_type_object{$package} ? $rename->($base_class) : $base_class,
      ];
    }

    $perl{$package} = $class->subclass_perl(package     => $package, 
                                            isa         => $isa{$package},
                                            in_memory   => $in_memory,
                                            code        => $args{'code'},
                                            code_filter => $args{'code_filter'});
  }

  return wantarray ? (\@packages, \%perl) : \%perl;
}

sub isa_perl
{
  my($class, %args) = @_;
  
  my $isa  = $args{'isa'} or Carp::confess "Missing 'isa' parameter";
  $isa = [ $isa ]  unless(ref $isa eq 'ARRAY');

  if($args{'in_memory'})
  {
    return 'our @ISA = qw(' . join(' ', @$isa) . ");";
  }
  else
  {
    return 'use base qw(' . join(' ', @$isa) . ");";
  }
}

our $Perl;

sub subclass_perl
{
  my($class, %args) = @_;
 
  my $package = $args{'package'} or Carp::confess "Missing 'package' parameter";
  my $isa     = $args{'isa'};
  $isa = [ $isa ]  unless(ref $isa eq 'ARRAY');

  my $filter = $args{'code_filter'};

  my($code, @code, @default_code);

  foreach my $param (qw(default_code code))
  {
    my $arg = $args{$param} || '';

    if(ref $arg eq 'HASH')
    {
      $arg = $arg->{$package};
    }
    
    no warnings 'uninitialized';
    if(ref $arg eq 'HASH')
    {
      if(my $existing_filter = $filter)
      {
        my $new_filter = $arg->{'filter'};
        $filter = sub 
        {
          $existing_filter->(@_); 
          $new_filter->(@_);
        };
      }
      else
      {
        $filter = $arg->{'filter'};
      }

      $arg = $arg->{'code'};
    }

    if(ref $arg eq 'CODE')
    {
      $code = $arg->($package, $isa);
    }
    else
    {
      $code = $arg;
    }

    if($code)
    {
      for($code)
      {
        s/^\n*/\n/;
        s/\n*\z/\n/;
      }
    }
    else
    {
      $code = '';
    }

    if($code)
    {
      if($param eq 'code')
      {
        push(@code, $code);      
      }
      else
      {
        push(@default_code, $code);
      }
    }
  }

  foreach my $default_code (@default_code)
  {
    if($default_code =~ /\n### %CODE% ###\n/)
    {
      $default_code =~ s/\n### %CODE% ###\n/join('', @code)/me;
      undef @code; # Attempt to reclaim memory
      undef $code; # Attempt to reclaim memory
    }
  }

  local $Perl;

  $Perl=<<"EOF";
package $package;

use strict;
@{[ $args{'isa'} ? "\n" . $class->isa_perl(%args) . "\n" : '' ]}@{[ join('', @default_code, @code) ]}
1;
EOF

  if($filter)
  {
    local *_ = *Perl;
    $filter->(\$Perl);
  }
  
  return $Perl;
}

1;

__END__

=head1 NAME

Rose::HTML::Objects - Object-oriented interfaces for HTML.

=head1 SYNOPSIS

    use Rose::HTML::Form;

    $form = Rose::HTML::Form->new(action => '/foo',
                                  method => 'post');

    $form->add_fields
    (
      name   => { type => 'text', size => 20, required => 1 },
      height => { type => 'text', size => 5, maxlength => 5 },
      bday   => { type => 'datetime' },
    );

    $form->params(name => 'John', height => '6ft', bday => '01/24/1984');

    $form->init_fields();

    $bday = $form->field('bday')->internal_value; # DateTime object

    print $bday->strftime('%A'); # Tuesday

    print $form->field('bday')->html;

=head1 DESCRIPTION

L<Rose::HTML::Objects> is a framework for creating a resuable set of HTML widgets as mutable Perl objects that can be serialized to HTML or XHTML for display purposes.  

The L<Rose::HTML::Object> class may be used directly to represent a generic tag with an explicitly set L<element|Rose::HTML::Object/element> name and arbitrary L<attributes|<Rose::HTML::Object/html_attr>.  There are also methods for L<parent/child manipulations|Rose::HTML::Object/HIERARCHY>.

Though such generic usage is possible, this family of modules is primarily intended as a framework for creating a resuable set of L<form|Rose::HTML::Form> and L<field|Rose::HTML::Form::Field> widgets as mutable Perl objects that can be serialized to HTML or XHTML for display purposes.  On the Perl side, these objects are treated as abstract entities that can be fed input and will produce output in the form that is most convenient for the programmer (e.g., pass a L<DateTime> object to a date picker field to initialize it, and get a L<DateTime> object back from the field when asking for its value).

Fields may be simple (one standard HTML form field to one Perl field object) or L<compound|Rose::HTML::Form::Field::Compound> (a field object that serializes to an arbitrary number of HTML tags, but can be addressed as a single logical field internally).  Likewise, forms themselves can be L<nested|Rose::HTML::Form/"NESTED FORMS">.

Each L<field|Rose::HTML::Form::Field> has its own customizable validation, input filter, output filter, internal value (a plain value or a Perl object, whatever is most convenient), output value (the value shown when the field is redisplayed), label, associated error, and any other metadata deemed necessary.  Each field can also be serialized to the L<equivalent|Rose::HTML::Form::Field/html_hidden_fields> set of (X)HTML "hidden" fields.

L<Forms|Rose::HTML::Form> are expected to be initialized with, and return an object or list of objects that the form represents.  For example, a registration form could be initialized with and return a C<UserAccount> object.

All labels, errors, and messages used in the bundled form and field widgets are localized in several languages, and you may add your own localized messages and errors using the provided L<localization framework|/LOCALIZATION>.

Users are encouraged to L<create their own library|/"PRIVATE LIBRARIES"> of reusable form and field widgets for use on their site.  The expectation is that the same kind of field appears in multiple places in any large web application (e.g., username fields, password fields, address forms, etc.)  Each field encapsulates a set of values (e.g., options in a pop-up menu), labels, validation constraints, filters, and error messages.  Similarly, each form encapsulates a set of fields along with any inter-field validation, error messages, and init-with/object-from methods.  Nesting forms and fields preserves this delegation of responsibility, with each higher level having access to its children to perform inter-form/field tasks.

=head1 PRIVATE LIBRARIES

The classes that make up the L<Rose::HTML::Objects> distribution can be used as-is to build forms, fields, and other HTML objects.  The provided classes may also be subclassed to change their behavior.  The interconnected nature of these classes may present some surprises, however.  For example, consider the case of subclassing the L<Rose::HTML::Form::Field::Option> class that represents a single option in a L<select box|Rose::HTML::Form::Field::SelectBox> or L<pop-up menu|Rose::HTML::Form::Field::PopUpMenu>.

    package My::HTML::Form::Field::Option;
    
    use base 'Rose::HTML::Form::Field::Option';

    sub bark
    {
      print "woof!\n";
    }

Now all your options can bark like a dog.

    $option = My::HTML::Form::Field::Option->new;
    $option->bark; # woof!

This seems great until you make your first select box or pop-up menu, pull ut an option object, and ask it to bark.

    $color = 
      Rose::HTML::Form::Field::PopUpMenu->new(
        name    => 'color',
        options => [ 'red', 'green', 'blue' ]);

    $option = $color->option('ref');

    $option->bark; # BOOM: fatal error, no such method!

What you'll get is an error message like this: "Can't locate object method 'bark' via package 'Rose::HTML::Form::Field::Option' - ..."  That's because C<$option> is a plain old L<Rose::HTML::Form::Field::Option> object and not one of your new C<My::HTML::Form::Field::Option> objects that can C<bark()>.

This is an example of the aforementioned interconnected nature of HTML objects: L<pop-up menus|Rose::HTML::Form::Field::PopUpMenu> and L<select boxes|Rose::HTML::Form::Field::SelectBox> contain L<options|Rose::HTML::Form::Field::Option>; L<radio button groups|Rose::HTML::Form::Field::RadioButtonGroup> contain L<radio buttons|Rose::HTML::Form::Field::RadioButton>; L<checkbox groups|Rose::HTML::Form::Field::CheckboxGroup> contain L<checkboxes|Rose::HTML::Form::Field::CheckBox>; L<forms|Rose::HTML::Form> contain all of the above; and so on.


####################

=head1 LOCALIZATION



=head1 DEVELOPMENT POLICY

The L<Rose development policy|Rose/"DEVELOPMENT POLICY"> applies to this, and all C<Rose::*> modules.  Please install L<Rose> from CPAN and then run "C<perldoc Rose>" for more information.

=head1 SUPPORT

Any L<Rose::HTML::Objects> questions or problems can be posted to the L<Rose::HTML::Objects> mailing list.  To subscribe to the list or view the archives, go here:

L<http://groups.google.com/group/rose-html-objects>

Although the mailing list is the preferred support mechanism, you can also email the author (see below) or file bugs using the CPAN bug tracking system:

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Rose-HTML-Objects>

There's also a wiki and other resources linked from the Rose project home page:

L<http://rose.googlecode.com>

=head1 CONTRIBUTORS

Uwe Voelker, Jacques Supcik, Cees Hek, Denis Moskowitz

=head1 AUTHOR

John C. Siracusa (siracusa@gmail.com)

=head1 COPYRIGHT

Copyright (c) 2008 by John C. Siracusa.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
