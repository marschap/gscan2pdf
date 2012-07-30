# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Test::More tests => 17;
BEGIN { use_ok('Gscan2pdf::Scanner::Options') }

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $data = [
 {
  'cap'             => '0',
  'unit'            => '0',
  'max_values'      => '0',
  'desc'            => '',
  'name'            => '',
  'title'           => 'Geometry',
  'type'            => '5',
  'constraint_type' => '0'
 },
 {
  'cap'        => '5',
  'max_values' => '1',
  'name'       => 'tl-x',
  'val'        => '0',
  'unit'       => '3',
  'desc'       => 'Top-left x position of scan area.',
  'constraint' => {
   'min'   => '0',
   'max'   => '200',
   'quant' => '1'
  },
  'title'           => 'Top-left x',
  'type'            => '2',
  'constraint_type' => '1'
 },
 {
  'cap'        => '5',
  'max_values' => '1',
  'name'       => 'tl-y',
  'val'        => '0',
  'unit'       => '3',
  'desc'       => 'Top-left y position of scan area.',
  'constraint' => {
   'min'   => '0',
   'max'   => '200',
   'quant' => '1'
  },
  'title'           => 'Top-left y',
  'type'            => '2',
  'constraint_type' => '1'
 },
 {
  'cap'        => '5',
  'max_values' => '1',
  'name'       => 'br-x',
  'val'        => '80',
  'unit'       => '3',
  'desc'       => 'Bottom-right x position of scan area.',
  'constraint' => {
   'min'   => '0',
   'max'   => '200',
   'quant' => '1'
  },
  'title'           => 'Bottom-right x',
  'type'            => '2',
  'constraint_type' => '1'
 },
 {
  'cap'        => '5',
  'max_values' => '1',
  'name'       => 'br-y',
  'val'        => '100',
  'unit'       => '3',
  'desc'       => 'Bottom-right y position of scan area.',
  'constraint' => {
   'min'   => '0',
   'max'   => '200',
   'quant' => '1'
  },
  'title'           => 'Bottom-right y',
  'type'            => '2',
  'constraint_type' => '1'
 },
 {
  'cap'        => '5',
  'max_values' => '1',
  'name'       => 'page-width',
  'val'        => '200',
  'unit'       => '3',
  'desc' =>
'Specifies the width of the media.  Required for automatic centering of sheet-fed scans.',
  'constraint' => {
   'min'   => '0',
   'max'   => '300',
   'quant' => '1'
  },
  'title'           => 'Page width',
  'type'            => '2',
  'constraint_type' => '1'
 },
 {
  'cap'        => '5',
  'max_values' => '1',
  'name'       => 'page-height',
  'val'        => '200',
  'unit'       => '3',
  'desc'       => 'Specifies the height of the media.',
  'constraint' => {
   'min'   => '0',
   'max'   => '300',
   'quant' => '1'
  },
  'title'           => 'Page height',
  'type'            => '2',
  'constraint_type' => '1'
 },
];
my $options = Gscan2pdf::Scanner::Options->new_from_data($data);
my @that    = (
 {
  index             => 0,
  'cap'             => '0',
  'unit'            => '0',
  'max_values'      => '0',
  'desc'            => '',
  'name'            => '',
  'title'           => 'Geometry',
  'type'            => '5',
  'constraint_type' => '0'
 },
 {
  index        => 1,
  'cap'        => '5',
  'max_values' => '1',
  'name'       => 'tl-x',
  'val'        => '0',
  'unit'       => '3',
  'desc'       => 'Top-left x position of scan area.',
  'constraint' => {
   'min'   => '0',
   'max'   => '200',
   'quant' => '1'
  },
  'title'           => 'Top-left x',
  'type'            => '2',
  'constraint_type' => '1'
 },
 {
  index        => 2,
  'cap'        => '5',
  'max_values' => '1',
  'name'       => 'tl-y',
  'val'        => '0',
  'unit'       => '3',
  'desc'       => 'Top-left y position of scan area.',
  'constraint' => {
   'min'   => '0',
   'max'   => '200',
   'quant' => '1'
  },
  'title'           => 'Top-left y',
  'type'            => '2',
  'constraint_type' => '1'
 },
 {
  index        => 3,
  'cap'        => '5',
  'max_values' => '1',
  'name'       => 'br-x',
  'val'        => '80',
  'unit'       => '3',
  'desc'       => 'Bottom-right x position of scan area.',
  'constraint' => {
   'min'   => '0',
   'max'   => '200',
   'quant' => '1'
  },
  'title'           => 'Bottom-right x',
  'type'            => '2',
  'constraint_type' => '1'
 },
 {
  index        => 4,
  'cap'        => '5',
  'max_values' => '1',
  'name'       => 'br-y',
  'val'        => '100',
  'unit'       => '3',
  'desc'       => 'Bottom-right y position of scan area.',
  'constraint' => {
   'min'   => '0',
   'max'   => '200',
   'quant' => '1'
  },
  'title'           => 'Bottom-right y',
  'type'            => '2',
  'constraint_type' => '1'
 },
 {
  index        => 5,
  'cap'        => '5',
  'max_values' => '1',
  'name'       => 'page-width',
  'val'        => '200',
  'unit'       => '3',
  'desc' =>
'Specifies the width of the media.  Required for automatic centering of sheet-fed scans.',
  'constraint' => {
   'min'   => '0',
   'max'   => '300',
   'quant' => '1'
  },
  'title'           => 'Page width',
  'type'            => '2',
  'constraint_type' => '1'
 },
 {
  index        => 6,
  'cap'        => '5',
  'max_values' => '1',
  'name'       => 'page-height',
  'val'        => '200',
  'unit'       => '3',
  'desc'       => 'Specifies the height of the media.',
  'constraint' => {
   'min'   => '0',
   'max'   => '300',
   'quant' => '1'
  },
  'title'           => 'Page height',
  'type'            => '2',
  'constraint_type' => '1'
 },
);
is_deeply( $options->{array}, \@that, 'libsane-perl' );

