package Rose::DB::Object::Loader;

use strict;

use Carp;

use Rose::DB;
use Rose::DB::Object;
use Rose::DB::Object::ConventionManager;

use Rose::Object;
our @ISA = qw(Rose::Object);

our $VERSION = '0.50';

use Rose::Object::MakeMethods::Generic
(
  scalar =>
  [
    'db_catalog',
    'db_schema',
  ],

  boolean => 
  [
    'using_default_base_class',
  ],
);

my $Base_Class_Counter = 1;

sub generate_base_class 
{
  my($self) = shift;

  return (($self->class_prefix . 'Base') || "Rose::DB::Object::Auto::Base") . 
          $Base_Class_Counter++;
}

sub base_classes
{
  my($self) = shift;

  unless(@_)
  {
    if(my $bc = $self->{'base_classes'})
    {
      return wantarray ? @$bc : $bc;
    }
    
    # Make new base class
    my $bc = $self->{'base_classes'} = [ $self->generate_base_class ];
    
    $self->using_default_base_class(1);

    no strict 'refs';
    @{"$bc->[0]::ISA"} = qw(Rose::DB::Object);

    return wantarray ? @$bc : $bc;
  }
  
  my $bc = shift;

  unless(ref $bc)
  {
    $bc = [ $bc ];
  }
  
  my $found_rdbo = 0;

  foreach my $class (@$bc)
  {
    unless($class =~ /^(?:\w+::)*\w+$/)
    {
      croak "Illegal class name: $class";
    }
    
    $found_rdbo = 1  if(UNIVERSAL::isa($class, 'Rose::DB::Object'));
  }
  
  unless($found_rdbo)
  {
    croak "None of the base classes inherit from Rose::DB::Object";
  }

  $self->using_default_base_class(0);
  $self->{'base_classes'} = $bc;

  return wantarray ? @$bc : $bc;
}

sub convention_manager
{
  my($self) = shift;
  
  if(@_)
  {
    my $cm = shift;
    
    unless(UNIVERSAL::isa($cm, 'Rose::DB::Object::ConventionManager'))
    {
      croak "Not a Rose::DB::Object::ConventionManager-derived object: $cm";
    }
  }

  return $self->{'convention_manager'} ||= Rose::DB::Object::ConventionManager->new;
}

sub class_prefix
{
  my($self) = shift;

  return $self->{'class_prefix'}  unless(@_);
  
  my $class_prefix = shift;

  unless($class_prefix =~ /^(?:\w+::)*\w+$/)
  {
    croak "Illegal class prefix: $class_prefix";
  }
  
  $class_prefix .= '::'  unless($class_prefix =~ /::$/);

  return $self->{'class_prefix'} = $class_prefix;
}

sub db
{
  my($self) = shift;

  return $self->{'db'}  unless(@_);

  my $db = shift;

  unless(UNIVERSAL::isa($db, 'Rose::DB'))
  {
    croak "Not a Rose::DB-derived object: $db";
  }

  my $db_class = $db->class;
  $self->{'db_class'} = $db_class;

  return $self->{'db'} = $db;
}

sub dn_dsn
{
  my($self) = shift;
  
  return $self->{'dn_dsn'}  unless(@_);

  my $dn_dsn = shift;
  
  if(my $db = $self->db)
  {
    $db->dn_dsn($dn_dsn);
  }
  
  return $self->{'dn_dsn'} = $dn_dsn;
}

sub db_class
{
  my($self) = shift;

  return $self->{'db_class'}  unless(@_);

  my $db_class = shift;

  unless($db_class =~ /^(?:\w+::)*\w+$/)
  {
    croak "Illegal class name: $db_class";
  }

  eval "require $db_class";

  no strict 'refs';
  if(!$@ && @{"${db_class}::ISA"} && !UNIVERSAL::isa($db_class, 'Rose::DB'))
  {
    croak "Not a Rose::DB-derived class: $db_class";
  }

  $self->db(undef);
  return $self->{'db_class'} = $db_class;
}

