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

my $filename = 'scanners/umax';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new_from_data($output);
my @that     = (
 {
  index => 0,
  title => 'Scan Mode',
 },
 {
  name      => 'mode',
  index     => 1,
  'tip'     => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
  'default' => 'Color',
  'values'  => [ 'Lineart', 'Gray', 'Color' ]
 },
 {
  name      => 'source',
  index     => 2,
  'tip'     => 'Selects the scan source (such as a document-feeder).',
  'default' => 'Flatbed',
  'values'  => ['Flatbed']
 },
 {
  name       => 'resolution',
  index      => 3,
  'tip'      => 'Sets the resolution of the scanned image.',
  'default'  => '100',
  constraint => {
   'min'  => 5,
   'max'  => 300,
   'step' => 5,
  },
  'unit' => 'dpi',
 },
 {
  name       => 'y-resolution',
  index      => 4,
  'tip'      => 'Sets the vertical resolution of the scanned image.',
  'default'  => 'inactive',
  constraint => {
   'min'  => 5,
   'max'  => 600,
   'step' => 5,
  },
  'unit' => 'dpi',
 },
 {
  name      => 'resolution-bind',
  index     => 5,
  'tip'     => 'Use same values for X and Y resolution',
  'default' => 'yes',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'negative',
  index     => 6,
  'tip'     => 'Swap black and white',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
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
   'max' => 215.9,
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
   'max' => 297.18,
  },
  'unit' => 'mm',
 },
 {
  name       => 'x',
  index      => 10,
  'tip'      => 'Width of scan-area.',
  'default'  => 215.9,
  constraint => {
   'min' => 0,
   'max' => 215.9,
  },
  'unit' => 'mm',
 },
 {
  name       => 'y',
  index      => 11,
  'tip'      => 'Height of scan-area.',
  'default'  => 297.18,
  constraint => {
   'min' => 0,
   'max' => 297.18,
  },
  'unit' => 'mm',
 },
 {
  index => 12,
  title => 'Enhancement',
 },
 {
  name  => 'depth',
  index => 13,
  'tip' =>
'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
  'default' => '8',
  'values'  => ['8'],
  'unit'    => 'bit',
 },
 {
  name      => 'quality-cal',
  index     => 14,
  'tip'     => 'Do a quality white-calibration',
  'default' => 'yes',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'double-res',
  index     => 15,
  'tip'     => 'Use lens that doubles optical resolution',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'warmup',
  index     => 16,
  'tip'     => 'Warmup lamp before scanning',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'rgb-bind',
  index     => 17,
  'tip'     => 'In RGB-mode use same values for each color',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name       => 'brightness',
  index      => 18,
  'tip'      => 'Controls the brightness of the acquired image.',
  'default'  => 'inactive',
  constraint => {
   'min'  => -100,
   'max'  => 100,
   'step' => 1,
  },
  'unit' => '%',
 },
 {
  name       => 'contrast',
  index      => 19,
  'tip'      => 'Controls the contrast of the acquired image.',
  'default'  => 'inactive',
  constraint => {
   'min'  => -100,
   'max'  => 100,
   'step' => 1,
  },
  'unit' => '%',
 },
 {
  name       => 'threshold',
  index      => 20,
  'tip'      => 'Select minimum-brightness to get a white point',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => '%',
 },
 {
  name       => 'highlight',
  index      => 21,
  'tip'      => 'Selects what radiance level should be considered "white".',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => '%',
 },
 {
  name  => 'highlight-r',
  index => 22,
  'tip' => 'Selects what red radiance level should be considered "full red".',
  'default'  => '100',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => '%',
 },
 {
  name  => 'highlight-g',
  index => 23,
  'tip' =>
    'Selects what green radiance level should be considered "full green".',
  'default'  => '100',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => '%',
 },
 {
  name  => 'highlight-b',
  index => 24,
  'tip' => 'Selects what blue radiance level should be considered "full blue".',
  'default'  => '100',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => '%',
 },
 {
  name       => 'shadow',
  index      => 25,
  'tip'      => 'Selects what radiance level should be considered "black".',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => '%',
 },
 {
  name       => 'shadow-r',
  index      => 26,
  'tip'      => 'Selects what red radiance level should be considered "black".',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => '%',
 },
 {
  name  => 'shadow-g',
  index => 27,
  'tip' => 'Selects what green radiance level should be considered "black".',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => '%',
 },
 {
  name      => 'shadow-b',
  index     => 28,
  'tip'     => 'Selects what blue radiance level should be considered "black".',
  'default' => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => '%',
 },
 {
  name       => 'analog-gamma',
  index      => 29,
  'tip'      => 'Analog gamma-correction',
  'default'  => 'inactive',
  constraint => {
   'min'  => 1,
   'max'  => 2,
   'step' => 0.00999451,
  },
 },
 {
  name       => 'analog-gamma-r',
  index      => 30,
  'tip'      => 'Analog gamma-correction for red',
  'default'  => 'inactive',
  constraint => {
   'min'  => 1,
   'max'  => 2,
   'step' => 0.00999451,
  },
 },
 {
  name       => 'analog-gamma-g',
  index      => 31,
  'tip'      => 'Analog gamma-correction for green',
  'default'  => 'inactive',
  constraint => {
   'min'  => 1,
   'max'  => 2,
   'step' => 0.00999451,
  },
 },
 {
  name       => 'analog-gamma-b',
  index      => 32,
  'tip'      => 'Analog gamma-correction for blue',
  'default'  => 'inactive',
  constraint => {
   'min'  => 1,
   'max'  => 2,
   'step' => 0.00999451,
  },
 },
 {
  name  => 'custom-gamma',
  index => 33,
  'tip' =>
    'Determines whether a builtin or a custom gamma-table should be used.',
  'default' => 'yes',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name       => 'gamma-table',
  index      => 34,
  constraint => {
   'min' => 0,
   'max' => 255,
  },
  'tip' =>
'Gamma-correction table.  In color mode this option equally affects the red, green, and blue channels simultaneously (i.e., it is an intensity gamma table).',
 },
 {
  name       => 'red-gamma-table',
  index      => 35,
  constraint => {
   'min' => 0,
   'max' => 255,
  },
  'tip' => 'Gamma-correction table for the red band.',
 },
 {
  name       => 'green-gamma-table',
  index      => 36,
  constraint => {
   'min' => 0,
   'max' => 255,
  },
  'tip' => 'Gamma-correction table for the green band.',
 },
 {
  name       => 'blue-gamma-table',
  index      => 37,
  constraint => {
   'min' => 0,
   'max' => 255,
  },
  'tip' => 'Gamma-correction table for the blue band.',
 },
 {
  name  => 'halftone-size',
  index => 38,
  'tip' =>
'Sets the size of the halftoning (dithering) pattern used when scanning halftoned images.',
  'default' => 'inactive',
  'values'  => [ '2', '4', '6', '8', '12' ],
  'unit'    => 'pel',
 },
 {
  name  => 'halftone-pattern',
  index => 39,
  'tip' =>
    'Defines the halftoning (dithering) pattern for scanning halftoned images.',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 255,
  },
 },
 {
  index => 40,
  title => 'Advanced',
 },
 {
  name       => 'cal-exposure-time',
  index      => 41,
  'tip'      => 'Define exposure-time for calibration',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => 'us',
 },
 {
  name       => 'cal-exposure-time-r',
  index      => 42,
  'tip'      => 'Define exposure-time for red calibration',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => 'us',
 },
 {
  name       => 'cal-exposure-time-g',
  index      => 43,
  'tip'      => 'Define exposure-time for green calibration',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => 'us',
 },
 {
  name       => 'cal-exposure-time-b',
  index      => 44,
  'tip'      => 'Define exposure-time for blue calibration',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => 'us',
 },
 {
  name       => 'scan-exposure-time',
  index      => 45,
  'tip'      => 'Define exposure-time for scan',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => 'us',
 },
 {
  name       => 'scan-exposure-time-r',
  index      => 46,
  'tip'      => 'Define exposure-time for red scan',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => 'us',
 },
 {
  name       => 'scan-exposure-time-g',
  index      => 47,
  'tip'      => 'Define exposure-time for green scan',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => 'us',
 },
 {
  name       => 'scan-exposure-time-b',
  index      => 48,
  'tip'      => 'Define exposure-time for blue scan',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => 'us',
 },
 {
  name      => 'disable-pre-focus',
  index     => 49,
  'tip'     => 'Do not calibrate focus',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'manual-pre-focus',
  index     => 50,
  'tip'     => '',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'fix-focus-position',
  index     => 51,
  'tip'     => '',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'lens-calibration-in-doc-position',
  index     => 52,
  'tip'     => 'Calibrate lens focus in document position',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'holder-focus-position-0mm',
  index     => 53,
  'tip'     => 'Use 0mm holder focus position instead of 0.6mm',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name       => 'cal-lamp-density',
  index      => 54,
  'tip'      => 'Define lamp density for calibration',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => '%',
 },
 {
  name       => 'scan-lamp-density',
  index      => 55,
  'tip'      => 'Define lamp density for scan',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => '%',
 },
 {
  name      => 'select-exposure-time',
  index     => 56,
  'tip'     => 'Enable selection of exposure-time',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name  => 'select-calibration-exposure-time',
  index => 57,
  'tip' => 'Allow different settings for calibration and scan exposure times',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'select-lamp-density',
  index     => 58,
  'tip'     => 'Enable selection of lamp density',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'lamp-on',
  index     => 59,
  'tip'     => 'Turn on scanner lamp',
  'default' => 'inactive',
 },
 {
  name      => 'lamp-off',
  index     => 60,
  'tip'     => 'Turn off scanner lamp',
  'default' => 'inactive',
 },
 {
  name      => 'lamp-off-at-exit',
  index     => 61,
  'tip'     => 'Turn off lamp when program exits',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'batch-scan-start',
  index     => 62,
  'tip'     => 'set for first scan of batch',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'batch-scan-loop',
  index     => 63,
  'tip'     => 'set for middle scans of batch',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'batch-scan-end',
  index     => 64,
  'tip'     => 'set for last scan of batch',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name       => 'batch-scan-next-tl-y',
  index      => 65,
  'tip'      => 'Set top left Y position for next scan',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 297.18,
  },
  'unit' => 'mm',
 },
 {
  name      => 'preview',
  index     => 66,
  'tip'     => 'Request a preview-quality scan.',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
);
is_deeply( $options->{array}, \@that, 'umax' );
