package Rose::BuildConf;

use strict;

use Carp;

use FindBin qw($Bin);

use File::Copy;
use File::Path;
use File::Basename;
use File::Find;
use File::Compare;
use Getopt::Long;

use Rose::BuildConf::Class;
use Rose::BuildConf::Question;
use Rose::BuildConf::Install::Target;

use Rose::BuildConf::Helpers qw(:all);

use Rose::Object;
our @ISA = qw(Rose::Object);

our $Self;

our $DIFF = _get_executable('diff', qw(/usr/bin/diff /usr/local/bin/diff /bin/diff));

our $VERSION = '0.01';

our $Debug = 0;

use Rose::Object::MakeMethods::Generic
(
  'scalar' => 
  [
    qw(install_root post_qa_action pre_install_action 
       post_install_action _readline error)
  ],

  'scalar --get_set_init' =>
  [
    qw(action script_name build_root diff_command)
  ]
);

sub init_action       { 'configure' }
sub init_script_name  { $0 }
sub init_build_root   { $Bin }
sub init_diff_command { $DIFF }

sub run
{
  my($self) = shift;

  if($self->action eq 'install')
  {
    $self->install;
  }
  else # configure
  {
    $self->configure;
  }
}

sub parse_command_line
{
  my($self) = shift;

  $self->{'_save_argv'} = [ @ARGV ];

  if($self->action eq 'install')
  {
    $self->parse_command_line_install;
  }
  else # configure
  {
    $self->parse_command_line_configure;
  }

  unless($self->option('noreadline') || 
         (defined $self->option('interactive') && !$self->option('interactive')))
  {
    eval { require Term::ReadLine };

    if($@)
    {
      die "Could not load Term::Readline - $@\n",
          "Perhaps you should use the --noreadline option.\n";
    }

    my $term = $self->{'_readline'} = Term::ReadLine->new(ref($self));

    if($term->ReadLine =~ /::Stub$/) # the stub doesn't do what we need
    {
      $self->{'_readline'} = undef;
    }
    else
    {
      # Get rid of that underlining crap
      $term->ornaments(0);

      ($term->OUT) ? select($term->OUT) : select(STDOUT);
    }
  }
}

sub parse_command_line_configure
{
  my($self) = shift;

  Getopt::Long::Configure('auto_abbrev');

  my $opts = $self->{'options'} ||= {};

  GetOptions($opts, qw(verbose:1 help interactive:1 load-preset=s list-presets
                       save-preset=s delete-preset=s install current-preset
                       noreadline quiet

                       force all simple)) # install options
    or $self->usage();

  $self->usage()  if(exists $opts->{'help'});

  $self->action('install')  if($opts->{'install'});

  unless($self->option('load-preset'))
  {
    $self->option(interactive => 1)  
      unless(defined $self->option('interactive'));
  }
}

sub parse_command_line_install
{
  my($self) = shift;

  Getopt::Long::Configure('auto_abbrev');

  my $opts = $self->{'options'} ||= {};

  GetOptions($opts, qw(verbose:1 help force all quiet simple))
    or $self->usage();

  $self->usage()  if(exists $opts->{'help'});
}

sub usage
{
  my($self) = shift;

  if($self->action eq 'install')
  {
    $self->usage_install;
  }
  else # configure
  {
    $self->usage_configure;
  }
}

sub usage_configure
{
  my($self) = shift;

  print STDERR<<"EOF";
Usage: $self->{'script_name'} [--help] | [--verbose [num]] [--noreadline]
       [ --list-presets | --current-preset | --delete-preset <preset> ] |
       [ --save-preset <preset> | --load-preset <preset> ] [--interactive]

--help             Show this help screen
--quiet            Don't print status messages
--verbose [num]    Print status messages (more as num gets larger)

--interactive      Prompt for each configuration value.

--list-presets     List all available presets
--current-preset   List the currently active preset (if any)

--save <preset>    Save the current configuration as a preset named <preset>
--load <preset>    Load the preset configuration named <preset>
--delete <preset>  Delete the preset configuration named <preset>

--noreadline       Don't use the Term::ReadLine module
EOF

  exit;
}

sub usage_install
{
  my($self) = shift;

  print STDERR<<"EOF";
Usage: $self->{'script_name'} [--force] [--all] [--verbose | --quiet] | [--help]

--help           Show this help screen
--verbose [num]  Print status messages (more as num gets larger)
--quiet          Don't print any status messages

--all            Overwrite any existing files
--force          Overwrite existing files without asking
--simple         Just compare file sizes, don't diff
EOF

  exit;
}

sub option
{
  my($self) = shift;

  if(@_ == 1)
  {
    return $self->{'options'}{$_[0]};
  }
  elsif(@_ == 2)
  {
    return $self->{'options'}{$_[0]} = $_[1];
  }

  croak "Missing option name argument";
}

