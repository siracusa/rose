package Rose::WebApp::Util::InlineContent;

use strict;

use Carp;

use File::Path;
use Path::Class();
use Path::Class::File();
use Path::Class::Dir();

use Exporter;
our @ISA = qw(Exporter);

our $VERSION = '0.01';

our @EXPORT_OK = 
  qw(extract_inline_content create_inline_content normalize_content_type 
     valid_content_types);

our %EXPORT_TAGS = (all => \@EXPORT_OK);

__PACKAGE__->register_subclass;

our %CONTENT_TYPES =
(
  'mason-comps' => 1,
  'htdocs'      => 1,
  'unknown'     => 1,
);

sub valid_content_types { sort keys %CONTENT_TYPES }

sub normalize_content_type
{
  my($type) = shift;

  for($type)
  {
    s/[^-\w:]+//g;
    s/\s+/-/g;
  }

  return $type;
}

sub extract_inline_content
{
  my(%args) = @_;

  my $class     = $args{'class'} or croak "Missing class parameter";
  my $dest      = $args{'dest'}  or croak "Missing dest parameter";
  my $type      = $args{'type'};
  my $verbose   = $args{'verbose'} || 0;
  my $noclobber = $args{'noclobber'} || 0;

  my $dest_is_hash = ref $dest eq 'HASH' ? 1 : 0;

  if(defined $type)
  {
    $type = normalize_content_type($type);
    croak "Invalid content type '$type'"  unless($CONTENT_TYPES{$type});
  }

  no strict 'refs';
  my $fh = \*{"${class}::DATA"};

  croak "$class has no inline content to extract"  unless(fileno($fh));

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

      if($dest_is_hash)
      {
        my $path = Path::Class::File->new($file{'file'});
        $path->cleanup;

        if(exists $dest->{$file{'type'} || 'unknown'}{$path})
        {
          carp "Skipping duplicate file found in inline content: $path";
        }
        else
        {
          $dest->{$file{'type'} || 'unknown'}{$path} = { %file };
        }
      }
      else # write files
      {
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
}

sub create_inline_content
{
  my(%args) = @_;

  my $path = $args{'dir'} || $args{'file'} || 
    croak "Missing file or dir parameter";

  my $prefix = $args{'prefix'};

  my $path_re = $args{'path_match'};
  my $file_re = $args{'file_match'};
  
  foreach my $value (grep { defined } ($path_re, $file_re))
  {
    if(!ref $value || ref $value ne 'CODE')
    {
      my $regex = qr($value);
      $value = sub { $_[0] =~ $regex }; 
    }
  }

  my $type = $args{'type'} or croak "Missing type parameter";

  croak "Invalid content type '$type'"  unless($CONTENT_TYPES{$type});

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
      next  if($file =~ /^\.\.?|\._.+|\.DS_Store$/);
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

  if(($path_re && !$path_re->($full_rel_path)) ||
     ($file_re && !$file_re->($file->basename)))
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
