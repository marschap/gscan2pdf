# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Test::More tests => 23;
BEGIN { use_ok('Gscan2pdf::Scanner::Options') }

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $filename = 'scanners/fujitsu';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new_from_data($output);
my @that     = (
 {
  index => 0,
  title => 'Scan Mode',
 },
 {
  name      => 'source',
  index     => 1,
  'tip'     => 'Selects the scan source (such as a document-feeder).',
  'default' => 'ADF Front',
  'values'  => [ 'ADF Front', 'ADF Back', 'ADF Duplex' ]
 },
 {
  name      => 'mode',
  index     => 2,
  'tip'     => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
  'default' => 'Gray',
  'values'  => [ 'Gray', 'Color' ]
 },
 {
  name       => 'resolution',
  index      => 3,
  'tip'      => 'Sets the horizontal resolution of the scanned image.',
  'default'  => '600',
  constraint => {
   'min'  => 100,
   'max'  => 600,
   'step' => 1,
  },
  'unit' => 'dpi',
 },
 {
  name       => 'y-resolution',
  index      => 4,
  'tip'      => 'Sets the vertical resolution of the scanned image.',
  'default'  => '600',
  constraint => {
   'min'  => 50,
   'max'  => 600,
   'step' => 1,
  },
  'unit' => 'dpi',
 },
 {
  index => 5,
  title => 'Geometry',
 },
 {
  name       => 'l',
  index      => 6,
  'tip'      => 'Top-left x position of scan area.',
  'default'  => 0,
  constraint => {
   'min'  => 0,
   'max'  => 224.846,
   'step' => 0.0211639,
  },
  'unit' => 'mm',
 },
 {
  name       => 't',
  index      => 7,
  'tip'      => 'Top-left y position of scan area.',
  'default'  => 0,
  constraint => {
   'min'  => 0,
   'max'  => 863.489,
   'step' => 0.0211639,
  },
  'unit' => 'mm',
 },
 {
  name       => 'x',
  index      => 8,
  'tip'      => 'Width of scan-area.',
  'default'  => 215.872,
  constraint => {
   'min'  => 0,
   'max'  => 224.846,
   'step' => 0.0211639,
  },
  'unit' => 'mm',
 },
 {
  name       => 'y',
  index      => 9,
  'tip'      => 'Height of scan-area.',
  'default'  => 279.364,
  constraint => {
   'min'  => 0,
   'max'  => 863.489,
   'step' => 0.0211639,
  },
  'unit' => 'mm',
 },
 {
  name       => 'pagewidth',
  index      => 10,
  'tip'      => 'Must be set properly to align scanning window',
  'default'  => '215.872',
  constraint => {
   'min'  => 0,
   'max'  => 224.846,
   'step' => 0.0211639,
  },
  'unit' => 'mm',
 },
 {
  name       => 'pageheight',
  index      => 11,
  'tip'      => 'Must be set properly to eject pages',
  'default'  => '279.364',
  constraint => {
   'min'  => 0,
   'max'  => 863.489,
   'step' => 0.0211639,
  },
  'unit' => 'mm',
 },
 {
  index => 12,
  title => 'Enhancement',
 },
 {
  name      => 'rif',
  index     => 13,
  'tip'     => 'Reverse image format',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  index => 14,
  title => 'Advanced',
 },
 {
  name  => 'dropoutcolor',
  index => 15,
  'tip' =>
'One-pass scanners use only one color during gray or binary scanning, useful for colored paper or ink',
  'default' => 'Default',
  'values'  => [ 'Default', 'Red', 'Green', 'Blue' ]
 },
 {
  name  => 'sleeptimer',
  index => 16,
  'tip' =>
    'Time in minutes until the internal power supply switches to sleep mode',
  'default'  => '0',
  constraint => {
   'min'  => 0,
   'max'  => 60,
   'step' => 1,
  },
 },
 {
  index => 17,
  title => 'Sensors and Buttons',
 },
);
is_deeply( $options->{array}, \@that, 'fujitsu' );

is( $options->num_options,               18,       'number of options' );
is( $options->by_index(1)->{name},       'source', 'by_index' );
is( $options->by_name('source')->{name}, 'source', 'by_name' );

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

$options->delete_by_index(1);
is( $options->by_index(1),       undef, 'delete_by_index' );
is( $options->by_name('source'), undef, 'delete_by_index got hash too' );

$options->delete_by_name('mode');
is( $options->by_name('mode'), undef, 'delete_by_name' );
is( $options->by_index(2),     undef, 'delete_by_name got array too' );

$output = <<'END';
Options specific to device `fujitsu:libusb:002:004':
  Geometry:
    -l 0..224.846mm (in steps of 0.0211639) [0]
        Top-left x position of scan area.
    -t 0..863.489mm (in steps of 0.0211639) [0]
        Top-left y position of scan area.
    -x 0..204.846mm (in steps of 0.0211639) [215.872]
        Width of scan-area.
    -y 0..263.489mm (in steps of 0.0211639) [279.364]
        Height of scan-area.
    --page-width 0..224.846mm (in steps of 0.0211639) [215.872]
        Must be set properly to align scanning window
    --page-height 0..863.489mm (in steps of 0.0211639) [279.364]
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