sub conf_root
{
  my($self) = shift;

  if(@_)
  {
    $self->{'conf_root'} = $ENV{'ROSE_CONF_FILE_ROOT'} = shift;
  }

  return $self->{'conf_root'};
}

sub add_questions
{
  my($self) = shift;

  if(@_)
  {
    if(@_ == 1 && ref $_[0] eq 'ARRAY')
    {
      if(ref $_[0][0] eq 'HASH')
      {
        $self->_add_questions_from_struct(@_);      
      }
      else
      {
        foreach my $question (@{$_[0]})
        {
          $self->add_question($question);
        }
      }
    }
    else
    {
      foreach my $question (@_)
      {
        $self->add_question($question);
      }
    }
  }
  else
  {
    croak "Missing questions argument(s)";
  }
}

sub _add_questions_from_struct
{
  my($self, $questions) = @_;

  foreach my $class_block (@$questions)
  {
    my $class = $class_block->{'class'} 
      or croak "Missing class name in question structure";

    $class = Rose::BuildConf::Class->new($class);

    $class->preamble($class_block->{'preamble'})
      if(exists $class_block->{'preamble'});

    $class->skip_if($class_block->{'skip_if'})
      if(exists $class_block->{'skip_if'});

    if(exists $class_block->{'questions'} &&
       ref $class_block->{'questions'} eq 'ARRAY')
    {
      foreach my $param_hash (@{$class_block->{'questions'}})
      {
        my $question = Rose::BuildConf::Question->new(%$param_hash);

        $Debug && warn "Adding question: ", $question->question;

        $class->add_question($question);
      }
    }

    $Debug && warn "Adding class ", $class->name, " with ",
                   $class->num_questions, " question(s)";

    $self->add_class($class);
  }
}

sub add_question
{
  my($self, $question) = @_;

  croak "No question to add"  unless(defined $question);
  croak "Question is not a Rose::BuildConf::Question object"
    unless(ref $question && $question->isa('Rose::BuildConf::Question'));

  my $class = $question->class || croak "Cannot add class-less queston";

  $self->add_class($class)  unless($self->class_exists($class->name));

  $class->add_question($question);
}

sub class
{
  my($self, $class) = @_;

  croak "Missing class argument"  unless(defined $class);

  if(exists $self->{'_classes'}{$class})
  {
    return $self->{'_classes'}{$class};
  }

  return;
}

sub class_exists { (shift->class(@_)) ? 1 : 0 }

sub classes
{
  my($self) = shift;

  if(@_)
  {
    my @classes;

    if(@_ == 1 && ref $_[0] eq 'ARRAY')
    {
      @classes = @{$_[0]};
    }
    else
    {
      @classes = @_;
    }

    $self->{'_classes'} = {};

    foreach my $class (@classes)
    {
      $self->add_class($class);
    }
  }

  return (wantarray) ? @{$self->{'classes'}} : [ @{$self->{'classes'}} ];
}

sub add_class
{
  my($self, $class) = @_;

  croak "No conf class to add"  unless(defined $class);

  unless(ref $class && $class->isa('Rose::BuildConf::Class'))
  {
    $class = Rose::BuildConf::Class->new($class);
  }

  $self->{'_classes'}{$class->name} = $class;

  push(@{$self->{'classes'}}, $class);
}

sub conf_value
{
  my($self, %args) = @_;

  my $class = $args{'class'};
  my $param = $args{'param'};

  croak "Missing one or more required argument: class, param"
    unless(defined $class && defined $param);

  if(my $class = $self->class($class))
  {
    return $class->conf_value($param);
  }

  return;
}

sub custom_conf
{
  my($self, %args) = @_;

  my $class = $args{'class'};
  my $param = $args{'param'};

  croak "Missing one or more required argument: class, param"
    unless(defined $class && defined $param);

  unless(ref $class && $class->isa('Rose::BuildConf::Class'))
  {
    $class = $self->class($class) or croak "No such class: $args{'class'}";
  }

  my $class_name = $class->name;

  if(exists $args{'value'})
  {
    $class->conf_value($args{'param'} => $args{'value'});
    return $self->{'custom_conf'}{$class_name}{$args{'param'}} = $args{'value'};
  }

  return $self->{'custom_conf'}{$class_name}{$args{'param'}};
}

sub custom_classes
{
  my($self) = shift;

  return sort keys %{$self->{'custom_conf'}};
}

sub custom_conf_params
{
  my($self, $class) = @_;

  croak "Missing class namr argument"  unless(defined $class);

  return sort keys %{$self->{'custom_conf'}{$class}};
}

