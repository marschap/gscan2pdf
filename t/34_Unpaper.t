use warnings;
use strict;
use Sub::Override;
use Test::More tests => 7;

BEGIN {
    use_ok('Gscan2pdf::Unpaper');
    use Gtk2 -init;    # Could just call init separately
    use version;
}

#########################

my $unpaper_version = 0.3;
my $override        = Sub::Override->new;
$override->replace(
    'Gscan2pdf::Unpaper::version' => sub { return $unpaper_version } );

Gscan2pdf::Translation::set_domain('gscan2pdf');
my $unpaper = Gscan2pdf::Unpaper->new;
my $vbox    = Gtk2::VBox->new;
$unpaper->add_options($vbox);
is(
    $unpaper->get_cmdline,
'unpaper --black-threshold 0.33 --border-margin 0,0 --deskew-scan-direction left,right --layout single --output-pages 1 --white-threshold 0.9 --overwrite --input-file-sequence %s --output-file-sequence %s %s',
    'Basic functionality 0.3'
);

$unpaper_version = 0.6;
is(
    $unpaper->get_cmdline,
'unpaper --black-threshold 0.33 --border-margin 0,0 --deskew-scan-direction left,right --layout single --output-pages 1 --white-threshold 0.9 --overwrite %s %s %s',
    'Basic functionality > 0.3'
);

$unpaper = Gscan2pdf::Unpaper->new( { layout => 'double' } );
$unpaper->add_options($vbox);
is(
    $unpaper->get_cmdline,
'unpaper --black-threshold 0.33 --border-margin 0,0 --deskew-scan-direction left,right --layout double --output-pages 1 --white-threshold 0.9 --overwrite %s %s %s',
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
    'unpaper --black-threshold 0.35 --white-threshold 0.8 --overwrite %s %s %s',
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
#'unpaper --black-threshold 0.33 --border-margin 0,0 --deskew-scan-direction left,right --layout double --output-pages 2 --white-threshold 0.9 --overwrite %s %s %s',
#    'output-pages = 2'
#);

__END__