sub make_classes
{
  my($self, %args) = @_;
  
  my $include = delete $args{'include_tables'};
  my $exclude = delete $args{'exclude_tables'};
  my $filter  = delete $args{'filter_tables'};
  
  if($include || $exclude)
  {
    if($filter)
    {
      croak "The filter_tables parameter cannot be used with ",
            "the include_tables or exclude_tables parameters";
    }

    $include = qr($include)  if(defined $include);
    $exclude = qr($exclude)  if(defined $exclude);
    
    $filter = sub 
    {
      return 0  if((defined $include && !/$include/) ||
                   (defined $exclude && /$exclude/));
      return 1;
    };
  }
  
  #
  # Get or create the db object
  #

  my $db = $self->db;
  
  my $db_class = $db->class;

  unless($db)
  {
    $db_class = $self->db_class;

    if($db_class)
    {
      eval "require $db_class";
      
      if($@)
      {
        # Failed to load existing module
        unless($@ =~ /^Can't locate $db_class\.pm/)
        {
          croak "Could not load db class '$db_class' - $@";
        }

        # Make the class
        no strict 'refs';
        @{"${db_class}::ISA"} = qw(Rose::DB);
        $db_class->use_private_registry;
      }
    }
    else
    {
      $db_class = 'Rose::DB';
    }
    
    $db = $db_class->new;
  }
  
  # Create the init_db subroutine that will be used with the objects
  my %db_args =
  (
    type   => $db->type,
    domain => $db->domain,
  );

  delete $db_args{'type'}    if($db_args{'type'} eq $db->default_type);
  delete $db_args{'domain'}  if($db_args{'domain'} eq $db->default_domain);

  $db_args{'catalog'} = $self->db_catalog  if($self->db_catalog);
  $db_args{'schema'}  = $self->db_schema   if($self->db_schema);

  my $init_db = sub { $db_class->new(%db_args) };

  # Refresh the db
  $db = $init_db->();

  # Set up the object base class
  my @base_classes = $self->base_classes;
  
  foreach my $class (@base_classes)
  {
    unless(UNIVERSAL::isa($class, 'Rose::DB::Object'))
    {
      eval "require $class";
      croak $@  if($@);
    }
  }
  
  my $installed_init_db_in_base_class = 0;

  # Install the init_db routine in the base class, but only if 
  # using the default base calss.
  if($self->using_default_base_class)
  {
    no strict 'refs';
    *{"$base_classes[0]::init_db"} = $init_db;
    $installed_init_db_in_base_class = 1;
  }

  my $with_managers = exists $args{'with_managers'} ? delete $args{'with_managers'} : 1;

  my $class_prefix = $self->class_prefix || '';

  my $cm = $self->convention_manager or die "Missing convention manager";

  my @classes;
$DB::single = 1;
  # Iterate over tables, creating RDBO classes for each
  foreach my $table ($db->list_tables)
  {
    local $_ = $table;
    next  unless(!$filter || $filter->($table));

    my $obj_class = $class_prefix . $cm->table_to_class($table);

    # Set up the class
    no strict 'refs';
    @{"${obj_class}::ISA"} = @base_classes;
    
    unless($installed_init_db_in_base_class)
    {
      *{"${obj_class}::init_db"} = $init_db;
    }
    
    my $meta = $obj_class->meta;
    
    $meta->table($table);
    $meta->auto_initialize(%args);
    
    push(@classes, $obj_class);

    # Make the manager class
    if($with_managers)
    {
      $meta->make_manager_class($table);
      push(@classes, "${obj_class}::Manager");
    }
  }
  
  return wantarray ? @classes : \@classes;
}

1;

__END__

=head1 NAME

Rose::DB::Object::Iterator - Iterate over a series of Rose::DB::Objects.

=head1 SYNOPSIS

    $iterator = Rose::DB::Object::Manager->get_objects_iterator(...);

    while($object = $iterator->next)
    {
      # do stuff with $object...

      if(...) # bail out early
      {
        $iterator->finish;
        last;
      }
    }

    if($iterator->error)
    {
      print "There was an error: ", $iterator->error;
    }
    else
    {
      print "Total: ", $iterator->total;
    }

=head1 DESCRIPTION

C<Rose::DB::Object::Iterator> is an iterator object that traverses a database query, returning L<Rose::DB::Object>-derived objects for each row.  C<Rose::DB::Object::Iterator> objects are created by calls to the C<get_objects_iterator|Rose::DB::Object::Manager/get_objects_iterator> method of L<Rose::DB::Object::Manager> or one of its subclasses.

=head1 OBJECT METHODS

=over 4

=item B<error>

Returns the text message associated with the last error, or false if there was no error.

=item B<finish>

Prematurely stop the iteration (i.e., before iterating over all of the available objects).

=item B<next>

Return the next L<Rose::DB::Object>-derived object.  Returns false (but defined) if there are no more objects to iterate over, or undef if there was an error.

=item B<total>

Returns the total number of objects iterated over so far.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
