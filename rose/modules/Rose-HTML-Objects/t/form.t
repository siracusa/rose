#!/usr/bin/perl -w

use strict;

use Test::More tests => 81;

BEGIN 
{
  use_ok('Rose::HTML::Form');
  use_ok('Rose::HTML::Form::Field::Text');
  use_ok('Rose::HTML::Form::Field::SelectBox');
  use_ok('Rose::HTML::Form::Field::RadioButtonGroup');
  use_ok('Rose::HTML::Form::Field::CheckBoxGroup');
  use_ok('Rose::HTML::Form::Field::DateTime::Split::MonthDayYear');
  use_ok('Rose::HTML::Form::Field::DateTime::Split::MDYHMS');
}

my $form = Rose::HTML::Form->new;
ok(ref $form && $form->isa('Rose::HTML::Form'), 'new()');

$form->html_attr('action' => '/foo/bar');

is($form->start_html, '<form action="/foo/bar" enctype="application/x-www-form-urlencoded" method="get">', 'start_html() 1');

eval { $form->html_attr('nonesuch') };
ok($@, 'invalid attribute');

$form->error('Foo > bar');
is($form->error, 'Foo > bar', 'error()');

is($form->html_error, '<span class="error">Foo &gt; bar</span>', 'html_error()');
is($form->xhtml_error, '<span class="error">Foo &gt; bar</span>', 'xhtml_error()');

$form->escape_html(0);

is($form->html_error, '<span class="error">Foo > bar</span>', 'html_error()');
is($form->xhtml_error, '<span class="error">Foo > bar</span>', 'xhtml_error()');

my $field = Rose::HTML::Form::Field::Text->new();

ok($form->add_field(foo => $field), 'add_field()');

is($form->field('foo'), $field, 'field() set with field object');

my @fields = $form->fields;
is(@fields, 1, 'fields()');

$form->delete_fields();
@fields = $form->fields;
is(@fields, 0, 'delete_fields()');

my $field2 =  Rose::HTML::Form::Field::Text->new(name => 'bar');
$form->add_fields($field, $field2);

ok($form->field('foo') eq $field &&
   $form->field('bar') eq $field2,
  'add_fields() objects');

@fields = $form->fields;
is(@fields, 2, 'add_fields() objects check');

my @field_names = $form->field_names;
is(join(', ', @field_names), 'bar, foo', 'field_names()');

$form->delete_fields();
@fields = $form->fields;
is(@fields, 0, 'delete_fields()');

$form->add_fields(foo2 => $field, bar2 => $field2);

ok($form->field('foo2') eq $field && $field->name eq 'foo2' &&
  $form->field('bar2')  eq $field2 && $field2->name eq 'bar2',
  'add_fields() hash');

@fields = $form->fields;
is(@fields, 2, 'add_fields() hash check');

$form->params(a => 1, b => 2, c => [ 7, 8, 9 ]);
is($form->param('b'), 2, 'param()');

ok($form->param_exists('a'), 'param_exists() true');
ok(!$form->param_exists('z'), 'param_exists() false');

ok($form->param_value_exists('c' => 8), 'param_value_exists() true');
ok(!$form->param_value_exists('c' => 10), 'param_value_exists() false');

$form->delete_param('b');
ok(!$form->param_exists('b'), 'delete_param()');

$form->add_param_value('c' => 10);
ok($form->param_value_exists('c' => 10), 'add_param_value()');

$form->params(foo2 => 2, bar2 => 5);
$form->init_fields();
is($form->query_string, 'bar2=5&foo2=2', 'query_string() 1');

$form->clear_fields;
is($form->query_string, '', 'clear_fields()');

$form->delete_fields;

my %fields;

$fields{'name'} = Rose::HTML::Form::Field::Text->new;
$fields{'age'}  = Rose::HTML::Form::Field::Text->new(size => 2);
$fields{'bday'} = Rose::HTML::Form::Field::DateTime::Split::MonthDayYear->new(name => 'bday');

