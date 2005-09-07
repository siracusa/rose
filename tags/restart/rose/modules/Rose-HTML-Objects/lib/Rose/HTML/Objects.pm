package Rose::HTML::Objects;

use strict;

# The sole purpose of this module is to provide a version number
our $VERSION = '0.022';

1;

__END__

=head1 NAME

Rose::HTML::Objects - Object-oriented interfaces for HTML.

=head1 SYNOPSIS

    use Rose::HTML::Form;
    use Rose::HTML::Form::Field::Text;
    use Rose::HTML::Form::Field::DateTime;

    my $form = Rose::HTML::Form->new(action => '/foo',
                                     method => 'get');

    my %fields =
    (
      name   => Rose::HTML::Form::Field::Text->new,
      height => Rose::HTML::Form::Field::Text->new(size => 5),
      bday   => Rose::HTML::Form::Field::DateTime->new,
    );

    $form->add_fields(%fields);

    $form->params(name => 'John', height => '6ft', bday => '01/24/1984');

    $form->init_fields();
    ...
    my $bday = $form->field('bday')->internal_value;
    print $bday->strftime('%m/%d/%Y')  if($bday);
    ...
    print $form->field('bday')->html;
    ...

=head1 DESCRIPTION

The C<Rose::HTML::Object::*> family of classes represent HTML tags, or groups
of tags.  These objects  allow HTML to be arbitrarily manipulated, then
serialized to actual HTML (or XHTML). Currently, the process only works in one
direction.  Objects cannot be constructed from their serialized
representations.  In practice, given the purpose of these modules, this is not
an important limitation.

Any HTML tag can theoretically be represented by a
L<Rose::HTML::Object>-derived class, but this family of modules was originally
motivated by a desire to simplify the use of HTML forms.

The form/field object interfaces have been heavily abstracted to allow for
input and output filtering, inflation/deflation of values, and compound fields
(fields that contain other fields).  The classes are also designed to be
subclassed. The creation of custom form and field subclasses is really the
"big win" for these modules.

There is also a simple image tag class which is useful for auto-populating the
C<width> and C<height> attributes of C<img> tags. Future releases may include
object representations of other HTML tags. Contributions are welcome.

=head1 BUGS

Just in case this doesn't go without saying, I do not promise that the
C<Rose::HTML::Object::*> API will be stable until version 1.0.  I will make
every effort to avoid changing the API needlessly, however.

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
