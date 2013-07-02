use warnings;
use strict;
use Test::More tests => 25;
use Sane 0.05;    # For enums
BEGIN { use_ok('Gscan2pdf::Scanner::Options') }

#########################

my $filename = 'scanners/fujitsu';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new_from_data($output);
my @that     = (
 {
  'index' => 0,
 },
 {
  index             => 1,
  title             => 'Scan Mode',
  'cap'             => 0,
  'max_values'      => 0,
  'name'            => '',
  'unit'            => SANE_UNIT_NONE,
  'desc'            => '',
  type              => SANE_TYPE_GROUP,
  'constraint_type' => SANE_CONSTRAINT_NONE
 },
 {
  name            => 'source',
  title           => 'Source',
  index           => 2,
  'desc'          => 'Selects the scan source (such as a document-feeder).',
  'val'           => 'ADF Front',
  'constraint'    => [ 'ADF Front', 'ADF Back', 'ADF Duplex' ],
  'unit'          => SANE_UNIT_NONE,
  constraint_type => SANE_CONSTRAINT_STRING_LIST,
  type            => SANE_TYPE_STRING,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name   => 'mode',
  title  => 'Mode',
  index  => 3,
  'desc' => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
  'val'  => 'Gray',
  'constraint'    => [ 'Gray', 'Color' ],
  'unit'          => SANE_UNIT_NONE,
  constraint_type => SANE_CONSTRAINT_STRING_LIST,
  type            => SANE_TYPE_STRING,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name       => 'resolution',
  title      => 'Resolution',
  index      => 4,
  'desc'     => 'Sets the horizontal resolution of the scanned image.',
  'val'      => '600',
  constraint => {
   'min'   => 100,
   'max'   => 600,
   'quant' => 1,
  },
  'unit'          => SANE_UNIT_DPI,
  constraint_type => SANE_CONSTRAINT_RANGE,
  type            => SANE_TYPE_INT,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name       => 'y-resolution',
  title      => 'Y resolution',
  index      => 5,
  'desc'     => 'Sets the vertical resolution of the scanned image.',
  'val'      => '600',
  constraint => {
   'min'   => 50,
   'max'   => 600,
   'quant' => 1,
  },
  'unit'          => SANE_UNIT_DPI,
  constraint_type => SANE_CONSTRAINT_RANGE,
  type            => SANE_TYPE_INT,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  index             => 6,
  title             => 'Geometry',
  'cap'             => 0,
  'max_values'      => 0,
  'name'            => '',
  'unit'            => SANE_UNIT_NONE,
  'desc'            => '',
  type              => SANE_TYPE_GROUP,
  'constraint_type' => SANE_CONSTRAINT_NONE
 },
 {
  name       => 'l',
  title      => 'Top-left x',
  index      => 7,
  'desc'     => 'Top-left x position of scan area.',
  'val'      => 0,
  constraint => {
   'min'   => 0,
   'max'   => 224.846,
   'quant' => 0.0211639,
  },
  'unit'          => SANE_UNIT_MM,
  constraint_type => SANE_CONSTRAINT_RANGE,
  type            => SANE_TYPE_FIXED,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name       => 't',
  title      => 'Top-left y',
  index      => 8,
  'desc'     => 'Top-left y position of scan area.',
  'val'      => 0,
  constraint => {
   'min'   => 0,
   'max'   => 863.489,
   'quant' => 0.0211639,
  },
  'unit'          => SANE_UNIT_MM,
  constraint_type => SANE_CONSTRAINT_RANGE,
  type            => SANE_TYPE_FIXED,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name       => 'x',
  title      => 'Width',
  index      => 9,
  'desc'     => 'Width of scan-area.',
  'val'      => 215.872,
  constraint => {
   'min'   => 0,
   'max'   => 224.846,
   'quant' => 0.0211639,
  },
  'unit'          => SANE_UNIT_MM,
  constraint_type => SANE_CONSTRAINT_RANGE,
  type            => SANE_TYPE_FIXED,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name       => 'y',
  title      => 'Height',
  index      => 10,
  'desc'     => 'Height of scan-area.',
  'val'      => 279.364,
  constraint => {
   'min'   => 0,
   'max'   => 863.489,
   'quant' => 0.0211639,
  },
  'unit'          => SANE_UNIT_MM,
  constraint_type => SANE_CONSTRAINT_RANGE,
  type            => SANE_TYPE_FIXED,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name       => 'pagewidth',
  title      => 'Pagewidth',
  index      => 11,
  'desc'     => 'Must be set properly to align scanning window',
  'val'      => '215.872',
  constraint => {
   'min'   => 0,
   'max'   => 224.846,
   'quant' => 0.0211639,
  },
  'unit'          => SANE_UNIT_MM,
  constraint_type => SANE_CONSTRAINT_RANGE,
  type            => SANE_TYPE_FIXED,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name       => 'pageheight',
  title      => 'Pageheight',
  index      => 12,
  'desc'     => 'Must be set properly to eject pages',
  'val'      => '279.364',
  constraint => {
   'min'   => 0,
   'max'   => 863.489,
   'quant' => 0.0211639,
  },
  'unit'          => SANE_UNIT_MM,
  constraint_type => SANE_CONSTRAINT_RANGE,
  type            => SANE_TYPE_FIXED,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  index             => 13,
  title             => 'Enhancement',
  'cap'             => 0,
  'max_values'      => 0,
  'name'            => '',
  'unit'            => SANE_UNIT_NONE,
  'desc'            => '',
  type              => SANE_TYPE_GROUP,
  'constraint_type' => SANE_CONSTRAINT_NONE
 },
 {
  name              => 'rif',
  title             => 'Rif',
  index             => 14,
  'desc'            => 'Reverse image format',
  'val'             => SANE_FALSE,
  'unit'            => SANE_UNIT_NONE,
  'type'            => SANE_TYPE_BOOL,
  'constraint_type' => SANE_CONSTRAINT_NONE,
  'cap'             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'      => 1,
 },
 {
  index             => 15,
  title             => 'Advanced',
  'cap'             => 0,
  'max_values'      => 0,
  'name'            => '',
  'unit'            => SANE_UNIT_NONE,
  'desc'            => '',
  type              => SANE_TYPE_GROUP,
  'constraint_type' => SANE_CONSTRAINT_NONE
 },
 {
  name  => 'dropoutcolor',
  title => 'Dropoutcolor',
  index => 16,
  'desc' =>
'One-pass scanners use only one color during gray or binary scanning, useful for colored paper or ink',
  'val'           => 'Default',
  'constraint'    => [ 'Default', 'Red', 'Green', 'Blue' ],
  'unit'          => SANE_UNIT_NONE,
  constraint_type => SANE_CONSTRAINT_STRING_LIST,
  type            => SANE_TYPE_STRING,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name  => 'sleeptimer',
  title => 'Sleeptimer',
  index => 17,
  'desc' =>
    'Time in minutes until the internal power supply switches to sleep mode',
  'val'      => '0',
  constraint => {
   'min'   => 0,
   'max'   => 60,
   'quant' => 1,
  },
  'unit'          => SANE_UNIT_NONE,
  constraint_type => SANE_CONSTRAINT_RANGE,
  type            => SANE_TYPE_INT,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  index             => 18,
  title             => 'Sensors and Buttons',
  'cap'             => 0,
  'max_values'      => 0,
  'name'            => '',
  'unit'            => SANE_UNIT_NONE,
  'desc'            => '',
  type              => SANE_TYPE_GROUP,
  'constraint_type' => SANE_CONSTRAINT_NONE
 },
);
is_deeply( $options->{array}, \@that, 'fujitsu' );

