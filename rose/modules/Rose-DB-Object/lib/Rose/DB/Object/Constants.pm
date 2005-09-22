package Rose::DB::Object::Constants;

use strict;

our $VERSION = '0.01';

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = 
  qw(PRIVATE_PREFIX META_ATTR_NAME ON_SAVE_ATTR_NAME FLAG_DB_IS_PRIVATE
     STATE_IN_DB STATE_LOADING STATE_SAVING STATE_CLONING);

our %EXPORT_TAGS = (all => \@EXPORT_OK);

use constant PRIVATE_PREFIX     => '__xrdbopriv';
use constant META_ATTR_NAME     => PRIVATE_PREFIX . '_meta';
use constant ON_SAVE_ATTR_NAME  => PRIVATE_PREFIX . '_on_save';
use constant FLAG_DB_IS_PRIVATE => PRIVATE_PREFIX . '_db_is_private';
use constant STATE_IN_DB        => PRIVATE_PREFIX . '_in_db';
use constant STATE_LOADING      => PRIVATE_PREFIX . '_loading';
use constant STATE_SAVING       => PRIVATE_PREFIX . '_saving';
use constant STATE_CLONING      => STATE_SAVING;

1;
