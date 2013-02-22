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

my $filename = 'scanners/brother';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new_from_data($output);
my @that     = (
 {
  index => 0,
  title => 'Mode',
 },
 {
  name         => 'mode',
  index        => 1,
  'desc'       => 'Select the scan mode',
  'val'        => '24bit Color',
  'constraint' => [
   'Black & White',
   'Gray[Error Diffusion]',
   'True Gray',
   '24bit Color',
   '24bit Color[Fast]'
  ],
  'unit' => SANE_UNIT_NONE,
 },
 {
  name         => 'resolution',
  index        => 2,
  'desc'       => 'Sets the resolution of the scanned image.',
  'val'        => '200',
  'constraint' => [
   '100', '150', '200', '300', '400', '600', '1200', '2400', '4800', '9600'
  ],
  'unit' => SANE_UNIT_DPI,
 },
 {
  name         => 'source',
  index        => 3,
  'desc'       => 'Selects the scan source (such as a document-feeder).',
  'val'        => 'Automatic Document Feeder',
  'constraint' => [ 'FlatBed', 'Automatic Document Feeder' ],
  'unit'       => SANE_UNIT_NONE,
 },
 {
  name       => 'brightness',
  index      => 4,
  'desc'     => 'Controls the brightness of the acquired image.',
  'val'      => 'inactive',
  constraint => {
   'min'  => -50,
   'max'  => 50,
   'step' => 1,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  name       => 'contrast',
  index      => 5,
  'desc'     => 'Controls the contrast of the acquired image.',
  'val'      => 'inactive',
  constraint => {
   'min'  => -50,
   'max'  => 50,
   'step' => 1,
  },
  'unit' => SANE_UNIT_PERCENT,
 },
 {
  index => 6,
  title => 'Geometry',
 },
 {
  name       => 'l',
  index      => 7,
  'desc'     => 'Top-left x position of scan area.',
  'val'      => 0,
  constraint => {
   'min'  => 0,
   'max'  => 210,
   'step' => 0.0999908,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name       => 't',
  index      => 8,
  'desc'     => 'Top-left y position of scan area.',
  'val'      => 0,
  constraint => {
   'min'  => 0,
   'max'  => 297,
   'step' => 0.0999908,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name       => 'x',
  index      => 9,
  'desc'     => 'Width of scan-area.',
  'val'      => 209.981,
  constraint => {
   'min'  => 0,
   'max'  => 210,
   'step' => 0.0999908,
  },
  'unit' => SANE_UNIT_MM,
 },
 {
  name       => 'y',
  index      => 10,
  'desc'     => 'Height of scan-area.',
  'val'      => 296.973,
  constraint => {
   'min'  => 0,
   'max'  => 297,
   'step' => 0.0999908,
  },
  'unit' => SANE_UNIT_MM,
 }
);
is_deeply( $options->{array}, \@that, 'brother' );
