package Rose::DateTime::Parser;

use strict;

use Rose::DateTime::Util();

use Rose::Object;
our @ISA = qw(Rose::Object);

use Rose::Object::MakeMethods::Generic
(
  scalar => 'error',
  'scalar --get_set_init' => 'time_zone',
);

our $VERSION = '0.012';

sub init_time_zone { Rose::DateTime::Util->time_zone }

sub parse_date
{
  my($self) = shift;
  my $date = Rose::DateTime::Util::parse_date(shift, $self->time_zone);
  return $date  if($date);
  $self->error(Rose::DateTime::Util->error);
  return $date;
}

*parse_datetime = \&parse_date;

1;

__END__

=head1 NAME

Rose::DateTime::Parser - DateTime parser object.

=head1 SYNOPSIS

  use Rose::DateTime::Parser;

  $parser = Rose::DateTime::Parser->new(time_zone => 'UTC');

  $dt = $parser->parse_date('4/30/2001 8am')
    or warn $parser->error;


=head1 DESCRIPTION

C<Rose::DateTime::Parser> encapsulates a particular kind of call to L<Rose::DateTime::Util>'s L<parse_date|Rose::DateTime::Util/parse_date> function.  The object maintains the desired time zone, which is then passed to each call to C<parse_date()>.

This class inherits from, and follows the conventions of, L<Rose::Object>. See the L<Rose::Object> documentation for more information.

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a new C<Rose::DateTime::Parser> object based on PARAMS, where PARAMS are name/value pairs.  Any object method is a valid parameter name.

=back

=head1 OBJECT METHODS

=over 4

=item B<error [ERROR]>

Get or set the error message string.

=item B<parse_date STRING>

Attempt to parse STRING by passing it to L<Rose::DateTime::Util>'s L<parse_date|Rose::DateTime::Util/parse_date> function. If parsing is successful, the resulting C<DateTime> object is returned. Otherwise, C<error()> is set and false is returned.

=item B<parse_datetime STRING>

Alias for C<parse_date()>

=item B<time_zone [STRING]>

Get or set the time zone string passed to L<Rose::DateTime::Util>'s L<parse_date|Rose::DateTime::Util/parse_date> function. Defaults to C<Rose::DateTime::Util-E<gt>time_zone>.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
