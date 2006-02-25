package Rose::Apache::Version;

use strict;

use Carp();

# Scary version...
# sub mod_perl_major_version
# {
#   use DynaLoader ();
#   return 1  if(DynaLoader::dl_find_symbol_anywhere("XS_Apache_define"));
#   return 2  if(DynaLoader::dl_find_symbol_anywhere("XS_ModPerl__Util_exit"));
#   return undef;
# }

sub mod_perl_major_version
{
  no warnings;
  if($ENV{'MOD_PERL_API_VERSION'} == 2)
  {
    return 2;
  }

  if($ENV{'MOD_PERL'})
  {
    return 1;
  }

  return 0;
}

sub choose_super
{
  my(%args) = @_;
  my $pkg = (caller)[0];

  my $vers = 'mp' . mod_perl_major_version();

  unless($args{$vers})
  {
    Carp::croak "No superclass listed for current mod_perl major version ",
                mod_perl_major_version();
  }

  no strict 'refs';
  eval "use $args{$vers}";
  Carp::croak "Error when trying to use() $args{$vers} - $@"  if($@);
  #print STDERR qq(push(${pkg}::ISA, $args{$vers});\n);
  push(@{"${pkg}::ISA"}, $args{$vers});
}

1;