sub install_targets
{
  my($self) = shift;

  if(@_)
  {
    if(@_ == 1 && ref $_[0] eq 'ARRAY')
    {
      $self->{'install_targets'} = $_[0];
    }
    else
    {
      $self->{'install_targets'} = [ @_ ];
    }

    $self->{'_install_targets'} = {};

    foreach my $target (@{$self->{'install_targets'}})
    {
      $self->{'_install_targets'}{$target->tag}++;

      unless(ref $target && $target->isa('Rose::BuildConf::Install::Target'))
      {
        croak "Not a Rose::BuildConf::Install::Target: '$target'";
      }
    }
  }

  return (wantarray) ? @{$self->{'install_targets'}} : $self->{'install_targets'};
}

sub install_target_exists
{
  my($self, $tag) = @_;

  return (exists $self->{'_install_targets'}{$tag}) ? 1 : 0;
}

sub add_install_target
{
  my($self, $target) = @_;

  croak "No install target to add"  unless(defined $target);

  unless(ref $target && $target->isa('Rose::BuildConf::Install::Target'))
  {
    croak "Not a Rose::BuildConf::Install::Target: '$target'";
  }

  $self->{'_install_targets'}{$target->tag}++;
  push(@{$self->{'install_targets'}}, $target);      
}

sub add_install_targets
{
  my($self) = shift;

  if(@_)
  {
    if(@_ == 1 && ref $_[0] eq 'ARRAY')
    {
      $self->_add_install_targets_from_struct(@_);      
    }
    else
    {
      foreach my $target (@_)
      {
        $self->add_install_target($target);
      }
    }
  }
  else
  {
    croak "No install targets to add";
  }
}

sub _add_install_targets_from_struct
{
  my($self, $targets) = @_;

  foreach my $target (@$targets)
  {
    croak "Expected has reference, but got '$target'"
      unless(ref $target eq 'HASH');

    my %args = %$target;

    foreach my $arg (keys(%args))
    {
      if(ref $args{$arg} eq 'CODE')
      {
        $args{$arg} = $args{$arg}->($self); 
      }
    }

    my $target = Rose::BuildConf::Install::Target->new(%args);

    $self->add_install_target($target);
  }
}

sub conf_root_relative
{
  my($self, $path) = @_;

  if(length $path)
  {
    if($path =~ m{^@{[$self->conf_root]}(?:/|$)})
    {
      $path =~ s{^@{[$self->conf_root]}/?}{};
      return $path;
    }

    return join('/', $self->conf_root, $path);
  }

  return $self->conf_root;
}

sub build_root_relative
{
  my($self, $path) = @_;

  if(length $path)
  {
    if($path =~ m{^@{[$self->build_root]}(?:/|$)})
    {
      $path =~ s{^@{[$self->build_root]}/?}{};
      return $path;
    }

    return join('/', $self->build_root, $path);
  }

  return $self->build_root;
}

sub install_root_relative
{
  my($self, $path) = @_;

  if(length $path)
  {
    if($path =~ m{^@{[$self->install_root]}(?:/|$)})
    {
      $path =~ s{^@{[$self->install_root]}/?}{};
      return $path;
    }

    return join('/', $self->install_root, $path);
  }

  return $self->install_root;
}

sub presets_root
{
  my($self) = shift;

  if(@_)
  {
    return $self->{'presets_root'} = shift;
  }

  return $self->{'presets_root'} ||= $self->conf_root_relative('presets');
}

sub configure
{
  my($self) = shift;

  my $quiet = $self->option('quiet');

  my $preset;

  if($preset = $self->option('load-preset'))
  {
    $self->load_preset($preset);
    $quiet or print "Loaded preset configuration: $preset\n";
    exit;
  }
  elsif($preset = $self->option('save-preset'))
  {
    $self->save_preset($preset);
    $quiet or print "Saved current configuration to preset: $preset\n";
    exit;
  }
  elsif($preset = $self->option('delete-preset'))
  {
    $self->delete_preset($preset);
    $quiet or print "Deleted preset configuration: $preset\n";
    exit;
  }
  elsif($self->option('list-presets'))
  {
    $self->list_presets();
    exit;
  }
  elsif($self->option('current-preset'))
  {
    $self->list_current_preset();
    exit;
  }

  $self->ask_questions();

  if(ref $self->{'post_qa_action'} eq 'CODE')
  {
    $self->{'post_qa_action'}->($self);
  }

  $self->write_local_conf()  if($self->option('interactive'));

  $self->process_templates();
}

sub install
{
  my($self) = shift;

  if(ref $self->{'pre_install_action'} eq 'CODE')
  {
    $self->{'pre_install_action'}->($self);
  }

  foreach my $target ($self->install_targets)
  {
    $self->install_target($target);
  }

  if(ref $self->{'post_install_action'} eq 'CODE')
  {
    $self->{'post_install_action'}->($self);
  }
}

