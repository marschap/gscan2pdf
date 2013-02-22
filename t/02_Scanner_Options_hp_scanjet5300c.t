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

my $filename = 'scanners/hp_scanjet5300c';
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
  'constraint' =>
    [ 'Lineart', 'Dithered', 'Gray', '12bit Gray', 'Color', '12bit Color' ],
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'resolution',
  index      => 2,
  'desc'     => 'Sets the resolution of the scanned image.',
  'val'      => '150',
  constraint => {
   'min'  => 100,
   'max'  => 1200,
   'step' => 5,
  },
  'unit' => SANE_UNIT_DPI,
 },
 {
  name       => 'speed',
  index      => 3,
  'desc'     => 'Determines the speed at which the scan proceeds.',
  'val'      => '0',
  constraint => {
   'min'  => 0,
   'max'  => 4,
   'step' => 1,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name         => 'preview',
  index        => 4,
  'desc'       => 'Request a preview-quality scan.',
  'val'        => 'no',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'source',
  index        => 5,
  'desc'       => 'Selects the scan source (such as a document-feeder).',
  'val'        => 'Normal',
  'constraint' => [ 'Normal', 'ADF' ],
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
   'max' => 216,
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
   'max' => 296,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name       => 'x',
  index      => 9,
  'desc'     => 'Width of scan-area.',
  'val'      => 216,
  constraint => {
   'min' => 0,
   'max' => 216,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name       => 'y',
  index      => 10,
  'desc'     => 'Height of scan-area.',
  'val'      => 296,
  constraint => {
   'min' => 0,
   'max' => 296,
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
  name         => 'quality-scan',
  index        => 14,
  'desc'       => 'Turn on quality scanning (slower but better).',
  'val'        => 'yes',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'quality-cal',
  index        => 15,
  'desc'       => 'Do a quality white-calibration',
  'val'        => 'yes',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name  => 'gamma-table',
  index => 16,
  'desc' =>
'Gamma-correction table.  In color mode this option equally affects the red, green, and blue channels simultaneously (i.e., it is an intensity gamma table).',
  constraint => {
   'min' => 0,
   'max' => 255,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'red-gamma-table',
  index      => 17,
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
  index      => 18,
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
  index      => 19,
  'desc'     => 'Gamma-correction table for the blue band.',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 255,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'frame',
  index      => 20,
  'desc'     => 'Selects the number of the frame to scan',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name  => 'power-save-time',
  index => 21,
  'desc' =>
'Allows control of the scanner\'s power save timer, dimming or turning off the light.',
  'val'        => '65535',
  'constraint' => ['<int>'],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name  => 'nvram-values',
  index => 22,
  'desc' =>
'Allows access obtaining the scanner\'s NVRAM values as pretty printed text.',
  'val' =>
"Vendor: HP      \nModel: ScanJet 5300C   \nFirmware: 4.00\nSerial: 3119ME\nManufacturing date: 0-0-0\nFirst scan date: 65535-0-0\nFlatbed scans: 65547\nPad scans: -65536\nADF simplex scans: 136183808",
  'constraint' => '<string>',
  'unit'       => SANE_UNIT_NONE,
 },
);
is_deeply( $options->{array}, \@that, 'hp_scanjet5300c' );
