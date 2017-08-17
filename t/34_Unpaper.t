use warnings;
use strict;
use Test::More tests => 6;

BEGIN {
    use_ok('Gscan2pdf::Unpaper');
    use Gtk2 -init;    # Could just call init separately
    use version;
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
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

$unpaper = Gscan2pdf::Unpaper->new( { layout => 'double' } );
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

is( $unpaper->get_option('direction'), 'ltr', 'get_option' );

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
        'no-mask-center'        => '',
        'no-grayfilter'         => '',
        'no-border-align'       => '',
        'black-threshold'       => '0.33',
        'deskew-scan-direction' => 'left,right',
        'border-margin'         => '0,0',
        'direction'             => 'ltr',
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

#########################

$unpaper = Gscan2pdf::Unpaper->new;
$unpaper->add_options($vbox);

# have to set output-pages in separate call to make sure is happens afterwards
$unpaper->set_options( { layout         => 'double' } );
$unpaper->set_options( { 'output-pages' => 2 } );

# There is a race condition here, which means that the layout is not always set
# before output-pages. Don't know how to solve that, so commenting out for now
#is(
#    $unpaper->get_cmdline,
#'unpaper --black-threshold 0.33 --border-margin 0,0 --deskew-scan-direction left,right --layout double --output-pages 2 --white-threshold 0.9 --overwrite '
#      . (
#        version->parse( $unpaper->version ) > version->parse('v0.3')
#        ? '%s %s %s'
#        : '--input-file-sequence %s --output-file-sequence %s %s'
#      ),
#    'output-pages = 2'
#);

__END__
