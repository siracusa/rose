package My::Vendor;
use strict;
use base 'My::Object';
__PACKAGE__->meta->columns(qw(id name));
__PACKAGE__->meta->initialize;
1;
