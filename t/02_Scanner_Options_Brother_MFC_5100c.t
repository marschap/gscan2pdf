use warnings;
use strict;
use Test::More tests => 3;
use Sane 0.05;    # For enums
BEGIN { use_ok('Gscan2pdf::Scanner::Options') }

#########################

my $filename = 'scanners/Brother_MFC_5100c';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new_from_data($output);
my @that     = (
 {
  'index' => 0,
 },
 {
  title             => 'Mode',
  'index'           => 1,
  type              => SANE_TYPE_GROUP,
  'cap'             => 0,
  'max_values'      => 0,
  'name'            => '',
  'unit'            => SANE_UNIT_NONE,
  'desc'            => '',
  type              => SANE_TYPE_GROUP,
  'constraint_type' => SANE_CONSTRAINT_NONE
 },
 {
  name   => 'mode',
  title  => 'Mode',
  index  => 2,
  'desc' => 'Select the scan mode',
  'val'  => '24bit Color',
  'constraint' =>
    [ 'Black & White', 'Gray[Error Diffusion]', 'True Gray', '24bit Color', ],
  constraint_type => SANE_CONSTRAINT_STRING_LIST,
  'unit'          => SANE_UNIT_NONE,
  type            => SANE_TYPE_STRING,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name         => 'resolution',
  title        => 'Resolution',
  index        => 3,
  'desc'       => 'Sets the resolution of the scanned image.',
  'val'        => '200',
  'constraint' => [
   '100', '150', '200', '300', '400', '600', '1200', '2400', '4800', '9600'
  ],
  'unit'          => SANE_UNIT_DPI,
  constraint_type => SANE_CONSTRAINT_WORD_LIST,
  type            => SANE_TYPE_INT,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name            => 'source',
  title           => 'Source',
  index           => 4,
  'desc'          => 'Selects the scan source (such as a document-feeder).',
  'val'           => 'Automatic Document Feeder',
  'constraint'    => [ 'FlatBed', 'Automatic Document Feeder' ],
  'unit'          => SANE_UNIT_NONE,
  constraint_type => SANE_CONSTRAINT_STRING_LIST,
  type            => SANE_TYPE_STRING,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name       => 'brightness',
  title      => 'Brightness',
  index      => 5,
  'desc'     => 'Controls the brightness of the acquired image.',
  constraint => {
   'min'   => -50,
   'max'   => 50,
   'quant' => 1,
  },
  'unit'          => SANE_UNIT_PERCENT,
  constraint_type => SANE_CONSTRAINT_RANGE,
  type            => SANE_TYPE_INT,
  'cap' => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT + SANE_CAP_INACTIVE,
  'max_values' => 1,
 },
 {
  name       => 'contrast',
  title      => 'Contrast',
  index      => 6,
  'desc'     => 'Controls the contrast of the acquired image.',
  constraint => {
   'min'   => -50,
   'max'   => 50,
   'quant' => 1,
  },
  'unit'          => SANE_UNIT_PERCENT,
  constraint_type => SANE_CONSTRAINT_RANGE,
  type            => SANE_TYPE_INT,
  'cap' => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT + SANE_CAP_INACTIVE,
  'max_values' => 1,
 },
 {
  index             => 7,
  title             => 'Geometry',
  'cap'             => 0,
  'max_values'      => 0,
  'name'            => '',
  'unit'            => SANE_UNIT_NONE,
  'desc'            => '',
  type              => SANE_TYPE_GROUP,
  'constraint_type' => SANE_CONSTRAINT_NONE
 },
 {
  name       => 'l',
  title      => 'Top-left x',
  index      => 8,
  'desc'     => 'Top-left x position of scan area.',
  'val'      => 0,
  constraint => {
   'min'   => 0,
   'max'   => 208,
   'quant' => 0.0999908,
  },
  constraint_type => SANE_CONSTRAINT_RANGE,
  'unit'          => SANE_UNIT_MM,
  type            => SANE_TYPE_FIXED,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name       => 't',
  title      => 'Top-left y',
  index      => 9,
  'desc'     => 'Top-left y position of scan area.',
  'val'      => 0,
  constraint => {
   'min'   => 0,
   'max'   => 355.6,
   'quant' => 0.0999908,
  },
  constraint_type => SANE_CONSTRAINT_RANGE,
  'unit'          => SANE_UNIT_MM,
  type            => SANE_TYPE_FIXED,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name       => 'x',
  title      => 'Width',
  index      => 10,
  'desc'     => 'Width of scan-area.',
  'val'      => 207.981,
  constraint => {
   'min'   => 0,
   'max'   => 208,
   'quant' => 0.0999908,
  },
  constraint_type => SANE_CONSTRAINT_RANGE,
  'unit'          => SANE_UNIT_MM,
  type            => SANE_TYPE_FIXED,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name       => 'y',
  title      => 'Height',
  index      => 11,
  'desc'     => 'Height of scan-area.',
  'val'      => 296.973,
  constraint => {
   'min'   => 0,
   'max'   => 355.6,
   'quant' => 0.0999908,
  },
  constraint_type => SANE_CONSTRAINT_RANGE,
  'unit'          => SANE_UNIT_MM,
  type            => SANE_TYPE_FIXED,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 }
);
is_deeply( $options->{array}, \@that, 'Brother_MFC_5100c' );
is( Gscan2pdf::Scanner::Options->device, 'brother:bus1;dev2', 'device name' );
