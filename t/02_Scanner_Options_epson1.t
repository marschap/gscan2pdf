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

my $filename = 'scanners/epson1';
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
  'val'  => 'Binary',
  'constraint' => [ 'Binary', 'Gray', 'Color' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name  => 'depth',
  index => 2,
  'desc' =>
'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
  'val'        => 'inactive',
  'constraint' => [ '8', '16' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'halftoning',
  index        => 3,
  'desc'       => 'Selects the halftone.',
  'val'        => 'Halftone A (Hard Tone)',
  'constraint' => [
   'None',
   'Halftone A (Hard Tone)',
   'Halftone B (Soft Tone)',
   'Halftone C (Net Screen)',
   'Dither A (4x4 Bayer)',
   'Dither B (4x4 Spiral)',
   'Dither C (4x4 Net Screen)',
   'Dither D (8x4 Net Screen)',
   'Text Enhanced Technology',
   'Download pattern A',
   'Download pattern B'
  ],
  'unit' => SANE_UNIT_NONE,
 },
 {
  name         => 'dropout',
  index        => 4,
  'desc'       => 'Selects the dropout.',
  'val'        => 'None',
  'constraint' => [ 'None', 'Red', 'Green', 'Blue' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name       => 'brightness',
  index      => 5,
  'desc'     => 'Selects the brightness.',
  'val'      => '0',
  constraint => {
   'min' => -4,
   'max' => 3,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'sharpness',
  index      => 6,
  'desc'     => '',
  'val'      => '0',
  constraint => {
   'min' => -2,
   'max' => 2,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name  => 'gamma-correction',
  index => 7,
  'desc' =>
'Selects the gamma correction value from a list of pre-defined devices or the user defined table, which can be downloaded to the scanner',
  'val'        => 'Default',
  'constraint' => [
   'Default',
   'User defined',
   'High density printing',
   'Low density printing',
   'High contrast printing'
  ],
  'unit' => SANE_UNIT_NONE,
 },
 {
  name   => 'color-correction',
  index  => 8,
  'desc' => 'Sets the color correction table for the selected output device.',
  'val'  => 'CRT monitors',
  'constraint' => [
   'No Correction',
   'User defined',
   'Impact-dot printers',
   'Thermal printers',
   'Ink-jet printers',
   'CRT monitors'
  ],
  'unit' => SANE_UNIT_NONE,
 },
 {
  name         => 'resolution',
  index        => 9,
  'desc'       => 'Sets the resolution of the scanned image.',
  'val'        => '50',
  'constraint' => [
   '50',  '60',  '72',  '75',  '80',   '90',   '100',  '120',
   '133', '144', '150', '160', '175',  '180',  '200',  '216',
   '240', '266', '300', '320', '350',  '360',  '400',  '480',
   '600', '720', '800', '900', '1200', '1600', '1800', '2400',
   '3200'
  ],
  'unit' => SANE_UNIT_DPI,
 },
 {
  name       => 'threshold',
  index      => 10,
  'desc'     => 'Select minimum-brightness to get a white point',
  'val'      => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 255,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  index => 11,
  title => 'Advanced',
 },
 {
  name         => 'mirror',
  index        => 12,
  'desc'       => 'Mirror the image.',
  'val'        => 'no',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'speed',
  index        => 13,
  'desc'       => 'Determines the speed at which the scan proceeds.',
  'val'        => 'no',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'auto-area-segmentation',
  index        => 14,
  'desc'       => '',
  'val'        => 'yes',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'short-resolution',
  index        => 15,
  'desc'       => 'Display short resolution list',
  'val'        => 'no',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name       => 'zoom',
  index      => 16,
  'desc'     => 'Defines the zoom factor the scanner will use',
  'val'      => 'inactive',
  constraint => {
   'min' => 50,
   'max' => 200,
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
  name  => 'wait-for-button',
  index => 20,
  'desc' =>
'After sending the scan command, wait until the button on the scanner is pressed to actually start the scan process.',
  'val'        => 'no',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  index => 21,
  title => 'Color correction coefficients',
 },
 {
  name       => 'cct-1',
  index      => 22,
  'desc'     => 'Controls green level',
  'val'      => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'cct-2',
  index      => 23,
  'desc'     => 'Adds to red based on green level',
  'val'      => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'cct-3',
  index      => 24,
  'desc'     => 'Adds to blue based on green level',
  'val'      => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'cct-4',
  index      => 25,
  'desc'     => 'Adds to green based on red level',
  'val'      => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'cct-5',
  index      => 26,
  'desc'     => 'Controls red level',
  'val'      => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'cct-6',
  index      => 27,
  'desc'     => 'Adds to blue based on red level',
  'val'      => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'cct-7',
  index      => 28,
  'desc'     => 'Adds to green based on blue level',
  'val'      => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'cct-8',
  index      => 29,
  'desc'     => 'Adds to red based on blue level',
  'val'      => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  name       => 'cct-9',
  index      => 30,
  'desc'     => 'Controls blue level',
  'val'      => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
  'unit' => SANE_UNIT_NONE,
 },
 {
  index => 31,
  title => 'Preview',
 },
 {
  name         => 'preview',
  index        => 32,
  'desc'       => 'Request a preview-quality scan.',
  'val'        => 'no',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'preview-speed',
  index        => 33,
  'desc'       => '',
  'val'        => 'no',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  index => 34,
  title => 'Geometry',
 },
 {
  name       => 'l',
  index      => 35,
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
  index      => 36,
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
  index      => 37,
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
  index      => 38,
  'desc'     => 'Height of scan-area.',
  'val'      => 297.18,
  constraint => {
   'min' => 0,
   'max' => 297.18,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name   => 'quick-format',
  index  => 39,
  'desc' => '',
  'val'  => 'Max',
  'constraint' =>
    [ 'CD', 'A5 portrait', 'A5 landscape', 'Letter', 'A4', 'Max' ],
  'unit' => SANE_UNIT_NONE,
 },
 {
  index => 40,
  title => 'Optional equipment',
 },
 {
  name         => 'source',
  index        => 41,
  'desc'       => 'Selects the scan source (such as a document-feeder).',
  'val'        => 'Flatbed',
  'constraint' => [ 'Flatbed', 'Transparency Unit' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'auto-eject',
  index        => 42,
  'desc'       => 'Eject document after scanning',
  'val'        => 'inactive',
  'constraint' => [ 'yes', 'no' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'film-type',
  index        => 43,
  'desc'       => '',
  'val'        => 'inactive',
  'constraint' => [ 'Positive Film', 'Negative Film' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name  => 'focus-position',
  index => 44,
  'desc' =>
    'Sets the focus position to either the glass or 2.5mm above the glass',
  'val'        => 'Focus on glass',
  'constraint' => [ 'Focus on glass', 'Focus 2.5mm above glass' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name         => 'bay',
  index        => 45,
  'desc'       => 'Select bay to scan',
  'val'        => 'inactive',
  'constraint' => [ ' 1 ', ' 2 ', ' 3 ', ' 4 ', ' 5 ', ' 6 ' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name   => 'eject',
  index  => 46,
  'desc' => 'Eject the sheet in the ADF',
  'val'  => 'inactive',
  'unit' => SANE_UNIT_NONE,
 },
 {
  name         => 'adf_mode',
  index        => 47,
  'desc'       => 'Selects the ADF mode (simplex/duplex)',
  'val'        => 'inactive',
  'constraint' => [ 'Simplex', 'Duplex' ],
  'unit'       => SANE_UNIT_NONE,
 },
);
is_deeply( $options->{array}, \@that, 'epson1' );