sub install_target
{
  my($self, $target) = @_;

  return  unless($target->is_enabled);

  if((my $preamble = $target->preamble) && $self->option('verbose') > 1)
  {
    print "\n", $preamble, "\n";
  }

  my $source      = $target->source;
  my $destination = $target->destination;
  my $recursive   = $target->recursive;

  if(-d $source)
  {
    $self->_install_tree(target      => $target,
                         source      => $source, 
                         destination => $destination,
                         recursive   => $recursive);
  }
  elsif(-f $source)
  {
    $self->install_file(target      => $target,
                        source      => $source, 
                        destination => $destination);
  }
  else
  {
    warn "Nothing to install!";
  }
}

sub _install_tree
{
  my($self, %args) = @_;

  my $target      = $args{'target'};
  my $source      = $args{'source'};
  my $destination = $args{'destination'};
  my $recursive   = $args{'recursive'};

  $self->install_dir(target      => $target,
                     source      => $source, 
                     destination => $destination);

  opendir(my $dirh, $source) or croak "Could not opendir($source): $!";

  my $file;

  FILE: while(defined($file = readdir($dirh)))
  {
    next FILE  if($file =~ /^\.\.?$/);

    local $_ = $file;

    my $source_path      = "$source/$file";
    my $destination_path = "$destination/$file";

    next FILE  if($target->should_skip($source_path));

    next FILE  unless($target->should_install($source_path));

    if(-d $source_path && $recursive)
    {
      $self->_install_tree(target      => $target,
                           source      => $source_path,
                           destination => $destination_path,
                           recursive   => $recursive);
    }
    elsif(-f $source_path)
    {
      $self->install_file(target      => $target,
                          source      => $source_path,
                          destination => $destination_path);
    }
  }
}

sub install_dir
{
  my($self, %args) = @_;

  my $target      = $args{'target'};
  my $source      = $args{'source'};
  my $destination = $args{'destination'};

  mkpath($destination, undef, 0775);

  die "ERROR: Could not make path $destination: $!\n"
    unless(-d $destination);

  $self->_sync_modes($source, $destination, $target->mode);
}

sub install_file
{
  my($self, %args) = @_;

  my $target      = $args{'target'};
  my $source      = $args{'source'};
  my $destination = $args{'destination'};

  my $verbose  = $self->option('verbose');
  my $skip     = 0;
  my $mode_set = $target->mode;

  my $rel_dest = $destination;
  $rel_dest =~ s{^@{[$self->install_root]}(?:/|$)}{};

  if(-e $destination && !$self->option('all'))
  {
    my($src_mtime, $src_size)   = (stat($source))[9,7];
    my($dest_mtime, $dest_size) = (stat($destination))[9,7];

    if(!($self->option('all') || $target->reinstall) && 
       $src_size == $dest_size && ($dest_mtime >= $src_mtime || 
        $self->_files_are_identical($destination, $source)))
    {
      unless($dest_mtime >= $src_mtime)
      {
        my $now = time;
        utime($now, $now, $destination) or
          warn "Could not update utime() for $destination - $!\n";
      }

      $skip = 1;
    }
    else
    {
      my $src_mod  = localtime($src_mtime);
      my $dest_mod = localtime($dest_mtime);

      $src_size  .= ' byte' . (($src_size == 1) ? '' : 's');
      $dest_size .= ' byte' . (($dest_size == 1) ? '' : 's');

      my $source_file = basename($source);

      CONFIRM:
      {
        unless($self->option('force') || $target->force)
        {
          my $res = $self->ask(prompt   => "Overwrite? [ynqd] ",
                               default  => 'n',
                               question =><<"EOF");
WARNING: $destination exists.
Do you want to over-write the existing file?

  Existing: $destination - $dest_size
            Modified $dest_mod

       New: $source_file - $src_size
            Modified $src_mod
EOF

          exit  if($res =~ /^q/i);

          if($res =~ /^d/i)
          {
            if(my $diff = $self->diff_command)
            {
              print "Running '$diff <new-file> <old-file>'\n\n";
              system($diff, $source, $destination);
            }
            else
            {
              print "\nERROR: Cannot show differences: ",
                    "no diff command defined.\n";
            }

            redo CONFIRM; 
          }

          $skip = 1  unless($res =~ /^y(?:es)?$/i);
        }
      }
    }

    $self->_sync_modes($source, $destination, $mode_set);
  }

  if($skip)
  {
    ($verbose > 1) and print "$rel_dest: Skipped (No change)\n";
    return;
  }

  if($verbose > 1)
  {
    print "$source -> $destination\n";
  }
  elsif($verbose)
  {
    print "$destination\n";
  }

  #if(-e $destination && !-w _)
  #{
  #  # XXX: I'd like to do this with Perl's chmod(), but I'll be lazy for now...
  #  system('chmod', 'u+w', $destination);
  #}

  copy($source, $destination) 
    or die "ERROR: copy($source -> $destination): $!\n";

  $self->_sync_modes($source, $destination, $mode_set);
}

