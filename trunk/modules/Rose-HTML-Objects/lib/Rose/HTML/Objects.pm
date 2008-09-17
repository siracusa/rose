package Rose::HTML::Objects;

use strict;

use Carp;

our $VERSION = '0.554_05';

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
  
  my $messages_package  = $rename->('Rose::HTML::Object::Messages');
  my $errors_package    = $rename->('Rose::HTML::Object::Errors');
  my $localizer_package = $rename->('Rose::HTML::Object::Message::Localizer');
  my $custom_package    = $rename->('Rose::HTML::Object::Custom');

  my $load_message_and_errors_perl = '';
  
  unless($in_memory)
  {
    $load_message_and_errors_perl=<<"EOF";
use $errors_package();
use $messages_package();
EOF
  }

  my %code =
  (
    $messages_package =>
    {
      filter => sub
      {
        s/^(use base.+)/use Rose::HTML::Object::Messages qw(:all);\n$1/m;
      },

      code =><<"EOF",
##
## Define your new message ids below
##

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

BEGIN { __PACKAGE__->add_messages }
EOF
    },

    $errors_package =>
    {
      filter => sub
      {
        s/^(use base.+)/use Rose::HTML::Object::Errors qw(:all);\n$1/m;
      },

      code =><<"EOF",
##
## Define your new error ids below
##

# Field errors

#use constant FIELD_ERROR_PASSWORD_TOO_SHORT => 101_000;
#use constant FIELD_ERROR_USERNAME_INVALID   => 101_001;
#...

# Generic errors

#use constant LOGIN_NO_SUCH_USER             => 200_000;
#use constant LOGIN_USER_EXISTS_ERROR        => 200_001;
#...

BEGIN { __PACKAGE__->add_errors }
EOF
    },

    $localizer_package =><<"EOF",
$load_message_and_errors_perl
sub init_messages_class { '$messages_package' }
sub init_errors_class   { '$errors_package' }
EOF

    $custom_package =><<"EOF",
use Rose::HTML::Object qw(:customize);
@{[ $in_memory ? '' : "\nuse $localizer_package;\n" ]}
__PACKAGE__->localizer($localizer_package->new);

$object_map_perl
EOF

#     $rename->('Rose::HTML::Object') =>=<<"EOF",
# use $errors_package;
# use $messages_package;
# EOF
  );

  #
  # Rose::HTML::Object::Errors
  # Rose::HTML::Object::Messages
  # Rose::HTML::Object::Message::Localizer
  #

  require Rose::HTML::Object::Errors;
  require Rose::HTML::Object::Messages;
  require Rose::HTML::Object::Message::Localizer;
  
  foreach my $base_class (qw(Rose::HTML::Object::Errors
                             Rose::HTML::Object::Messages
                             Rose::HTML::Object::Message::Localizer))
  {
    eval "require $base_class";
    croak "Could not load '$base_class' - $@"  if($@);

    my $package = $rename->($base_class);
  
    push(@packages, $package);
  
    $isa{$package} = $base_class;

    $perl{$package} = $class->subclass_perl(package      => $package, 
                                            isa          => $isa{$package},
                                            in_memory    => 0,
                                            default_code => \%code,
                                            code         => $args{'code'});
  }

  #
  # Rose::HTML::Object::Customized
  #

  $perl{$custom_package} =
    $class->subclass_perl(package      => $custom_package, 
                          in_memory    => $in_memory,
                          default_code => \%code,
                          code         => $args{'code'});
                                            
  push(@packages, $custom_package);

  #
  # All other classes
  #

  foreach my $base_class (sort values %$base_object_type)
  {
    next  if($class_filter && !$class_filter->($base_class));

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

    $perl{$package} = $class->subclass_perl(package   => $package, 
                                            isa       => $isa{$package},
                                            in_memory => $in_memory);
  }

  return wantarray ? (\@packages, \%perl) : \%perl;
}

sub isa_perl
{
  my($class, %args) = @_;
  
  my $isa  = $args{'isa'} or Carp::confess "Missing 'isa' parameter";
  $isa = [ $isa ]  unless(ref $isa eq 'ARRAY');

  if(0 && $args{'in_memory'}) # XXX: disabled for now
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

  my($filter, $code, @code);

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
    
    push(@code, $code)  if($code);
  }

  local $Perl;

  $Perl=<<"EOF";
package $package;

use strict;
@{[ $args{'isa'} ? "\n" . $class->isa_perl(%args) . "\n" : '' ]}@{[ join('', @code) ]}
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

The C<Rose::HTML::Object::*> family of classes represent HTML tags, or groups of tags.  These objects  allow HTML to be arbitrarily manipulated, then serialized to actual HTML (or XHTML). Currently, the process only works in one direction.  Objects cannot be constructed from their serialized representations.  In practice, given the purpose of these modules, this is not an important limitation.

Any HTML tag can theoretically be represented by a L<Rose::HTML::Object>-derived class, but this family of modules was originally motivated by a desire to simplify the use of HTML forms.

The form/field object interfaces have been heavily abstracted to allow for input and output filtering, inflation/deflation of values, and compound fields (fields that contain other fields).  The classes are also designed to be subclassed. The creation of custom form and field subclasses is really the "big win" for these modules.

There is also a simple image tag class which is useful for auto-populating the C<width> and C<height> attributes of C<img> tags. Future releases may include object representations of other HTML tags. Contributions are welcome.

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
