# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Test::More tests => 2;
BEGIN { use_ok('Gscan2pdf::Scanner::Options') }

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $filename = 'scanners/hp_scanjet5300c';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new_from_data($output);
my @that     = (
 {
  index => 0,
  title => 'Scan mode',
 },
 {
  name      => 'mode',
  index     => 1,
  'tip'     => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
  'default' => 'Color',
  'values' =>
    [ 'Lineart', 'Dithered', 'Gray', '12bit Gray', 'Color', '12bit Color' ]
 },
 {
  name       => 'resolution',
  index      => 2,
  'tip'      => 'Sets the resolution of the scanned image.',
  'default'  => '150',
  constraint => {
   'min'  => 100,
   'max'  => 1200,
   'step' => 5,
  },
  'unit' => 'dpi',
 },
 {
  name       => 'speed',
  index      => 3,
  'tip'      => 'Determines the speed at which the scan proceeds.',
  'default'  => '0',
  constraint => {
   'min'  => 0,
   'max'  => 4,
   'step' => 1,
  },
 },
 {
  name      => 'preview',
  index     => 4,
  'tip'     => 'Request a preview-quality scan.',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'source',
  index     => 5,
  'tip'     => 'Selects the scan source (such as a document-feeder).',
  'default' => 'Normal',
  'values'  => [ 'Normal', 'ADF' ]
 },
 {
  index => 6,
  title => 'Geometry',
 },
 {
  name       => 'l',
  index      => 7,
  'tip'      => 'Top-left x position of scan area.',
  'default'  => 0,
  constraint => {
   'min' => 0,
   'max' => 216,
  },
  'unit' => 'mm',
 },
 {
  name       => 't',
  index      => 8,
  'tip'      => 'Top-left y position of scan area.',
  'default'  => 0,
  constraint => {
   'min' => 0,
   'max' => 296,
  },
  'unit' => 'mm',
 },
 {
  name       => 'x',
  index      => 9,
  'tip'      => 'Width of scan-area.',
  'default'  => 216,
  constraint => {
   'min' => 0,
   'max' => 216,
  },
  'unit' => 'mm',
 },
 {
  name       => 'y',
  index      => 10,
  'tip'      => 'Height of scan-area.',
  'default'  => 296,
  constraint => {
   'min' => 0,
   'max' => 296,
  },
  'unit' => 'mm',
 },
 {
  index => 11,
  title => 'Enhancement',
 },
 {
  name       => 'brightness',
  index      => 12,
  'tip'      => 'Controls the brightness of the acquired image.',
  'default'  => '0',
  constraint => {
   'min'  => -100,
   'max'  => 100,
   'step' => 1,
  },
  'unit' => '%',
 },
 {
  name       => 'contrast',
  index      => 13,
  'tip'      => 'Controls the contrast of the acquired image.',
  'default'  => '0',
  constraint => {
   'min'  => -100,
   'max'  => 100,
   'step' => 1,
  },
  'unit' => '%',
 },
 {
  name      => 'quality-scan',
  index     => 14,
  'tip'     => 'Turn on quality scanning (slower but better).',
  'default' => 'yes',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'quality-cal',
  index     => 15,
  'tip'     => 'Do a quality white-calibration',
  'default' => 'yes',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name  => 'gamma-table',
  index => 16,
  'tip' =>
'Gamma-correction table.  In color mode this option equally affects the red, green, and blue channels simultaneously (i.e., it is an intensity gamma table).',
  constraint => {
   'min' => 0,
   'max' => 255,
  },
 },
 {
  name       => 'red-gamma-table',
  index      => 17,
  'tip'      => 'Gamma-correction table for the red band.',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 255,
  },
 },
 {
  name       => 'green-gamma-table',
  index      => 18,
  'tip'      => 'Gamma-correction table for the green band.',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 255,
  },
 },
 {
  name       => 'blue-gamma-table',
  index      => 19,
  'tip'      => 'Gamma-correction table for the blue band.',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 255,
  },
 },
 {
  name       => 'frame',
  index      => 20,
  'tip'      => 'Selects the number of the frame to scan',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
 },
 {
  name  => 'power-save-time',
  index => 21,
  'tip' =>
'Allows control of the scanner\'s power save timer, dimming or turning off the light.',
  'default' => '65535',
  'values'  => ['<int>']
 },
 {
  name  => 'nvram-values',
  index => 22,
  'tip' =>
'Allows access obtaining the scanner\'s NVRAM values as pretty printed text.',
  'default' =>
"Vendor: HP      \nModel: ScanJet 5300C   \nFirmware: 4.00\nSerial: 3119ME\nManufacturing date: 0-0-0\nFirst scan date: 65535-0-0\nFlatbed scans: 65547\nPad scans: -65536\nADF simplex scans: 136183808",
  'values' => '<string>'
 },
);
is_deeply( $options->{array}, \@that, 'hp_scanjet5300c' );
