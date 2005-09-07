package Rose::WebApp::SelfConfig;

use strict;

use Carp;

use File::Path;
use Path::Class();
use Path::Class::File();
use Path::Class::Dir();

use Rose::WebApp;
our @ISA = qw(Rose::WebApp);

our $VERSION = '0.01';

__PACKAGE__->register_subclass;

sub feature_name { 'selfconfig' }

our %FILE_TYPES =
(
  masoncomps => 1,
  htdocs     => 1,
);

sub extract_files
{
  my($class, %args) = @_;

  my $type      = $args{'type'} or croak "Missing type parameter";
  my $dest      = $args{'dest'} or croak "Missing dest parameter";
  my $verbose   = $args{'verbose'} || 0;
  my $noclobber = $args{'noclobber'} || 0;

  croak "Invalid file type '$type'"  unless($FILE_TYPES{$type});

  no strict 'refs';
  my $fh = \*{"${class}::DATA"};

  croak "$class has no files to extract"  unless(fileno($fh));

  local $/ = "\n";

  my(%file, $line);

  while(<$fh>)
  {
    if(/^__END__/)
    {
      last;
    }
    elsif(/^---$/)
    {
      next  unless(%file);
      croak "Syntax error on line $. - $_"  unless(exists $file{'contents'});
      %file = ();
      $line = 0;
    }
    elsif(/^(File|Type|Lines|Mode): *(\S.*)$/i)
    {
      $file{lc $1} = $2;
    }
    elsif(/^$/)
    {
      next  unless(%file);

      foreach my $line (1 .. $file{'lines'})
      {
        $file{'contents'} .= <$fh>;
      }

      my $install_path = Path::Class::File->new($dest, $file{'file'});
      $install_path->cleanup;

      if(-e $install_path && $noclobber)
      {
        warn "Skip existing file: $install_path\n"  if($verbose);
        next;
      }

      unless(-d $install_path->dir)
      {
        warn "Make directory: ", $install_path->dir, "\n"  if($verbose > 1);
        mkpath($install_path->dir->stringify);
      }

      warn "Install: $install_path\n"  if($verbose);

      open(my $fh, '>', $install_path->stringify) 
        or croak "Could not install file '$install_path' - $!";

      print $fh $file{'contents'};

      close($fh) or croak "Could not write file '$install_path' - $!";

      if(defined $file{'mode'})
      {
        chmod($file{'mode'}, $install_path)
          or warn "Could not set file mode to $file{'mode'} for file $install_path - $!\n";
      }
    }
  }
}

sub archive_files
{
  my($class, %args) = @_;

  my $path = $args{'dir'} || $args{'file'} || 
    croak "Missing file or dir parameter";

  my $prefix = $args{'prefix'};

  my $path_re = defined $args{'path_match'} ? qr($args{'path_match'}) : undef;
  my $file_re = defined $args{'file_match'} ? qr($args{'file_match'}) : undef;

  my $type = $args{'type'} or croak "Missing type parameter";

  croak "Invalid file type '$type'"  unless($FILE_TYPES{$type});

  my @files;

  _archive_files_recursive($path, $prefix, $type, $path_re, $file_re, \@files);

  return join('', @files), "\n";
}

sub _archive_files_recursive
{
  my $path = shift;
  my($prefix, $type, $path_re, $file_re, $files) = @_;

  croak "No such file or directory - '$path'"  unless(-e $path);

  if(-f _)
  {
    _archive_file($path, @_);
  }
  elsif(-d _)
  {
    opendir(my $dir, $path) or 
      croak "Could not read directory '$path' - $!";

    while(my $file = readdir($dir))
    {
      next  if($file =~ /^\.\.?$/);
      my $file_path = Path::Class::File->new($path, $file);
      $file_path->cleanup;
      _archive_files_recursive($file_path->stringify, @_);
    }

    closedir($dir);
  }
  else
  {
    croak "Don't know how to handle file system object '$path'";
  }
}

sub _archive_file
{
  my($path, $prefix, $type, $path_re, $file_re, $files) = @_;

  my $file = Path::Class::File->new($path);
  $file->cleanup;

  my $full_rel_path;

  if(defined $prefix)
  {
    $prefix = Path::Class::Dir->new($prefix);

    if(($prefix->is_absolute && $file->is_absolute) ||
       (!$file->is_absolute && !$prefix->is_absolute))
    {
      $full_rel_path = $file->relative($prefix);
    }
    else
    {
      croak "File/dir and prefix must both be relative or both be absolute";
    }
  }
  else
  {
    $full_rel_path = $file;
  }

  if(($path_re && $full_rel_path !~ /$path_re/) ||
     ($file_re && $file->basename !~ /$file_re/))
  {
    return;
  }

  my $contents = $file->slurp;

  push(@$files, _format_archive_file($file, $full_rel_path, $contents, $type));
}

sub _format_archive_file
{
  my($file, $path, $contents, $type) = @_;

  chomp($contents);

  my $mode  = (stat($file))[2];
  my $lines = ($contents =~ tr/\n/\n/) + 1;

  return<<"EOF";
---
File: $path
Mode: $mode
Type: $type
Lines: $lines

$contents
EOF
}

1;
