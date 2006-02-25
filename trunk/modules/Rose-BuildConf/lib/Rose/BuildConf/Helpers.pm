package Rose::BuildConf::Helpers;

use strict;

use File::Path;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK =
  qw(helper_make_path helper_host_ip 
     helper_check_executable helper_check_directory);

our %EXPORT_TAGS = 
(
  all       => \@EXPORT_OK,

  callbacks =>
  [
    qw(helper_check_executable helper_check_directory)
  ],

  functions => [ qw(helper_host_ip helper_make_path) ],
);

sub helper_make_path
{
  my($bc) = shift;

  my($path, $mode);

  if(@_ == 1)
  {
    $path = shift;
    $mode = 0775;
  }
  else
  {
    my %args = @_;
    $path = $args{'path'};
    $mode = $args{'mode'};
  }

  mkpath($path, undef, $mode);
  chmod($mode, $path);

  unless(-d $path && ((stat(_))[2] & 07777) == $mode)
  {
    die "ERROR: Could not make directory $path: $!\n";
  }
}

sub helper_host_ip
{
  my($hostname) = shift;

  return $hostname  if($hostname =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/);

  my(@octets,  $name, $aliases, $type, $length, $address);

  ($name, $aliases, $type, $length, $address) = gethostbyname($hostname);

  @octets = unpack('CCCC', $address);

  unless($hostname && @octets)
  {
    return 0;
  }
  else
  {
    return join('.', @octets);
  }
}

sub helper_check_executable
{
  my($bc, %args) = @_;

  my $file = $args{'value'};
  my $install_file = $file;

  $install_file =~ s/@{[$bc->install_root]}/@{[$bc->build_root]}/;

  unless(-e $file || -e $install_file)
  {
    print "\nERROR: No such file: $file\n\n";
    return 0; 
  }

  foreach my $f ($file, $install_file)
  {
    if(-e $file)
    {
      my $mode = (stat($file))[2] & 00111;

      if($mode == 0)
      {
        print "\nERROR: File is not executable: $file\n";
        return 0;
      }
    }
  }

  unless(-x $file || -x $install_file)
  {
    print "\nWARNING: File is not executable by the current user: $file\n";
  }

  return 1;
}

sub helper_check_directory
{
  my($bc, %args) = @_;

  my $dir = $args{'value'};
  $dir =~ s{/$}{};

  my $install_dir = $dir;

  $install_dir =~ s/@{[$bc->install_root]}/@{[$bc->build_root]}/;

  unless(-d $dir || -d $install_dir)
  {
    print "\nERROR: No such directory: $dir\n";
    return 0; 
  }

  return 1;
}

1;
