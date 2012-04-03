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

my $filename = 'scanners/canonLiDE25';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new($output);
my @that     = (
 {
  name      => 'mode',
  index     => 0,
  'tip'     => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
  'default' => 'Color',
  'values'  => [ 'Lineart', 'Gray', 'Color' ]
 },
 {
  name  => 'depth',
  index => 1,
  'tip' =>
'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
  'default' => '8',
  'values'  => [ '8', '16' ]
 },
 {
  name      => 'source',
  index     => 2,
  'tip'     => 'Selects the scan source (such as a document-feeder).',
  'default' => 'inactive',
  'values'  => [ 'Normal', 'Transparency', 'Negative' ]
 },
 {
  name      => 'resolution',
  index     => 3,
  'tip'     => 'Sets the resolution of the scanned image.',
  'default' => '50',
  'min'     => 50,
  'max'     => 2400,
  'unit'    => 'dpi',
 },
 {
  name      => 'preview',
  index     => 4,
  'tip'     => 'Request a preview-quality scan.',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ],
 },
 {
  name      => 'l',
  index     => 5,
  'tip'     => 'Top-left x position of scan area.',
  'default' => 0,
  'min'     => 0,
  'max'     => 215,
  'unit'    => 'mm',
 },
 {
  name      => 't',
  index     => 6,
  'tip'     => 'Top-left y position of scan area.',
  'default' => 0,
  'min'     => 0,
  'max'     => 297,
  'unit'    => 'mm',
 },
 {
  name      => 'x',
  index     => 7,
  'tip'     => 'Width of scan-area.',
  'default' => 103,
  'min'     => 0,
  'max'     => 215,
  'unit'    => 'mm',
 },
 {
  name      => 'y',
  index     => 8,
  'tip'     => 'Height of scan-area.',
  'default' => 76.21,
  'min'     => 0,
  'max'     => 297,
  'unit'    => 'mm',
 },
 {
  name      => 'brightness',
  index     => 9,
  'tip'     => 'Controls the brightness of the acquired image.',
  'default' => '0',
  'min'     => -100,
  'max'     => 100,
  'step'    => 1,
  'unit'    => '%',
 },
 {
  name      => 'contrast',
  index     => 10,
  'tip'     => 'Controls the contrast of the acquired image.',
  'default' => '0',
  'min'     => -100,
  'max'     => 100,
  'step'    => 1,
  'unit'    => '%',
 },
 {
  name  => 'custom-gamma',
  index => 11,
  'tip' =>
    'Determines whether a builtin or a custom gamma-table should be used.',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name  => 'gamma-table',
  index => 12,
  'tip' =>
'Gamma-correction table.  In color mode this option equally affects the red, green, and blue channels simultaneously (i.e., it is an intensity gamma table).',
  'default' => 'inactive',
  'min'     => 0,
  'max'     => 255,
 },
 {
  name      => 'red-gamma-table',
  index     => 13,
  'tip'     => 'Gamma-correction table for the red band.',
  'default' => 'inactive',
  'min'     => 0,
  'max'     => 255,
 },
 {
  name      => 'green-gamma-table',
  index     => 14,
  'tip'     => 'Gamma-correction table for the green band.',
  'default' => 'inactive',
  'min'     => 0,
  'max'     => 255,
 },
 {
  name      => 'blue-gamma-table',
  index     => 15,
  'tip'     => 'Gamma-correction table for the blue band.',
  'default' => 'inactive',
  'min'     => 0,
  'max'     => 255,
 },
 {
  name      => 'lamp-switch',
  index     => 16,
  'tip'     => 'Manually switching the lamp(s).',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'lampoff-time',
  index     => 17,
  'tip'     => 'Lampoff-time in seconds.',
  'default' => '300',
  'min'     => 0,
  'max'     => 999,
  'step'    => 1,
 },
 {
  name      => 'lamp-off-at-exit',
  index     => 18,
  'tip'     => 'Turn off lamp when program exits',
  'default' => 'yes',
  'values'  => [ 'yes', 'no' ],
 },
 {
  name      => 'warmup-time',
  index     => 19,
  'tip'     => 'Warmup-time in seconds.',
  'default' => 'inactive',
  'min'     => -1,
  'max'     => 999,
  'step'    => 1,
 },
 {
  name      => 'calibration-cache',
  index     => 20,
  'tip'     => 'Enables or disables calibration data cache.',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'speedup-switch',
  index     => 21,
  'tip'     => 'Enables or disables speeding up sensor movement.',
  'default' => 'inactive',
  'values'  => [ 'yes', 'no' ],
 },
 {
  name      => 'calibrate',
  index     => 22,
  'tip'     => 'Performs calibration',
  'default' => 'inactive',
 },
 {
  name      => 'red-gain',
  index     => 23,
  'tip'     => 'Red gain value of the AFE',
  'default' => '-1',
  'min'     => -1,
  'max'     => 63,
  'step'    => 1,
 },
 {
  name      => 'green-gain',
  index     => 24,
  'tip'     => 'Green gain value of the AFE',
  'default' => '-1',
  'min'     => -1,
  'max'     => 63,
  'step'    => 1,
 },
 {
  name      => 'blue-gain',
  index     => 25,
  'tip'     => 'Blue gain value of the AFE',
  'default' => '-1',
  'min'     => -1,
  'max'     => 63,
  'step'    => 1,
 },
 {
  name      => 'red-offset',
  index     => 26,
  'tip'     => 'Red offset value of the AFE',
  'default' => '-1',
  'min'     => -1,
  'max'     => 63,
  'step'    => 1,
 },
 {
  name      => 'green-offset',
  index     => 27,
  'tip'     => 'Green offset value of the AFE',
  'default' => '-1',
  'min'     => -1,
  'max'     => 63,
  'step'    => 1,
 },
 {
  name      => 'blue-offset',
  index     => 28,
  'tip'     => 'Blue offset value of the AFE',
  'default' => '-1',
  'min'     => -1,
  'max'     => 63,
  'step'    => 1,
 },
 {
  name      => 'redlamp-off',
  index     => 29,
  'tip'     => 'Defines red lamp off parameter',
  'default' => '-1',
  'min'     => -1,
  'max'     => 16363,
  'step'    => 1,
 },
 {
  name      => 'greenlamp-off',
  index     => 30,
  'tip'     => 'Defines green lamp off parameter',
  'default' => '-1',
  'min'     => -1,
  'max'     => 16363,
  'step'    => 1,
 },
 {
  name      => 'bluelamp-off',
  index     => 31,
  'tip'     => 'Defines blue lamp off parameter',
  'default' => '-1',
  'min'     => -1,
  'max'     => 16363,
  'step'    => 1,
 },
);
is_deeply( $options->{array}, \@that, 'canonLiDE25' );