$form->add_fields(%fields);

is($form->html_hidden_fields, 
   qq(<input name="age" type="hidden" value="">\n) .
   qq(<input name="bday.day" type="hidden" value="">\n) .
   qq(<input name="bday.month" type="hidden" value="">\n) .
   qq(<input name="bday.year" type="hidden" value="">\n) .
   qq(<input name="name" type="hidden" value="">),
   'html_hidden_fields() 1');

is($form->xhtml_hidden_fields, 
   qq(<input name="age" type="hidden" value="" />\n) .
   qq(<input name="bday.day" type="hidden" value="" />\n) .
   qq(<input name="bday.month" type="hidden" value="" />\n) .
   qq(<input name="bday.year" type="hidden" value="" />\n) .
   qq(<input name="name" type="hidden" value="" />),
   'xhtml_hidden_fields() 1');

$form->coalesce_hidden_fields(1);

is($form->html_hidden_fields, 
   qq(<input name="age" type="hidden" value="">\n) .
   qq(<input name="bday" type="hidden" value="">\n) . 
   qq(<input name="name" type="hidden" value="">),
   'html_hidden_fields() coalesced 1');

is($form->xhtml_hidden_fields, 
   qq(<input name="age" type="hidden" value="" />\n) .
   qq(<input name="bday" type="hidden" value="" />\n) . 
   qq(<input name="name" type="hidden" value="" />),
   'xhtml_hidden_fields() coalesced 1');

$form->params(name => 'John', age => 27, bday => '12/25/1980');

$form->init_fields();

is($form->html_hidden_fields, 
   qq(<input name="age" type="hidden" value="27">\n) .
   qq(<input name="bday" type="hidden" value="12/25/1980">\n) . 
   qq(<input name="name" type="hidden" value="John">),
   'init_fields() 1');

$form->clear_fields();

is($form->html_hidden_fields, 
   qq(<input name="age" type="hidden" value="">\n) .
   qq(<input name="bday" type="hidden" value="">\n) . 
   qq(<input name="name" type="hidden" value="">),
   'clear_fields()');

%fields = 
(
  'hobbies' =>
    Rose::HTML::Form::Field::SelectBox->new(
      multiple => 1,
      options =>
      {
        tennis  => 'Tennis',
        golf     => 'Golf',
        sleeping => 'Sleeping',
      }),

  'sex' =>
    Rose::HTML::Form::Field::RadioButtonGroup->new(
      radio_buttons => [ 'M', 'F' ],
      labels =>
      {
        M  => 'Male',
        F  => 'Female',
      }),

  'status' =>
    Rose::HTML::Form::Field::CheckBoxGroup->new(
      checkboxes => [ 'married', 'kids', 'tired' ],
      labels =>
      {
        married  => 'Married',
        kids     => 'With Kids & Stuff',
        tired    => 'And tired',
      }),
);

$form->add_fields(%fields);

$form->params(name => ' John ', age => 27, bday => '1980-12-25', 
              hobbies => [ 'tennis', 'sleeping' ],
              sex => 'M', status => [ 'married', 'tired' ]);

$form->init_fields();

is($form->html_hidden_fields, 
   qq(<input name="age" type="hidden" value="27">\n) .
   qq(<input name="bday" type="hidden" value="12/25/1980">\n) . 
   qq(<input name="hobbies" type="hidden" value="sleeping">\n) . 
   qq(<input name="hobbies" type="hidden" value="tennis">\n) . 
   qq(<input name="name" type="hidden" value="John">\n) .
   qq(<input name="sex" type="hidden" value="M">\n) .
   qq(<input name="status" type="hidden" value="married">\n) .
   qq(<input name="status" type="hidden" value="tired">),
   'init_fields() 2');

$form->field('name')->default('<Anonymous>');
$form->field('age')->validator(sub { /^\d+$/ });

$form->params(age => '27d', bday => '1980-12-25', 
              hobbies => [ 'tennis', 'sleeping' ],
              sex => 'M', status => [ 'married', 'tired' ]);

