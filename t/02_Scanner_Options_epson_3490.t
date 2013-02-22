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

my $filename = 'scanners/epson_3490';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new_from_data($output);
my @that     = (
 {
  index => 0,
  title => 'Scan Mode',
 },
 {
  name         => 'resolution',
  index        => 1,
  'desc'       => 'Sets the resolution of the scanned image.',
  'val'        => '300',
  'constraint' => [
   'auto', '50',  '150', '200', '240', '266',  '300',  '350',
   '360',  '400', '600', '720', '800', '1200', '1600', '3200'
  ],
  'unit' => SANE_UNIT_DPI,
 },
 {
  name         => 'preview',
  index        => 2,
  'desc'       => 'Request a preview-quality scan.',
  'val'        => 'no',
  'constraint' => [ 'auto', 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name   => 'mode',
  index  => 3,
  'desc' => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
  'val'  => 'Color',
  'constraint' => [ 'auto', 'Color', 'Gray', 'Lineart' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name  => 'preview-mode',
  index => 4,
  'desc' =>
'Select the mode for previews. Greyscale previews usually give the best combination of speed and detail.',
  'val'        => 'Auto',
  'constraint' => [ 'auto', 'Auto', 'Color', 'Gray', 'Lineart' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'high-quality',
  index        => 5,
  'desc'       => 'Highest quality but lower speed',
  'val'        => 'no',
  'constraint' => [ 'auto', 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'source',
  index        => 6,
  'desc'       => 'Selects the scan source (such as a document-feeder).',
  'val'        => 'Flatbed',
  'constraint' => [ 'auto', 'Flatbed', 'Transparency Adapter' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  index => 7,
  title => 'Geometry',
 },
 {
  name       => 'l',
  index      => 8,
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
  index      => 9,
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
  index      => 10,
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
  index      => 11,
  'desc'     => 'Height of scan-area.',
  'val'      => 297,
  constraint => {
   'min' => 0,
   'max' => 297,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name  => 'predef-window',
  index => 12,
  'desc' =>
'Provides standard scanning areas for photographs, printed pages and the like.',
  'val'        => 'None',
  'constraint' => [ 'None', '6x4 (inch)', '8x10 (inch)', '8.5x11 (inch)' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  index => 13,
  title => 'Enhancement',
 },
 {
  name  => 'depth',
  index => 14,
  'desc' =>
'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
  'val'        => '8',
  'constraint' => [ '8', '16' ],
  'unit'       => SANE_UNIT_BIT,
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
  name  => 'halftoning',
  index => 16,
  'desc' =>
    'Selects whether the acquired image should be halftoned (dithered).',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name  => 'halftone-pattern',
  index => 17,
  'desc' =>
    'Defines the halftoning (dithering) pattern for scanning halftoned images.',
  'val'        => 'inactive',
  'constraint' => [ 'DispersedDot8x8', 'DispersedDot16x16' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name  => 'custom-gamma',
  index => 18,
  'desc' =>
    'Determines whether a builtin or a custom gamma-table should be used.',
  'val'        => 'no',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'analog-gamma-bind',
  index        => 19,
  'desc'       => 'In RGB-mode use same values for each color',
  'val'        => 'no',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name       => 'analog-gamma',
  index      => 20,
  'desc'     => 'Analog gamma-correction',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 4,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'analog-gamma-r',
  index      => 21,
  'desc'     => 'Analog gamma-correction for red',
  'val'      => '1.79999',
  constraint => {
   'min' => 0,
   'max' => 4,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'analog-gamma-g',
  index      => 22,
  'desc'     => 'Analog gamma-correction for green',
  'val'      => '1.79999',
  constraint => {
   'min' => 0,
   'max' => 4,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'analog-gamma-b',
  index      => 23,
  'desc'     => 'Analog gamma-correction for blue',
  'val'      => '1.79999',
  constraint => {
   'min' => 0,
   'max' => 4,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name  => 'gamma-table',
  index => 24,
  'desc' =>
'Gamma-correction table.  In color mode this option equally affects the red, green, and blue channels simultaneously (i.e., it is an intensity gamma table).',
  'val'      => 'inactive',
  constraint => {
   'min'  => 0,
   'max'  => 65535,
   'step' => 1,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'red-gamma-table',
  index      => 25,
  'desc'     => 'Gamma-correction table for the red band.',
  'val'      => 'inactive',
  constraint => {
   'min'  => 0,
   'max'  => 65535,
   'step' => 1,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'green-gamma-table',
  index      => 26,
  'desc'     => 'Gamma-correction table for the green band.',
  'val'      => 'inactive',
  constraint => {
   'min'  => 0,
   'max'  => 65535,
   'step' => 1,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'blue-gamma-table',
  index      => 27,
  'desc'     => 'Gamma-correction table for the blue band.',
  'val'      => 'inactive',
  constraint => {
   'min'  => 0,
   'max'  => 65535,
   'step' => 1,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name         => 'negative',
  index        => 28,
  'desc'       => 'Swap black and white',
  'val'        => 'inactive',
  'constraint' => [ 'auto', 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name       => 'threshold',
  index      => 29,
  'desc'     => 'Select minimum-brightness to get a white point',
  'val'      => 'inactive',
  constraint => {
   'min'  => 0,
   'max'  => 100,
   'step' => 1,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name       => 'brightness',
  index      => 30,
  'desc'     => 'Controls the brightness of the acquired image.',
  'val'      => '0',
  constraint => {
   'min'  => -400,
   'max'  => 400,
   'step' => 1,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name       => 'contrast',
  index      => 31,
  'desc'     => 'Controls the contrast of the acquired image.',
  'val'      => '0',
  constraint => {
   'min'  => -100,
   'max'  => 400,
   'step' => 1,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  index => 32,
  title => 'Advanced',
 },
 {
  name  => 'rgb-lpr',
  index => 33,
  'desc' =>
'Number of scan lines to request in a SCSI read. Changing this parameter allows you to tune the speed at which data is read from the scanner during scans. If this is set too low, the scanner will have to stop periodically in the middle of a scan; if it\'s set too high, X-based frontends may stop responding to X events and your system could bog down.',
  'val'      => '4',
  constraint => {
   'step' => 1,
   'min'  => 1,
   'max'  => 50,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name  => 'gs-lpr',
  index => 34,
  'desc' =>
'Number of scan lines to request in a SCSI read. Changing this parameter allows you to tune the speed at which data is read from the scanner during scans. If this is set too low, the scanner will have to stop periodically in the middle of a scan; if it\'s set too high, X-based frontends may stop responding to X events and your system could bog down.',
  'val'      => 'inactive',
  constraint => {
   'step' => 1,
   'min'  => 1,
   'max'  => 50,
  },
  'unit' => SANE_UNIT_NONE,
 },
);
is_deeply( $options->{array}, \@that, 'epson_3490' );
