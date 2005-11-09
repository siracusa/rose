package Rose::DB::Generic;

use strict;

use Rose::DB;
our @ISA = qw(Rose::DB);

our $VERSION = '0.1';

#
# Object methods
#

sub build_dsn
{
  my($self_or_class, %args) = @_;

  my %info;

  $info{'dbname'} = $args{'db'} || $args{'database'};
  $info{'host'}   = $args{'host'};
  $info{'port'}   = $args{'port'};

  return
    "dbi:$args{'dbi_driver'}:" . 
    join(';', map { "$_=$info{$_}" } grep { defined $info{$_} }
              qw(dbname host port));
}

sub last_insertid_from_sth { }

1;

__END__

=head1 NAME

Rose::DB::Generic - Generic driver class for Rose::DB.

=head1 SYNOPSIS

  use Rose::DB;

  Rose::DB->register_db(
    dsn      => 'dbi:SomeDB:...', # unknown driver
    username => 'devuser',
    password => 'mysecret',
  );

  Rose::DB->default_domain('development');
  Rose::DB->default_type('main');
  ...

  $db = Rose::DB->new; # $db is really a Rose::DB::Generic object
  ...

=head1 DESCRIPTION

This is the subclass that L<Rose::DB> blesses an object into (by default) when the C<driver> specified in the registry entry is has no class name registered in the L<driver class map|Rose::DB/driver_class>.

To maximize the chance that this class will work with an unsupported database, specify the DSN explicitly rather than providing the pieces separately (host, database, port, etc.) and then relying upon this class to assemble them into L<DBI> DSN.  This class will assemble a DSN, but it may not be in the format that your driver expects.

This class inherits from L<Rose::DB>.  See the L<Rose::DB> documentation for information on the inherited methods.

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