is(
 $options->supports_paper(
  {
   x => 210,
   y => 297,
   l => 0,
   t => 0,
  },
  0
 ),
 1,
 'page-width supports_paper'
);
is(
 $options->supports_paper(
  {
   x => 210,
   y => 297,
   l => 0,
   t => -10,
  },
  0
 ),
 0,
 'page-width paper crosses top border'
);
is(
 $options->supports_paper(
  {
   x => 210,
   y => 297,
   l => 0,
   t => 600,
  },
  0
 ),
 0,
 'page-width paper crosses bottom border'
);
is(
 $options->supports_paper(
  {
   x => 210,
   y => 297,
   l => -10,
   t => 0,
  },
  0
 ),
 0,
 'page-width paper crosses left border'
);
is(
 $options->supports_paper(
  {
   x => 210,
   y => 297,
   l => 100,
   t => 0,
  },
  0
 ),
 0,
 'page-width paper crosses right border'
);
is(
 $options->supports_paper(
  {
   x => 301,
   y => 297,
   l => 0,
   t => 0,
  },
  0
 ),
 0,
 'page-width paper too wide'
);
is(
 $options->supports_paper(
  {
   x => 210,
   y => 870,
   l => 0,
   t => 0,
  },
  0
 ),
 0,
 'page-width paper too tall'
);

$options->delete_by_name('page-width');
$options->delete_by_name('page-height');
delete $options->{geometry}{w};
delete $options->{geometry}{h};

is(
 $options->supports_paper(
  {
   x => 200,
   y => 200,
   l => 0,
   t => 0,
  },
  0
 ),
 1,
 'supports_paper'
);
is(
 $options->supports_paper(
  {
   x => 200,
   y => 200,
   l => 0,
   t => -10,
  },
  0
 ),
 0,
 'paper crosses top border'
);
is(
 $options->supports_paper(
  {
   x => 200,
   y => 200,
   l => 0,
   t => 600,
  },
  0
 ),
 0,
 'paper crosses bottom border'
);
is(
 $options->supports_paper(
  {
   x => 200,
   y => 200,
   l => -10,
   t => 0,
  },
  0
 ),
 0,
 'paper crosses left border'
);
is(
 $options->supports_paper(
  {
   x => 200,
   y => 200,
   l => 100,
   t => 0,
  },
  0
 ),
 0,
 'paper crosses right border'
);
is(
 $options->supports_paper(
  {
   x => 201,
   y => 200,
   l => 0,
   t => 0,
  },
  0
 ),
 0,
 'paper too wide'
);
is(
 $options->supports_paper(
  {
   x => 200,
   y => 270,
   l => 0,
   t => 0,
  },
  0
 ),
 0,
 'paper too tall'
);

is( $options->by_name('page-height'), undef, 'by name undefined' );
