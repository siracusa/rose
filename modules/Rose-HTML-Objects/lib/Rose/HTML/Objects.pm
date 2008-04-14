package Rose::HTML::Objects;

use strict;

# The sole purpose of this module is to provide a version number
our $VERSION = '0.553_03';

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
