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
my $options  = Gscan2pdf::Scanner::Options->new($output);
my @that     = (
 {
  name      => 'mode',
  index     => 0,
  'tip'     => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
  'default' => 'Binary',
  'values'  => [ 'Binary', 'Gray', 'Color' ]
 },
 {
  name  => 'depth',
  index => 1,
  'tip' =>
'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
  'default' => 'inactive',
  'values'  => [ '8', '16' ]
 },
 {
  name      => 'halftoning',
  index     => 2,
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
  index     => 3,
  'tip'     => 'Selects the dropout.',
  'default' => 'None',
  'values'  => [ 'None', 'Red', 'Green', 'Blue' ]
 },
 {
  name      => 'brightness',
  index     => 4,
  'tip'     => 'Selects the brightness.',
  'default' => '0',
  'min'     => -4,
  'max'     => 3,
 },
 {
  name      => 'sharpness',
  index     => 5,
  'tip'     => '',
  'default' => '0',
  'min'     => -2,
  'max'     => 2,
 },
 {
  name  => 'gamma-correction',
  index => 6,
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
  index => 7,
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
  index     => 8,
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
  name      => 'threshold',
  index     => 9,
  'tip'     => 'Select minimum-brightness to get a white point',
  'default' => 'inactive',
  'min'     => 0,
  'max'     => 255,
 },
 {
  name      => 'mirror',
  index     => 10,
  'tip'     => 'Mirror the image.',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'speed',
  index     => 11,
  'tip'     => 'Determines the speed at which the scan proceeds.',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'auto-area-segmentation',
  index     => 12,
  'tip'     => '',
  'default' => 'yes',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'short-resolution',
  index     => 13,
  'tip'     => 'Display short resolution list',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'zoom',
  index     => 14,
  'tip'     => 'Defines the zoom factor the scanner will use',
  'default' => 'inactive',
  'min'     => 50,
  'max'     => 200,
 },
 {
  name      => 'red-gamma-table',
  index     => 15,
  'tip'     => 'Gamma-correction table for the red band.',
  'default' => 'inactive',
  'min'     => 0,
  'max'     => 255,
 },
 {
  name      => 'green-gamma-table',
  index     => 16,
  'tip'     => 'Gamma-correction table for the green band.',
  'default' => 'inactive',
  'min'     => 0,
  'max'     => 255,
 },
 {
  name      => 'blue-gamma-table',
  index     => 17,
  'tip'     => 'Gamma-correction table for the blue band.',
  'default' => 'inactive',
  'min'     => 0,
  'max'     => 255,
 },
 {
  name  => 'wait-for-button',
  index => 18,
  'tip' =>
'After sending the scan command, wait until the button on the scanner is pressed to actually start the scan process.',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'cct-1',
  index     => 19,
  'tip'     => 'Controls green level',
  'default' => 'inactive',
  'min'     => -127,
  'max'     => 127,
 },
 {
  name      => 'cct-2',
  index     => 20,
  'tip'     => 'Adds to red based on green level',
  'default' => 'inactive',
  'min'     => -127,
  'max'     => 127,
 },
 {
  name      => 'cct-3',
  index     => 21,
  'tip'     => 'Adds to blue based on green level',
  'default' => 'inactive',
  'min'     => -127,
  'max'     => 127,
 },
 {
  name      => 'cct-4',
  index     => 22,
  'tip'     => 'Adds to green based on red level',
  'default' => 'inactive',
  'min'     => -127,
  'max'     => 127,
 },
 {
  name      => 'cct-5',
  index     => 23,
  'tip'     => 'Controls red level',
  'default' => 'inactive',
  'min'     => -127,
  'max'     => 127,
 },
 {
  name      => 'cct-6',
  index     => 24,
  'tip'     => 'Adds to blue based on red level',
  'default' => 'inactive',
  'min'     => -127,
  'max'     => 127,
 },
 {
  name      => 'cct-7',
  index     => 25,
  'tip'     => 'Adds to green based on blue level',
  'default' => 'inactive',
  'min'     => -127,
  'max'     => 127,
 },
 {
  name      => 'cct-8',
  index     => 26,
  'tip'     => 'Adds to red based on blue level',
  'default' => 'inactive',
  'min'     => -127,
  'max'     => 127,
 },
 {
  name      => 'cct-9',
  index     => 27,
  'tip'     => 'Controls blue level',
  'default' => 'inactive',
  'min'     => -127,
  'max'     => 127,
 },
 {
  name      => 'preview',
  index     => 28,
  'tip'     => 'Request a preview-quality scan.',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'preview-speed',
  index     => 29,
  'tip'     => '',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'l',
  index     => 30,
  'tip'     => 'Top-left x position of scan area.',
  'default' => 0,
  'min'     => 0,
  'max'     => 215.9,
  'unit'    => 'mm',
 },
 {
  name      => 't',
  index     => 31,
  'tip'     => 'Top-left y position of scan area.',
  'default' => 0,
  'min'     => 0,
  'max'     => 297.18,
  'unit'    => 'mm',
 },
 {
  name      => 'x',
  index     => 32,
  'tip'     => 'Width of scan-area.',
  'default' => 215.9,
  'min'     => 0,
  'max'     => 215.9,
  'unit'    => 'mm',
 },
 {
  name      => 'y',
  index     => 33,
  'tip'     => 'Height of scan-area.',
  'default' => 297.18,
  'min'     => 0,
  'max'     => 297.18,
  'unit'    => 'mm',
 },
 {
  name      => 'quick-format',
  index     => 34,
  'tip'     => '',
  'default' => 'Max',
  'values'  => [ 'CD', 'A5 portrait', 'A5 landscape', 'Letter', 'A4', 'Max' ]
 },
 {
  name      => 'source',
  index     => 35,
  'tip'     => 'Selects the scan source (such as a document-feeder).',
  'default' => 'Flatbed',
  'values'  => [ 'Flatbed', 'Transparency Unit' ]
 },
 {
  name      => 'auto-eject',
  index     => 36,
  'tip'     => 'Eject document after scanning',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'film-type',
  index     => 37,
  'tip'     => '',
  'default' => 'inactive',
  'values'  => [ 'Positive Film', 'Negative Film' ]
 },
 {
  name  => 'focus-position',
  index => 38,
  'tip' =>
    'Sets the focus position to either the glass or 2.5mm above the glass',
  'default' => 'Focus on glass',
  'values'  => [ 'Focus on glass', 'Focus 2.5mm above glass' ]
 },
 {
  name      => 'bay',
  index     => 39,
  'tip'     => 'Select bay to scan',
  'default' => 'inactive',
  'values'  => [ ' 1 ', ' 2 ', ' 3 ', ' 4 ', ' 5 ', ' 6 ' ]
 },
 {
  name      => 'eject',
  index     => 40,
  'tip'     => 'Eject the sheet in the ADF',
  'default' => 'inactive',
 },
 {
  name      => 'adf_mode',
  index     => 41,
  'tip'     => 'Selects the ADF mode (simplex/duplex)',
  'default' => 'inactive',
  'values'  => [ 'Simplex', 'Duplex' ]
 },
);
is_deeply( $options->{array}, \@that, 'epson1' );