$form->init_fields();

ok(!$form->validate, 'validate()');

$form->params(name => '<John>', age => 27, bday => '1980-12-25', 
              hobbies => [ 'tennis', 'sleeping' ],
              sex => 'M', status => [ 'married', 'tired' ]);

$form->init_fields();

ok($form->validate, 'validate()');

is($form->html_hidden_fields, 
   qq(<input name="age" type="hidden" value="27">\n) .
   qq(<input name="bday" type="hidden" value="12/25/1980">\n) . 
   qq(<input name="hobbies" type="hidden" value="sleeping">\n) . 
   qq(<input name="hobbies" type="hidden" value="tennis">\n) . 
   qq(<input name="name" type="hidden" value="&lt;John&gt;">\n) .
   qq(<input name="sex" type="hidden" value="M">\n) .
   qq(<input name="status" type="hidden" value="married">\n) .
   qq(<input name="status" type="hidden" value="tired">),
   'init_fields() 3');

my $html=<<"EOF";
<form action="/foo/bar" enctype="application/x-www-form-urlencoded" method="get">
<input name="age" size="2" type="text" value="27">
<span class="date"><input class="month" maxlength="2" name="bday.month" size="2" type="text" value="12">/<input class="day" maxlength="2" name="bday.day" size="2" type="text" value="25">/<input class="year" maxlength="4" name="bday.year" size="4" type="text" value="1980"></span>
<select multiple name="hobbies" size="5">
<option value="golf">Golf</option>
<option selected value="sleeping">Sleeping</option>
<option selected value="tennis">Tennis</option>
</select>
<input name="name" size="15" type="text" value="&lt;John&gt;">
<input checked name="sex" type="radio" value="M"> <label>Male</label><br>
<input name="sex" type="radio" value="F"> <label>Female</label>
<input checked name="status" type="checkbox" value="married"> <label>Married</label><br>
<input name="status" type="checkbox" value="kids"> <label>With Kids &amp; Stuff</label><br>
<input checked name="status" type="checkbox" value="tired"> <label>And tired</label>
</form>
EOF

is(join("\n", $form->start_html, 
              (map { $form->field($_)->html } sort $form->field_names),
              $form->end_html) . "\n", $html, 'html()');

$form->params(age => '27', 'bday.month' => 12, 'bday.day' => 25, 'bday.year' => 1980, 
              hobbies => [ 'tennis', 'sleeping' ], name => 'John',
              sex => 'M', status => [ 'married', 'tired' ]);

$form->init_fields();
my $f = $form->field('bday');

is($form->field('bday')->internal_value->strftime('%m/%d/%Y'), '12/25/1980', 'compound field init internal_value()');
is($form->field('bday')->output_value, '12/25/1980', 'compound field init output_value()');

is($form->query_string, 'age=27&bday=12/25/1980&hobbies=sleeping&hobbies=tennis&name=John&sex=M&status=married&status=tired', 'query_string() 2');

$form->coalesce_query_string_params(0);

is($form->query_string, 'age=27&bday.day=25&bday.month=12&bday.year=1980&hobbies=sleeping&hobbies=tennis&name=John&sex=M&status=married&status=tired', 'query_string() 3');

my $object = $form->object_from_form('MyObject');

is($object->name, 'John', 'object_from_form() 1');
is($object->age, 27, 'object_from_form() 2');
is($object->bday->strftime('%m/%d/%Y'), '12/25/1980', 'object_from_form() 3');

my $object2 = $form->object_from_form(class => 'MyObject');

is($object2->name, 'John', 'object_from_form() 4');

is($object2->age, 27, 'object_from_form() 5');

$object->name(undef);
$object->age(undef);

$form->object_from_form($object);

is($object->name, 'John', 'object_from_form() 6');

is($object->age, 27, 'object_from_form() 7');

$object->name('Tina');
$object->age(26);

$form->init_with_object($object);

