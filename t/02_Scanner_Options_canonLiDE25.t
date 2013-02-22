# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Test::More tests => 2;
use Sane 0.05;    # For enums
BEGIN { use_ok('Gscan2pdf::Scanner::Options') }

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $filename = 'scanners/canonLiDE25';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new_from_data($output);
my @that     = (
 {
  index => 0,
  title => 'Scan Mode',
 },
 {
  name   => 'mode',
  index  => 1,
  'desc' => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
  'val'  => 'Color',
  'constraint' => [ 'Lineart', 'Gray', 'Color' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name  => 'depth',
  index => 2,
  'desc' =>
'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
  'val'        => '8',
  'constraint' => [ '8', '16' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'source',
  index        => 3,
  'desc'       => 'Selects the scan source (such as a document-feeder).',
  'val'        => 'inactive',
  'constraint' => [ 'Normal', 'Transparency', 'Negative' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name       => 'resolution',
  index      => 4,
  'desc'     => 'Sets the resolution of the scanned image.',
  'val'      => '50',
  constraint => {
   'min' => 50,
   'max' => 2400,
  },
  'unit' => SANE_UNIT_DPI,
 },
 {
  name         => 'preview',
  index        => 5,
  'desc'       => 'Request a preview-quality scan.',
  'val'        => 'no',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  index => 6,
  title => 'Geometry',
 },
 {
  name       => 'l',
  index      => 7,
  'desc'     => 'Top-left x position of scan area.',
  'val'      => 0,
  constraint => {
   'min' => 0,
   'max' => 215,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name       => 't',
  index      => 8,
  'desc'     => 'Top-left y position of scan area.',
  'val'      => 0,
  constraint => {
   'min' => 0,
   'max' => 297,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name       => 'x',
  index      => 9,
  'desc'     => 'Width of scan-area.',
  'val'      => 103,
  constraint => {
   'min' => 0,
   'max' => 215,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name       => 'y',
  index      => 10,
  'desc'     => 'Height of scan-area.',
  'val'      => 76.21,
  constraint => {
   'min' => 0,
   'max' => 297,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  index => 11,
  title => 'Enhancement',
 },
 {
  name       => 'brightness',
  index      => 12,
  'desc'     => 'Controls the brightness of the acquired image.',
  'val'      => '0',
  constraint => {
   'min'  => -100,
   'max'  => 100,
   'step' => 1,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name       => 'contrast',
  index      => 13,
  'desc'     => 'Controls the contrast of the acquired image.',
  'val'      => '0',
  constraint => {
   'min'  => -100,
   'max'  => 100,
   'step' => 1,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name  => 'custom-gamma',
  index => 14,
  'desc' =>
    'Determines whether a builtin or a custom gamma-table should be used.',
  'val'        => 'no',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name  => 'gamma-table',
  index => 15,
  'desc' =>
'Gamma-correction table.  In color mode this option equally affects the red, green, and blue channels simultaneously (i.e., it is an intensity gamma table).',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 255,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'red-gamma-table',
  index      => 16,
  'desc'     => 'Gamma-correction table for the red band.',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 255,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'green-gamma-table',
  index      => 17,
  'desc'     => 'Gamma-correction table for the green band.',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 255,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'blue-gamma-table',
  index      => 18,
  'desc'     => 'Gamma-correction table for the blue band.',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 255,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  index => 19,
  title => 'Device-Settings',
 },
 {
  name         => 'lamp-switch',
  index        => 20,
  'desc'       => 'Manually switching the lamp(s).',
  'val'        => 'no',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name       => 'lampoff-time',
  index      => 21,
  'desc'     => 'Lampoff-time in seconds.',
  'val'      => '300',
  constraint => {
   'min'  => 0,
   'max'  => 999,
   'step' => 1,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name         => 'lamp-off-at-exit',
  index        => 22,
  'desc'       => 'Turn off lamp when program exits',
  'val'        => 'yes',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name       => 'warmup-time',
  index      => 23,
  'desc'     => 'Warmup-time in seconds.',
  'val'      => 'inactive',
  constraint => {
   'min'  => -1,
   'max'  => 999,
   'step' => 1,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name         => 'calibration-cache',
  index        => 24,
  'desc'       => 'Enables or disables calibration data cache.',
  'val'        => 'no',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'speedup-switch',
  index        => 25,
  'desc'       => 'Enables or disables speeding up sensor movement.',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name   => 'calibrate',
  index  => 26,
  'desc' => 'Performs calibration',
  'val'  => 'inactive',
  'unit' => SANE_UNIT_NONE,
 },
 {
  index => 27,
  title => 'Analog frontend',
 },
 {
  name       => 'red-gain',
  index      => 28,
  'desc'     => 'Red gain value of the AFE',
  'val'      => '-1',
  constraint => {
   'min'  => -1,
   'max'  => 63,
   'step' => 1,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'green-gain',
  index      => 29,
  'desc'     => 'Green gain value of the AFE',
  'val'      => '-1',
  constraint => {
   'min'  => -1,
   'max'  => 63,
   'step' => 1,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'blue-gain',
  index      => 30,
  'desc'     => 'Blue gain value of the AFE',
  'val'      => '-1',
  constraint => {
   'min'  => -1,
   'max'  => 63,
   'step' => 1,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'red-offset',
  index      => 31,
  'desc'     => 'Red offset value of the AFE',
  'val'      => '-1',
  constraint => {
   'min'  => -1,
   'max'  => 63,
   'step' => 1,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'green-offset',
  index      => 32,
  'desc'     => 'Green offset value of the AFE',
  'val'      => '-1',
  constraint => {
   'min'  => -1,
   'max'  => 63,
   'step' => 1,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'blue-offset',
  index      => 33,
  'desc'     => 'Blue offset value of the AFE',
  'val'      => '-1',
  constraint => {
   'min'  => -1,
   'max'  => 63,
   'step' => 1,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'redlamp-off',
  index      => 34,
  'desc'     => 'Defines red lamp off parameter',
  'val'      => '-1',
  constraint => {
   'min'  => -1,
   'max'  => 16363,
   'step' => 1,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'greenlamp-off',
  index      => 35,
  'desc'     => 'Defines green lamp off parameter',
  'val'      => '-1',
  constraint => {
   'min'  => -1,
   'max'  => 16363,
   'step' => 1,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'bluelamp-off',
  index      => 36,
  'desc'     => 'Defines blue lamp off parameter',
  'val'      => '-1',
  constraint => {
   'min'  => -1,
   'max'  => 16363,
   'step' => 1,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  index => 37,
  title => 'Buttons',
 },
);
is_deeply( $options->{array}, \@that, 'canonLiDE25' );
