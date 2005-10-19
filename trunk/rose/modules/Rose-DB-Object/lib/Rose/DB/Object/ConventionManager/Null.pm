package Rose::DB::Object::ConventionManager::Null;

use strict;

use Rose::DB::Object::ConventionManager;
our @ISA = qw(Rose::DB::Object::ConventionManager);

our $VERSION = '0.01';

our $Instance;

# This class is a singleton
sub new
{
  my($class) = shift;
  return $Instance ||= $class->SUPER::new(@_);
}

sub class_to_table_singular { }
sub class_to_table_plural { }
sub table_to_class_plural { }
sub table_to_class { }
sub class_prefix { }
sub related_table_to_class_plural { }
sub related_table_to_class { }
sub auto_table_name { }
sub auto_primary_key_column_names { }
sub init_singular_to_plural_function { }
sub init_plural_to_singular_function { }
sub singular_to_plural { }
sub plural_to_singular { }
sub auto_foreign_key_name { }
sub auto_foreign_key { }
sub auto_relationship { }

1;
