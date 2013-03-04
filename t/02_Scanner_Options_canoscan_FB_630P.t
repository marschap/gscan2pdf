use warnings;
use strict;
use Test::More tests => 3;
use Sane 0.05;    # For enums
BEGIN { use_ok('Gscan2pdf::Scanner::Options') }

#########################

my $filename = 'scanners/canoscan_FB_630P';
my $output   = do { local ( @ARGV, $/ ) = $filename; <> };
my $options  = Gscan2pdf::Scanner::Options->new_from_data($output);
my @that     = (
 {
  'index' => 0,
 },
 {
  name            => 'resolution',
  title           => 'Resolution',
  index           => 1,
  'desc'          => 'Sets the resolution of the scanned image.',
  'val'           => '75',
  'constraint'    => [ '75', '150', '300', '600' ],
  'unit'          => SANE_UNIT_DPI,
  constraint_type => SANE_CONSTRAINT_WORD_LIST,
  type            => SANE_TYPE_INT,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name   => 'mode',
  title  => 'Mode',
  index  => 2,
  'desc' => 'Selects the scan mode (e.g., lineart, monochrome, or color).',
  'val'  => 'Gray',
  'constraint'    => [ 'Gray', 'Color' ],
  'unit'          => SANE_UNIT_NONE,
  constraint_type => SANE_CONSTRAINT_STRING_LIST,
  type            => SANE_TYPE_STRING,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name  => 'depth',
  title => 'Depth',
  index => 3,
  'desc' =>
'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
  'val'           => '8',
  'constraint'    => [ '8', '12' ],
  'unit'          => SANE_UNIT_NONE,
  constraint_type => SANE_CONSTRAINT_WORD_LIST,
  type            => SANE_TYPE_INT,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name       => 'l',
  title      => 'Top-left x',
  index      => 4,
  'desc'     => 'Top-left x position of scan area.',
  'val'      => 0,
  constraint => {
   'min'   => 0,
   'max'   => 215,
   'quant' => 1869504867,
  },
  'unit'          => SANE_UNIT_MM,
  constraint_type => SANE_CONSTRAINT_RANGE,
  type            => SANE_TYPE_INT,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name       => 't',
  title      => 'Top-left y',
  index      => 5,
  'desc'     => 'Top-left y position of scan area.',
  'val'      => 0,
  constraint => {
   'min'   => 0,
   'max'   => 296,
   'quant' => 1852795252,
  },
  'unit'          => SANE_UNIT_MM,
  constraint_type => SANE_CONSTRAINT_RANGE,
  type            => SANE_TYPE_INT,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name       => 'x',
  title      => 'Width',
  index      => 6,
  'desc'     => 'Width of scan-area.',
  'val'      => 100,
  constraint => {
   'min'   => 3,
   'max'   => 216,
   'quant' => 16,
  },
  'unit'          => SANE_UNIT_MM,
  constraint_type => SANE_CONSTRAINT_RANGE,
  type            => SANE_TYPE_INT,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name       => 'y',
  title      => 'Height',
  index      => 7,
  'desc'     => 'Height of scan-area.',
  'val'      => 100,
  constraint => {
   'min' => 1,
   'max' => 297,
  },
  'unit'          => SANE_UNIT_MM,
  constraint_type => SANE_CONSTRAINT_RANGE,
  type            => SANE_TYPE_INT,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 1,
 },
 {
  name            => 'quality-cal',
  title           => 'Quality cal',
  'val'           => '',
  index           => 8,
  'desc'          => 'Do a quality white-calibration',
  'unit'          => SANE_UNIT_NONE,
  constraint_type => SANE_CONSTRAINT_NONE,
  type            => SANE_TYPE_BUTTON,
  'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
  'max_values'    => 0,
 },
);
is_deeply( $options->{array}, \@that, 'canoscan_FB_630P' );
is( Gscan2pdf::Scanner::Options->device, 'canon_pp:parport0', 'device name' );