sub _sync_modes
{
  my($self, $source, $destination, $mode_set) = @_;

  my $mode;

  if(ref $mode_set eq 'CODE')
  {
    $mode = $mode_set->($self, source      => $source, 
                               destination => $destination);
  }

  if($mode_set eq 'copy' or !defined $mode_set)
  {
    $mode = (stat($source))[2];

    chmod($mode, $destination);
  }
  elsif($mode_set =~ /^\d+$/)
  {
    chmod($mode = $mode_set, $destination);
  }

  unless((stat($destination))[2] == $mode)
  {
    # One last try
    chmod($mode, $destination) 
      or die "Could not chmod($mode, $destination): $!\n";
  }

  #my $now = time;
  #
  #utime($now, $now, $destination) or
  #  warn "Could not update utime() for $destination - $!\n";

  return 1;
}

sub list_presets
{
  my($self) = shift;

  my $presets_dir = $self->presets_root;

  my(@confs);

  if(opendir(my $dir, $presets_dir))
  {
    while(my $file = readdir($dir))
    {
      next  unless($file =~ /(.+)\.conf$/);
      push(@confs, $1);
    }

    closedir($dir);
  }

  if(@confs)
  {
    print "Preset Configruations:\n\n",
          join("\n", map { "\t$_" } sort @confs), 
          "\n\n";
  }
  else
  {
    print "No preset configurations.\n";
  }
}

sub load_preset
{
  my($self, $preset) = @_;

  my $active_conf = $self->conf_root    . '/local.conf';
  my $preset_conf = $self->presets_root . '/' . $preset . '.conf';

  die "No such preset: $preset\n"      unless(-e $preset_conf);
  die "Cannot read preset: $preset\n"  unless(-r $preset_conf);

  copy($preset_conf, $active_conf) 
    or die "Could not copy $preset_conf -> $active_conf - $!\n";

  unless($self->_files_are_identical($preset_conf, $active_conf))
  {
    die "Could not copy $preset_conf -> $active_conf - $!\n";
  }

  #
  # Run the script again, but without the "--load" argument.
  #

  my @argv;

  my $skip = 0;
  my $saw_int_flag = 0;

  foreach my $arg (@{$self->{'_save_argv'}})
  {
    if($skip) { $skip--; next }

    # XXX: This is a somewhat fragile hack to account for the 
    # XXX: way the auto_abbrev feature of Getopt::Long works.
    if($arg =~ /^--?(?:lo|loa|load(?:-preset)?)/)
    {
      $skip++;
      next;
    }

    # XXX: see above
    if($arg =~ /^--?int/)
    {
      $saw_int_flag++;
    }

    push(@argv, $arg);
  }

  exec($0, @argv, ($saw_int_flag ? () : '--interactive=0'));
}

sub save_preset
{
  my($self, $preset) = @_;

  my $active_conf = $self->conf_root    . '/local.conf';
  my $preset_conf = $self->presets_root . '/' . $preset . '.conf';

  die "No active config to save.\n"     unless(-e $active_conf);

  if(-e $preset_conf)
  {
    my $response = 
      $self->ask(question => "\nWARNING: a preset named '$preset' already exists.\n\n",
                 prompt   => "Overwrite? [yn] ");

    exit  unless($response =~ /^y$/i);
  }

  copy($active_conf, $preset_conf) 
    or die "Could not copy $active_conf -> $preset_conf - $!\n";
}

sub delete_preset
{
  my($self, $preset) = @_;

  my $active_conf = $self->conf_root    . '/local.conf';
  my $preset_conf = $self->presets_root . '/' . $preset . '.conf';

  die "No such preset: $preset\n"      unless(-e $preset_conf);

  unlink($preset_conf) or
    die "Cannot delete preset '$preset' - $!\n";
}

sub list_current_preset
{
  my($self) = shift;

  my @matches = $self->current_preset_matches;

  if($self->option('verbose'))
  {
    if(@matches > 1)
    {
      print "The current configuration matches the following presets:\n",
            join(', ', map { "'$_'" } @matches), "\n";
    }
    elsif(@matches)
    {
      print "The current configuration matches the preset '$matches[0]'\n";
    }
    else
    {
      print "The current configuration does not match any presets.\n";
    }
  }
  else
  {
    if(@matches)
    {
      print join(', ', @matches), "\n";
    }
    else
    {
      print "No matching presets.\n";
    }
  }
}