is( $options->num_options,                19,       'number of options' );
is( $options->by_index(2)->{name},        'source', 'by_index' );
is( $options->by_name('source')->{name},  'source', 'by_name' );
is( $options->by_title('Source')->{name}, 'source', 'by_title' );

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
 'supports_paper'
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
 'paper crosses top border'
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
 'paper crosses bottom border'
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
 'paper crosses left border'
);
is(
 $options->supports_paper(
  {
   x => 210,
   y => 297,
   l => 20,
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
   x => 225,
   y => 297,
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
   x => 210,
   y => 870,
   l => 0,
   t => 0,
  },
  0
 ),
 0,
 'paper too tall'
);

$options->delete_by_index(2);
is( $options->by_index(2),       undef, 'delete_by_index' );
is( $options->by_name('source'), undef, 'delete_by_index got hash too' );

$options->delete_by_name('mode');
is( $options->by_name('mode'), undef, 'delete_by_name' );
is( $options->by_index(3),     undef, 'delete_by_name got array too' );

$output = <<'END';
Options specific to device `fujitsu:libusb:002:004':
  Geometry:
    -l 0..224.846mm (in quants of 0.0211639) [0]
        Top-left x position of scan area.
    -t 0..863.489mm (in quants of 0.0211639) [0]
        Top-left y position of scan area.
    -x 0..204.846mm (in quants of 0.0211639) [215.872]
        Width of scan-area.
    -y 0..263.489mm (in quants of 0.0211639) [279.364]
        Height of scan-area.
    --page-width 0..224.846mm (in quants of 0.0211639) [215.872]
        Must be set properly to align scanning window
    --page-height 0..863.489mm (in quants of 0.0211639) [279.364]
        Must be set properly to eject pages
END
$options = Gscan2pdf::Scanner::Options->new_from_data($output);

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
   l => 20,
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
   x => 225,
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
is( Gscan2pdf::Scanner::Options->device,
 'fujitsu:libusb:002:004', 'device name' );
