package Rose::HTML::Objects;

use strict;

use Carp;

our $VERSION = '0.554_02';

use Rose::Class::MakeMethods::Generic
(
  inherited_hash =>
  [
    'class' =>
    {
      plural_name => 'classes',
      keys_method => 'class_names',
    },
  ],
  
);

#Rose::HTML::Objects->class_info
#(
#   'Rose::HTML::Anchor' => { },
#   'Rose::HTML::Form::Field::Checkbox' => { },
#   'Rose::HTML::Form::Field::CheckboxGroup' => { },
#   'Rose::HTML::Form::Field::Compound' => { },
#   'Rose::HTML::Form::Field::Date' => { },
#   'Rose::HTML::Form::Field::DateTime::EndDate' => { },
#   'Rose::HTML::Form::Field::DateTime::Range' => { },
#   'Rose::HTML::Form::Field::DateTime::Split::MDYHMS' => { },
#   'Rose::HTML::Form::Field::DateTime::Split::MonthDayYear' => { },
#   'Rose::HTML::Form::Field::DateTime::Split' => { },
#   'Rose::HTML::Form::Field::DateTime::StartDate' => { },
#   'Rose::HTML::Form::Field::DateTime' => { },
#   'Rose::HTML::Form::Field::Email' => { },
#   'Rose::HTML::Form::Field::File' => { },
#   'Rose::HTML::Form::Field::Group::OnOff' => { },
#   'Rose::HTML::Form::Field::Group' => { },
#   'Rose::HTML::Form::Field::Hidden' => { },
#   'Rose::HTML::Form::Field::Input' => { },
#   'Rose::HTML::Form::Field::Integer' => { },
#   'Rose::HTML::Form::Field::Numeric' => { },
#   'Rose::HTML::Form::Field::Option' => { },
#   'Rose::HTML::Form::Field::OptionGroup' => { },
#   'Rose::HTML::Form::Field::Password' => { },
#   'Rose::HTML::Form::Field::PhoneNumber::US::Split' => { },
#   'Rose::HTML::Form::Field::PhoneNumber::US' => { },
#   'Rose::HTML::Form::Field::PopUpMenu' => { },
#   'Rose::HTML::Form::Field::RadioButton' => { },
#   'Rose::HTML::Form::Field::RadioButtonGroup' => { },
#   'Rose::HTML::Form::Field::Reset' => { },
#   'Rose::HTML::Form::Field::SelectBox' => { },
#   'Rose::HTML::Form::Field::Set' => { },
#   'Rose::HTML::Form::Field::Submit' => { },
#   'Rose::HTML::Form::Field::Text' => { },
#   'Rose::HTML::Form::Field::TextArea' => { },
#   'Rose::HTML::Form::Field::Time::Hours' => { },
#   'Rose::HTML::Form::Field::Time::Minutes' => { },
#   'Rose::HTML::Form::Field::Time::Seconds' => { },
#   'Rose::HTML::Form::Field::Time::Split::HourMinuteSecond' => { },
#   'Rose::HTML::Form::Field::Time::Split' => { },
#   'Rose::HTML::Form::Field::Time' => { },
#   'Rose::HTML::Form::Field' => { },
#   'Rose::HTML::Form::Repeatable' => { },
#   'Rose::HTML::Form' => { },
#   'Rose::HTML::Image' => { },
#   'Rose::HTML::Label' => { },
#   'Rose::HTML::Link' => { },
#   'Rose::HTML::Object::Errors' => { },
#   'Rose::HTML::Object::Message::Localizer' => { },
#   'Rose::HTML::Object::Messages' => { },
#  'Rose::HTML::Object' => { },
#   'Rose::HTML::Objects' => { },
#   'Rose::HTML::Script' => { },
#   'Rose::HTML::Text' => { },
#);

sub private_library_perl
{
  my($class, %args) = @_;

  my $prefix = $args{'prefix'} or croak "Missing 'prefix' parameter";
  my $trim_prefix = $args{'trim_prefix'} || 'Rose::';

  my $prefix_regex = qr(^$trim_prefix);

  my $rename = sub 
  {
    my($name) = shift;
    $name =~ s/$prefix_regex/$prefix/;
    return $name;
  };

  my $class_filter = $args{'class_filter'};

  #
  # Rose::HTML::Object::Localized subclass
  #

  require Rose::HTML::Object::Localized;

  my $package = $rename->('Rose::HTML::Object::Localized');

  my(%perl, %isa);

  $isa{$package} = 'Rose::HTML::Object::Localized';

  $perl{$package} = $class->subclass_perl(package => $package, isa => $isa{$package});

  #
  # Rose::HTML::Object subclass
  #

  require Rose::HTML::Object;

  my %object_type;

  my $base_object_type = Rose::HTML::Object->object_type_classes;

  my $max_type_len = 0;

  while(my($type, $base_class) = each(%$base_object_type))
  {
    $object_type{$type} = $rename->($base_class);
    $max_type_len = length($type)  if(length($type) > $max_type_len);
  }

  $package = $rename->('Rose::HTML::Object');

  $perl{$package} =<<"EOF";
package $package;

use strict;

use base 'Rose::HTML::Object';

__PACKAGE__->object_type_classes
(
EOF

  while(my($type, $class) = each(%object_type))
  {
    $perl{$package} .= sprintf("  %-*s => '$class',\n", $max_type_len + 2, qq('$type'));
  }
  
  $perl{$package} .=<<"EOF";
);

1;
EOF

  while(my($pkg, $perl) = each(%perl))
  {
    print $perl, "\n\n";
  }

  # Now make all the other classes
}

sub subclass_perl
{
  my($class, %args) = @_;

  my $package = $args{'package'} or Carp::confess "Missing 'package' parameter";
  my $isa     = $args{'isa'} or Carp::confess "Missing 'package' parameter";
  $isa = [ $isa ]  unless(ref $isa eq 'ARRAY');

  return<<"EOF";
package $package;

use strict;

use base qw(@{[ join(' ', @$isa) ]});

1;
EOF
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
