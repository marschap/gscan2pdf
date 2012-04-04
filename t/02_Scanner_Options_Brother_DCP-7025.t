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

my $filename = 'scanners/Brother_DCP-7025';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new($output);
my @that     = (
 {
  name      => 'mode',
  index     => 0,
  'tip'     => 'Select the scan mode',
  'default' => 'Black & White',
  'values'  => [
   'Black & White',
   'Gray[Error Diffusion]',
   'True Gray',
   '24bit Color',
   '24bit Color[Fast]'
  ]
 },
 {
  name      => 'resolution',
  index     => 1,
  'tip'     => 'Sets the resolution of the scanned image.',
  'default' => 200,
  'values'  => [ 100, 150, 200, 300, 400, 600, 1200, 2400, 4800, '9600' ],
  'unit'    => 'dpi',
 },
 {
  name      => 'source',
  index     => 2,
  'tip'     => 'Selects the scan source (such as a document-feeder).',
  'default' => 'Automatic Document Feeder',
  'values'  => [ 'FlatBed', 'Automatic Document Feeder' ],
 },
 {
  name       => 'brightness',
  index      => 3,
  'tip'      => 'Controls the brightness of the acquired image.',
  'default'  => 0,
  constraint => {
   'min'  => -50,
   'max'  => 50,
   'step' => 1,
  },
  'unit' => '%',
 },
 {
  name       => 'contrast',
  index      => 4,
  'tip'      => 'Controls the contrast of the acquired image.',
  'default'  => 'inactive',
  constraint => {
   'min'  => -50,
   'max'  => 50,
   'step' => 1,
  },
  'unit' => '%',
 },
 {
  name       => 'l',
  index      => 5,
  'tip'      => 'Top-left x position of scan area.',
  'default'  => 0,
  constraint => {
   'min'  => 0,
   'max'  => 210,
   'step' => 0.0999908,
  },
  'unit' => 'mm',
 },
 {
  name       => 't',
  index      => 6,
  'tip'      => 'Top-left y position of scan area.',
  'default'  => 0,
  constraint => {
   'min'  => 0,
   'max'  => 297,
   'step' => 0.0999908,
  },
  'unit' => 'mm',
 },
 {
  name       => 'x',
  index      => 7,
  'tip'      => 'Width of scan-area.',
  'default'  => 209.981,
  constraint => {
   'min'  => 0,
   'max'  => 210,
   'step' => 0.0999908,
  },
  'unit' => 'mm',
 },
 {
  name       => 'y',
  index      => 8,
  'tip'      => 'Height of scan-area.',
  'default'  => 296.973,
  constraint => {
   'min'  => 0,
   'max'  => 297,
   'step' => 0.0999908,
  },
  'unit' => 'mm',
 }
);
is_deeply( $options->{array}, \@that, 'Brother_DCP-7025' );
