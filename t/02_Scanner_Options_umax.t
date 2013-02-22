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

my $filename = 'scanners/umax';
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
  name         => 'source',
  index        => 2,
  'desc'       => 'Selects the scan source (such as a document-feeder).',
  'val'        => 'Flatbed',
  'constraint' => ['Flatbed'],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name       => 'resolution',
  index      => 3,
  'desc'     => 'Sets the resolution of the scanned image.',
  'val'      => '100',
  constraint => {
   'min'  => 5,
   'max'  => 300,
   'step' => 5,
  },
  'unit' => SANE_UNIT_DPI,
 },
 {
  name       => 'y-resolution',
  index      => 4,
  'desc'     => 'Sets the vertical resolution of the scanned image.',
  'val'      => 'inactive',
  constraint => {
   'min'  => 5,
   'max'  => 600,
   'step' => 5,
  },
  'unit' => SANE_UNIT_DPI,
 },
 {
  name         => 'resolution-bind',
  index        => 5,
  'desc'       => 'Use same values for X and Y resolution',
  'val'        => 'yes',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'negative',
  index        => 6,
  'desc'       => 'Swap black and white',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
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
   'max' => 215.9,
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
   'max' => 297.18,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name       => 'x',
  index      => 10,
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
  index      => 11,
  'desc'     => 'Height of scan-area.',
  'val'      => 297.18,
  constraint => {
   'min' => 0,
   'max' => 297.18,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  index => 12,
  title => 'Enhancement',
 },
 {
  name  => 'depth',
  index => 13,
  'desc' =>
'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
  'val'        => '8',
  'constraint' => ['8'],
  'unit'       => SANE_UNIT_BIT,
 },
 {
  name         => 'quality-cal',
  index        => 14,
  'desc'       => 'Do a quality white-calibration',
  'val'        => 'yes',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'double-res',
  index        => 15,
  'desc'       => 'Use lens that doubles optical resolution',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'warmup',
  index        => 16,
  'desc'       => 'Warmup lamp before scanning',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'rgb-bind',
  index        => 17,
  'desc'       => 'In RGB-mode use same values for each color',
  'val'        => 'no',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name       => 'brightness',
  index      => 18,
  'desc'     => 'Controls the brightness of the acquired image.',
  'val'      => 'inactive',
  constraint => {
   'min'  => -100,
   'max'  => 100,
   'step' => 1,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name       => 'contrast',
  index      => 19,
  'desc'     => 'Controls the contrast of the acquired image.',
  'val'      => 'inactive',
  constraint => {
   'min'  => -100,
   'max'  => 100,
   'step' => 1,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name       => 'threshold',
  index      => 20,
  'desc'     => 'Select minimum-brightness to get a white point',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name       => 'highlight',
  index      => 21,
  'desc'     => 'Selects what radiance level should be considered "white".',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name   => 'highlight-r',
  index  => 22,
  'desc' => 'Selects what red radiance level should be considered "full red".',
  'val'  => '100',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name  => 'highlight-g',
  index => 23,
  'desc' =>
    'Selects what green radiance level should be considered "full green".',
  'val'      => '100',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name  => 'highlight-b',
  index => 24,
  'desc' =>
    'Selects what blue radiance level should be considered "full blue".',
  'val'      => '100',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name       => 'shadow',
  index      => 25,
  'desc'     => 'Selects what radiance level should be considered "black".',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name       => 'shadow-r',
  index      => 26,
  'desc'     => 'Selects what red radiance level should be considered "black".',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name   => 'shadow-g',
  index  => 27,
  'desc' => 'Selects what green radiance level should be considered "black".',
  'val'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name   => 'shadow-b',
  index  => 28,
  'desc' => 'Selects what blue radiance level should be considered "black".',
  'val'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name       => 'analog-gamma',
  index      => 29,
  'desc'     => 'Analog gamma-correction',
  'val'      => 'inactive',
  constraint => {
   'min'  => 1,
   'max'  => 2,
   'step' => 0.00999451,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'analog-gamma-r',
  index      => 30,
  'desc'     => 'Analog gamma-correction for red',
  'val'      => 'inactive',
  constraint => {
   'min'  => 1,
   'max'  => 2,
   'step' => 0.00999451,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'analog-gamma-g',
  index      => 31,
  'desc'     => 'Analog gamma-correction for green',
  'val'      => 'inactive',
  constraint => {
   'min'  => 1,
   'max'  => 2,
   'step' => 0.00999451,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'analog-gamma-b',
  index      => 32,
  'desc'     => 'Analog gamma-correction for blue',
  'val'      => 'inactive',
  constraint => {
   'min'  => 1,
   'max'  => 2,
   'step' => 0.00999451,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name  => 'custom-gamma',
  index => 33,
  'desc' =>
    'Determines whether a builtin or a custom gamma-table should be used.',
  'val'        => 'yes',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name       => 'gamma-table',
  index      => 34,
  constraint => {
   'min' => 0,
   'max' => 255,
  },
  'desc' =>
'Gamma-correction table.  In color mode this option equally affects the red, green, and blue channels simultaneously (i.e., it is an intensity gamma table).',
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'red-gamma-table',
  index      => 35,
  constraint => {
   'min' => 0,
   'max' => 255,
  },
  'desc' => 'Gamma-correction table for the red band.',
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'green-gamma-table',
  index      => 36,
  constraint => {
   'min' => 0,
   'max' => 255,
  },
  'desc' => 'Gamma-correction table for the green band.',
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'blue-gamma-table',
  index      => 37,
  constraint => {
   'min' => 0,
   'max' => 255,
  },
  'desc' => 'Gamma-correction table for the blue band.',
  'unit' => SANE_UNIT_NONE,
 },
 {
  name  => 'halftone-size',
  index => 38,
  'desc' =>
'Sets the size of the halftoning (dithering) pattern used when scanning halftoned images.',
  'val'        => 'inactive',
  'constraint' => [ '2', '4', '6', '8', '12' ],
  'unit'       => SANE_UNIT_PIXEL,
 },
 {
  name  => 'halftone-pattern',
  index => 39,
  'desc' =>
    'Defines the halftoning (dithering) pattern for scanning halftoned images.',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 255,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  index => 40,
  title => 'Advanced',
 },
 {
  name       => 'cal-exposure-time',
  index      => 41,
  'desc'     => 'Define exposure-time for calibration',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => SANE_UNIT_MICROSECOND,
 },
 {
  name       => 'cal-exposure-time-r',
  index      => 42,
  'desc'     => 'Define exposure-time for red calibration',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => SANE_UNIT_MICROSECOND,
 },
 {
  name       => 'cal-exposure-time-g',
  index      => 43,
  'desc'     => 'Define exposure-time for green calibration',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => SANE_UNIT_MICROSECOND,
 },
 {
  name       => 'cal-exposure-time-b',
  index      => 44,
  'desc'     => 'Define exposure-time for blue calibration',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => SANE_UNIT_MICROSECOND,
 },
 {
  name       => 'scan-exposure-time',
  index      => 45,
  'desc'     => 'Define exposure-time for scan',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => SANE_UNIT_MICROSECOND,
 },
 {
  name       => 'scan-exposure-time-r',
  index      => 46,
  'desc'     => 'Define exposure-time for red scan',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => SANE_UNIT_MICROSECOND,
 },
 {
  name       => 'scan-exposure-time-g',
  index      => 47,
  'desc'     => 'Define exposure-time for green scan',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => SANE_UNIT_MICROSECOND,
 },
 {
  name       => 'scan-exposure-time-b',
  index      => 48,
  'desc'     => 'Define exposure-time for blue scan',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 0,
  },
  'unit' => SANE_UNIT_MICROSECOND,
 },
 {
  name         => 'disable-pre-focus',
  index        => 49,
  'desc'       => 'Do not calibrate focus',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'manual-pre-focus',
  index        => 50,
  'desc'       => '',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'fix-focus-position',
  index        => 51,
  'desc'       => '',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'lens-calibration-in-doc-position',
  index        => 52,
  'desc'       => 'Calibrate lens focus in document position',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'holder-focus-position-0mm',
  index        => 53,
  'desc'       => 'Use 0mm holder focus position instead of 0.6mm',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name       => 'cal-lamp-density',
  index      => 54,
  'desc'     => 'Define lamp density for calibration',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name       => 'scan-lamp-density',
  index      => 55,
  'desc'     => 'Define lamp density for scan',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 100,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name         => 'select-exposure-time',
  index        => 56,
  'desc'       => 'Enable selection of exposure-time',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name   => 'select-calibration-exposure-time',
  index  => 57,
  'desc' => 'Allow different settings for calibration and scan exposure times',
  'val'  => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'select-lamp-density',
  index        => 58,
  'desc'       => 'Enable selection of lamp density',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name   => 'lamp-on',
  index  => 59,
  'desc' => 'Turn on scanner lamp',
  'val'  => 'inactive',
  'unit' => SANE_UNIT_NONE,
 },
 {
  name   => 'lamp-off',
  index  => 60,
  'desc' => 'Turn off scanner lamp',
  'val'  => 'inactive',
  'unit' => SANE_UNIT_NONE,
 },
 {
  name         => 'lamp-off-at-exit',
  index        => 61,
  'desc'       => 'Turn off lamp when program exits',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'batch-scan-start',
  index        => 62,
  'desc'       => 'set for first scan of batch',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'batch-scan-loop',
  index        => 63,
  'desc'       => 'set for middle scans of batch',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'batch-scan-end',
  index        => 64,
  'desc'       => 'set for last scan of batch',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name       => 'batch-scan-next-tl-y',
  index      => 65,
  'desc'     => 'Set top left Y position for next scan',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 297.18,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name         => 'preview',
  index        => 66,
  'desc'       => 'Request a preview-quality scan.',
  'val'        => 'no',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
);
is_deeply( $options->{array}, \@that, 'umax' );
