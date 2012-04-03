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

my $filename = 'scanners/hp_scanjet5300c';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new($output);
my @that     = (
 {
  name      => 'mode',
  index     => 0,
  'tip'     => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
  'default' => 'Color',
  'values' =>
    [ 'Lineart', 'Dithered', 'Gray', '12bit Gray', 'Color', '12bit Color' ]
 },
 {
  name      => 'resolution',
  index     => 1,
  'tip'     => 'Sets the resolution of the scanned image.',
  'default' => '150',
  'min'     => 100,
  'max'     => 1200,
  'step'    => 5,
  'unit'    => 'dpi',
 },
 {
  name      => 'speed',
  index     => 2,
  'tip'     => 'Determines the speed at which the scan proceeds.',
  'default' => '0',
  'min'     => 0,
  'max'     => 4,
  'step'    => 1,
 },
 {
  name      => 'preview',
  index     => 3,
  'tip'     => 'Request a preview-quality scan.',
  'default' => 'no',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'source',
  index     => 4,
  'tip'     => 'Selects the scan source (such as a document-feeder).',
  'default' => 'Normal',
  'values'  => [ 'Normal', 'ADF' ]
 },
 {
  name      => 'l',
  index     => 5,
  'tip'     => 'Top-left x position of scan area.',
  'default' => 0,
  'min'     => 0,
  'max'     => 216,
  'unit'    => 'mm',
 },
 {
  name      => 't',
  index     => 6,
  'tip'     => 'Top-left y position of scan area.',
  'default' => 0,
  'min'     => 0,
  'max'     => 296,
  'unit'    => 'mm',
 },
 {
  name      => 'x',
  index     => 7,
  'tip'     => 'Width of scan-area.',
  'default' => 216,
  'min'     => 0,
  'max'     => 216,
  'unit'    => 'mm',
 },
 {
  name      => 'y',
  index     => 8,
  'tip'     => 'Height of scan-area.',
  'default' => 296,
  'min'     => 0,
  'max'     => 296,
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
  name      => 'quality-scan',
  index     => 11,
  'tip'     => 'Turn on quality scanning (slower but better).',
  'default' => 'yes',
  'values'  => [ 'yes', 'no' ]
 },
 {
  name      => 'quality-cal',
  index     => 12,
  'tip'     => 'Do a quality white-calibration',
  'default' => 'yes',
  'values'  => [ 'yes', 'no' ]
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
  name      => 'frame',
  index     => 16,
  'tip'     => 'Selects the number of the frame to scan',
  'default' => 'inactive',
  'min'     => 0,
  'max'     => 0,
 },
 {
  name  => 'power-save-time',
  index => 17,
  'tip' =>
'Allows control of the scanner\'s power save timer, dimming or turning off the light.',
  'default' => '65535',
  'values'  => ['<int>']
 },
);
is_deeply( $options->{array}, \@that, 'hp_scanjet5300c' );