sub current_preset_matches
{
  my($self) = shift;

  my $active_conf = $self->conf_root    . '/local.conf';

  return  unless(-e $active_conf);

  my $active_conf_size = -s _;

  my $presets_dir = $self->presets_root;

  my @current_preset;

  return  unless(-d $presets_dir);

  opendir(my $dir, $presets_dir) || die "Could not opendir($presets_dir) = $!\n";

  while(my $file = readdir($dir))
  {
    if(-s "$presets_dir/$file" == $active_conf_size && 
          !_diff("$presets_dir/$file", $active_conf))
    {
      $file =~ s/\.conf$//;
      push(@current_preset, $file);
    }
  }

 return @current_preset;
}

sub _diff
{
  my($file1, $file2) = @_;

  open(my $fh1, $file1) or die "Could not read $file1 - $!\n";
  open(my $fh2, $file2) or die "Could not read $file2 - $!\n";

  while(my $l1 = <$fh1>)
  {
    my $l2 = <$fh2>;

    for($l1, $l2)
    {
      s/^\s+//;
      s/\s+$//;
      s/  +/ /g;
    }

    return 1  unless($l1 eq $l2);
  }

  close($fh1);
  close($fh2);

  return;
}

sub prompt
{
  my($self, %args) = @_;

  %args = (prompt => $_[1])  if(@_ == 2);

  my($term, $response);

  if($term = $self->{'_readline'})
  {
    $args{'prompt'} .= ': '  unless($args{'prompt'} =~ /\s$/);
    $response = $term->readline($args{'prompt'}, $args{'default'})
  }
  else
  {
    print "$args{'prompt'} ($args{'default'}): ";
    chomp($response = <STDIN>);
  }

  unless($response =~ /\S/)
  {
    $response = $args{'default'}  if(!$term && length $args{'default'});
    $term->addhistory($response)  if($term);
  }

  return $response;
}

sub ask
{
  my($self, %args) = @_;

  my $response;

  ASK:
  {
    for($args{'question'})
    {
      s/\A\n*/\n/;
      s/\s*\Z/\n\n/;
    }

    print $args{'question'};

    $response = $self->prompt(prompt  => $args{'prompt'},
                              default => $args{'default'});

    redo ASK  unless(defined $response);
  }

  return $response;
}

