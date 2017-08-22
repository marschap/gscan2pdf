package Gscan2pdf::Cuneiform;

use 5.008005;
use strict;
use warnings;
use Carp;
use File::Temp;                      # To create temporary files
use Gscan2pdf::Document;             # for slurp
use version;
use English qw( -no_match_vars );    # for $PROCESS_ID

our $VERSION = '1.8.6';

my $SPACE = q{ };
my $EMPTY = q{};
my ( %languages, $version, $setup, $logger );

# cuneiform language codes
my %iso639 = (
    bul    => { code => 'bul',    name => 'Bulgarian' },
    ces    => { code => 'cze',    name => 'Czech' },
    dan    => { code => 'dan',    name => 'Danish' },
    deu    => { code => 'ger',    name => 'German' },
    eng    => { code => 'eng',    name => 'English' },
    est    => { code => 'est',    name => 'Estonian' },
    fra    => { code => 'fra',    name => 'French' },
    hrv    => { code => 'hrv',    name => 'Croatian' },
    hun    => { code => 'hun',    name => 'Hungarian' },
    lav    => { code => 'lav',    name => 'Latvian' },
    lit    => { code => 'lit',    name => 'Lithuanian' },
    nld    => { code => 'dut',    name => 'Dutch' },
    ita    => { code => 'ita',    name => 'Italian' },
    pol    => { code => 'pol',    name => 'Polish' },
    por    => { code => 'por',    name => 'Portuguese' },
    ron    => { code => 'rum',    name => 'Romanian' },
    rus    => { code => 'rus',    name => 'Russian' },
    ruseng => { code => 'ruseng', name => 'Russian+English' },
    slk    => { code => 'slo',    name => 'Slovak' },
    slv    => { code => 'slv',    name => 'Slovenian' },
    spa    => { code => 'spa',    name => 'Spanish' },
    srp    => { code => 'srp',    name => 'Serbian' },
    swe    => { code => 'swe',    name => 'Swedish' },
    tur    => { code => 'tur',    name => 'Turkish' },
    ukr    => { code => 'ukr',    name => 'Ukrainian' },
);

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
        my %cunmap;
        for my $key ( keys %iso639 ) {
            $cunmap{ $iso639{$key}{code} } = $key;
        }

        # Dig out supported languages
        my ( undef, $output ) =
          Gscan2pdf::Document::exec_command( [ 'cuneiform', '-l' ] );

        my $langs;
        if ( $output =~ /Supported[ ]languages:[ ](.*)[.]/xsm ) {
            $langs = $1;
            for ( split $SPACE, $langs ) {
                if ( defined $cunmap{$_} ) {
                    $languages{ $cunmap{$_} } = $iso639{ $cunmap{$_} }{name};
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

    # Map the iso639 language code back to an cuneiform code
    if ( defined $iso639{ $options{language} } ) {
        $options{language} = $iso639{ $options{language} }{code};
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
