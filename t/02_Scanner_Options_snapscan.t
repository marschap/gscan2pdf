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

my $filename = 'scanners/snapscan';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new($output);
my @that     = (
 {
  name      => 'resolution',
  index     => 0,
  'tip'     => 'Sets the resolution of the scanned image.',
  'default' => '300',
  'values'  => [ 'auto', '50', '75', '100', '150', '200', '300', '450', '600' ],
  'unit'    => 'dpi',
 },
 {
  name      => 'preview',
  index     => 1,
  'tip'     => 'Request a preview-quality scan.',
  'default' => 'no',
  'values'  => [ 'auto', 'yes', 'no' ]
 },
 {
  name      => 'mode',
  index     => 2,
  'tip'     => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
  'default' => 'Color',
  'values'  => [ 'auto', 'Color', 'Halftone', 'Gray', 'Lineart' ]
 },
 {
  name  => 'preview-mode',
  index => 3,
  'tip' =>
'Select the mode for previews. Greyscale previews usually give the best combination of speed and detail.',
  'default' => 'Auto',
  'values'  => [ 'auto', 'Auto', 'Color', 'Halftone', 'Gray', 'Lineart' ]
 },
 {
  name      => 'high-quality',
  index     => 4,
  'tip'     => 'Highest quality but lower speed',
  'default' => 'no',
  'values'  => [ 'auto', 'yes', 'no' ]
 },
 {
  name      => 'source',
  index     => 5,
  'tip'     => 'Selects the scan source (such as a document-feeder).',
  'default' => 'inactive',
  'values'  => [ 'auto', 'Flatbed' ]
 },
 {
  name      => 'l',
  index     => 6,
  'tip'     => 'Top-left x position of scan area.',
  'default' => 0,
  'min'     => 0,
  'max'     => 216,
  'unit'    => 'mm',
 },
 {
  name      => 't',
  index     => 7,
  'tip'     => 'Top-left y position of scan area.',
  'default' => 0,
  'min'     => 0,
  'max'     => 297,
  'unit'    => 'mm',
 },
 {
  name      => 'x',
  index     => 8,
  'tip'     => 'Width of scan-area.',
  'default' => 216,
  'min'     => 0,
  'max'     => 216,
  'unit'    => 'mm',
 },
 {
  name      => 'y',
  index     => 9,
  'tip'     => 'Height of scan-area.',
  'default' => 297,
  'min'     => 0,
  'max'     => 297,
  'unit'    => 'mm',
 },
 {
  name  => 'predef-window',
  index => 10,
  'tip' =>
'Provides standard scanning areas for photographs, printed pages and the like.',
  'default' => 'None',
  'values'  => [ 'None', '6x4 (inch)', '8x10 (inch)', '8.5x11 (inch)' ]
 },
 {
  name  => 'depth',
  index => 11,
  'tip' =>
'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
  'default' => 'inactive',
  'values'  => ['8'],
  'unit'    => 'bit',
 },
 {
  name      => 'quality-cal',
  index     => 12,
  'tip'     => 'Do a quality white-calibration',
  'default' => 'yes',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name  => 'halftoning',
  index => 13,
  'tip' => 'Selects whether the acquired image should be halftoned (dithered).',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name  => 'halftone-pattern',
  index => 14,
  'tip' =>
    'Defines the halftoning (dithering) pattern for scanning halftoned images.',
  'default' => 'inactive',
  'values'  => [ 'DispersedDot8x8', 'DispersedDot16x16' ]
 },
 {
  name  => 'custom-gamma',
  index => 15,
  'tip' =>
    'Determines whether a builtin or a custom gamma-table should be used.',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'analog-gamma-bind',
  index     => 16,
  'tip'     => 'In RGB-mode use same values for each color',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'analog-gamma',
  index     => 17,
  'tip'     => 'Analog gamma-correction',
  'default' => 'inactive',
  'min'     => 0,
  'max'     => 4,
 },
 {
  name      => 'analog-gamma-r',
  index     => 18,
  'tip'     => 'Analog gamma-correction for red',
  'default' => '1.79999',
  'min'     => 0,
  'max'     => 4,
 },
 {
  name      => 'analog-gamma-g',
  index     => 19,
  'tip'     => 'Analog gamma-correction for green',
  'default' => '1.79999',
  'min'     => 0,
  'max'     => 4,
 },
 {
  name      => 'analog-gamma-b',
  index     => 20,
  'tip'     => 'Analog gamma-correction for blue',
  'default' => '1.79999',
  'min'     => 0,
  'max'     => 4,
 },
 {
  name  => 'gamma-table',
  index => 21,
  'tip' =>
'Gamma-correction table.  In color mode this option equally affects the red, green, and blue channels simultaneously (i.e., it is an intensity gamma table).',
  'default' => 'inactive',
  'min'     => 0,
  'max'     => 65535,
  'step'    => 1,
 },
 {
  name      => 'red-gamma-table',
  index     => 22,
  'tip'     => 'Gamma-correction table for the red band.',
  'default' => 'inactive',
  'min'     => 0,
  'max'     => 65535,
  'step'    => 1,
 },
 {
  name      => 'green-gamma-table',
  index     => 23,
  'tip'     => 'Gamma-correction table for the green band.',
  'default' => 'inactive',
  'min'     => 0,
  'max'     => 65535,
  'step'    => 1,
 },
 {
  name      => 'blue-gamma-table',
  index     => 24,
  'tip'     => 'Gamma-correction table for the blue band.',
  'default' => 'inactive',
  'min'     => 0,
  'max'     => 65535,
  'step'    => 1,
 },
 {
  name      => 'negative',
  index     => 25,
  'tip'     => 'Swap black and white',
  'default' => 'inactive',
  'values'  => [ 'auto', 'yes', 'no' ]
 },
 {
  name      => 'threshold',
  index     => 26,
  'tip'     => 'Select minimum-brightness to get a white point',
  'default' => 'inactive',
  'min'     => 0,
  'max'     => 100,
  'step'    => 1,
  'unit'    => '%',
 },
 {
  name      => 'brightness',
  index     => 27,
  'tip'     => 'Controls the brightness of the acquired image.',
  'default' => '0',
  'min'     => -400,
  'max'     => 400,
  'step'    => 1,
  'unit'    => '%',
 },
 {
  name      => 'contrast',
  index     => 28,
  'tip'     => 'Controls the contrast of the acquired image.',
  'default' => '0',
  'min'     => -100,
  'max'     => 400,
  'step'    => 1,
  'unit'    => '%',
 },
 {
  name  => 'rgb-lpr',
  index => 29,
  'tip' =>
'Number of scan lines to request in a SCSI read. Changing this parameter allows you to tune the speed at which data is read from the scanner during scans. If this is set too low, the scanner will have to stop periodically in the middle of a scan; if it\'s set too high, X-based frontends may stop responding to X events and your system could bog down.',
  'default' => '4',
  'min'     => 1,
  'max'     => 50,
  'step'    => 1,
 },
 {
  name  => 'gs-lpr',
  index => 30,
  'tip' =>
'Number of scan lines to request in a SCSI read. Changing this parameter allows you to tune the speed at which data is read from the scanner during scans. If this is set too low, the scanner will have to stop periodically in the middle of a scan; if it\'s set too high, X-based frontends may stop responding to X events and your system could bog down.',
  'default' => 'inactive',
  'min'     => 1,
  'max'     => 50,
  'step'    => 1,
 },
);
is_deeply( $options->{array}, \@that, 'snapscan' );
