package Rose::WebApp::WithInlineContent;

use strict;

use Carp;

use File::Path;
use Path::Class();
use Path::Class::File();
use Path::Class::Dir();

use Rose::WebApp::Util::InlineContent qw(extract_inline_content create_inline_content);

use Rose::WebApp::Feature;
our @ISA = qw(Rose::WebApp::Feature);

our $VERSION = '0.01';

__PACKAGE__->register_subclass;

1;