is($form->field('name')->internal_value, 'Tina', 'init_with_object() 1');

is($form->field('age')->internal_value, 26, 'init_with_object() 2');

$form->params(age => '7', 'bday.month' => 12, 'bday.day' => 25, 'bday.year' => 1995, 
              hobbies => [ 'eating', 'snoozing' ], name => 'Huckleberry',
              sex => 'M', status => 'single');

$form->init_fields();

$form->init_object_with_form($object);

is($form->field('name')->internal_value, 'Huckleberry', 'init_object_with_form() 1');

is($form->field('age')->internal_value, 7, 'init_object_with_form() 2');

$form->method('post');

is($form->start_html, 
  '<form action="/foo/bar" enctype="application/x-www-form-urlencoded" method="post">', 
  'start_html() 2');

is($form->start_xhtml, 
  '<form action="/foo/bar" enctype="application/x-www-form-urlencoded" method="post">', 
  'start_xhtml()');

is($form->start_multipart_html, 
  '<form action="/foo/bar" enctype="multipart/form-data" method="post">', 
  'start_multipart_html()');

is($form->start_multipart_xhtml, 
  '<form action="/foo/bar" enctype="multipart/form-data" method="post">', 
  'start_multipart_xhtml()');

is($form->end_html, '</form>', 'end_html()');
is($form->end_xhtml, '</form>', 'end_xhtml()');

is($form->end_multipart_html, '</form>', 'end_multipart_html()');
is($form->end_multipart_xhtml, '</form>', 'end_multipart_xhtml()');

$form->param(a => [ 1, 2, 3, 4 ]);

$form->delete_param(a => 1);
my $a = $form->param('a');
ok(ref $a eq 'ARRAY' && @$a == 3 && $a->[0] == 2 && $a->[1] == 3 &&
   $a->[2] == 4, 'delete_param() 2');

$form->delete_param(a => [ 2, 3 ]);
$a = $form->param('a');
ok($a == 4, 'delete_param() 3');

$form->delete_param(a => 4);
$a = $form->param('a');
is($a, undef, 'delete_param() 4');
ok(!$form->param_exists('a'), 'delete_param() 5');

$form = MyForm->new();

$form->params(name    => 'John', 
              gender  => 'm',
              hobbies => undef,
              bday    => '1/24/1984');

$form->init_fields;

my $vals = join(':', map { defined $_ ? $_ : '' } 
             $form->field('name')->internal_value,
             $form->field('gender')->internal_value,
             join(', ', $form->field('hobbies')->internal_value),
             $form->field('bday')->internal_value);

is($vals, ':m::1984-01-24T00:00:00', 'init_fields() 4');

$form->reset;

$form->params(name  => 'John', 
              bday  => '1/24/1984');

$form->init_fields(no_clear => 1);

$vals = join(':', map { defined $_ ? $_ : '' } 
             $form->field('name')->internal_value,
             $form->field('gender')->internal_value,
             join(', ', $form->field('hobbies')->internal_value),
             $form->field('bday')->internal_value);

is($vals, ':m:Chess:1984-01-24T00:00:00', 'init_fields() 5');


$form->reset;

$form->params('your_name'  => 'John',
              'bday.month' => 1,
              'bday.day'   => 24,
              'bday.year'  => 1984);

$form->init_fields();

$vals = join(':', map { defined $_ ? $_ : '' } 
             $form->field('name')->internal_value,
             $form->field('gender')->internal_value,
             join(', ', $form->field('hobbies')->internal_value),
             $form->field('bday')->internal_value);

is($vals, 'John::1984-01-24T00:00:00', 'init_fields() 6');

$form->reset;
$form->params('bday'       => '1/24/1984',
              'bday.month' => 12,
              'bday.day'   => 25,
              'bday.year'  => 1975);

$form->init_fields();

$vals = join(':', map { defined $_ ? $_ : '' } 
             $form->field('name')->internal_value,
             $form->field('gender')->internal_value,
             join(', ', $form->field('hobbies')->internal_value),
             $form->field('bday')->internal_value);

