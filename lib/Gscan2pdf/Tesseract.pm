package Gscan2pdf::Tesseract;

use 5.008005;
use strict;
use warnings;
use Carp;
use Encode;
use File::Temp;    # To create temporary files
use File::Basename;
use Gscan2pdf::Document;             # for slurp
use version;
use English qw( -no_match_vars );    # for $PROCESS_ID

our $VERSION = '1.8.3';
my $EMPTY = q{};
my $COMMA = q{,};

my ( %languages, $installed, $setup, $version, $tessdata, $datasuffix,
    $logger );

sub setup {
    ( my $class, $logger ) = @_;
    return $installed if $setup;

    ( undef, my $exe ) =
      Gscan2pdf::Document::exec_command( [ 'which', 'tesseract' ] );
    return if ( not defined $exe or $exe eq $EMPTY );
    $installed = 1;

    # if we have 3.02.01 or better,
    # we can use --list-langs and not bother with tessdata
    ( undef, my $out, my $err ) =
      Gscan2pdf::Document::exec_command( [ 'tesseract', '-v' ] );
    if ( $err =~ /^tesseract[ ]([\d.]+)/xsm ) {
        $version = $1;
    }
    elsif ( $out =~ /^tesseract[ ]([\d.]+)/xsm ) {
        $version = $1;
    }
    if ( $version and version->parse("v$version") > version->parse('v3.02') ) {
        $logger->info("Found tesseract version $version.");
        $setup = 1;
        return $installed;
    }

    ( $out, $err ) =
      Gscan2pdf::Document::exec_command( ["tesseract '' '' -l ''"] );
    ( $tessdata, $version, $datasuffix ) = parse_tessdata( $out . $err );

    if ( not defined $tessdata ) {
        if ( $version
            and version->parse("v$version") > version->parse('v3.01') )
        {
            ( undef, my $lib ) =
              Gscan2pdf::Document::exec_command( [ 'ldd', $exe ] );
            if ( $lib =~ /libtesseract[.]so[.]\d+[ ]=>[ ]([\/\w\-.]+)[ ]/xsm ) {
                ( undef, $out ) =
                  Gscan2pdf::Document::exec_command( [ 'strings', $1 ] );
                $tessdata = parse_strings($out);
            }
            else {
                return;
            }
        }
        else {
            return;
        }
    }

    $logger->info(
        "Found tesseract version $version. Using tessdata at $tessdata");
    $setup = 1;
    return $installed;
}

sub parse_tessdata {
    my @output = @_;
    my $output = join $COMMA, @output;
    my ( $v, $suffix );
    if ( $output =~ /[ ]v(\d[.]\d\d)[ ]/xsm ) {
        $v = $1;
    }
    if ( $output =~ /Unable[ ]to[ ]load[ ]unicharset[ ]file[ ]([^\n]+)/xsm ) {
        $output = $1;
        if ( not defined $v ) { $v = '2' }
        $suffix = '.unicharset';
    }
    elsif ( $output =~ /Error[ ]openn?ing[ ]data[ ]file[ ]([^\n]+)/xsm ) {
        $output = $1;
        if ( not defined $v ) { $v = '3' }
        $suffix = '.traineddata';
    }
    elsif ( defined $v and version->parse("v$v") > version->parse('v3.01') ) {
        return ( undef, $v + 0, '.traineddata' );
    }
    else {
        return;
    }
    $output =~ s/\/ $suffix $//xsm;
    return $output, $v + 0, $suffix;
}

