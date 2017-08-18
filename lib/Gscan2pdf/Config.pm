package Gscan2pdf::Config;

use strict;
use warnings;
use Gscan2pdf::Document;
use Gscan2pdf::Translation '__';    # easier to extract strings with xgettext
use Glib qw(TRUE FALSE);            # To get TRUE and FALSE
use File::Copy;
use Try::Tiny;
use Data::Dumper;
use Config::General 2.40;
use JSON::PP;
use version;

BEGIN {
    use Exporter ();
    our ( $VERSION, @EXPORT_OK, %EXPORT_TAGS );

    $VERSION = '1.8.5';

    use base qw(Exporter);
    %EXPORT_TAGS = ();    # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK = qw();
}

my $EMPTY = q{};

sub _pre_151 {
    my ( $version, $SETTING ) = @_;
    if ( version->parse($version) < version->parse('1.5.1') ) {
        if ( defined $SETTING->{profile}
            and ref( $SETTING->{profile} ) eq 'HASH' )
        {
            for my $name ( keys %{ $SETTING->{profile} } ) {
                if ( ref( $SETTING->{profile}{$name} ) eq 'ARRAY' ) {
                    $SETTING->{profile}{$name} =
                      _add_profile_backend( $SETTING->{profile}{$name} );
                }
                elsif ( ref( $SETTING->{profile}{$name} ) eq 'HASH' ) {
                    $SETTING->{profile}{$name} =
                      _add_profile_backend(
                        _hash_profile_to_array( $SETTING->{profile}{$name} ) );
                }
                else {
                    delete $SETTING->{profile}{$name};
                }
            }
        }
        if ( defined $SETTING->{'default-scan-options'} ) {
            if ( ref( $SETTING->{'default-scan-options'} ) eq 'ARRAY' ) {
                $SETTING->{'default-scan-options'} =
                  _add_profile_backend( $SETTING->{'default-scan-options'} );
            }
            elsif ( ref( $SETTING->{'default-scan-options'} ) eq 'HASH' ) {
                $SETTING->{'default-scan-options'} = _add_profile_backend(
                    _hash_profile_to_array(
                        $SETTING->{'default-scan-options'}
                    )
                );
            }
            else {
                delete $SETTING->{'default-scan-options'};
            }
        }
    }
    return;
}

sub _pre_171 {
    my ( $version, $SETTING ) = @_;
    if ( version->parse($version) < version->parse('1.7.1') ) {
        if ( defined $SETTING->{'keyword-suggestions'} ) {
            $SETTING->{'keywords-suggestions'} =
              $SETTING->{'keyword-suggestions'};
            delete $SETTING->{'keyword-suggestions'};
        }
    }
    return;
}

sub _pre_181 {
    my ( $version, $SETTING ) = @_;
    if ( version->parse($version) < version->parse('1.8.1') ) {
        if ( defined $SETTING->{'default filename'} ) {
            $SETTING->{'default filename'} =~ s/%a/%Da/gsm;
            $SETTING->{'default filename'} =~ s/%t/%Dt/gsm;
            $SETTING->{'default filename'} =~ s/%y/%DY/gsm;
            $SETTING->{'default filename'} =~ s/%m/%Dm/gsm;
            $SETTING->{'default filename'} =~ s/%d/%Dd/gsm;
            $SETTING->{'default filename'} =~ s/%M/%m/gsm;
            $SETTING->{'default filename'} =~ s/%D\b/%d/gsmx;
            $SETTING->{'default filename'} =~ s/%I/%M/gsm;
        }
    }
    return;
}

sub _pre_184 {
    my ( $version, $SETTING ) = @_;
    if ( version->parse($version) < version->parse('1.8.4') ) {
        if ( defined $SETTING->{'frontend'}
            and $SETTING->{'frontend'} eq 'libsane-perl' )
        {
            $SETTING->{'frontend'} = 'libimage-sane-perl';
        }
    }
    return;
}

