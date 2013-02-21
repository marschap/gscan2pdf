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

my $filename = 'scanners/epson_3490';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new_from_data($output);
my @that     = (
 {
  index => 0,
  title => 'Scan Mode',
 },
 {
  name      => 'resolution',
  index     => 1,
  'tip'     => 'Sets the resolution of the scanned image.',
  'default' => '300',
  'values'  => [
   'auto', '50',  '150', '200', '240', '266',  '300',  '350',
   '360',  '400', '600', '720', '800', '1200', '1600', '3200'
  ],
  'unit' => 'dpi',
 },
 {
  name      => 'preview',
  index     => 2,
  'tip'     => 'Request a preview-quality scan.',
  'default' => 'no',
  'values'  => [ 'auto', 'yes', 'no' ]
 },
 {
  name      => 'mode',
  index     => 3,
  'tip'     => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
  'default' => 'Color',
  'values'  => [ 'auto', 'Color', 'Gray', 'Lineart' ]
 },
 {
  name  => 'preview-mode',
  index => 4,
  'tip' =>
'Select the mode for previews. Greyscale previews usually give the best combination of speed and detail.',
  'default' => 'Auto',
  'values'  => [ 'auto', 'Auto', 'Color', 'Gray', 'Lineart' ]
 },
 {
  name      => 'high-quality',
  index     => 5,
  'tip'     => 'Highest quality but lower speed',
  'default' => 'no',
  'values'  => [ 'auto', 'yes', 'no' ]
 },
 {
  name      => 'source',
  index     => 6,
  'tip'     => 'Selects the scan source (such as a document-feeder).',
  'default' => 'Flatbed',
  'values'  => [ 'auto', 'Flatbed', 'Transparency Adapter' ]
 },
 {
  index => 7,
  title => 'Geometry',
 },
 {
  name       => 'l',
  index      => 8,
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
  index      => 9,
  'tip'      => 'Top-left y position of scan area.',
  'default'  => 0,
  constraint => {
   'min' => 0,
   'max' => 297,
  },
  'unit' => 'mm',
 },
 {
  name       => 'x',
  index      => 10,
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
  index      => 11,
  'tip'      => 'Height of scan-area.',
  'default'  => 297,
  constraint => {
   'min' => 0,
   'max' => 297,
  },
  'unit' => 'mm',
 },
 {
  name  => 'predef-window',
  index => 12,
  'tip' =>
'Provides standard scanning areas for photographs, printed pages and the like.',
  'default' => 'None',
  'values'  => [ 'None', '6x4 (inch)', '8x10 (inch)', '8.5x11 (inch)' ]
 },
 {
  index => 13,
  title => 'Enhancement',
 },
 {
  name  => 'depth',
  index => 14,
  'tip' =>
'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
  'default' => '8',
  'values'  => [ '8', '16' ],
  'unit'    => 'bit',
 },
 {
  name      => 'quality-cal',
  index     => 15,
  'tip'     => 'Do a quality white-calibration',
  'default' => 'yes',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name  => 'halftoning',
  index => 16,
  'tip' => 'Selects whether the acquired image should be halftoned (dithered).',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name  => 'halftone-pattern',
  index => 17,
  'tip' =>
    'Defines the halftoning (dithering) pattern for scanning halftoned images.',
  'default' => 'inactive',
  'values'  => [ 'DispersedDot8x8', 'DispersedDot16x16' ]
 },
 {
  name  => 'custom-gamma',
  index => 18,
  'tip' =>
    'Determines whether a builtin or a custom gamma-table should be used.',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'analog-gamma-bind',
  index     => 19,
  'tip'     => 'In RGB-mode use same values for each color',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name       => 'analog-gamma',
  index      => 20,
  'tip'      => 'Analog gamma-correction',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 4,
  },
 },
 {
  name       => 'analog-gamma-r',
  index      => 21,
  'tip'      => 'Analog gamma-correction for red',
  'default'  => '1.79999',
  constraint => {
   'min' => 0,
   'max' => 4,
  },
 },
 {
  name       => 'analog-gamma-g',
  index      => 22,
  'tip'      => 'Analog gamma-correction for green',
  'default'  => '1.79999',
  constraint => {
   'min' => 0,
   'max' => 4,
  },
 },
 {
  name       => 'analog-gamma-b',
  index      => 23,
  'tip'      => 'Analog gamma-correction for blue',
  'default'  => '1.79999',
  constraint => {
   'min' => 0,
   'max' => 4,
  },
 },
 {
  name  => 'gamma-table',
  index => 24,
  'tip' =>
'Gamma-correction table.  In color mode this option equally affects the red, green, and blue channels simultaneously (i.e., it is an intensity gamma table).',
  'default'  => 'inactive',
  constraint => {
   'min'  => 0,
   'max'  => 65535,
   'step' => 1,
  },
 },
 {
  name       => 'red-gamma-table',
  index      => 25,
  'tip'      => 'Gamma-correction table for the red band.',
  'default'  => 'inactive',
  constraint => {
   'min'  => 0,
   'max'  => 65535,
   'step' => 1,
  },
 },
 {
  name       => 'green-gamma-table',
  index      => 26,
  'tip'      => 'Gamma-correction table for the green band.',
  'default'  => 'inactive',
  constraint => {
   'min'  => 0,
   'max'  => 65535,
   'step' => 1,
  },
 },
 {
  name       => 'blue-gamma-table',
  index      => 27,
  'tip'      => 'Gamma-correction table for the blue band.',
  'default'  => 'inactive',
  constraint => {
   'min'  => 0,
   'max'  => 65535,
   'step' => 1,
  },
 },
 {
  name      => 'negative',
  index     => 28,
  'tip'     => 'Swap black and white',
  'default' => 'inactive',
  'values'  => [ 'auto', 'yes', 'no' ]
 },
 {
  name       => 'threshold',
  index      => 29,
  'tip'      => 'Select minimum-brightness to get a white point',
  'default'  => 'inactive',
  constraint => {
   'min'  => 0,
   'max'  => 100,
   'step' => 1,
  },
  'unit' => '%',
 },
 {
  name       => 'brightness',
  index      => 30,
  'tip'      => 'Controls the brightness of the acquired image.',
  'default'  => '0',
  constraint => {
   'min'  => -400,
   'max'  => 400,
   'step' => 1,
  },
  'unit' => '%',
 },
 {
  name       => 'contrast',
  index      => 31,
  'tip'      => 'Controls the contrast of the acquired image.',
  'default'  => '0',
  constraint => {
   'min'  => -100,
   'max'  => 400,
   'step' => 1,
  },
  'unit' => '%',
 },
 {
  index => 32,
  title => 'Advanced',
 },
 {
  name  => 'rgb-lpr',
  index => 33,
  'tip' =>
'Number of scan lines to request in a SCSI read. Changing this parameter allows you to tune the speed at which data is read from the scanner during scans. If this is set too low, the scanner will have to stop periodically in the middle of a scan; if it\'s set too high, X-based frontends may stop responding to X events and your system could bog down.',
  'default'  => '4',
  constraint => {
   'step' => 1,
   'min'  => 1,
   'max'  => 50,
  },
 },
 {
  name  => 'gs-lpr',
  index => 34,
  'tip' =>
'Number of scan lines to request in a SCSI read. Changing this parameter allows you to tune the speed at which data is read from the scanner during scans. If this is set too low, the scanner will have to stop periodically in the middle of a scan; if it\'s set too high, X-based frontends may stop responding to X events and your system could bog down.',
  'default'  => 'inactive',
  constraint => {
   'step' => 1,
   'min'  => 1,
   'max'  => 50,
  },
 },
);
is_deeply( $options->{array}, \@that, 'epson_3490' );
