package Rose::WebSite::App::Comp;

use strict;

use Carp;

use Rose::WebSite::App::Page;
our @ISA = qw(Rose::WebSite::App::Page);

our $VERSION = '0.50';

our $Debug = undef;

sub comp_path { shift->page_path(@_) }
sub page_uri  { croak __PACKAGE__, ' does not support the page_uri() method' }

1;
