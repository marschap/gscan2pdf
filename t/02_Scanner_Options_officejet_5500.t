# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Test::More tests => 9;
use Sane 0.05;    # For enums
BEGIN { use_ok('Gscan2pdf::Scanner::Options') }

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $filename = 'scanners/officejet_5500';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new_from_data($output);
my @that     = (
 {
  index => 0,
  title => 'Scan mode',
 },
 {
  name   => 'mode',
  index  => 1,
  'desc' => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
  'val'  => 'Color',
  'constraint' => [ 'Lineart', 'Grayscale', 'Color' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name       => 'resolution',
  index      => 2,
  'desc'     => 'Sets the resolution of the scanned image.',
  'val'      => '75',
  constraint => {
   'min' => 75,
   'max' => 600,
  },
  'unit' => SANE_UNIT_DPI,
 },
 {
  index => 3,
  title => 'Advanced',
 },
 {
  name       => 'contrast',
  index      => 4,
  'desc'     => 'Controls the contrast of the acquired image.',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name  => 'compression',
  index => 5,
  'desc' =>
'Selects the scanner compression method for faster scans, possibly at the expense of image quality.',
  'val'        => 'JPEG',
  'constraint' => [ 'None', 'JPEG' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name  => 'jpeg-compression-factor',
  index => 6,
  'desc' =>
'Sets the scanner JPEG compression factor.  Larger numbers mean better compression, and smaller numbers mean better image quality.',
  'val'      => '10',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name  => 'batch-scan',
  index => 7,
  'desc' =>
'Guarantees that a "no documents" condition will be returned after the last scanned page, to prevent endless flatbed scans after a batch scan. For some models, option changes in the middle of a batch scan don\'t take effect until after the last page.',
  'val'        => 'no',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name  => 'source',
  index => 8,
  'desc' =>
'Selects the desired scan source for models with both flatbed and automatic document feeder (ADF) capabilities.  The "Auto" setting means that the ADF will be used if it\'s loaded, and the flatbed (if present) will be used otherwise.',
  'val'        => 'Auto',
  'constraint' => [ 'Auto', 'Flatbed', 'ADF' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name  => 'duplex',
  index => 9,
  'desc' =>
'Enables scanning on both sides of the page for models with duplex-capable document feeders.  For pages printed in "book"-style duplex mode, one side will be scanned upside-down.  This feature is experimental.',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  index => 10,
  title => 'Geometry',
 },
 {
  name  => 'length-measurement',
  index => 11,
  'desc' =>
'Selects how the scanned image length is measured and reported, which is impossible to know in advance for scrollfed scans.',
  'val'        => 'Padded',
  'constraint' => [ 'Unknown', 'Approximate', 'Padded' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name       => 'l',
  index      => 12,
  'desc'     => 'Top-left x position of scan area.',
  'val'      => 0,
  constraint => {
   'min' => 0,
   'max' => 215.9,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name       => 't',
  index      => 13,
  'desc'     => 'Top-left y position of scan area.',
  'val'      => 0,
  constraint => {
   'min' => 0,
   'max' => 381,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name       => 'x',
  index      => 14,
  'desc'     => 'Width of scan-area.',
  'val'      => 215.9,
  constraint => {
   'min' => 0,
   'max' => 215.9,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name       => 'y',
  index      => 15,
  'desc'     => 'Height of scan-area.',
  'val'      => 381,
  constraint => {
   'min' => 0,
   'max' => 381,
  },
  'unit' => SANE_UNIT_MM,
 }
);
is_deeply( $options->{array}, \@that, 'officejet_5500' );

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
   t => 90,
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
   l => 10,
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
