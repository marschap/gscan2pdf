package Gscan2pdf::Cuneiform;

use 5.008005;
use strict;
use warnings;
use Carp;
use File::Temp;                      # To create temporary files
use Gscan2pdf::Document;             # for slurp
use version;
use English qw( -no_match_vars );    # for $PROCESS_ID

our $VERSION = '1.8.1';

my $SPACE = q{ };
my $EMPTY = q{};
my ( %languages, $version, $setup, $logger );

sub setup {
    ( my $class, $logger ) = @_;
    return $version if $setup;

    my ( undef, $out, $err ) =
      Gscan2pdf::Document::exec_command( [ 'which', 'cuneiform' ] );
    return if ( not defined $out or $out eq $EMPTY );

    ( undef, $out, $err ) = Gscan2pdf::Document::exec_command( ['cuneiform'] );
    if ( $out =~ /^Cuneiform[ ]for[ ]Linux[ ]([\d.]+)/xsm ) { $version = $1 }

    $setup = 1;
    return $version;
}

sub languages {
    if ( not %languages ) {

        # cuneiform language codes
        my %lang = (
            eng    => 'English',
            ger    => 'German',
            fra    => 'French',
            rus    => 'Russian',
            swe    => 'Swedish',
            spa    => 'Spanish',
            ita    => 'Italian',
            ruseng => 'Russian+English',
            ukr    => 'Ukrainian',
            srp    => 'Serbian',
            hrv    => 'Croatian',
            pol    => 'Polish',
            dan    => 'Danish',
            por    => 'Portuguese',
            dut    => 'Dutch',
            cze    => 'Czech',
            rum    => 'Romanian',
            hun    => 'Hungarian',
            bul    => 'Bulgarian',
            slo    => 'Slovak',
            slv    => 'Slovenian',
            lav    => 'Latvian',
            lit    => 'Lithuanian',
            est    => 'Estonian',
            tur    => 'Turkish',
        );

        # Dig out supported languages
        my ( undef, $output ) =
          Gscan2pdf::Document::exec_command( [ 'cuneiform', '-l' ] );

        my $langs;
        if ( $output =~ /Supported[ ]languages:[ ](.*)[.]/xsm ) {
            $langs = $1;
            for ( split $SPACE, $langs ) {
                if ( defined $lang{$_} ) {
                    $languages{$_} = $lang{$_};
                }
                else {
                    $languages{$_} = $_;
                }
            }
        }
        else {
            $logger->info("Unrecognised output from cuneiform: $output");
        }
    }
    return \%languages;
}

sub hocr {
    my ( $class, %options ) = @_;
    my ($bmp);
    if ( not $setup ) { Gscan2pdf::Cuneiform->setup( $options{logger} ) }

    # Temporary filename for output
    my $txt = File::Temp->new( SUFFIX => '.txt' );

    if (
        (
            version->parse("v$version") < version->parse('v1.1.0')
            and $options{file} !~ /[.]bmp$/xsm
        )
        or ( defined $options{threshold} and $options{threshold} )
      )
    {

        # Temporary filename for new file
        $bmp = File::Temp->new( SUFFIX => '.bmp' );
        my $image = Image::Magick->new;
        $image->Read( $options{file} );

        my $x;
        if ( defined $options{threshold} and $options{threshold} ) {
            $logger->info("thresholding at $options{threshold} to $bmp");
            $image->BlackThreshold( threshold => "$options{threshold}%" );
            $image->WhiteThreshold( threshold => "$options{threshold}%" );
            $x = $image->Quantize( colors => 2 );
            $x = $image->Write( depth => 1, filename => $bmp );
        }
        else {
            $logger->info("writing temporary image $bmp");

# Force TrueColor, as this produces DirectClass, which is what cuneiform expects.
# Without this, PseudoClass is often produced, for which cuneiform gives
# "PUMA_XFinalrecognition failed" warnings
            $image->Write( filename => $bmp, type => 'TrueColor' );
        }
        if ("$x") { $logger->warn($x) }
    }
    else {
        $bmp = $options{file};
    }
    my $cmd = "cuneiform -l $options{language} -f hocr -o $txt $bmp";
    $logger->info($cmd);
    if ( defined $options{pidfile} ) {
        system "echo $PROCESS_ID > $options{pidfile};$cmd";
    }
    else {
        system $cmd;
    }
    return Gscan2pdf::Document::slurp($txt);
}

1;

__END__
