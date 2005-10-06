package Rose::URI;

use strict;

use Carp;

use URI;
use URI::Escape();

use Rose::Object;
our @ISA = qw(Rose::Object);

use overload
(
  '""'   => sub { shift->as_string },
  'bool' => sub { length shift->as_string },
   fallback => 1,
);

our $Make_URI;

our $SCHEME_RE = '[a-zA-Z][a-zA-Z0-9.+\-]*';

our $VERSION = '0.013';

#our $Debug = 0;

use Rose::Object::MakeMethods::Generic
(
  scalar =>
  [
    'username',
    'password',
    'scheme',
    'host',
    'port',
    'default_port',
    'path',
    'fragment',
    'query_param_separator',    
  ]
);

sub new
{
  my($class) = shift;

  my $self =
  {
    username     => '',
    password     => '',
    scheme       => '',
    host         => '',
    port         => '',
    default_port => undef,
    path         => '',
    query        => {},
    fragment     => '',

    query_param_separator => '&',
  };

  bless $self, $class;

  $self->init(@_);

  return $self;
}

sub init
{
  my($self) = shift;

  if(@_ == 1)
  {
    $self->init_with_uri(@_);
  }
  else
  {
    $self->SUPER::init(@_);
  }
}

sub init_with_uri
{
  my($self) = shift;

  $self->$Make_URI($_[0]);
}

sub clone
{
  my($self) = shift;

  return ref($self)->new("$self");
}

sub parse_query
{
  my($self, $query) = @_;

  unless(defined $query && $query =~ /\S/)
  {
    $self->{'query'} = { };
    return 1;
  }

  my @params;

  if(index($query, '&') >= 0)
  {
    @params = split(/&/, $query);
  }
  elsif(index($query, ';') >= 0)
  {
    @params = split(/;/, $query);
  }
  elsif(index($query, '=') < 0)
  {
    # XXX: Should be "keywords"?
    $self->{'query'} = { $query => undef };
    return 1;
  }

  @params = ($query)  unless(@params);

  my %query;

  foreach my $item (@params)
  {
    my($param, $value) = map { __unescape_uri($_) } split(/=/, $item);

    $param = __unescape_uri($item)  unless(defined($param));

    if(exists $query{$param})
    {
      if(ref $query{$param})
      {
        push(@{$query{$param}}, $value);
      }
      else
      {
        $query{$param} = [ $query{$param}, $value ];
      }
    }
    else
    {
      $query{$param} = $value;
    }
  }

  $self->{'query'} = \%query;

  return 1;
}

sub query_hash
{
  my($self) = shift;

  return (wantarray) ? %{$self->{'query'}} : { %{$self->{'query'}} };
}

sub query_param
{
  my($self) = shift;

  if(@_ == 1)
  {
    return $self->{'query'}{$_[0]}  if(exists $self->{'query'}{$_[0]});
    return;
  }
  elsif(@_ == 2)
  {
    if(ref $_[1])
    {
      return $self->{'query'}{$_[0]} = [ @{$_[1]} ];
    }

    return $self->{'query'}{$_[0]} = $_[1];
  }

  croak "query_param() takes either one or two arguments";
}

sub query_params
{
  my($self) = shift;

  return sort keys %{$self->{'query'}}  unless(@_);

  my $params = $self->query_param(@_);

  $params = (ref $params) ? [ @$params ] : 
            (defined $params) ? [ $params ] : [];

  return (wantarray) ? @$params : $params;
}

sub query_param_add
{
  my($self, $name, $value) = @_;

  croak "query_add_param() takes two arguments"  unless(@_ == 3);

  my $params = $self->query_params($name);

  push(@$params, (ref $value) ? @$value : $value);

  $self->query_param($name => (@$params > 1) ? $params : $params->[0]);

  return (wantarray) ? @$params : $params;
}

sub query_param_exists
{
  my($self, $param) = @_;

  croak "Missing query param argument"  unless(defined $param);

  return exists $self->{'query'}{$param};
}

sub query_param_delete
{
  my($self) = shift;

  croak "query_param_delete() takes one or more arguments"  unless(@_);

  foreach my $param (@_)
  {
    delete $self->{'query'}{$param};
  }
}