sub read_config {
    my ( $filename, $logger ) = @_;
    my ( %SETTING, $conf );
    $logger->info("Reading config from $filename");
    if ( not -r $filename ) {
        Gscan2pdf::Document::exec_command( [ 'touch', $filename ] );
    }

    # from v1.3.3 onwards, the config file is saved as JSON
    my $config  = Gscan2pdf::Document::slurp($filename);
    my $version = '2';
    if ( $config =~ /^\s*"?version"?\s*[=:]\s*"?([\d.]+)"?/xsm ) {
        $version = $1;
    }
    $logger->info("Config file version $version");

    if ( version->parse($version) < version->parse('1.3.3') ) {
        try {
            $conf = Config::General->new(
                -ConfigFile  => $filename,
                -SplitPolicy => 'equalsign',
                -UTF8        => 1,
            );
        }
        catch {
            $logger->error(
"Error: unable to load settings.\nBacking up settings\nReverting to defaults"
            );
            move( $filename, "$filename.old" );
        }
        finally {
            if ( not @_ ) { %SETTING = $conf->getall }
        };
    }
    elsif ( length $config > 0 ) {
        $conf    = JSON::PP->new->ascii;
        $conf    = $conf->pretty->allow_nonref;
        %SETTING = %{ $conf->decode($config) };
    }

    if ( defined $SETTING{user_defined_tools}
        and ref( $SETTING{user_defined_tools} ) ne 'ARRAY' )
    {
        $SETTING{user_defined_tools} = [ $SETTING{user_defined_tools} ];
    }

    # remove undefined profiles
    if ( defined $SETTING{profile} ) {
        for my $profile ( keys %{ $SETTING{profile} } ) {
            if ( not defined $SETTING{profile}{$profile} ) {
                delete $SETTING{profile}{$profile};
            }
        }
    }

    _pre_151( $version, \%SETTING );

    _pre_171( $version, \%SETTING );

    _pre_181( $version, \%SETTING );

    _pre_184( $version, \%SETTING );

    $logger->debug( Dumper( \%SETTING ) );
    return %SETTING;
}

# If the profile is a hash, the order is undefined.
# Sort it to be consistent for tests.
sub _hash_profile_to_array {
    my ($profile_hashref) = @_;
    my @clone;
    for my $key ( sort keys %{$profile_hashref} ) {
        push @clone, { $key => $profile_hashref->{$key} };
    }
    return \@clone;
}

sub _add_profile_backend {
    my ($profile_arrayref) = @_;
    my $profile;
    $profile->{backend} = $profile_arrayref;
    return $profile;
}

