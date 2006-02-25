package Rose::WebApp::WithSession;

use strict;

use Rose::WebApp;
our @ISA = qw(Rose::WebApp);

our $VERSION = '0.01';

# use Rose::Object::MakeMethods::Generic
# (
# 
# );

__PACKAGE__->register_subclass;

sub feature_name { 'session' }



1;
