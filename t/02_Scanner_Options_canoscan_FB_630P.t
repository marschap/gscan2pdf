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

my $filename = 'scanners/canoscan_FB_630P';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new_from_data($output);
my @that     = (
 {
  name      => 'resolution',
  index     => 0,
  'tip'     => 'Sets the resolution of the scanned image.',
  'default' => '75',
  'values'  => [ '75', '150', '300', '600' ],
  'unit'    => 'dpi',
 },
 {
  name      => 'mode',
  index     => 1,
  'tip'     => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
  'default' => 'Gray',
  'values'  => [ 'Gray', 'Color' ]
 },
 {
  name  => 'depth',
  index => 2,
  'tip' =>
'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
  'default' => '8',
  'values'  => [ '8', '12' ]
 },
 {
  name       => 'l',
  index      => 3,
  'tip'      => 'Top-left x position of scan area.',
  'default'  => 0,
  constraint => {
   'min'  => 0,
   'max'  => 215,
   'step' => 1869504867,
  },
  'unit' => 'mm',
 },
 {
  name       => 't',
  index      => 4,
  'tip'      => 'Top-left y position of scan area.',
  'default'  => 0,
  constraint => {
   'min'  => 0,
   'max'  => 296,
   'step' => 1852795252,
  },
  'unit' => 'mm',
 },
 {
  name       => 'x',
  index      => 5,
  'tip'      => 'Width of scan-area.',
  'default'  => 100,
  constraint => {
   'min'  => 3,
   'max'  => 216,
   'step' => 16,
  },
  'unit' => 'mm',
 },
 {
  name       => 'y',
  index      => 6,
  'tip'      => 'Height of scan-area.',
  'default'  => 100,
  constraint => {
   'min' => 1,
   'max' => 297,
  },
  'unit' => 'mm',
 },
 {
  name      => 'quality-cal',
  index     => 7,
  'tip'     => 'Do a quality white-calibration',
  'default' => '',
 },
);
is_deeply( $options->{array}, \@that, 'canoscan_FB_630P' );
