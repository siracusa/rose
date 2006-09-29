package Rose::HTML::Object::Errors;

use strict;

use Carp;

use base 'Rose::HTML::Object::Messages';

our $VERSION = '0.531';

BEGIN
{
  __PACKAGE__->message_names_list([]);
  __PACKAGE__->message_id_to_name_map({});
  __PACKAGE__->message_name_to_id_map({});
}

__PACKAGE__->export_tags
(
  all   => __PACKAGE__->message_names_list,
  field => [ grep { /^FIELD_/ } @{__PACKAGE__->message_names_list} ],
  form  => [ grep { /^FORM_/ } @{__PACKAGE__->message_names_list} ],
);

BEGIN
{
  *error_id_exists   = \&Rose::HTML::Object::Messages::message_id_exists;
  *error_name_exists = \&Rose::HTML::Object::Messages::error_name_exists;
  
  *get_error_id   = \&Rose::HTML::Object::Messages::get_message_id;
  *get_error_name = \&Rose::HTML::Object::Messages::get_message_name;
  
  *add_error    = \&Rose::HTML::Object::Messages::add_message;
  *add_errors   = \&Rose::HTML::Object::Messages::add_messages;
  *get_error_id = \&Rose::HTML::Object::Messages::get_message_id;
  
  *add_error  = \&Rose::HTML::Object::Messages::add_message;
  *add_errors = \&Rose::HTML::Object::Messages::add_messages;
}

#
# Errors
#

use constant CUSTOM_ERROR    => -1;
use constant FIELD_REQUIRED  => 3;
use constant FORM_HAS_ERRORS => 100;

BEGIN { __PACKAGE__->add_errors }

1;