sub add_defaults {
    my ($SETTING) = @_;
    my %default_settings = (
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
        version                             => undef,
        'SANE version'                      => undef,
        'libimage-sane-perl version'        => undef,
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
        'downsample'                        => FALSE,
        'downsample dpi'                    => 150,
        'cache options'                     => TRUE,
        cache                               => undef,
        'restore window'                    => TRUE,
        'set_timestamp'                     => TRUE,
        'date offset'                       => 0,
        'pdf compression'                   => 'auto',
        'tiff compression'                  => undef,
        'pdf font'                          => undef,
        quality                             => 75,
        'image type'                        => undef,
        device                              => undef,
        'device blacklist'                  => undef,
        frontend                            => 'libimage-sane-perl',
        'scan prefix'                       => $EMPTY,
        'unpaper on scan'                   => FALSE,
        'unpaper options'                   => undef,
        'unsharp radius'                    => 0,
        'unsharp sigma'                     => 1,
        'unsharp amount'                    => 1,
        'unsharp threshold'                 => 0.05,
        'allow-batch-flatbed'               => FALSE,
        'adf-defaults-scan-all-pages'       => TRUE,
        'cycle sane handle'                 => FALSE,
        profile                             => undef,
        'default profile'                   => undef,
        'default-scan-options'              => undef,
        'rotate facing'                     => 0,
        'rotate reverse'                    => 0,
        'default filename'                  => '%Da %DY-%Dm-%Dd',
        'convert whitespace to underscores' => FALSE,
        'view files toggle'                 => TRUE,
        'threshold-before-ocr'              => FALSE,
        'brightness tool'                   => 65,
        'contrast tool'                     => 65,
        'threshold tool'                    => 80,
        'Blank threshold' => 0.005,    # Blank page standard deviation threshold
        'Dark threshold'  => 0.12,     # Dark page mean threshold
        'OCR on scan'     => TRUE,
        'ocr engine'   => 'tesseract',
        'ocr language' => undef,
        'OCR output' =>
          'replace',   # When a page is re-OCRed, replace old text with new text
        ps_backend              => 'pdftops',
        user_defined_tools      => ['gimp %i'],
        udt_on_scan             => FALSE,
        current_udt             => undef,
        post_save_hook          => FALSE,
        current_psh             => undef,
        'auto-open-scan-dialog' => TRUE,
        'available-tmp-warning' => 10,
        close_dialog_on_save    => TRUE,
        'Paper'                 => {
            __('A3') => {
                x => 297,
                y => 420,
                l => 0,
                t => 0,
            },
            __('A4') => {
                x => 210,
                y => 297,
                l => 0,
                t => 0,
            },
            __('US Letter') => {
                x => 216,
                y => 279,
                l => 0,
                t => 0,
            },
            __('US Legal') => {
                x => 216,
                y => 356,
                l => 0,
                t => 0,
            },
        },

        # show the options marked with 1, hide those with 0
        # for the others, see the value of default-option-visibility
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
    if (
        defined $SETTING->{frontend}
        and ( $SETTING->{frontend} !~
            /^(?:scanimage|scanadf|libimage-sane-perl)$/xsm )
      )
    {
        delete $SETTING->{frontend};
    }

    # remove unused settings
    for ( keys %{$SETTING} ) {
        if ( not exists $default_settings{$_} ) {
            delete $SETTING->{$_};
        }
    }

    # add default settings
    for ( keys %default_settings ) {
        if ( not defined $SETTING->{$_} ) {
            $SETTING->{$_} = $default_settings{$_};
        }
    }
    return;
}

sub remove_invalid_paper {
    my ($hashref) = @_;
    for my $paper ( keys %{$hashref} ) {
        if ( $paper eq '<>' or $paper eq '</>' ) {
            delete $hashref->{$paper};
        }
        else {
            for (qw(x y t l)) {
                if ( ref( $hashref->{$paper} ) ne 'HASH'
                    or not defined $hashref->{$paper}{$_} )
                {
                    delete $hashref->{$paper};
                    last;
                }
            }
        }
    }
    return;
}

# Delete the options cache if there is a new version of SANE
sub check_sane_version {
    my ( $SETTING, $SANE, $LIBSANEPERL ) = @_;
    if ( defined $SETTING->{'SANE version'}
        and $SETTING->{'SANE version'} ne $SANE )
    {
        if ( defined $SETTING->{cache} ) { delete $SETTING->{cache} }
    }
    $SETTING->{'SANE version'}               = $SANE;
    $SETTING->{'libimage-sane-perl version'} = $LIBSANEPERL;
    return;
}

sub write_config {
    my ( $rc, $logger, $SETTING ) = @_;
    my $conf = JSON::PP->new->ascii;
    $conf = $conf->pretty->allow_nonref;
    $conf = $conf->canonical;
    open my $fh, '>', $rc or die "Error: cannot open $rc\n";
    print {$fh} $conf->encode($SETTING) or die "Error: cannot write to $rc\n";
    close $fh or die "Error: cannot close $rc\n";
    $logger->info("Wrote config to $rc");
    return;
}

1;

__END__