is($vals, '::1984-01-24T00:00:00', 'init_fields() 7');

$form->reset;
$form->field('hobbies')->input_value('Knitting');
$form->params('hobbies' => undef);

$form->init_fields(no_clear => 1);

$vals = join(':', map { defined $_ ? $_ : '' } 
             $form->field('name')->internal_value,
             $form->field('gender')->internal_value,
             join(', ', $form->field('hobbies')->internal_value),
             $form->field('bday')->internal_value);

is($vals, ':m::', 'init_fields() 8');

$form->action('/foo/bar');
$form->uri_base('http://www.foo.com');
$form->delete_params();
is($form->self_uri, 'http://www.foo.com/foo/bar', 'self_uri()');

$form = MyForm->new(build_on_init => 0);

is(join('', $form->fields), '', 'build_on_init() 1');

$form->build_form;
@fields = $form->fields;

is(scalar @fields, 4,'build_on_init() 2');


$form = Rose::HTML::Form->new;
$form->add_field(Rose::HTML::Form::Field::DateTime::Split::MDYHMS->new(name => 'event'));
$form->params(
{
  'event.date.month'  => 10,
  'event.date.day'    => 23,
  'event.date.year'   => 2005,
  'event.time.hour'   => 15,
  'event.time.minute' => 21,
});

$form->init_fields;

my $cgi_params = {
    who                 => 'Some name',
    'event.date.month'  => 10,
    'event.date.day'    => 23,
    'event.date.year'   => 2005,
    'event.time.hour'   => 15,
    'event.time.minute' => 21,
};

$form->params( $cgi_params );
$form->init_fields;

is($form->field('event')->html, 
'<span class="datetime"><span class="date"><input class="month" maxlength="2" name="event.date.month" size="2" type="text" value="10">/<input class="day" maxlength="2" name="event.date.day" size="2" type="text" value="23">/<input class="year" maxlength="4" name="event.date.year" size="4" type="text" value="2005"></span> <span class="time"><input class="hour" maxlength="2" name="event.time.hour" size="2" type="text" value="15">:<input class="minute" maxlength="2" name="event.time.minute" size="2" type="text" value="21">:<input class="second" maxlength="2" name="event.time.second" size="2" type="text" value=""><select class="ampm" name="event.time.ampm" size="1">
<option value=""></option>
<option value="AM">AM</option>
<option value="PM">PM</option>
</select></span></span>', 
'init_fields 3-level compound');

BEGIN
{
  package MyObject;

  sub new
  {
    bless {}, shift;
  }

  sub name
  {
    my($self) = shift;

    return $self->{'name'} = shift  if(@_);
    return $self->{'name'};
  }

  sub age
  {
    my($self) = shift;

    return $self->{'age'} = shift  if(@_);
    return $self->{'age'};
  }

  sub bday
  {
    my($self) = shift;

    return $self->{'bday'} = shift  if(@_);
    return $self->{'bday'};
  }

  package MyForm;

  our @ISA = qw(Rose::HTML::Form);

  sub build_form 
  {
    my($self) = shift;

    my %fields;

    $fields{'name'} = 
      Rose::HTML::Form::Field::Text->new(
        name => 'name',
        size => 25);

    $fields{'gender'} = 
      Rose::HTML::Form::Field::RadioButtonGroup->new(
        name          => 'gender',
        radio_buttons => { 'm' => 'Male', 'f' => 'Female' },
        default       => 'm');

    $fields{'hobbies'} = 
      Rose::HTML::Form::Field::CheckBoxGroup->new(
        name       => 'hobbies',
        checkboxes => [ 'Chess', 'Checkers', 'Knitting' ],
        default    => 'Chess');

    $fields{'bday'} = 
      Rose::HTML::Form::Field::DateTime::Split::MonthDayYear->new(
        name => 'bday');

    $self->add_fields(%fields);

      $self->field('name')->html_attr(name => 'your_name');
  }
}
