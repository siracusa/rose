package Rose::WebApp::InlineContent::Util;

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
  qw(extract_inline_content create_inline_content normalize_group_name 
     valid_group_names);

our %EXPORT_TAGS = (all => \@EXPORT_OK);

use Rose::Class::MakeMethods::Generic
(
  scalar => 'default_group',
);

__PACKAGE__->default_group('htdocs');

our %GROUPS =
(
  'mason-comps' => 1,
  'htdocs'      => 1,
  'unknown'     => 1,
);

sub valid_group_names { sort keys %GROUPS }

sub normalize_group_name
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
  my $group     = $args{'group'} || __PACKAGE__->default_group;
  my $verbose   = $args{'verbose'} || 0;
  my $noclobber = $args{'noclobber'} || 0;

  my $dest_is_hash = ref $dest eq 'HASH' ? 1 : 0;

  no strict 'refs';
  my $fh = \*{"${class}::DATA"};

  unless(fileno($fh))
  {
    #croak "$class has no inline content to extract";
    return 0;
  }

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
      croak "Syntax error on line $. - $_"  unless(exists $file{'content'});
      %file = ();
      $line = 0;
    }
    elsif(/^(Path|Type|Lines|Mode|Chomp): *(\S.*)$/i)
    {
      $file{lc $1} = $2;
    }
    elsif(/^$/)
    {
      next  unless(%file);

      $file{'group'} ||= $group;

      foreach my $line (1 .. $file{'lines'})
      {
        $file{'content'} .= <$fh>;
      }

      if($file{'chomp'})
      {
        if($file{'chomp'} eq 'all')
        {
          $file{'content'} =~ tr/\n//;
        }
        else
        {
          chomp($file{'content'});
        }
      }

      $file{'modified'} = $^T; # time the program started
      $file{'loaded_from_class'} = $class;
#use Data::Dumper;
#print STDERR "EXTRACTED CONTENT: ", Dumper(\%file);
      if($dest_is_hash)
      {
        my $path = Path::Class::File->new($file{'path'});
        $path->cleanup;

        if(exists $dest->{$file{'group'}}{$path})
        {
          if($noclobber)
          {
            my $loaded_from = $dest->{$file{'group'}}{$path}{'loaded_from_class'};

            carp "Skipping duplicate $file{'group'} file found in inline ",
                 "content '$path' - previously loaded from $loaded_from";
          }

          next;
        }
        else
        {
          $dest->{$file{'group'}}{$path} = { %file };
        }
      }
      else # write files
      {
        my $install_path = Path::Class::File->new($dest, $file{'path'});
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

        print $fh $file{'content'};

        close($fh) or croak "Could not write file '$install_path' - $!";

        if(defined $file{'mode'})
        {
          chmod($file{'mode'}, $install_path)
            or warn "Could not set file mode to $file{'mode'} for file $install_path - $!\n";
        }
      }
    }
  }

  return 1;
}

sub choose_group_name
{
  /\.[sx]?html?$/i && return 'html';
  /\.mc$/i         && return 'mason-comp';

  return 'unknown';
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

  my $set_group = $args{'set_group'} || \&choose_group;

  my @files;

  _archive_files_recursive($path, $prefix, $set_group, $path_re, $file_re, \@files);

  return join('', @files), "\n";
}

sub _archive_files_recursive
{
  my $path = shift;
  my($prefix, $set_group, $path_re, $file_re, $files) = @_;

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
  my($path, $prefix, $set_group, $path_re, $file_re, $files) = @_;

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

  my $content = $file->slurp;

  push(@$files, _format_archive_file($file, $full_rel_path, \$content, $set_group));
}

use constant MAX_UNWRAPPED_CONTENT_LENGTH => 200;

sub _format_archive_file
{
  my($file, $path, $content_ref, $set_group) = @_;

  local $_ = $path;
  my $group = $set_group->($path) || 'unknown';

  my $chomp = 0;

  if($$content_ref !~ /\n/ && length($$content_ref) > MAX_UNWRAPPED_CONTENT_LENGTH)
  {
    $$content_ref =~ s/\G(.{1,80})/$1\n/g;
    $chomp = 'all';
  }
  else
  {
    $chomp = $$content_ref =~ /\n\z/ ? 1 : 0;
    chomp($$content_ref);
  }

  my $mode  = (stat($file))[2];
  my $lines = ($$content_ref =~ tr/\n/\n/) + 1;

  return<<"EOF";
---
Path:  $path
Mode:  $mode
Group: $group
Chomp: $chomp
Lines: $lines

$$content_ref
EOF
}

1;
