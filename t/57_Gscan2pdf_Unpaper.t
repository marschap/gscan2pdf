use warnings;
use strict;
use Test::More tests => 4;

BEGIN {
 use_ok('Gscan2pdf::Unpaper');
 use Gtk2 -init;    # Could just call init separately
}

#########################

my $unpaper = Gscan2pdf::Unpaper->new;
my $vbox    = Gtk2::VBox->new;
$unpaper->add_options($vbox);
is(
 $unpaper->get_cmdline,
'--output-pages 1 --white-threshold 0.9 --layout single --black-threshold 0.33 --deskew-scan-direction left,right --border-margin 0,0',
 'Basic functionality'
);

$unpaper = Gscan2pdf::Unpaper->new( { layout => 'Double' } );
$unpaper->add_options($vbox);
is(
 $unpaper->get_cmdline,
'--output-pages 1 --white-threshold 0.9 --layout double --black-threshold 0.33 --deskew-scan-direction left,right --border-margin 0,0',
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

__END__
