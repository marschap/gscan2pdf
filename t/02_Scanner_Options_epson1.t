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

my $filename = 'scanners/epson1';
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
  'default' => 'Binary',
  'values'  => [ 'Binary', 'Gray', 'Color' ]
 },
 {
  name  => 'depth',
  index => 2,
  'tip' =>
'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
  'default' => 'inactive',
  'values'  => [ '8', '16' ]
 },
 {
  name      => 'halftoning',
  index     => 3,
  'tip'     => 'Selects the halftone.',
  'default' => 'Halftone A (Hard Tone)',
  'values'  => [
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
  ]
 },
 {
  name      => 'dropout',
  index     => 4,
  'tip'     => 'Selects the dropout.',
  'default' => 'None',
  'values'  => [ 'None', 'Red', 'Green', 'Blue' ]
 },
 {
  name       => 'brightness',
  index      => 5,
  'tip'      => 'Selects the brightness.',
  'default'  => '0',
  constraint => {
   'min' => -4,
   'max' => 3,
  },
 },
 {
  name       => 'sharpness',
  index      => 6,
  'tip'      => '',
  'default'  => '0',
  constraint => {
   'min' => -2,
   'max' => 2,
  },
 },
 {
  name  => 'gamma-correction',
  index => 7,
  'tip' =>
'Selects the gamma correction value from a list of pre-defined devices or the user defined table, which can be downloaded to the scanner',
  'default' => 'Default',
  'values'  => [
   'Default',
   'User defined',
   'High density printing',
   'Low density printing',
   'High contrast printing'
  ]
 },
 {
  name  => 'color-correction',
  index => 8,
  'tip' => 'Sets the color correction table for the selected output device.',
  'default' => 'CRT monitors',
  'values'  => [
   'No Correction',
   'User defined',
   'Impact-dot printers',
   'Thermal printers',
   'Ink-jet printers',
   'CRT monitors'
  ]
 },
 {
  name      => 'resolution',
  index     => 9,
  'tip'     => 'Sets the resolution of the scanned image.',
  'default' => '50',
  'values'  => [
   '50',  '60',  '72',  '75',  '80',   '90',   '100',  '120',
   '133', '144', '150', '160', '175',  '180',  '200',  '216',
   '240', '266', '300', '320', '350',  '360',  '400',  '480',
   '600', '720', '800', '900', '1200', '1600', '1800', '2400',
   '3200'
  ],
  'unit' => 'dpi',
 },
 {
  name       => 'threshold',
  index      => 10,
  'tip'      => 'Select minimum-brightness to get a white point',
  'default'  => 'inactive',
  constraint => {
   'min' => 0,
   'max' => 255,
  },
 },
 {
  index => 11,
  title => 'Advanced',
 },
 {
  name      => 'mirror',
  index     => 12,
  'tip'     => 'Mirror the image.',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'speed',
  index     => 13,
  'tip'     => 'Determines the speed at which the scan proceeds.',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'auto-area-segmentation',
  index     => 14,
  'tip'     => '',
  'default' => 'yes',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'short-resolution',
  index     => 15,
  'tip'     => 'Display short resolution list',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name       => 'zoom',
  index      => 16,
  'tip'      => 'Defines the zoom factor the scanner will use',
  'default'  => 'inactive',
  constraint => {
   'min' => 50,
   'max' => 200,
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
  name  => 'wait-for-button',
  index => 20,
  'tip' =>
'After sending the scan command, wait until the button on the scanner is pressed to actually start the scan process.',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  index => 21,
  title => 'Color correction coefficients',
 },
 {
  name       => 'cct-1',
  index      => 22,
  'tip'      => 'Controls green level',
  'default'  => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
 },
 {
  name       => 'cct-2',
  index      => 23,
  'tip'      => 'Adds to red based on green level',
  'default'  => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
 },
 {
  name       => 'cct-3',
  index      => 24,
  'tip'      => 'Adds to blue based on green level',
  'default'  => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
 },
 {
  name       => 'cct-4',
  index      => 25,
  'tip'      => 'Adds to green based on red level',
  'default'  => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
 },
 {
  name       => 'cct-5',
  index      => 26,
  'tip'      => 'Controls red level',
  'default'  => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
 },
 {
  name       => 'cct-6',
  index      => 27,
  'tip'      => 'Adds to blue based on red level',
  'default'  => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
 },
 {
  name       => 'cct-7',
  index      => 28,
  'tip'      => 'Adds to green based on blue level',
  'default'  => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
 },
 {
  name       => 'cct-8',
  index      => 29,
  'tip'      => 'Adds to red based on blue level',
  'default'  => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
 },
 {
  name       => 'cct-9',
  index      => 30,
  'tip'      => 'Controls blue level',
  'default'  => 'inactive',
  constraint => {
   'min' => -127,
   'max' => 127,
  },
 },
 {
  index => 31,
  title => 'Preview',
 },
 {
  name      => 'preview',
  index     => 32,
  'tip'     => 'Request a preview-quality scan.',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'preview-speed',
  index     => 33,
  'tip'     => '',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  index => 34,
  title => 'Geometry',
 },
 {
  name       => 'l',
  index      => 35,
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
  index      => 36,
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
  index      => 37,
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
  index      => 38,
  'tip'      => 'Height of scan-area.',
  'default'  => 297.18,
  constraint => {
   'min' => 0,
   'max' => 297.18,
  },
  'unit' => 'mm',
 },
 {
  name      => 'quick-format',
  index     => 39,
  'tip'     => '',
  'default' => 'Max',
  'values'  => [ 'CD', 'A5 portrait', 'A5 landscape', 'Letter', 'A4', 'Max' ]
 },
 {
  index => 40,
  title => 'Optional equipment',
 },
 {
  name      => 'source',
  index     => 41,
  'tip'     => 'Selects the scan source (such as a document-feeder).',
  'default' => 'Flatbed',
  'values'  => [ 'Flatbed', 'Transparency Unit' ]
 },
 {
  name      => 'auto-eject',
  index     => 42,
  'tip'     => 'Eject document after scanning',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'film-type',
  index     => 43,
  'tip'     => '',
  'default' => 'inactive',
  'values'  => [ 'Positive Film', 'Negative Film' ]
 },
 {
  name  => 'focus-position',
  index => 44,
  'tip' =>
    'Sets the focus position to either the glass or 2.5mm above the glass',
  'default' => 'Focus on glass',
  'values'  => [ 'Focus on glass', 'Focus 2.5mm above glass' ]
 },
 {
  name      => 'bay',
  index     => 45,
  'tip'     => 'Select bay to scan',
  'default' => 'inactive',
  'values'  => [ ' 1 ', ' 2 ', ' 3 ', ' 4 ', ' 5 ', ' 6 ' ]
 },
 {
  name      => 'eject',
  index     => 46,
  'tip'     => 'Eject the sheet in the ADF',
  'default' => 'inactive',
 },
 {
  name      => 'adf_mode',
  index     => 47,
  'tip'     => 'Selects the ADF mode (simplex/duplex)',
  'default' => 'inactive',
  'values'  => [ 'Simplex', 'Duplex' ]
 },
);
is_deeply( $options->{array}, \@that, 'epson1' );