sub as_string
{
  my($self) = shift;

  my $scheme = $self->scheme;
  my $user   = $self->userinfo_escaped;
  my $port   = $self->port;
  my $query  = $self->query;
  my $frag   = __escape_uri($self->fragment);

  return ((length $scheme) ? "$scheme://" : '') .
         ((length $user) ? "$user\@" : '') .
         $self->host .
         ((length $port) ? ":$port" : '') .
         __escape_uri_whole($self->path) . 
         ((length $query) ? "?$query" : '') .
         ((length $frag) ? "#$frag" : '');
}

sub query
{
  my($self) = shift;

  if(@_ == 1)
  {
    if(ref $_[0])
    {
      $self->{'query'} = { %{$_[0]} };
    }
    else
    {
      $self->parse_query($_[0]);
    }
  }
  elsif(@_)
  {
    $self->{'query'} = { @_ };
  }

  return  unless(defined(wantarray));

  my @query;

  foreach my $param (sort keys %{$self->{'query'}})
  {
    foreach my $value ($self->query_params($param))
    {
      push(@query, __escape_uri($param) . '=' . __escape_uri($value));
    }
  }

  return join($self->{'query_param_separator'}, @query);
}

sub query_form
{
  my($self) = shift;

  if(@_)
  {
    $self->{'query'} = { };

    for(my $i = 0; $i < $#_; $i += 2)
    {
      $self->query_param_add($_[$i] => $_[$i + 1]);
    }
  }

  return  unless(defined(wantarray));

  my @query;

  foreach my $param ($self->query_params)
  {
    foreach my $value ($self->query_params($param))
    {
      push(@query, $param, $value);
    }
  }

  return @query;
}

sub abs
{
  my($self, $base) = @_;

  return $self  unless($base && !length $self->scheme);

  my $new = $self->as_string;

  $new  =~ s{^/}{};
  $base =~ s{/$}{};

  return Rose::URI->new("/$new")  unless($base =~ m{^$SCHEME_RE://}o);
  return Rose::URI->new("$base/$new");
}

sub rel
{
  my($self, $base) = @_;

  return $self  unless($base);

  my $uri = $self->as_string;

  if($uri =~ m{^$base/?})
  {
    $uri =~ s{^$base/?}{};

    return Rose::URI->new($uri);
  }

  return $self;
}

sub userinfo
{
  my($self) = shift;

  my $user = $self->username;
  my $pass = $self->password;

  if(length $user && length $pass)
  {
    return join(':', $user, $pass);
  }

  return $user  if(length $user);
  return '';
}

sub userinfo_escaped
{
  my($self) = shift;

  my $user = __escape_uri($self->username);
  my $pass = __escape_uri($self->password);

  if(length $user && length $pass)
  {
    return join(':', $user, $pass);
  }

  return $user  if(length $user);
  return '';
}

sub __uri_from_apache_uri
{
  my($self) = shift;

  my $uri = Apache::URI->parse(Apache->request, @_);

  $self->{'username'} = $uri->user     || '';
  $self->{'password'} = $uri->password || '';
  $self->{'scheme'}   = $uri->scheme   || '';
  $self->{'host'}     = $uri->hostname || '';
  $self->{'port'}     = $uri->port     || '';
  $self->{'path'}     = $uri->path     || '';
  $self->{'fragment'} = $uri->fragment || '';

  $self->parse_query($uri->query);

  return $uri;
}

sub __uri_from_uri
{
  my($self) = shift;

  my $uri = URI->new(@_);

  if($uri->can('user'))
  {
    $self->{'username'} = $uri->user;
  }
  elsif($uri->can('userinfo'))
  {
    if(my $userinfo = $uri->userinfo)
    {
      if(my($user, $pass) = split(':', $userinfo))
      {
        $self->{'username'} = __unescape_uri($user);
        $self->{'password'} = __unescape_uri($pass);
      }
    }
  }

  $self->{'scheme'}       = __unescape_uri($uri->scheme   || '');
  $self->{'host'}         = __unescape_uri($uri->host     || '')  if($uri->can('host'));
  $self->{'port'}         = __unescape_uri($uri->_port    || '')  if($uri->can('_port'));
  $self->{'default_port'} = __unescape_uri($uri->port     || '')  if($uri->can('port'));
  $self->{'path'}         = __unescape_uri($uri->path     || '')  if($uri->can('path'));
  $self->{'fragment'}     = __unescape_uri($uri->fragment || '');

  $self->parse_query($uri->query);

  return $uri;
}

if(exists $ENV{'MOD_PERL'} && require mod_perl && $mod_perl::VERSION < 1.99)
{
  require Apache;
  require Apache::URI;
  require Apache::Util;

  *__escape_uri   = \&Apache::Util::escape_uri;
  *__unescape_uri = \&Apache::Util::unescape_uri_info;

  $Make_URI = \&__uri_from_apache_uri;
}
else
{
  *__escape_uri   = \&URI::Escape::uri_escape;
  *__unescape_uri = sub 
  {
    my $e = URI::Escape::uri_unescape(@_);

    $e =~ s/\+/ /g;

    return $e;
  };

  $Make_URI = \&__uri_from_uri;
}

sub __escape_uri_whole
{
  URI::Escape::uri_escape($_[0], 
    (@_ > 1) ? (defined $_[1] ? $_[1] : ()) : q(^A-Za-z0-9\-_.,'!~*#?&()/?@\:\[\]=));
}

1;

__END__

=head1 NAME

Rose::URI - A standalone URI object built for easy and efficient manipulation of query
parameters and other URI components.

=head1 SYNOPSIS

    use Rose::URI;

    $uri = Rose::URI->new('http://un:pw@foo.com/bar/baz?a=1&b=two+3');

    $scheme = $uri->scheme;
    $user   = $uri->username;
    $pass   = $uri->password;
    $host   = $uri->host;
    $path   = $uri->path;
    ...

    $b = $uri->query_param('b');  # $b = "two 3"
    $a = $uri->query_param('a');  # $a = 1

    $uri->query_param_delete('b');
    $uri->query_param('c' => 'blah blah');
    ...

    print $uri;

=head1 DESCRIPTION

C<Rose::URI> is a limited alternative to C<URI>.  The important differences
are as follows.

C<Rose::URI> provides a rich set of query string manipulation methods. Query
parameters can be added, removed, and checked for their existence. C<URI>
allows the entire query to be set or returned as a whole via C<query_form()>
or C<query()>, and the C<URI::QueryParam> module provides a few more methods
for query string manipulation.

C<Rose::URI> supports query parameters with multiple values (e.g. "a=1&a=2"). 
C<URI> has  limited support for this (hrough C<query_form()>'s list return
value.  Better methods are available in C<URI::QueryParam>.

C<Rose::URI> uses Apache's C-based URI parsing and HTML escaping functions
when running in a mod_perl 1.x web server environment.

C<Rose::URI> stores each URI "in pieces" (scheme, host, path, etc.) and then
assembles those pieces when the entire URI is needed as a string. This
technique is based on the assumption that the URI will be manipulated many
more times than it is stringified.  If this is not the case in your usage
scenario, then C<URI> may be a better alternative.

Now some similarities: both classes use the C<overload> module to allow
"magic" stringification.  Both C<URI> and C<Rose::URI> objects can be printed
and compared as if they were strings.

C<Rose::URI> actually uses the C<URI> class to do the heavy lifting of parsing
URIs when not running in a mod_perl 1.x environment.

Finally, a caveat: C<Rose::URI>  supports only "http"-like URIs.  This
includes ftp, http, https, and other similar looking URIs. C<URI> supports
many more esoteric URI types (gopher, mailto, etc.) If you need to support
these formats, use C<URI> instead.

=head1 CONSTRUCTOR

=over 4

=item B<new [ URI | PARAMS ]>

Constructs a URI object based on URI or PARAMS, where URI is a string
and PARAMS are described below. Returns a new C<Rose::URI> object.

The query string portion of the URI argument may use either "&" or ";"
as the parameter separator. Examples:

    $uri = Rose::URI->new('/foo?a=1&b=2');
    $uri = Rose::URI->new('/foo?a=1;b=2'); # same thing

The C<query_param_separator> parameter determines what is used when the
query string (or the whole URI) is output as a string later.

C<Rose::URI> uses C<URI> or C<Apache::URI> (when running under mod_perl
1.x) to do its URI string parsing.

Valid PARAMS are:

    fragment
    host
    password
    path
    port
    query
    scheme
    username

    query_param_separator

Which correspond to the following URI pieces:

    <scheme>://<username:password>@<path>?<query>#<fragment>

All the above parameters accept strings.  See below for more information
about the C<query> parameter.  The C<query_param_separator> parameter
determines the separator used when constructing the query string.  It is
"&" by default (e.g. "a=1&b=2")

=back

=head1 METHODS

=over 4

=item B<abs [BASE]>

This method exists solely for compatibility with C<URI>.

Returns an absolute C<Rose::URI> object.  If the current URI is already
absolute, then a reference to it is simply returned.  If the current URI is
relative, then a new absolute URI is constructed by combining the URI and the
BASE, and returned.

=item B<as_string>

Returns the URI as a string.  The string is "URI escaped" (reserved URI
characters are replaced with %xx sequences), but not "HTML escaped"
(ampersands are not escaped, for example).

=item B<clone>

Returns a copy of the C<Rose::URI> object.

=item B<query QUERY>

Sets the URI's query based on QUERY.  QUERY may be a query string (e.g.
"a=1&b=2"), a reference to a hash, or a list of name/value pairs.

Query strings may use either "&" or ";" as their query separator. If a "&"
character exists anywhere in teh query string, it is assumed to be the
separator.

If none of the characters "&", ";", or "=" appears in the query string, then
the entire query string is taken as a single parameter name with an undefined
value.

Hashes and lists should specify multiple parameter values using array
references. 

Here are some examples representing the query string "a=1&a=2&b=3"

    $uri->query("a=1&a=2&b=3");             # string
    $uri->query("a=1;a=2;b=3");             # same thing
    $uri->query({ a => [ 1, 2 ], b => 3 }); # hash ref
    $uri->query(a => [ 1, 2 ], b => 3);     # list

Returns the current (or new) query as a URI-escaped (but not HTML-escaped)
query string.

=item B<query_form QUERY>

Implementation of C<URI>'s method of the same name.  This exists for backwards
compatibility purposes only and should not be used (or necessary).  See the
C<URI> documentation for more details.

=item B<query_hash>

Returns the current query as a hash (in list context) or reference to a hash
(in scalar context), with multiple parameter values represented by array
references (see C<query()> for details).

The return value is a shallow copy of the actual query hash.  It should be
treated as read-only unless you really know what you are doing.

Example:

    $uri = Rose::URI->new('/foo?a=1&b=2&a=2');

    $h = $uri->query_hash; # $h = { a => [ 1, 2 ], b => 2 }

=item B<query_param NAME [, VALUE]>

Get or set a query parameter.  If only NAME is passed, it returns the value of
the query parameter named NAME.  Parameters with multiple values are returned
as array references.  If both NAME and VALUE are passed, it sets the parameter
named NAME to VALUE, where VALUE can be a simple scalar value or a reference
to an array of simple scalar values.

Examples:

    $uri = Rose::URI->new('/foo?a=1');

    $a = $uri->query_param('a'); # $a = 1

    $uri->query_param('a' => 3); # query string is now "a=3"

    $uri->query_param('b' => [ 4, 5 ]); # now "a=3&b=4&b=5"

    $b = $uri->query_param('b'); # $b = [ 4, 5 ];

=item B<query_params NAME [, VALUE]>

Same as C<query_param()>, except the return value is always either an array
(in list context) or reference to an array (in scalar context), even if there
is only one value.

Examples:

    $uri = Rose::URI->new('/foo?a=1&b=1&b=2');

    $a = $uri->query_params('a'); # $a = [ 1 ]
    @a = $uri->query_params('a'); # @a = ( 1 )

    $b = $uri->query_params('a'); # $b = [ 1, 2 ]
    @b = $uri->query_params('a'); # @b = ( 1, 2 )

=item B<query_param_add NAME, VALUE>

Adds a new value to a query parameter.   Example:

    $uri = Rose::URI->new('/foo?a=1&b=1');

    $a = $uri->query_param_add('b' => 2); # now "a=2&b=1&b=2"

Returns an array (in list context) or reference to an array (in scalar
context) of the new parameter value(s).

=item B<query_param_delete NAME>

Deletes all instances of the parameter named NAME from the query.

=item B<query_param_exists NAME>

Returns a boolean value indicating whether or not a parameter named NAME
exists in the query string.

=item B<rel BASE>

This method exists solely for compatibility with C<URI>.

Returns a relative URI reference if it is possible to make one that denotes
the same resource relative to BASE.  If not, then the current URI is simply
returned.

=item B<userinfo>

Returns the C<username> and C<password> attributes joined by a ":" (colon). 
The username and password are not escaped in any way. If there is no password,
only the username is returned (without the colon).  If neither exist, an empty
string is returned.

=item B<userinfo_escaped>

Returns the C<username> and C<password> attributes joined by a ":" (colon). 
The username and password are URI-escaped, but not HTML-escaped. If there is
no password, only the username is returned (without the colon).  If neither
exist, an empty string is returned.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2004 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
