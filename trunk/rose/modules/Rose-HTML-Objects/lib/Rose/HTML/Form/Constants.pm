package Rose::HTML::Form::Constants;

use strict;

our $VERSION = '0.35';

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(FIELD_SEPARATOR FORM_SEPARATOR);

our %EXPORT_TAGS = (all => \@EXPORT_OK);

use constant FIELD_SEPARATOR => '.';
use constant FORM_SEPARATOR  => '.';

1;