sub ask_question
{
  my($self, %args) = @_;

  %args = (question => $_[1])  if(@_ == 2);

  my $question   = $args{'question'} || croak "No question to ask";
  my $class      = $question->class  || croak "Question has no class set";
  my $prompt     = $args{'prompt'}   || $question->prompt;
  my $default    = $args{'default'}  || $question->default;
  my $validate   = $args{'validate'} || $question->validate;
  my $in_filter  = $args{'input_filter'} || $question->input_filter;
  my $out_filter = $args{'output_filter'} || $question->output_filter;

  my $pre_action      = $args{'pre_action'}      || $question->pre_action;
  my $post_action     = $args{'post_action'}     || $question->post_action;
  my $post_set_action = $args{'post_set_action'} || $question->post_set_action;

  if(ref $pre_action eq 'CODE')
  {
    $pre_action->($self, question => $question);
  }

  if(ref $default eq 'CODE')
  {
    $default = $default->($self, question => $question);
  }

  my $response;

  ASK:
  {
    if(!$self->option('interactive'))
    {
      $response = $default;
    }
    else
    {
      my $display_default = $default;

      if(ref $out_filter)
      {
        local $_ = $default;
        $display_default = $out_filter->($self, question => $question,
                                                value    => $default);
      }

      $response = $self->ask(question => $question->question,
                             prompt   => $prompt,
                             default  => $display_default);
    }

    for($response) { s/^\s+//; s/\s+$//; }

    if(ref $in_filter)
    {
      local $_ = $response;
      $response = $in_filter->($self, question => $question,
                                      value    => $response);
    }

    if($self->option('interactive') && ref $validate eq 'CODE')
    {
      local $_ = $response;

      unless($validate->($self, value    => $response,
                                question => $question))
      {
        print "\n", $question->error, "\n"  if($question->error);
        redo ASK;
      }
    }
  }

  if(ref $post_action eq 'CODE')
  {
    local $_ = $response;
    $post_action->($self, question => $question,
                          value    => $response);
  }

  my $existing_value = $question->local_conf_value;

  # Decision to add to custom conf is still a bit sketchy...
  if($response ne $default || 
     (defined $existing_value && $response ne $existing_value) || 
     length($existing_value) || !$question->conf_param_exists)
  {
    $self->custom_conf(class => $class,
                       param => $question->conf_param,
                       value => $response);

    if(ref $post_set_action eq 'CODE')
    {
      local $_ = $response;
      $post_set_action->($self, question => $question,
                                value    => $response);
    }
  }
  else
  {
    $question->conf_value($response);
  }

  return $response;
}

sub ask_questions
{
  my($self) = shift;

  CLASS: foreach my $class ($self->classes)
  {
    my $class_name = $class->name;

    eval "use $class_name";

    die $@  if($@);

    next  if($class->should_skip);

    my $conf = $class->conf_hash;

    if((my $preamble = $class->preamble) && $self->option('interactive'))
    {
      print "\n", $preamble;
    }

    QUESTION: foreach my $question ($class->questions)
    {
      next  if($question->should_skip);

      my $param_name       = $question->conf_param;
      my $conf_value       = $class->conf_value($param_name);
      my $question_default = $question->default;
      my $custom_value     = $class->local_conf_value($param_name);
      my $use_default;

      if(defined $custom_value)
      {
        $use_default = $custom_value;
      }
      elsif(defined $question_default)
      {
        if(ref $question_default eq 'CODE')
        {
          $use_default = $question_default->($self, question => $question);
        }
        else
        {
          $use_default = $question_default;
        }
      }
      else
      {
        $use_default = $conf_value;
      }

      $self->ask_question(question => $question,
                          default  => $use_default);
    }
  }
}

sub write_local_conf
{
  my($self) = shift;

  my $written = 0;

  my $local_conf = $self->conf_root . '/local.conf';

  open(my $conf, ">$local_conf") or croak "Could not create $local_conf: $!";

  foreach my $class_name ($self->custom_classes)
  {
    print $conf "\n"  if($written);
    print $conf "CLASS $class_name\n\n";
    $written++;

    foreach my $param_name ($self->custom_conf_params($class_name))
    {
      my $val = $self->custom_conf(class => $class_name,
                                   param => $param_name);

      $val = qq('$val')  unless($val =~ /^\d+$/);
      print $conf qq($param_name = $val\n);
    }
  }

  close($conf) || croak "Could not write $local_conf: $!";
}

sub process_templates
{
  my($self) = shift;

  #print "\n"  if($self->option('verbose'));

  local $Self = $self;

  find({ wanted => \&_process_template, follow => 1 }, $self->build_root);
}

# Arbitrary constants
use constant NO_PART   => 0;
use constant IF_PART   => 1;
use constant ELSE_PART => 2;

# NON-arbitrary constants: don't change these!
use constant IN_PART   => 0;
use constant DO_PART   => 1;

sub _process_template
{
  return  unless(/\.tmpl$/);

  my($self) = $Self;

  my $template_file = $File::Find::name;
  my $final_file    = $template_file;

  $final_file =~ s/\.tmpl$//;

  print 'Processing ', $self->build_root_relative($final_file), "\n"
    unless($self->option('quiet'));

  open(my $template, $template_file) or croak "Could not open $template_file: $!";

  if(-e $final_file && !-w _)
  {
    # XXX: I'd like to do this with Perl's chmod(), but I'll be lazy for now...
    system('chmod', 'u+w', $final_file);
  }

  open(my $final, ">$final_file") or croak "Could not create $final_file: $!";

  my $mode = (stat($template_file))[2];

  chmod($mode, $final_file);

  no strict 'refs';

  my($class, $conf, @conds, $cond, $base_class, $just_set_class);

  ##
  ## XXX: This should be replaced with Template-ToolKit someday...
  ##

  while(<$template>)
  {
    # Skipping this clause
    if(!/\[\%\s*E(?:LSE|ND)\s*%\]/ && @conds && $conds[-1][IN_PART] != $conds[-1][DO_PART])
    {
      if(m{\[%\s*IF\s+.+\s*%\]})
      {
        #push(@conds, []);
        #$conds[-1][IN_PART] = IF_PART;
        #$conds[-1][DO_PART] = NO_PART;

        # Above is an expanded version of this
        push(@conds, [ IF_PART, NO_PART ]);
      }

      next;
    }

    # [% CLASS Some::Class::Name %]
    if(m{\s*\[%\s*CLASS\s+((?:\w|::)+)\s*%\]\s*})
    {
      $class = $self->class($base_class = $1) 
        or die "Could not set CLASS in file $template_file on line $. - No such class '$1'\n";

      $conf = $class->conf_hash;
      $just_set_class = 1;
      next;
    }

    # Skip blanks lines after CLASS directives
    if($just_set_class && /^\s*$/)
    {
      $just_set_class = 0;
      next;
    }

    $just_set_class = 0;

    # [% IF ... %]
    if(m{\[%\s*IF\s+(.+)\s*%\]})
    {
      my $var = $1;

      $var = _template_replace_vars($conf, $var, $template_file, $., $base_class, 1);

      $cond = eval "$var";
      $Debug && warn "EVAL $var = $cond\n";

      #push(@conds, []);
      #$conds[-1][IN_PART] = IF_PART;
      #$conds[-1][DO_PART] = $cond ? IF_PART : ELSE_PART;

      # Above is an expanded version of this
      push(@conds, [ IF_PART, $cond ? IF_PART : ELSE_PART ]);

      next;
    }

    if(@conds)
    {
      if(m{\[%\s*ELSE\s*%\]})
      {
        $conds[-1][IN_PART] = ELSE_PART;
        next;
      }

      if(m{\[%\s*END\s*%\]})
      {
        pop(@conds);
        next;
      }

      # Skip clause
      if($conds[-1][IN_PART] != $conds[-1][DO_PART])
      {
        next;
      }
    }

    s/\[%(.*?)%\]/_template_replace_vars($conf, $1, $template_file, $., $base_class)/ge;

    print $final $_;
  }

  close($template);
  close($final) or croak "Could not write $final_file: $!";
}

sub _template_replace_vars
{
  my($conf, $arg, $file, $line_num, $conf_class, $name_only) = @_;

  my $not;

  for($arg)
  {
    no strict 'refs';

    s/^\s+//;
    s/\s+$//;

    if($name_only && s/^(\!)//)
    {
      $not = 1;
    }

    if(/^"((?:[^"\\]+|\\.)+)"/ || /^((?:[^\s\\]+|\\.)+)(?:\s+|$)/)
    {
      my $var = $1;
      my($param, $value);

      # Pull off package name, if any
      if($var =~ m/^((?:\w+::)+)(.+)/)
      {
        $conf_class = substr($1, 0, -2); # trim trailing ::
        $param      = $2;
      }
      else
      {
        $param = $var;
      }

      # Hash sub-key access: KEY:subkey1:subkey2
      if($param =~ m/^(?:[^\\:]+|\\.)+:/)
      {
        my $var_name = "${conf_class}::CONF";

        if($param =~ /^(?:[^\\:]+|\\.)+:$/)
        {
          Carp::croak qq(Invalid hash sub-key access: "$var" - ),
            qq(missing key name after final ':' in $file line $line_num);
        }

        my @parts;
        my $hash = \%{"${conf_class}::CONF"};
        my $prev_hash;

        while($param =~ m/\G((?:[^\\:]+|\\.)+)(?::|$)/g)
        {
          $prev_hash = $hash;
          my $key = $1;

          my $unescaped_key = $key;
          $unescaped_key =~ s/(\\.)/eval qq("$1")/ge;

          if($@)
          {
            Carp::croak qq(Invalid string in hash sub-key "$key" ),
              qq( in $file line $line_num);          
          }

          $hash = $hash->{$unescaped_key} ||= {};
          push(@parts, $unescaped_key);

          for($key = $unescaped_key) { s/\\/\\\\/g; s/'/\\'/g }
          $var_name .= qq({'$key'});
        }

        $value = $prev_hash->{$parts[-1]};
        $Debug && warn "Found reference to $var_name\n";

        if($name_only)
        {
          s/^"((?:[^\\"]+|\\.)+)"/\$$var_name/ ||
          s/^((?:[^\\\s]+|\\.)+)(\s+|$)/\$$var_name$2/;
        }
        else
        {
          s/^"((?:[^"\\]+|\\.)+)"/$value/ ||
          s/^((?:[^\\\s]+|\\.)+)(\s+|$)/$value$2/
        }
      }
      else
      {  
        $param =~ s/\\(.)/$1/g;

        $Debug && warn "Found reference to $conf_class->param($param)\n";
        $value = $conf_class->param($param);

        if($name_only)
        {
          s/^"((?:[^\\ \t]+|\\.)+)"/$conf_class->param("$param")/ ||
          s/^((?:[^\\ \t]+|\\.)+)(\s+|$)/$conf_class->param("$param")$2/;

        }
        else
        {
          s/^"((?:[^"\\]+|\\.)+)"/$value/ ||
          s/^((?:[^\\ \t]+|\\.)+)(\s+|$)/$value$2/
        }
      }
    }
    else
    {
      Carp::croak "Could not parse variable '$_' in file $file line $line_num\n";    
    }

    if($name_only && $not)
    {
      s/^/!/;
    }

    $Debug && warn "Processed: $_\n";
    return $_;
  }

  $Debug && warn "Nop: $arg\n";
  return $arg;
}

sub _files_are_identical
{
  my($self, $file1, $file2) = @_;
  return compare($file1, $file2) == 0 ? 1 : 0;
}

sub _get_executable
{
  my($name) = shift;

  foreach my $exe (grep { defined } @_)
  {
    return $exe  if(-x $exe);
  }

  warn "Could not find $name executable.  Searched in: ",
        join(', ', @_), "\n"  if(defined $_[$#_]);

  return undef;
}

1;
