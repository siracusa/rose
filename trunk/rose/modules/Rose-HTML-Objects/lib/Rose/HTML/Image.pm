package Rose::HTML::Image;

use strict;

use Image::Size;

use Rose::HTML::Object;
our @ISA = qw(Rose::HTML::Object);

our $DOC_ROOT;

our $VERSION = '0.011';

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => 'document_root',
);

__PACKAGE__->add_required_html_attrs(
{
  'alt',  => '',
  'src',  => '',
});


__PACKAGE__->add_valid_html_attrs
(
  'src',      # %URI;      #REQUIRED -- URI of image to embed --
  'alt',      # %Text;     #REQUIRED -- short description --
  'longdesc', # %URI;      #IMPLIED  -- link to long description --
  'name',     # CDATA      #IMPLIED  -- name of image for scripting --
  'height',   # %Length;   #IMPLIED  -- override height --
  'width',    # %Length;   #IMPLIED  -- override width --
  'usemap',   # %URI;      #IMPLIED  -- use client-side image map --
  'ismap',    # (ismap)    #IMPLIED  -- use server-side image map --
);

__PACKAGE__->add_boolean_html_attrs
(
  'ismap',
);

sub html_element  { 'img' }
sub xhtml_element { 'img' }

sub init_document_root { ($ENV{'MOD_PERL'}) ? Apache->request->document_root : $DOC_ROOT || '' }

sub src
{
  my($self) = shift;
  my $src = $self->html_attr('src', @_);
  $self->_new_src($src)  if(@_);
  return $src;
}

sub path
{
  my($self) = shift;
  return $self->{'path'}  unless(@_);
  $self->_new_path($self->{'path'} = shift);
  return $self->{'path'};
}

sub _new_src
{
  my($self, $src) = @_;

  if(-e $src)
  {
    $self->{'path'} = $src;
  }
  else
  {
    $self->{'path'} = $self->document_root . $src;
  }

  $self->init_size($self->{'path'});
}

sub _new_path
{
  my($self, $path) = @_;

  unless(defined $self->{'document_root'})
  {
    $self->init_size;
    return;
  }

  my $src = $path;

  $src =~ s/^$self->{'document_root'}//;

  $self->html_attr('src' => $src);

  $self->init_size;
}

sub init_size
{
  my($self, $path) = @_;

  $path ||= $self->{'path'} || return;

  my($w, $h) = Image::Size::imgsize($path);

  $self->html_attr(width  => $w);
  $self->html_attr(height => $h);
}

1;

__END__

=head1 NAME

Rose::HTML::Image - Object representation of the "img" HTML tag.

=head1 SYNOPSIS

    $img = Rose::HTML::Image->new(src => '/logo.png',
                                  alt => 'Logo');

    $i->document_root('/var/web/htdocs');

    # <img alt="Logo" height="48" src="/logo.png" width="72">
    print $i->html;

    $i->alt(undef);

    # <img alt="" height="48" src="/logo.png" width="72" />
    print $i->xhtml;

    ...

=head1 DESCRIPTION

L<Rose::HTML::Image> is an object representation of the E<lt>imgE<gt> HTML
tag. It includes the ability to automatically fill in the "width" and "height"
HTML attributes with the correct values, provided it is given enough
information to find the actual image file on disk.  The L<Image::Size> module
is used to read the file and determine the correct dimensions.

This class inherits from, and follows the conventions of,
L<Rose::HTML::Object>. Inherited methods that are not overridden will not be
documented a second time here.  See the L<Rose::HTML::Object> documentation
for more information.

=head1 HTML ATTRIBUTES

Valid attributes:

    alt
    class
    dir
    height
    id
    ismap
    lang
    longdesc
    name
    onclick
    ondblclick
    onkeydown
    onkeypress
    onkeyup
    onmousedown
    onmousemove
    onmouseout
    onmouseover
    onmouseup
    src
    style
    title
    usemap
    width
    xml:lang

Required attributes:

    alt
    src

Boolean attributes:

    ismap

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a new L<Rose::HTML::Image> object based on PARAMS, where PARAMS are
name/value pairs.  Any object method is a valid parameter name.

=back

=head1 OBJECT METHODS

=over 4

=item B<document_root [PATH]>

Get or set the web site document root.  This is combined with the value of the
"src" HTML attribute to build the path to the actual image file on disk. If
running in a mod_perl environment, the document root defaults to the value
returned by:

    Apache->request->document_root

This call is made once for each L<Rose::HTML::Image> object that needs to use
the document root.

=item B<init_size [PATH]>

Try to set the "width" and "height" HTML attributes but using L<Image::Size>
to read the image file on disk.  If a PATH argument is passed, the image file
is read at that location.  Otherwise, if the C<path()> attribute is set, that
path is used.  Failing that, the width and height HTML attributes are simply
not modified.

=item B<path [PATH]>

Get or set the path to the image file on disk.

If a PATH argument is passed and C<document_root()> is defined, then PATH has
C<document_root()> removed from the front of it (substitution anchored at the
start of PATH) and the resulting string is set as the value of the "src" HTML
attribute.  Regardless of the value of C<document_root()>, C<init_size()> is
called in an attempt to set the "height" and "width" HTML attributes.

The current value of the C<path> object attribute is returned.

=item B<src [SRC]>

Get or set the value of the "src" HTML attribute.

If a SRC argument is passed and a file is found at the path specified by SRC,
then C<path()> is set to SRC.  Otherwise, C<path()> is set to the
concatenation of C<document_root()> and SRC.  In either case, C<init_size()>
is called in an attempt to set the "height" and "width" HTML attributes.

The current value of the "src" HTML attribute is returned.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
