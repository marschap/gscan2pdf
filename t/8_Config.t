use warnings;
use strict;
use Gscan2pdf::Document;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Test::More tests => 18;

BEGIN {
    use_ok('Gscan2pdf::Config');
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($FATAL);
my $logger = Log::Log4perl::get_logger;

my $EMPTY = q{};
my $rc    = 'test';

#########################

my $config = <<'EOS';
version = 1.3.2
EOS
open my $fh, '>', $rc or die "Error: cannot open $rc\n";
print $fh $config;
close $fh or die "Error: cannot close $rc\n";

my %example = ( version => '1.3.2' );
my %output = Gscan2pdf::Config::read_config( $rc, $logger );

is_deeply( \%output, \%example, 'Read Config::General' );

#########################

$config = <<'EOS';
{
   "version" : "1.3.3"
}
EOS
open $fh, '>', $rc or die "Error: cannot open $rc\n";
print $fh $config;
close $fh or die "Error: cannot close $rc\n";

%example = ( version => '1.3.3' );
%output = Gscan2pdf::Config::read_config( $rc, $logger );

is_deeply( \%output, \%example, 'Read JSON' );

#########################

Gscan2pdf::Config::write_config( $rc, $logger, \%example );

my @example = split "\n", $config;
my @output  = split "\n", Gscan2pdf::Document::slurp($rc);

is_deeply( \@output, \@example, 'Write JSON' );

#########################

%output = %example;
$output{'non-existant-option'} = undef;
Gscan2pdf::Config::add_defaults( \%output );
%example = (
    version                             => '1.3.3',
    'SANE version'                      => undef,
    'libimage-sane-perl version'        => undef,
    window_width                        => 800,
    window_height                       => 600,
    window_maximize                     => TRUE,
    window_x                            => undef,
    window_y                            => undef,
    'thumb panel'                       => 100,
    scan_window_width                   => undef,
    scan_window_height                  => undef,
    TMPDIR                              => undef,
    'Page range'                        => 'all',
    selection                           => undef,
    cwd                                 => undef,
    title                               => undef,
    'title-suggestions'                 => undef,
    author                              => undef,
    'author-suggestions'                => undef,
    subject                             => undef,
    'subject-suggestions'               => undef,
    keywords                            => undef,
    'keywords-suggestions'              => undef,
    device                              => undef,
    'device blacklist'                  => undef,
    'allow-batch-flatbed'               => FALSE,
    'cancel-between-pages'              => FALSE,
    'adf-defaults-scan-all-pages'       => TRUE,
    'cycle sane handle'                 => FALSE,
    'downsample'                        => FALSE,
    'downsample dpi'                    => 150,
    'threshold-before-ocr'              => FALSE,
    'threshold tool'                    => 80,
    'contrast tool'                     => 65,
    'brightness tool'                   => 65,
    'unsharp radius'                    => 0,
    'unsharp sigma'                     => 1,
    'unsharp amount'                    => 1,
    'unsharp threshold'                 => 0.05,
    'cache options'                     => TRUE,
    cache                               => undef,
    'restore window'                    => TRUE,
    'date offset'                       => 0,
    set_timestamp                       => TRUE,
    use_timezone                        => TRUE,
    use_time                            => FALSE,
    'pdf compression'                   => 'auto',
    'tiff compression'                  => undef,
    'pdf font'                          => undef,
    'quality'                           => 75,
    'image type'                        => undef,
    'unpaper on scan'                   => FALSE,
    'unpaper options'                   => undef,
    'OCR on scan'                       => TRUE,
    'frontend'                          => 'libimage-sane-perl',
    'rotate facing'                     => 0,
    'rotate reverse'                    => 0,
    'default filename'                  => '%Da %DY-%Dm-%Dd',
    'convert whitespace to underscores' => FALSE,
    'scan prefix'                       => $EMPTY,
    'Blank threshold'                   => 0.005,
    'Dark threshold'                    => 0.12,
    'ocr engine'                        => 'tesseract',
    'ocr language'                      => undef,
    'OCR output'                        => 'replace',
    ps_backend                          => 'pdftops',
    'auto-open-scan-dialog'             => TRUE,
    'available-tmp-warning'             => 10,
    close_dialog_on_save                => TRUE,
    'view files toggle'                 => TRUE,
    'Paper'                             => {
        'A3' => {
            x => 297,
            y => 420,
            l => 0,
            t => 0,
        },
        'A4' => {
            x => 210,
            y => 297,
            l => 0,
            t => 0,
        },
        'US Letter' => {
            x => 216,
            y => 279,
            l => 0,
            t => 0,
        },
        'US Legal' => {
            x => 216,
            y => 356,
            l => 0,
            t => 0,
        },
    },
    profile                => undef,
    'default profile'      => undef,
    'default-scan-options' => undef,
    user_defined_tools     => ['gimp %i'],
    udt_on_scan            => FALSE,
    current_udt            => undef,
    post_save_hook         => FALSE,
    current_psh            => undef,
    'visible-scan-options' => {
        mode                => 1,
        compression         => 1,
        resolution          => 1,
        brightness          => 1,
        gain                => 1,
        contrast            => 1,
        threshold           => 1,
        speed               => 1,
        'batch-scan'        => 1,
        'wait-for-button'   => 1,
        'button-wait'       => 1,
        'calibration-cache' => 1,
        source              => 1,
        pagewidth           => 1,
        pageheight          => 1,
        'page-width'        => 1,
        'page-height'       => 1,
        'overscan-top'      => 1,
        'overscan-bottom'   => 1,
        adf_mode            => 1,
        'adf-mode'          => 1,
        'Paper size'        => 1,
        x                   => 1,
        y                   => 1,
        l                   => 1,
        t                   => 1,
    },
    'scan-reload-triggers' => qw(mode),
    message                => undef,
);

is_deeply( \%output, \%example, 'add_defaults' );

#########################

$config = <<'EOS';
{
   "version" : "1.3.3",
   "frontend" : "scanimage-perl"
}
EOS
open $fh, '>', $rc or die "Error: cannot open $rc\n";
print $fh $config;
close $fh or die "Error: cannot close $rc\n";
%output = Gscan2pdf::Config::read_config( $rc, $logger );
Gscan2pdf::Config::add_defaults( \%output );
is_deeply( \%output, \%example, 'ignore invalid frontends' );

#########################

%output = (
    Paper => {
        1 => ['stuff']
    }
);
Gscan2pdf::Config::remove_invalid_paper( $output{Paper} );
%example = ( Paper => {} );
is_deeply( \%output, \%example, 'remove_invalid_paper (contents)' );

#########################

%output = (
    Paper => {
        '<>' => {
            x => 210,
            y => 297,
            l => 0,
            t => 0,
        }
    }
);
Gscan2pdf::Config::remove_invalid_paper( $output{Paper} );
%example = ( Paper => {} );
is_deeply( \%output, \%example, 'remove_invalid_paper (name)' );

#########################

%output = (
    'SANE version'               => '1.2.3',
    'libimage-sane-perl version' => 0.05,
    cache                        => ['stuff'],
);
Gscan2pdf::Config::check_sane_version( \%output, '1.2.4', 0.05 );
%example = (
    'SANE version'               => '1.2.4',
    'libimage-sane-perl version' => 0.05,
);
is_deeply( \%output, \%example, 'check_sane_version' );

#########################

$config = <<'EOS';
{
   "user_defined_tools" : "gimp %i"
}
EOS
open $fh, '>', $rc or die "Error: cannot open $rc\n";
print $fh $config;
close $fh or die "Error: cannot close $rc\n";

%example = ( user_defined_tools => ['gimp %i'] );
%output = Gscan2pdf::Config::read_config( $rc, $logger );

is_deeply( \%output, \%example, 'force user_defined_tools to be an array' );

#########################

$config = <<'EOS';
{
   "default-scan-options" : [
      {
         "source" : "Flatbed"
      }
   ],
   "profile" : {
      "10x10" : [
         {
            "br-y" : 10
         }
      ],
      "20x20" : [
         {
            "br-y" : 20
         }
      ]
   },
   "version" : "1.5.0"
}
EOS
open $fh, '>', $rc or die "Error: cannot open $rc\n";
print $fh $config;
close $fh or die "Error: cannot close $rc\n";

%example = (
    "default-scan-options" => {
        backend => [
            {
                "source" => "Flatbed"
            }
        ]
    },
    "profile" => {
        "10x10" => {
            backend => [
                {
                    "br-y" => 10
                }
            ]
        },
        "20x20" => {
            backend => [
                {
                    "br-y" => 20
                }
            ]
        }
    },
    "version" => "1.5.0"
);
%output = Gscan2pdf::Config::read_config( $rc, $logger );

is_deeply( \%output, \%example,
    'convert pre-v1.5.1 profiles to v1.5.1 format' );

#########################

$config = <<'EOS';
{
   "default-scan-options" : {
         "source" : "Flatbed"
      },
   "profile" : {
      "10x10" : {
            "br-y" : 10
         },
      "20x20" : {
            "br-y" : 20
         }
   },
   "version" : "1.5.0"
}
EOS
open $fh, '>', $rc or die "Error: cannot open $rc\n";
print $fh $config;
close $fh or die "Error: cannot close $rc\n";

%example = (
    "default-scan-options" => {
        backend => [
            {
                "source" => "Flatbed"
            }
        ]
    },
    profile => {
        "10x10" => {
            backend => [
                {
                    "br-y" => 10
                }
            ]
        },
        "20x20" => {
            backend => [
                {
                    "br-y" => 20
                }
            ]
        }
    },
    "version" => "1.5.0"
);
%output = Gscan2pdf::Config::read_config( $rc, $logger );

is_deeply( \%output, \%example, 'convert old hashed profiles to arrays' );

#########################

$config = <<'EOS';
{
   "keyword-suggestions" : [ "key1", "key2" ],
   "version" : "1.7.0"
}
EOS
open $fh, '>', $rc or die "Error: cannot open $rc\n";
print $fh $config;
close $fh or die "Error: cannot close $rc\n";

%example = (
    "keywords-suggestions" => [ "key1", "key2" ],
    "version"              => "1.7.0"
);
%output = Gscan2pdf::Config::read_config( $rc, $logger );

is_deeply( \%output, \%example,
    'convert keyword-suggestions->keywords-suggestions' );

#########################

$config = <<'EOS';
{
   "profile" : {
      "crash" : null
   },
   "version" : "1.7.3"
}
EOS
open $fh, '>', $rc or die "Error: cannot open $rc\n";
print $fh $config;
close $fh or die "Error: cannot close $rc\n";

%example = (
    profile   => {},
    "version" => "1.7.3"
);
%output = Gscan2pdf::Config::read_config( $rc, $logger );

is_deeply( \%output, \%example, 'remove undefined profiles' );

#########################

$config = <<'EOS';
{
   "default filename" : "%a %t %y %Y %m %M %d %D %H %I %S",
   "version" : "1.8.0"
}
EOS
open $fh, '>', $rc or die "Error: cannot open $rc\n";
print $fh $config;
close $fh or die "Error: cannot close $rc\n";

%example = (
    "default filename" => "%Da %Dt %DY %Y %Dm %m %Dd %d %H %M %S",
    "version"          => "1.8.0"
);
%output = Gscan2pdf::Config::read_config( $rc, $logger );

is_deeply( \%output, \%example, 'convert pre-1.8.1 filename codes' );

#########################

$config = <<'EOS';
{
   "frontend" : "libsane-perl",
   "version" : "1.8.0"
}
EOS
open $fh, '>', $rc or die "Error: cannot open $rc\n";
print $fh $config;
close $fh or die "Error: cannot close $rc\n";

%example = (
    "frontend" => "libimage-sane-perl",
    "version"  => "1.8.0"
);
%output = Gscan2pdf::Config::read_config( $rc, $logger );

is_deeply( \%output, \%example, 'convert pre-1.8.4 frontend' );

#########################

$config = <<'EOS';
{
   "version" : "
}
EOS
open $fh, '>', $rc or die "Error: cannot open $rc\n";
print $fh $config;
close $fh or die "Error: cannot close $rc\n";

%example = ();
%output = Gscan2pdf::Config::read_config( $rc, $logger );

is_deeply( \%output, \%example, 'deal with corrupt config' );

#########################

$config = <<'EOS';
{
   "selection" : [ 0, 0, 1289, 2009 ],
   "version" : "1.8.11"
}
EOS
open $fh, '>', $rc or die "Error: cannot open $rc\n";
print $fh $config;
close $fh or die "Error: cannot close $rc\n";

%example = (
    "selection" => { x => 0, y => 0, width => 1289, height => 2009 },
    "version"   => "1.8.11"
);
%output = Gscan2pdf::Config::read_config( $rc, $logger );

is_deeply( \%output, \%example, 'convert pre-2.0.0 selection' );

#########################

unlink $rc;

__END__
