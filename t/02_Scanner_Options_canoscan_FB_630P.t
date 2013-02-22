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

my $filename = 'scanners/canoscan_FB_630P';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new_from_data($output);
my @that     = (
 {
  name         => 'resolution',
  index        => 0,
  'desc'       => 'Sets the resolution of the scanned image.',
  'val'        => '75',
  'constraint' => [ '75', '150', '300', '600' ],
  'unit'       => SANE_UNIT_DPI,
 },
 {
  name   => 'mode',
  index  => 1,
  'desc' => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
  'val'  => 'Gray',
  'constraint' => [ 'Gray', 'Color' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name  => 'depth',
  index => 2,
  'desc' =>
'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
  'val'        => '8',
  'constraint' => [ '8', '12' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name       => 'l',
  index      => 3,
  'desc'     => 'Top-left x position of scan area.',
  'val'      => 0,
  constraint => {
   'min'  => 0,
   'max'  => 215,
   'step' => 1869504867,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name       => 't',
  index      => 4,
  'desc'     => 'Top-left y position of scan area.',
  'val'      => 0,
  constraint => {
   'min'  => 0,
   'max'  => 296,
   'step' => 1852795252,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name       => 'x',
  index      => 5,
  'desc'     => 'Width of scan-area.',
  'val'      => 100,
  constraint => {
   'min'  => 3,
   'max'  => 216,
   'step' => 16,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name       => 'y',
  index      => 6,
  'desc'     => 'Height of scan-area.',
  'val'      => 100,
  constraint => {
   'min' => 1,
   'max' => 297,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name   => 'quality-cal',
  index  => 7,
  'desc' => 'Do a quality white-calibration',
  'val'  => '',
  'unit' => SANE_UNIT_NONE,
 },
);
is_deeply( $options->{array}, \@that, 'canoscan_FB_630P' );