sub parse_strings {
    my ($strings) = @_;
    my @strings = split /\n/xsm, $strings;
    for (@strings) {
        return $_ . 'tessdata' if (/\/ share \//xsm);
    }
    return;
}

sub languages {
    if ( not %languages ) {
        my %iso639 = (
            ara        => 'Arabic',
            bul        => 'Bulgarian',
            cat        => 'Catalan',
            ces        => 'Czech',
            chr        => 'Cherokee',
            chi_tra    => 'Chinese (Traditional)',
            chi_sim    => 'Chinese (Simplified)',
            dan        => 'Danish',
            'dan-frak' => 'Danish (Fraktur)',
            deu        => 'German',
            'deu-f'    => 'German (Fraktur)',
            'deu-frak' => 'German (Fraktur)',
            ell        => 'Greek',
            eng        => 'English',
            fin        => 'Finish',
            fra        => 'French',
            heb        => 'Hebrew',
            hin        => 'Hindi',
            hun        => 'Hungarian',
            ind        => 'Indonesian',
            ita        => 'Italian',
            jpn        => 'Japanese',
            kor        => 'Korean',
            lav        => 'Latvian',
            lit        => 'Lituanian',
            nld        => 'Dutch',
            nor        => 'Norwegian',
            pol        => 'Polish',
            por        => 'Portuguese',
            que        => 'Quechua',
            ron        => 'Romanian',
            rus        => 'Russian',
            slk        => 'Slovak',
            'slk-frak' => 'Slovak (Fraktur)',
            slv        => 'Slovenian',
            spa        => 'Spanish',
            srp        => 'Serbian (Latin)',
            swe        => 'Swedish',
            'swe-frak' => 'Swedish (Fraktur)',
            tha        => 'Thai',
            tlg        => 'Tagalog',
            tur        => 'Turkish',
            ukr        => 'Ukranian',
            vie        => 'Vietnamese',
        );

        my @codes;
        if ( version->parse("v$version") > version->parse('v3.02') ) {
            my ( undef, $out, $err ) =
              Gscan2pdf::Document::exec_command(
                [ 'tesseract', '--list-langs' ] );
            @codes = split /\n/xsm, $err ? $err : $out;
            if ( $codes[0] =~ /^List[ ]of[ ]available[ ]languages/xsm ) {
                shift @codes;
            }
        }
        else {
            for ( glob "$tessdata/*$datasuffix" ) {

                # Weed out the empty language files
                if ( not -z ) {
                    if (/ ([\w\-]*) $datasuffix $/xsm) {
                        push @codes, $1;
                    }
                }
            }
        }

        for (@codes) {
            $logger->info("Found tesseract language $_");
            if ( defined $iso639{$_} ) {
                $languages{$_} = $iso639{$_};
            }
            else {
                $languages{$_} = $_;
            }
        }
    }
    return \%languages;
}

sub hocr {
    my ( $class, %options ) = @_;
    my ( $tif, $cmd, $name, $path, $txt );
    if ( not $setup ) { Gscan2pdf::Tesseract->setup( $options{logger} ) }

    if ( version->parse("v$version") >= version->parse('v3.03') ) {
        $name = 'stdout';
        $path = $EMPTY;
    }
    else {
        # Temporary filename for output
        my $suffix = '.txt';
        if ( version->parse("v$version") >= version->parse('v3') ) {
            $suffix = '.html';
        }
        $txt = File::Temp->new( SUFFIX => $suffix );
        ( $name, $path, undef ) = fileparse( $txt, $suffix );
    }

    if (
        (
            version->parse("v$version") < version->parse('v3')
            and $options{file} !~ /[.]tif$/xsm
        )
        or ( defined $options{threshold} and $options{threshold} )
      )
    {

        # Temporary filename for new file
        $tif = File::Temp->new( SUFFIX => '.tif' );
        my $image = Image::Magick->new;
        $image->Read( $options{file} );

        my $x;
        if ( defined $options{threshold} and $options{threshold} ) {
            $logger->info("thresholding at $options{threshold} to $tif");
            $image->BlackThreshold( threshold => "$options{threshold}%" );
            $image->WhiteThreshold( threshold => "$options{threshold}%" );
            $x = $image->Set( alpha => 'Off' );
            $x = $image->Quantize( colors => 2 );
            $x = $image->Write( depth => 1, filename => $tif );
        }
        else {
            $logger->info("writing temporary image $tif");
            $x = $image->Write( filename => $tif );
        }
        if ("$x") { $logger->warn($x) }
    }
    else {
        $tif = $options{file};
    }
    if ( version->parse("v$version") >= version->parse('v3.02.02') ) {
        $cmd = [
            'tesseract',        $tif, $path . $name, '-l',
            $options{language}, '-c', 'tessedit_create_hocr=1'
        ];
    }
    elsif ( version->parse("v$version") >= version->parse('v3') ) {
        $cmd =
          [
"echo tessedit_create_hocr 1 > hocr.config;tesseract $tif $path$name -l $options{language} +hocr.config;rm hocr.config"
          ];
    }
    elsif ( $options{language} ) {
        $cmd = [ 'tesseract', $tif, $path . $name, '-l', $options{language} ];
    }
    else {
        $cmd = [ 'tesseract', $tif, $path . $name ];
    }

    my ( undef, $out, $err ) =
      Gscan2pdf::Document::exec_command( $cmd, $options{pidfile} );
    my $warnings = ( $out ? $name ne 'stdout' : $EMPTY ) . $err;
    my $leading  = 'Tesseract Open Source OCR Engine';
    my $trailing = 'with Leptonica';
    $warnings =~ s/$leading v\d[.]\d\d $trailing\n//xsm;
    $warnings =~ s/^Page[ ][01]\n//xsm;

    if ( $name eq 'stdout' ) {
        return Encode::decode_utf8($out), $warnings;
    }
    return Gscan2pdf::Document::slurp($txt), $warnings;
}

1;

__END__
