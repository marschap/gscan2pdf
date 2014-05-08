use warnings;
use strict;
use Test::More tests => 5;

BEGIN {
 use_ok('Gscan2pdf::Unpaper');
 use Gtk2 -init;    # Could just call init separately
 use version;
}

#########################

my $unpaper = Gscan2pdf::Unpaper->new;
my $vbox    = Gtk2::VBox->new;
$unpaper->add_options($vbox);
is(
 $unpaper->get_cmdline,
'unpaper --black-threshold 0.33 --border-margin 0,0 --deskew-scan-direction left,right --layout single --output-pages 1 --white-threshold 0.9 --overwrite '
   . (
  version->parse( $unpaper->version ) > version->parse('v0.3')
  ? '%s %s %s'
  : '--input-file-sequence %s --output-file-sequence %s %s'
   ),
 'Basic functionality'
);

$unpaper = Gscan2pdf::Unpaper->new( { layout => 'Double' } );
$unpaper->add_options($vbox);
is(
 $unpaper->get_cmdline,
'unpaper --black-threshold 0.33 --border-margin 0,0 --deskew-scan-direction left,right --layout double --output-pages 1 --white-threshold 0.9 --overwrite '
   . (
  version->parse( $unpaper->version ) > version->parse('v0.3')
  ? '%s %s %s'
  : '--input-file-sequence %s --output-file-sequence %s %s'
   ),
 'Defaults'
);

is_deeply(
 $unpaper->get_options,
 {
  'no-blackfilter'        => '',
  'output-pages'          => '1',
  'no-deskew'             => '',
  'no-border-scan'        => '',
  'no-noisefilter'        => '',
  'no-blurfilter'         => '',
  'white-threshold'       => '0.9',
  'layout'                => 'double',
  'no-mask-scan'          => '',
  'no-grayfilter'         => '',
  'no-border-align'       => '',
  'black-threshold'       => '0.33',
  'deskew-scan-direction' => 'left,right',
  'border-margin'         => '0,0'
 },
 'get_options'
);

#########################

$unpaper = Gscan2pdf::Unpaper->new(
 {
  'white-threshold' => '0.8',
  'black-threshold' => '0.35',
 },
);

is(
 $unpaper->get_cmdline,
 'unpaper --black-threshold 0.35 --white-threshold 0.8 --overwrite '
   . (
  version->parse( $unpaper->version ) > version->parse('v0.3')
  ? '%s %s %s'
  : '--input-file-sequence %s --output-file-sequence %s %s'
   ),
 'no GUI'
);

__END__
